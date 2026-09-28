"""处理独立资源点图，并从分层素材生成 16:9 地图预览。"""

from __future__ import annotations

import json
import random
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAP_DIR = ROOT / "assets" / "map"
SITE_DIR = MAP_DIR / "resource_sites"
SOURCE_DIR = SITE_DIR / "source"
BASE = MAP_DIR / "moonlit_resource_map_16x9_base.png"
PREVIEW = MAP_DIR / "moonlit_resource_map_16x9_preview.png"
BORDER_LAYER = MAP_DIR / "moonlit_resource_map_16x9_border_forest.png"
DATA = MAP_DIR / "moonlit_resource_map_16x9_sites.json"
PINE = ROOT / "assets" / "art_candidates" / "night_set_v1" / "pine_tree.png"
WIDTH, HEIGHT = 2880, 1620

SPRITES = {
    "forest": ("", "forest_resource.png", (512, 420)),
    "stone": ("stone_deposit_raw.png", "stone_deposit.png", (384, 240)),
    "iron": ("iron_deposit_raw.png", "iron_deposit.png", (384, 220)),
}

# 坐标按用户红圈区域映射到 2880×1620 的 16:9 地图。
SITES = [
    ("forest_02", "forest", "lumber_camp", 1119, 672, 78),
    ("forest_03", "forest", "lumber_camp", 1464, 792, 78),
    ("forest_04", "forest", "lumber_camp", 930, 861, 78),
    ("forest_05", "forest", "lumber_camp", 1257, 1240, 78),
    ("stone_01", "stone_deposit", "stone_mine", 1800, 390, 72),
    ("stone_02", "stone_deposit", "stone_mine", 1775, 610, 72),
    ("iron_01", "iron_deposit", "iron_mine", 2359, 904, 72),
    ("iron_02", "iron_deposit", "iron_mine", 1119, 448, 72),
]


