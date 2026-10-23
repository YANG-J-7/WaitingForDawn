"""主城生成素材的确定性清理、根部对齐和轮廓投影，不绘制原始美术。"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/buildings/town_hall_v2'


def build():
    body = Image.open(OUT / 'processed/body/raw-sheet-clean.png').convert('RGBA')
    bbox = body.getbbox()
    body = body.crop(bbox)
    # 严格清理色键边缘残留的孤立高饱和洋红点。
    body.putdata([(r,g,b,0) if r>180 and b>180 and r>g+70 and b>g+70 else (r,g,b,a)
                  for r,g,b,a in body.get_flattened_data()])
    body.save(OUT / 'body.png')
    bw, bh = body.size
    # 按原稿坐标标注附着点，裁边后换算；运行仅使用归一化的建筑局部坐标。
    raw_points = {'flag': (690, 111), 'fire_left': (500, 851),
                  'fire_right': (670, 910), 'smoke': (1030, 382)}
    anchors = {k: [(x-bbox[0])/bw, (y-bbox[1])/bh] for k, (x, y) in raw_points.items()}
    records = {}
    for name in ['flag', 'flame', 'smoke']:
        frames = []
        roots = []
        folder = OUT / name
        folder.mkdir(exist_ok=True)
        meta = json.loads((OUT / f'processed/{name}/pipeline-meta.json').read_text())
        for gate in ['empty_frames', 'output_edge_touch_frames', 'paste_clamped_frames']:
            assert not meta[gate], (name, gate)
        for index in range(4):
            frame = Image.open(OUT / f'processed/{name}/{name}-{index+1}.png').convert('RGBA')
            pix = frame.load()
            box = frame.getbbox()
            if name == 'flag':
                # 左侧金色绑点的中点锁定旗杆；只平移，不逐帧缩放。
                points = [(x,y) for y in range(256) for x in range(box[0], box[0]+9)
                          if pix[x,y][0]>110 and pix[x,y][1]>65 and pix[x,y][2]<110 and pix[x,y][3]>180]
                assert points, '旗帜缺少金色固定点'
                root = (min(x for x,y in points), (min(y for x,y in points)+max(y for x,y in points))/2)
                target = (48, 128)
            else:
                bottom = box[3]-1
                xs = [x for x in range(box[0],box[2]) if pix[x,bottom][3]>0]
                root = (sum(xs)/len(xs), bottom)
                target = (128, 232)
            shift = (round(target[0]-root[0]), round(target[1]-root[1]))
            aligned = Image.new('RGBA', frame.size)
            aligned.alpha_composite(frame, shift)
            if name == 'smoke':
                # 洋红底的半透明烟边缘会残留紫色，去色并统一为冷蓝灰。
                cleaned = []
                for r,g,b,a in aligned.get_flattened_data():
                    light = round(.25*r + .50*g + .25*b)
                    cleaned.append((round(light*.78),round(light*.88),light,a))
                aligned.putdata(cleaned)
            assert aligned.getbbox()[0]>0 and aligned.getbbox()[2]<256
            assert aligned.getbbox()[1]>0 and aligned.getbbox()[3]<256
            aligned.save(folder / f'{index}.png')
            frames.append(aligned)
            roots.append({'before': root, 'shift': shift, 'target': target})
        frames[0].save(folder / 'preview.gif', save_all=True, append_images=frames[1:],
                       duration={'flag':230,'flame':120,'smoke':400}[name], loop=0, disposal=2)
        records[name] = {'roots': roots, 'qc': meta['qc_summary']}
    # 由建筑alpha推导投影。左上月光使上部向右下投射，绝不增加玩法占地。
    # 世界输出矩形(-100,-10,290,70)，源点投影 x=-90+180u+55(1-v), y=-4+45(1-v)。
    sw, sh = 1160, 280
    alpha = body.getchannel('A')
    projected = alpha.transform((sw,sh), Image.Transform.AFFINE,
        (bw/720, -bw*55/(180*180), bw*(-10+55*6/45)/180,
         0, -bh/180, bh*(1+6/45)), Image.Resampling.BICUBIC)
    projected = projected.filter(ImageFilter.GaussianBlur(5))
    projected = projected.point(lambda a: round(a*.36))
    shadow = Image.new('RGBA', (sw,sh), (6,15,26,0))
    shadow.putalpha(projected)
    shadow.save(OUT/'cast-shadow.png')
    # 建筑下缘alpha经竖向压缩作为接触影，轮廓与建筑脚部一致。
    contact = alpha.crop((0, int(bh*.75), bw, bh)).resize((720,100),Image.Resampling.LANCZOS)
    contact = contact.filter(ImageFilter.GaussianBlur(4)).point(lambda a: round(a*.42))
    img = Image.new('RGBA',contact.size,(5,13,22,0)); img.putalpha(contact)
    img.save(OUT/'contact-shadow.png')
    record = {'status':'runtime_candidate','body_bbox':bbox,'body_size':[bw,bh],
              'anchors': anchors, 'display_size':[180,176], 'animations':records,
              'sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in sorted((OUT/'source').glob('*'))}}
    (OUT/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'body_size':[bw,bh],'anchors':anchors,'qc':{k:v['qc'] for k,v in records.items()}},ensure_ascii=False))


if __name__ == '__main__':
    build()
