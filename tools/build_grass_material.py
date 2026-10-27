"""将已生成的细草原稿处理为高清细节与地图色域遮罩，不绘制新草叶。"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/art/concepts/grass-redesign-2026-10-26/detail-native.png"
MAP = ROOT / "assets/map/dawn_wide_v3"
OUT = ROOT / "assets/map/grass_hd_v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGB")
    # 分离草叶和低频底色，运行时由原地图提供连续地貌颜色。
    detail = np.asarray(source, dtype=np.float32) - np.asarray(
        source.filter(ImageFilter.GaussianBlur(40)), dtype=np.float32) + 128.0
    # 只在边缘40像素内对称混合，闭合纹理边界；不放大原稿。
    for axis in [0, 1]:
        original = detail.copy()
        for distance in range(40):
            weight = 0.5 * (1.0 - distance / 40.0) ** 2
            near = [slice(None)] * 3
            far = [slice(None)] * 3
            near[axis], far[axis] = distance, -1 - distance
            a, b = tuple(near), tuple(far)
            detail[a] = original[a] * (1 - weight) + original[b] * weight
            detail[b] = original[b] * (1 - weight) + original[a] * weight
    pixels = np.clip(np.rint(detail), 0, 255).astype(np.uint8)
    assert np.array_equal(pixels[0], pixels[-1])
    assert np.array_equal(pixels[:, 0], pixels[:, -1])
    Image.fromarray(pixels).save(OUT / "detail.png")

    # RGBA打包地图低频颜色和既有平原保护遮罩；缩小前向内收4像素，
    # 避免双线性采样越过山区保护边缘。遮罩只用于渲染，不参与玩法。
    base = Image.open(MAP / "base.png").convert("RGB")
    macro = base.filter(ImageFilter.GaussianBlur(32)).resize((1764, 720), Image.Resampling.LANCZOS)
    mask = Image.open(MAP / "plain-material-mask-v2.png").convert("L")
    mask = mask.filter(ImageFilter.MinFilter(9)).resize(macro.size, Image.Resampling.BOX)
    macro.putalpha(mask)
    macro.save(OUT / "macro-mask.png")
    record = dict(
        date="2026-10-27", generator="内置 image_gen（既有原稿）",
        source=str(SOURCE.relative_to(ROOT)).replace("\\", "/"), source_sha256=sha(SOURCE),
        native_size=list(source.size), world_coverage=[216, 162],
        texels_per_world_pixel=source.width / 216, world_size=[7056, 2880],
        processing="40像素低频分离、40像素边缘闭合；未放大、未程序绘制草叶",
        layout="世界坐标三角格混合三个固定随机偏移；不旋转月光方向；不按地图片重新铺纹理",
        scope="既有平原草地遮罩内；山区、岩缘、湖岸和导航保持",
        animation="静态接入阶段；无昆虫、无时间位移；后续全草地风动另行设计",
        map_sources={n: sha(MAP / n) for n in ["base.png", "plain-material-mask-v2.png"]},
        outputs={n: sha(OUT / n) for n in ["detail.png", "macro-mask.png"]})
    (OUT / "material-record.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record, ensure_ascii=False))


if __name__ == "__main__":
    build()