def _crop_visible(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    visible = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
    if visible is None:
        raise ValueError("素材没有可见主体")
    left, top, right, bottom = visible
    return image.crop((max(0, left - 8), max(0, top - 8), min(image.width, right + 8), min(image.height, bottom + 8)))


def _process_sprite(kind: str) -> Image.Image:
    source_name, output_name, output_size = SPRITES[kind]
    if kind == "forest":
        return _build_forest_resource(output_name, output_size)
    image = Image.open(SOURCE_DIR / source_name).convert("RGBA")
    if kind == "stone":
        pixels = np.asarray(image, dtype=np.uint8).copy()
        red = pixels[:, :, 0].astype(np.int16)
        green = pixels[:, :, 1].astype(np.int16)
        blue = pixels[:, :, 2].astype(np.int16)
        magenta = (red > 150) & (blue > 150) & (green < 125) & (red > green * 1.5) & (blue > green * 1.5)
        pixels[:, :, 3] = np.where(magenta, 0, 255).astype(np.uint8)
        pixels[:, :, 0] = (pixels[:, :, 0].astype(np.float32) * 0.74).astype(np.uint8)
        pixels[:, :, 1] = (pixels[:, :, 1].astype(np.float32) * 0.79).astype(np.uint8)
        pixels[:, :, 2] = (pixels[:, :, 2].astype(np.float32) * 0.88).astype(np.uint8)
        image = Image.fromarray(pixels, "RGBA")
    image = _crop_visible(image).resize(output_size, Image.Resampling.LANCZOS)
    image.save(SITE_DIR / output_name)
    return image


def _build_forest_resource(output_name: str, output_size: tuple[int, int]) -> Image.Image:
    """复用边界松树，组成密集但保留中央建筑落点的树林资源点。"""
    pine = _crop_visible(Image.open(PINE).convert("RGBA"))
    forest = Image.new("RGBA", output_size, (0, 0, 0, 0))
    # x、脚点 y、高度。复用同源松树组成实心密林；建成伐木场后由运行时隐藏树丛。
    placements = [
        (60, 215, 190), (145, 205, 225), (256, 190, 250), (365, 205, 225), (452, 215, 190),
        (38, 305, 220), (128, 330, 250), (256, 320, 270), (384, 330, 250), (474, 305, 220),
        (58, 412, 225), (158, 420, 235), (256, 410, 245), (354, 420, 235), (454, 412, 225),
    ]
    for center_x, foot_y, height in sorted(placements, key=lambda value: value[1]):
        width = round(height * pine.width / pine.height * 1.12)
        sprite = pine.resize((width, height), Image.Resampling.LANCZOS)
        forest.alpha_composite(sprite, (round(center_x - width / 2), foot_y - height))
    forest.save(SITE_DIR / output_name)
    return forest


def _pine_placements() -> list[dict]:
    randomizer = random.Random(20260922)
    points: list[tuple[float, float]] = []
    for _ in range(340):
        points.append((randomizer.uniform(-20, WIDTH + 20), randomizer.uniform(-25, 170)))
    for _ in range(220):
        points.append((randomizer.uniform(-25, 190), randomizer.uniform(75, HEIGHT + 20)))
    for _ in range(180):
        points.append((randomizer.uniform(-20, 1220), randomizer.uniform(1480, HEIGHT + 25)))
    for _ in range(70):
        points.append((randomizer.uniform(2700, WIDTH + 20), randomizer.uniform(-20, 610)))
    return [
        {"x": round(x), "y": round(y), "height": randomizer.randint(64, 112)}
        for x, y in sorted(points, key=lambda point: point[1])
    ]


def main() -> None:
    base = Image.open(BASE).convert("RGBA")
    if base.size != (WIDTH, HEIGHT):
        raise ValueError(f"地图尺寸错误：{base.size}")
    processed = {kind: _process_sprite(kind) for kind in SPRITES}

    pine_source = Image.open(PINE).convert("RGBA")
    pine = _crop_visible(pine_source)
    border_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    objects: list[tuple[int, str, dict]] = []
    for index, item in enumerate(_pine_placements()):
        objects.append((item["y"], "border_pine", {"id": f"border_pine_{index:03d}", **item}))
    site_data: list[dict] = []
    for site_id, site_type, card_id, x, y, radius in SITES:
        kind = "forest" if site_type == "forest" else "stone" if site_type == "stone_deposit" else "iron"
        image_name = SPRITES[kind][1]
        item = {
            "id": site_id,
            "siteType": site_type,
            "requiredCardId": card_id,
            "position": {"x": x, "y": y},
            "placementRadius": radius,
            "sprite": f"assets/map/resource_sites/{image_name}",
            "spriteAnchor": "center_bottom",
            "spriteDisplaySize": {"width": 218 if kind == "forest" else 130, "height": 178 if kind == "forest" else 82},
            "buildingPad": {"shape": "circle", "cx": 0.5, "cy": 0.78, "radius": 0.2} if kind == "forest" else None,
            "occupiedVisualPolicy": "hide_resource_sprite" if kind == "forest" else "keep_behind_building",
            "collision": "待地形与寻路规则确定",
        }
        site_data.append(item)
        objects.append((y, "site", {"kind": kind, **item}))

    for _, object_type, item in sorted(objects, key=lambda value: value[0]):
        if object_type == "border_pine":
            height = item["height"]
            width = round(height * pine.width / pine.height * 1.12)
            sprite = pine.resize((width, height), Image.Resampling.LANCZOS)
            x = item["x"] - width // 2
            y = item["y"] - height
            border_layer.alpha_composite(sprite, (x, y))
        else:
            size = item["spriteDisplaySize"]
            sprite = processed[item["kind"]].resize((size["width"], size["height"]), Image.Resampling.LANCZOS)
            x = item["position"]["x"] - size["width"] // 2
            y = item["position"]["y"] - size["height"]
        base.alpha_composite(sprite, (x, y))

    base.convert("RGB").save(PREVIEW)
    border_layer.save(BORDER_LAYER)
    DATA.write_text(
        json.dumps(
            {
                "version": 1,
                "mapSize": {"width": WIDTH, "height": HEIGHT},
                "base": "assets/map/moonlit_resource_map_16x9_base.png",
                "borderTreeSprite": "assets/art_candidates/night_set_v1/pine_tree.png",
                "borderPines": _pine_placements(),
                "resourceSites": site_data,
                "borderForest": "assets/map/moonlit_resource_map_16x9_border_forest.png",
                "note": "资源点和边界树林作为独立运行时图层接入；底图不含道路。",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"生成 {PREVIEW.name}：{len(site_data)} 处资源点")


if __name__ == "__main__":
    main()
