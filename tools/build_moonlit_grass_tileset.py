from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageStat


TILE_SIZE = 36
SEAM_FEATHER = 3
VARIANT_LOOKUP = (0, 0, 0, 0, 1, 2, 3, 3)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="从2×2图像生成源稿构建36像素无缝草地图集。")
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def quadrant(source: Image.Image, column: int, row: int) -> Image.Image:
    cell_width = source.width // 2
    cell_height = source.height // 2
    return source.crop(
        (
            column * cell_width,
            row * cell_height,
            (column + 1) * cell_width,
            (row + 1) * cell_height,
        )
    )


def normalize_color_balance(images: list[Image.Image]) -> list[Image.Image]:
    channel_means = [ImageStat.Stat(image).mean[:3] for image in images]
    target = [sum(means[channel] for means in channel_means) / len(images) for channel in range(3)]
    normalized: list[Image.Image] = []
    for image, means in zip(images, channel_means, strict=True):
        channels = []
        for channel, source_channel in enumerate(image.split()[:3]):
            delta = target[channel] - means[channel]
            channels.append(source_channel.point(lambda value, shift=delta: max(0, min(255, round(value + shift)))))
        normalized.append(Image.merge("RGB", tuple(channels)))
    return normalized


def make_seamless_tile(source: Image.Image) -> Image.Image:
    tile = source.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.LANCZOS).convert("RGB")
    pixels = tile.load()

    for offset in range(SEAM_FEATHER):
        left_x = offset
        right_x = TILE_SIZE - 1 - offset
        for y in range(TILE_SIZE):
            left = pixels[left_x, y]
            right = pixels[right_x, y]
            mixed = tuple((left[channel] + right[channel]) // 2 for channel in range(3))
            pixels[left_x, y] = mixed
            pixels[right_x, y] = mixed

    for offset in range(SEAM_FEATHER):
        top_y = offset
        bottom_y = TILE_SIZE - 1 - offset
        for x in range(TILE_SIZE):
            top = pixels[x, top_y]
            bottom = pixels[x, bottom_y]
            mixed = tuple((top[channel] + bottom[channel]) // 2 for channel in range(3))
            pixels[x, top_y] = mixed
            pixels[x, bottom_y] = mixed

    return tile.quantize(colors=32, method=Image.Quantize.MEDIANCUT).convert("RGB")


def edge_is_closed(tile: Image.Image) -> bool:
    pixels = tile.load()
    return all(pixels[0, y] == pixels[TILE_SIZE - 1, y] for y in range(TILE_SIZE)) and all(
        pixels[x, 0] == pixels[x, TILE_SIZE - 1] for x in range(TILE_SIZE)
    )


def build_preview(tiles: list[Image.Image]) -> Image.Image:
    columns = 12
    rows = 8
    preview = Image.new("RGB", (columns * TILE_SIZE, rows * TILE_SIZE))
    for y in range(rows):
        for x in range(columns):
            variant_hash = (x * 17 + y * 31 + (x // 3) + (y // 2)) % len(VARIANT_LOOKUP)
            variant = VARIANT_LOOKUP[variant_hash]
            preview.paste(tiles[variant], (x * TILE_SIZE, y * TILE_SIZE))
    return preview.resize((preview.width * 2, preview.height * 2), Image.Resampling.NEAREST)


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    source = Image.open(args.input).convert("RGB")
    quadrants = [quadrant(source, column, row) for row in range(2) for column in range(2)]
    quadrants = normalize_color_balance(quadrants)
    tiles = [make_seamless_tile(image) for image in quadrants]

    for index, tile in enumerate(tiles):
        if not edge_is_closed(tile):
            raise RuntimeError(f"草地变体{index}未闭合边缘")

    atlas = Image.new("RGB", (TILE_SIZE * len(tiles), TILE_SIZE))
    for index, tile in enumerate(tiles):
        atlas.paste(tile, (index * TILE_SIZE, 0))

    atlas.save(args.output_dir / "moonlit_grass_atlas.png")
    build_preview(tiles).save(args.output_dir / "moonlit_grass_preview.png")


if __name__ == "__main__":
    main()
