"""裁出重叠精修参考并拼接生成地形；只处理生成素材，不绘制岩石、水面或草地。"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


WORLD_SIZE = (2880, 1620)
NATIVE_SIZE = (3344, 1882)
OVERLAP = 64


def regions(size: tuple[int, int]) -> list[tuple[int, int, int, int]]:
    width, height = size
    return [
        (max(0, x * width // 2 - OVERLAP), max(0, y * height // 2 - OVERLAP),
         min(width, (x + 1) * width // 2 + OVERLAP), min(height, (y + 1) * height // 2 + OVERLAP))
        for y in range(2) for x in range(2)
    ]


def prepare(source_path: Path, output_dir: Path) -> None:
    source = Image.open(source_path).convert("RGB")
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, box in enumerate(regions(source.size), 1):
        source.crop(box).save(output_dir / f"region-{index}-reference.png")


def stitch(first: Image.Image, second: Image.Image, overlap: int, horizontal: bool = False) -> Image.Image:
    # 最小色差路径只选择两张生成图的像素，不绘制新内容，避免宽混合形成双岸线。
    a = np.asarray(first)
    b = np.asarray(second)
    if horizontal:
        a = a.transpose(1, 0, 2)
        b = b.transpose(1, 0, 2)
    if a.ndim != 3 or b.ndim != 3 or a.shape[0] != b.shape[0] or a.shape[2] != b.shape[2] or overlap <= 0 or overlap > min(a.shape[1], b.shape[1]):
        raise ValueError("拼接图通道、共同边长或重叠范围不匹配")
    old = a[:, -overlap:].astype(np.float32)
    new = b[:, :overlap].astype(np.float32)
    cost = np.abs(old - new).mean(axis=2)
    old_blue = old[:, :, 2] - old[:, :, 1] > 8
    new_blue = new[:, :, 2] - new[:, :, 1] > 8
    cost += (old_blue != new_blue) * 120
    cumulative = cost[0].copy()
    previous = np.zeros(cost.shape, dtype=np.int16)
    columns = np.arange(overlap)
    for row in range(1, cost.shape[0]):
        candidates = np.stack((np.r_[np.inf, cumulative[:-1]], cumulative, np.r_[cumulative[1:], np.inf]))
        choice = candidates.argmin(axis=0)
        previous[row] = columns + choice - 1
        cumulative = candidates[choice, columns] + cost[row]
    seam = np.zeros(cost.shape[0], dtype=np.int32)
    seam[-1] = cumulative.argmin()
    for row in range(cost.shape[0] - 1, 0, -1):
        seam[row - 1] = previous[row, seam[row]]
    blend = np.clip((columns[None, :] - seam[:, None] + 2) / 4, 0, 1)[:, :, None]
    joined = np.rint(old * (1 - blend) + new * blend).astype(np.uint8)
    result = np.concatenate((a[:, :-overlap], joined, b[:, overlap:]), axis=1)
    if horizontal:
        result = result.transpose(1, 0, 2)
    return Image.fromarray(result)


def assemble(source_path: Path, output_dir: Path, output_path: Path) -> None:
    source = Image.open(source_path).convert("RGB")
    if source.size != (1672, 941):
        raise ValueError("当前四分区坐标以实际1672×941参考图定义；尺寸变化需重新定义，禁止静默拉伸构图。")
    # 按原参考两倍密度规范各生成片区。源片区不足目标85%则拒收，并记录真实源密度。
    tiles = []
    metadata_regions = []
    for index, original_box in enumerate(regions(source.size), 1):
        path = output_dir / f"region-{index}-source.png"
        prompt_path = output_dir / f"region-{index}-source.prompt.txt"
        reference_path = output_dir / f"region-{index}-reference.png"
        if not prompt_path.is_file() or not prompt_path.read_text(encoding="utf-8").strip() or not reference_path.is_file():
            raise ValueError(f"片区{index}缺少完整提示词或编辑参考，禁止无溯源合成")
        art = Image.open(path).convert("RGB")
        box = tuple(value * 2 for value in original_box)
        target = (box[2] - box[0], box[3] - box[1])
        if min(art.width / target[0], art.height / target[1]) < 0.85:
            raise ValueError(f"片区{index}真实细节尺寸不足：{art.size}，目标{target}")
        if abs(art.width / art.height - target[0] / target[1]) > 0.03:
            raise ValueError(f"片区{index}比例错误，不能拉伸改变边界")
        tile = art.resize(target, Image.Resampling.LANCZOS)
        tiles.append(tile)
        metadata_regions.append({"source": path.name, "reference": reference_path.name, "prompt": prompt_path.name, "source_size": list(art.size), "output_box": list(box), "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "reference_sha256": hashlib.sha256(reference_path.read_bytes()).hexdigest()})
    top = stitch(tiles[0], tiles[1], OVERLAP * 4)
    bottom = stitch(tiles[2], tiles[3], OVERLAP * 4)
    canvas = stitch(top, bottom, OVERLAP * 4, horizontal=True)
    if canvas.size != NATIVE_SIZE:
        raise ValueError("合成尺寸不匹配，禁止改变世界范围")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path)
    metadata = {
        "schema": "waiting_for_dawn.terrain_artwork.v2",
        "source_origin": "builtin_imagegen",
        "source": source_path.name,
        "prompt": source_path.with_suffix(".prompt.txt").name,
        "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "source_size": list(source.size),
        "native_size": list(NATIVE_SIZE),
        "world_size": list(WORLD_SIZE),
        "region_directory": output_dir.name,
        "regions": metadata_regions,
        "sampling": "linear",
        "quantization": "none",
        "pixel_world_size": WORLD_SIZE[0] / NATIVE_SIZE[0],
        "collision_source": "src/gameplay/grid/terrain_map_data.gd",
        "seam_policy": "minimum_color_difference_with_4_pixel_feather",
        "notes": "四片区分别生成真实岩面细节，重叠区沿最小色差路径拼接；细草叶和所有实体仍为独立层，玩法数据不取自图像。",
    }
    output_path.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["prepare", "assemble"])
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--regions", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.mode == "assemble" and args.output is None:
        parser.error("assemble必须指定--output")
    if args.mode == "prepare":
        prepare(args.reference, args.regions)
    else:
        assemble(args.reference, args.regions, args.output)


if __name__ == "__main__":
    main()
