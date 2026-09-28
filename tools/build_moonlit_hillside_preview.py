"""用独立松树素材与地面底图生成大地图预览及摆放数据。"""

from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAP_DIR = ROOT / "assets" / "map"
BASE = MAP_DIR / "moonlit_hillside_lake_large_base.png"
TREE = ROOT / "assets" / "art_candidates" / "night_set_v1" / "pine_tree.png"
PREVIEW = MAP_DIR / "moonlit_hillside_lake_large_preview.png"
PLACEMENTS = MAP_DIR / "moonlit_hillside_lake_large_props.json"
WIDTH, HEIGHT = 2800, 1200


def main() -> None:
    rng = random.Random(20260922)
    base = Image.open(BASE).convert("RGBA")
    if base.size != (WIDTH, HEIGHT):
        raise ValueError(f"地图底图尺寸错误：{base.size}")

    source = Image.open(TREE).convert("RGBA")
    alpha = source.getchannel("A")
    visible = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
    if visible is None:
        raise ValueError("松树素材没有可见主体")
    tree = source.crop(visible)

    points: list[tuple[float, float]] = []
    for _ in range(325):
        points.append((rng.uniform(-15, WIDTH + 15), rng.uniform(-30, 160)))
    for _ in range(170):
        points.append((rng.uniform(-25, 185), rng.uniform(40, HEIGHT + 20)))
    for _ in range(150):
        points.append((rng.uniform(-20, 1050), rng.uniform(1060, HEIGHT + 30)))
    for _ in range(55):
        points.append((rng.uniform(2620, WIDTH + 20), rng.uniform(-20, 410)))

    props: list[dict] = []
    for index, (x, y) in enumerate(sorted(points, key=lambda point: point[1])):
        height = rng.randint(62, 112)
        width = round(height * tree.width / tree.height * 1.12)
        sprite = tree.resize((width, height), Image.Resampling.LANCZOS)
        x_px = round(x - width / 2)
        y_px = round(y - height)
        base.alpha_composite(sprite, (x_px, y_px))
        props.append(
            {
                "id": f"border_pine_{index:03d}",
                "image": "assets/art_candidates/night_set_v1/pine_tree.png",
                "x": round(x),
                "y": round(y),
                "w": width,
                "h": height,
                "sortY": round(y),
                "layer": "props",
                "occlusionClass": "tall",
                "actorSafeArea": {
                    "shape": "ellipse",
                    "cx": 0.5,
                    "cy": 0.91,
                    "rx": 0.16,
                    "ry": 0.07,
                },
                "occupantPolicy": {"mode": "y_sort"},
            }
        )

    base.convert("RGB").save(PREVIEW)
    PLACEMENTS.write_text(
        json.dumps(
            {
                "version": 1,
                "mapSize": {"width": WIDTH, "height": HEIGHT},
                "base": "assets/map/moonlit_hillside_lake_large_base.png",
                "sourceTree": "assets/art_candidates/night_set_v1/pine_tree.png",
                "props": props,
                "note": "视觉候选摆放；树林、湖泊与山坡尚未定义通行和建造规则。",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"生成预览：{PREVIEW}，松树 {len(props)} 棵")


if __name__ == "__main__":
    main()
