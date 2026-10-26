"""验证底座来源、确定性重建、透明边缘和运行尺寸；不替代真实画面复核。"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
from build_town_hall_base import build

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/buildings/town_hall_v2/ground-base'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


paths = [OUT / 'ground-base.png', OUT / 'manifest.json']
before = [digest(p) for p in paths]
build()
assert before == [digest(p) for p in paths], '底座重建不一致'
meta = json.loads(paths[1].read_text(encoding='utf-8'))
assert meta['display_rect'] == [-166, -120, 320, 198]
for path, value in meta['sources'].items():
    assert digest(OUT / path) == value, path
image = Image.open(paths[0]).convert('RGBA')
assert image.size == (1280, 792)
pixels = np.asarray(image).astype(np.int16)
alpha = pixels[:, :, 3]
assert not alpha[0, :].any() and not alpha[-1, :].any()
assert not alpha[:, 0].any() and not alpha[:, -1].any()
assert alpha.max() == 255 and (alpha == 0).mean() > .30
assert ((alpha > 0) & (alpha < 255)).sum() / (alpha > 0).sum() > .18, '可见草缘缺少透明过渡'
magenta = (pixels[:, :, 0] > pixels[:, :, 1] + 15) & (pixels[:, :, 2] > pixels[:, :, 1] + 15)
assert not (magenta & (alpha > 0)).any(), '草缘残留紫边'
assert alpha[492, 582] > 200, '台阶附近地面中空'
for wx, wy in [(-112,-70), (-108,-45), (-104,-25)]:
    px, py = round((wx+166)*4), round((wy+120)*4)
    assert alpha[py-6:py+7, px-6:px+7].mean() > 40, '左墙侧后草缘断开'
record = json.loads((OUT / 'source/generation-record.json').read_text(encoding='utf-8'))
assert digest(OUT / 'source/raw.png') == record['sha256']
for reference in record['references']:
    assert digest(ROOT / reference['path']) == reference['sha256']
rear_record = json.loads((OUT / 'source/rear-left.generation-record.json').read_text(encoding='utf-8'))
assert digest(OUT / 'source/rear-left-raw-v2.png') == rear_record['selected']['sha256']
for reference in rear_record['selected']['references']:
    assert digest(ROOT / reference['path']) == reference['sha256']
# 生成底色存在轻微色差，用色键色域判断四边没有草/石主体，不要求每像素等于FF00FF。
for name in ['raw.png', 'rear-left-raw-v2.png']:
    raw = np.asarray(Image.open(OUT / 'source' / name).convert('RGB'))
    for edge in [raw[0, :, :], raw[-1, :, :], raw[:, 0, :], raw[:, -1, :]]:
        assert np.all(edge[:, 0] > 200) and np.all(edge[:, 1] < 60) and np.all(edge[:, 2] > 200), (name, '原稿触边')
print('PASS: 底座确定性、来源哈希、画布/运行尺寸、四边透明、渐疏草缘、紫边和台阶地面检查通过')
