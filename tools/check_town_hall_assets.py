"""核查主城运行素材、透明边缘、锚点和确定性重建。"""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
sys.dont_write_bytecode = True
from build_town_hall import build

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/buildings/town_hall_v2'
paths = [OUT/'body.png',OUT/'cast-shadow.png',OUT/'contact-shadow.png',OUT/'manifest.json']
paths += [OUT/name/f'{i}.png' for name in ['flag','flame','smoke'] for i in range(4)]
before = {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
build()
assert before == {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}, '重建不一致'
for p in paths:
    if p.suffix != '.png':
        continue
    image = Image.open(p).convert('RGBA')
    assert image.getextrema()[3][0] == 0, (p,'缺少透明背景')
    assert image.getbbox() is not None
    fringe = sum(1 for r,g,b,a in image.get_flattened_data()
                 if a>64 and r>180 and b>180 and r>g+70 and b>g+70)
    assert fringe == 0, (p,'残留洋红',fringe)
for name in ['flag','flame','smoke']:
    images = [Image.open(OUT/name/f'{i}.png') for i in range(4)]
    assert len({hashlib.sha256(i.tobytes()).hexdigest() for i in images}) == 4
    for image in images:
        x0,y0,x1,y1 = image.getbbox()
        assert 0<x0<x1<256 and 0<y0<y1<256
    meta = json.loads((OUT/f'processed/{name}/pipeline-meta.json').read_text())
    assert not any(meta[g] for g in ['empty_frames','output_edge_touch_frames','paste_clamped_frames'])
manifest = json.loads((OUT/'manifest.json').read_text())
for file, digest in manifest['sources'].items():
    assert hashlib.sha256((OUT/'source'/file).read_bytes()).hexdigest() == digest
for name, data in manifest['animations'].items():
    assert all(max(abs(v-round(v)) for v in item['shift']) == 0 for item in data['roots'])
print('PASS: 主城16项产物确定性重建、透明边缘、12帧差异/边界、严格QC及源文件哈希核查通过')
