"""将图像生成的清晰地形规范为两世界像素美术格，不绘制或臆造地形。"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True, help="该轮图像编辑的输入参考，记录溯源而不从它生成像素")
    args = parser.parse_args()
    source = Image.open(args.input).convert("RGB")
    if abs(source.width / source.height - 16 / 9) > 0.01:
        raise ValueError("生成图不是16:9，禁止拉伸或裁切改变岸线构图")
    if source.width < 1440 or source.height < 810:
        raise ValueError("生成源图不足1440×810原生格，需重新生成")
    # 只进行生成素材的尺寸规范和有限色量化；从不使用平滑重采样。
    native = source.resize((1440, 810), Image.Resampling.NEAREST)
    native = native.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    runtime = native.resize((2880, 1620), Image.Resampling.NEAREST)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(args.output)
    metadata = {
        "schema": "waiting_for_dawn.terrain_artwork.v1",
        "source": args.input.name,
        "texture": args.output.name,
        "prompt": args.input.with_suffix(".prompt.txt").name,
        "source_size": list(source.size),
        "native_size": [1440, 810],
        "world_size": [2880, 1620],
        "pixel_world_size": 2,
        "palette_limit": 64,
        "palette_count": len(native.getcolors(1440 * 810)),
        "sampling": "nearest",
        "source_origin": "builtin_imagegen",
        "source_sha256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
        "edit_reference": args.reference.name,
        "edit_reference_sha256": hashlib.sha256(args.reference.read_bytes()).hexdigest(),
        "collision_source": "src/gameplay/grid/terrain_map_data.gd",
        "notes": "图像只定义外观；保持现有资源节点、地形、建造和寻路规则。",
    }
    args.output.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
