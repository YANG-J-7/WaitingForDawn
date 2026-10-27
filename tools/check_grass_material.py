"""验证高清草地的原生尺寸、闭合边缘、来源与确定性重建。"""
import json
import sys
sys.dont_write_bytecode = True
import numpy as np
from PIL import Image
from build_grass_material import ROOT, OUT, SOURCE, MAP, build, sha

before = {p.name: sha(p) for p in OUT.iterdir() if p.suffix in [".png", ".json"]}
build()
after = {p.name: sha(p) for p in OUT.iterdir() if p.suffix in [".png", ".json"]}
assert before == after, "重建产物不一致"
record = json.loads((OUT / "material-record.json").read_text(encoding="utf-8"))
assert record["source_sha256"] == sha(SOURCE)
for name, digest in record["map_sources"].items():
    assert sha(MAP / name) == digest
detail = np.asarray(Image.open(OUT / "detail.png"))
assert detail.shape == (1086, 1448, 3)
assert np.array_equal(detail[0], detail[-1]) and np.array_equal(detail[:,0], detail[:,-1])
assert 1.6 * 4 / record["texels_per_world_pixel"] < 1
packed = Image.open(OUT / "macro-mask.png")
assert packed.size == (1764, 720) and packed.mode == "RGBA"
mask = np.asarray(packed)[:,:,3]
assert mask[300,300] == 255
assert mask[225,1450] == 0 and mask[600,1625] == 0
for name, digest in record["outputs"].items():
    assert sha(OUT / name) == digest
print("PASS: 3项产物确定性、源稿/旧地图哈希、原生尺寸、双向闭合、4K像素预算、遮罩及产物哈希")

# 实际GL像素中的材质周期相关性；排除地图颜色低频影响后测量。
folder = ROOT / "tests/reports/images/grass-static-2026-10-27"
if (folder / "chunk-crossing-max.png").exists():
    from PIL import ImageFilter
    image = Image.open(folder / "chunk-crossing-max.png").convert("L")
    residual = np.asarray(image,dtype=float)-np.asarray(image.filter(ImageFilter.GaussianBlur(12)),dtype=float)
    correlations = {}
    for name, shift, axis in [("horizontal_216_world",461,1),("vertical_162_world",346,0)]:
        a = np.take(residual,range(residual.shape[axis]-shift),axis=axis).ravel()
        b = np.take(residual,range(shift,residual.shape[axis]),axis=axis).ravel()
        correlation = float(np.corrcoef(a,b)[0,1])
        assert abs(correlation) < .1, f"出现原纹理周期重复：{name}={correlation}"
        correlations[name] = correlation
    (folder / "material-checks.json").write_text(json.dumps(dict(
        result="通过", deterministic_outputs=before, repetition_correlation=correlations,
        note="两种原纹理周期的像素相关性检查，不替代美术复核或长时间漫游"),
        ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("PASS: 实际画面原纹理横/纵周期相关性均低于0.1", correlations)
