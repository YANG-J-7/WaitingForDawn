"""为7056×2880地图准备带重叠的参考裁图；不绘制最终美术。"""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/map_kits/reference_hd_20261102'
SOURCE = OUT / 'source'
SOURCE.mkdir(parents=True, exist_ok=True)
reference = Path('C:/Users/y1971/AppData/Local/Temp/codex-clipboard-a702c2f0-25d8-444b-9002-00a26aec8563.png')
shutil.copy2(reference, SOURCE / 'user-reference.png')
im = Image.open(reference).convert('RGB')
regions = []
for row in range(3):
    for col in range(6):
        core = (col * 1176, row * 960, (col + 1) * 1176, (row + 1) * 960)
        rect = (max(0, core[0]-72), max(0, core[1]-72), min(7056, core[2]+72), min(2880, core[3]+72))
        crop = tuple(round(v * im.size[i % 2] / (7056 if i % 2 == 0 else 2880)) for i, v in enumerate(rect))
        name = f'region-{col}-{row}'
        im.crop(crop).save(SOURCE / f'{name}-reference.png')
        regions.append({'id': name, 'core': core, 'rect': rect, 'reference': f'source/{name}-reference.png', 'source': f'source/{name}.png'})
manifest = {'version': 1, 'world_size': [7056,2880], 'reference_size': list(im.size), 'reference_sha256': hashlib.sha256(reference.read_bytes()).hexdigest(), 'regions': regions, 'generation_source': 'builtin_imagegen', 'status': '待生成，不接入运行'}
(OUT / 'production.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'已准备{len(regions)}个重叠参考区块')
