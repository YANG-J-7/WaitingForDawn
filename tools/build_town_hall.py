"""主城生成素材的确定性清理、根部对齐和轮廓投影，不绘制原始美术。"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageFilter, ImageChops
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/buildings/town_hall_v2'


def build_shadows(body):
    """从同一主体的alpha提取每列墙脚，再投到地面；不把脚点压到水平线上。"""
    bw, bh = body.size
    alpha = np.asarray(body.getchannel('A'))
    occupied = alpha >= 180
    feet = bh - 1 - np.argmax(occupied[::-1], axis=0)
    # 灯笼等悬挂物不能成为地面接触点；只用下部确有墙脚的列。
    valid = occupied.any(axis=0) & (feet > bh * .78)
    origin = (-108, -54)
    size = (304, 144)
    density = 4
    sw, sh = size[0] * density, size[1] * density
    yy, xx = np.indices(alpha.shape)
    height = np.maximum(0, (feet[None, :] - yy) * 176 / bh)
    ground_y = -176 + feet * 176 / bh
    world_x = -90 + xx * 180 / bw
    projected_x = np.rint((world_x + height * .58 - origin[0]) * density).astype(int)
    projected_y = np.rint((ground_y[None, :] + height * .44 - origin[1]) * density).astype(int)
    inside = (alpha > 0) & valid[None, :] & (projected_x >= 0) & (projected_x < sw) & (projected_y >= 0) & (projected_y < sh)
    cast = np.zeros((sh, sw), dtype=np.uint8)
    # 近端较实，远端略淡；最大值合成避免同一建筑的投影自我叠黑。
    strength = alpha * (.62 - .14 * np.minimum(height / 176, 1))
    np.maximum.at(cast, (projected_y[inside], projected_x[inside]), strength[inside].astype(np.uint8))
    cast = Image.fromarray(cast).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(7))
    shadow = Image.new('RGBA', (sw, sh), (3, 10, 18, 0))
    shadow.putalpha(cast)
    shadow.save(OUT / 'cast-shadow.png')

    # 每列最下缘形成接触带，保留透视底边和台阶形状，向外露出约4～6世界像素。
    contact = np.zeros((sh, sw), dtype=np.uint8)
    edge = inside & (yy >= feet[None, :] - bh * .035)
    contact_x = np.rint((world_x - origin[0]) * density).astype(int)
    contact_y = np.rint((-176 + yy * 176 / bh + 1.5 - origin[1]) * density).astype(int)
    np.maximum.at(contact, (contact_y[edge], contact_x[edge]), alpha[edge])
    contact = Image.fromarray(contact).filter(ImageFilter.MaxFilter(9))
    core = contact.filter(ImageFilter.GaussianBlur(5)).point(lambda a: round(a * .76))
    soft = contact.filter(ImageFilter.GaussianBlur(18)).point(lambda a: round(a * .26))
    shadow.putalpha(ImageChops.lighter(core, soft))
    shadow.save(OUT / 'contact-shadow.png')
    return {'origin': list(origin), 'size': list(size), 'pixels_per_world_unit': density,
            'method': '逐列墙脚alpha接触带与右下投影', 'direction': [.58, .44]}


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
    shadows = build_shadows(body)
    record = {'status':'runtime_candidate','body_bbox':bbox,'body_size':[bw,bh],
              'anchors': anchors, 'display_size':[180,176], 'animations':records, 'shadows':shadows,
              'sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in sorted((OUT/'source').glob('*')) if p.suffix != '.import'}}
    (OUT/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'body_size':[bw,bh],'anchors':anchors,'qc':{k:v['qc'] for k,v in records.items()}},ensure_ascii=False))


if __name__ == '__main__':
    build()
