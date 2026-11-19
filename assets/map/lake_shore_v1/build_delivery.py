"""仅处理已生成图片：裁去透明留白、拼铺检查、记录来源与打包。"""
from pathlib import Path
from PIL import Image
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent
water = Image.open(ROOT / 'water-raw.png').convert('RGB')
water.save(ROOT / 'water.png')
shore = Image.open(ROOT / 'processed/raw-sheet-clean.png').convert('RGBA')
# 只清理红蓝同时明显高于绿色的品红残边，保留正常灰蓝岩石。
pixels = list(shore.get_flattened_data())
removed = sum(a>0 and r>90 and r>g+45 and b>g+45 for r,g,b,a in pixels)
shore.putdata([(0,0,0,0) if a>0 and r>90 and r>g+45 and b>g+45 else (r,g,b,a) for r,g,b,a in pixels])
box = shore.getbbox()
assert box is not None
box = (max(0, box[0]-8), max(0, box[1]-8), min(shore.width, box[2]+8), min(shore.height, box[3]+8))
shore = shore.crop(box)
shore.save(ROOT / 'shore-transparent.png')
repeat = Image.new('RGB', (water.width*2, water.height*2))
for y in range(2):
    for x in range(2):
        repeat.paste(water, (x*water.width, y*water.height))
        assert repeat.crop((x*water.width,y*water.height,(x+1)*water.width,(y+1)*water.height)).tobytes() == water.tobytes()
repeat.save(ROOT / 'water-repeat-2x2.png')

def edge_mae(pairs):
    values = [abs(a-b) for p,q in pairs for a,b in zip(p,q)]
    return round(sum(values)/len(values), 4)

seams = {
    'left_right_rgb_mean_absolute_difference': edge_mae((water.getpixel((0,y)),water.getpixel((water.width-1,y))) for y in range(water.height)),
    'top_bottom_rgb_mean_absolute_difference': edge_mae((water.getpixel((x,0)),water.getpixel((x,water.height-1))) for x in range(water.width)),
    'strict_seamless_verified': False,
    '说明': '生成原稿自然拼铺候选；未做周期闭边，不将拼铺预览视为严格无缝证明。',
}
alpha = shore.getchannel('A')
assert alpha.getextrema() == (0,255)
assert all(alpha.getpixel((x,y)) == 0 for x in range(shore.width) for y in (0,shore.height-1))
assert all(alpha.getpixel((x,y)) == 0 for y in range(shore.height) for x in (0,shore.width-1))
assert not any(a>0 and r>180 and b>180 and g<100 for r,g,b,a in shore.get_flattened_data())
meta = json.loads((ROOT/'processed/pipeline-meta.json').read_text(encoding='utf-8'))
assert not any(meta[k] for k in ('empty_frames','source_edge_touch_frames','output_edge_touch_frames','paste_clamped_frames'))
preview = Image.open(ROOT/'combination-preview.png')
record = {
    'id':'ASSET-0019','日期':'2026-11-12','status':'candidate','integrated':False,
    'generator':'built-in-image_gen','说明':'两份独立素材及一张参考生成的组合效果图；组合图不是引擎截图或确定性装配证据。',
    '原生尺寸':{'water':list(water.size),'shore_raw':[1774,887],'preview':list(preview.size)},
    '湖岸交付尺寸':list(shore.size),'湖岸裁切框':box,'品红残边清理像素数':removed,'water_qc':seams,
    '来源':{
        'water':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-b376b89f-fc40-4846-b168-3560d91f313e.png',
        'shore':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-d0717717-795a-49b0-94f7-b07b9109304a.png',
        'preview':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-508525ce-c12b-40b7-92a7-9dba2b9b417f.png'},
    'checks':{'png_decode':True,'repeat_crops_exact':True,'shore_alpha_range':[0,255],'shore_border_clear':True,'no_visible_magenta':True,'processor_strict_qc':True},
    '待验':'最终观感、岸段连接、与现有草地真实拼接、严格水面无缝、Godot导入和通行数据均待后续。',
}
files = ['water-raw.png','shore-raw.png','water.png','shore-transparent.png','combination-preview.png','reference.png','water-prompt.txt','shore-prompt.txt','preview-prompt.txt']
record['sha256']={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}
record['草地参考sha256']=hashlib.sha256((ROOT.parent/'grass_variants_v1/grass.png').read_bytes()).hexdigest()
(ROOT/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(ROOT/'lake-shore-v1.zip','w',zipfile.ZIP_DEFLATED) as bundle:
    for name in ['water.png','shore-transparent.png','combination-preview.png','water-repeat-2x2.png','water-prompt.txt','shore-prompt.txt','preview-prompt.txt','manifest.json','README.md']:
        bundle.write(ROOT/name,name)
with zipfile.ZipFile(ROOT/'lake-shore-v1.zip') as bundle:
    assert bundle.testzip() is None
print(json.dumps({'checks':record['checks'],'sizes':record['原生尺寸'],'shore':shore.size,'seams':seams},ensure_ascii=False))
