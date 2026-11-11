"""校验已装配贴图并制作审阅图；不绘制或修改交付贴图的美术像素。"""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/map/grass_variants_v1"
NAMES = ("grass", "small-stones", "boulders", "wildflowers")
LABELS = ("纯草地", "小碎石", "大石头", "野草与花")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    sources = {"grass": ROOT / "assets/map/grass_reference_v3/grass.png"}
    sources.update({name: PACK / "source" / f"{name}.png" for name in NAMES[1:]})
    images = {}
    checks = 0
    for name, source in sources.items():
        with Image.open(source) as raw:
            raw.verify()
        target = PACK / f"{name}.png"
        images[name] = Image.open(target).convert("RGB")
        assert images[name].size == (1254, 1254), f"尺寸不一致：{name}"
        assert ImageStat.Stat(images[name]).stddev[1] > 5, f"图像为空或单色：{name}"
        checks += 2
        if name != "grass":
            assert (PACK / "source" / f"{name}.prompt.txt").stat().st_size > 100
            assert (PACK / "references" / f"{name}.png").is_file()
            checks += 2
        assert source.is_file() and sha(source) != sha(target), f"尚未经过共同边缘装配：{name}"
        checks += 1
    assert len({sha(PACK / f"{name}.png") for name in NAMES}) == 4
    checks += 1

    # 直接拼接实际交付贴图，检查图不额外对接边进行混合。
    n = 1254
    layout = [[0, 1, 2, 3], [1, 0, 3, 2], [2, 3, 0, 1], [3, 2, 1, 0]]
    mixed = Image.new("RGB", (n * 4, n * 4))
    for y, row in enumerate(layout):
        for x, index in enumerate(row):
            mixed.paste(images[NAMES[index]], (x * n, y * n))
    mixed.save(PACK / "mixed-tiling-full.png")
    mixed.resize((1600, 1600), Image.Resampling.LANCZOS).save(PACK / "mixed-tiling-preview.png")
    mixed.crop((n - 256, n - 256, n + 256, n + 256)).save(PACK / "four-corner-native.png")

    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 28)
    board = Image.new("RGB", (1600, 456), "#0b1724")
    draw = ImageDraw.Draw(board)
    for i, name in enumerate(NAMES):
        board.paste(images[name].resize((400, 400), Image.Resampling.LANCZOS), (i * 400, 56))
        draw.text((i * 400 + 16, 10), LABELS[i], font=font, fill="#d7e7e5")
    board.save(PACK / "contact-sheet.png")

    # 全部有向组合的末行/列差与64像素窄带均色差仅作辅助指标。
    pairs = []
    for a in NAMES:
        for b in NAMES:
            ia, ib = images[a], images[b]
            def diff(box_a, box_b):
                return [round(v, 4) for v in ImageStat.Stat(ImageChops.difference(ia.crop(box_a), ib.crop(box_b))).mean]
            def band(box_a, box_b):
                ma, mb = ImageStat.Stat(ia.crop(box_a)).mean, ImageStat.Stat(ib.crop(box_b)).mean
                return [round(abs(u-v), 4) for u, v in zip(ma, mb)]
            pairs.append({"from": a, "to": b,
                "horizontal_edge_rgb_mae": diff((n-1, 0, n, n), (0, 0, 1, n)),
                "vertical_edge_rgb_mae": diff((0, n-1, n, n), (0, 0, n, 1)),
                "horizontal_band_mean_delta": band((n-64, 0, n, n), (0, 0, 64, n)),
                "vertical_band_mean_delta": band((0, n-64, n, n), (0, 0, n, 64))})
            for edge_a, edge_b in [((n-1, 0, n, n), (0, 0, 1, n)), ((0, n-1, n, n), (0, 0, n, 1))]:
                extrema = ImageChops.difference(ia.crop(edge_a), ib.crop(edge_b)).getextrema()
                assert max(v[1] for v in extrema) <= 1, f"接边超出8位量化容差：{a}/{b}"
                checks += 1
            checks += 1
    report = {"date": "2026-11-11", "automated_checks": checks, "pair_count": len(pairs),
        "pixel_exact_seamless": False, "max_edge_channel_delta_8bit": 1,
        "preview_policy": "实际交付贴图直接拼接，不额外混合接边；缩略图仅供审阅，不作为交付纹理",
        "pairs": pairs}
    (PACK / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest = {"date": "2026-11-11", "status": "candidate", "generator": "built-in-image_gen",
        "base_approved": "ASSET-0016", "scope": "静态素材与拼铺审阅，正式地图未迁移", "animation": False,
        "native_size": [n, n], "processing": "内置图像生成原稿保持；Godot静态材质使用共同底草偏移采样与边缘过渡装配四款交付PNG",
        "assembly": "res://tools/assemble_grass_variant_tiles.gd",
        "assembly_shader": "res://tools/assemble_grass_variant_tiles.gdshader",
        "edge_policy": "四款共同周期边缘；16有向组合水平和垂直端点每通道最大差不超过1/255", "assets": [
            {"id": name, "file": f"{name}.png", "sha256": sha(PACK / f"{name}.png"),
             "source": str(sources[name].relative_to(ROOT)).replace("\\", "/"),
             "source_sha256": sha(sources[name]),
             "prompt": f"source/{name}.prompt.txt" if name != "grass" else "../grass_reference_v3/grass.prompt.txt"}
            for name in NAMES]}
    (PACK / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {checks} checks; 16 directed pairs; 32 edge joins within 1/255")


if __name__ == "__main__":
    main()
