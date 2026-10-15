from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageStat


TILE_SIZE = 36
SEAM_FEATHER = 3
VARIANT_LOOKUP = (0, 0, 0, 0, 1, 2, 3, 3)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="从2×2图像生成源稿构建无缝草地图集，可保留原生细节分辨率。")
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--native-pixel", action="store_true", help="硬像素源稿采用最近邻采样和共享12色色板，不进行平滑缩小。")
    parser.add_argument("--detail-native", action="store_true", help="保留生成源稿象限的原生分辨率与64色，不降采样到36像素。")
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


def make_native_tiles(images: list[Image.Image]) -> list[Image.Image]:
    # 切片和色板量化只处理生成图，草叶形状完全来自图像生成源稿。
    small_atlas = Image.new("RGB", (TILE_SIZE * len(images), TILE_SIZE))
    for index, image in enumerate(images):
        small_atlas.paste(image.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.NEAREST), (index * TILE_SIZE, 0))
    small_atlas = small_atlas.quantize(colors=12, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    common_ground = max(small_atlas.getcolors(small_atlas.width * small_atlas.height), key=lambda item: item[0])[1]
    tiles: list[Image.Image] = []
    for index in range(len(images)):
        tile = small_atlas.crop((index * TILE_SIZE, 0, (index + 1) * TILE_SIZE, TILE_SIZE))
        pixels = tile.load()
        # 所有变体共用边缘像素，保证异种相邻也无色缝。
        for position in range(TILE_SIZE):
            pixels[0, position] = common_ground
            pixels[TILE_SIZE - 1, position] = common_ground
            pixels[position, 0] = common_ground
            pixels[position, TILE_SIZE - 1] = common_ground
        tiles.append(tile)
    return tiles


def make_detail_tiles(images: list[Image.Image]) -> list[Image.Image]:
    # 只切片并统一色板，不绘制草叶，不放大36像素旧稿伪造细节。
    atlas = Image.new("RGB", (TILE_SIZE * len(images), TILE_SIZE))
    for index, image in enumerate(images):
        if image.size != (TILE_SIZE, TILE_SIZE):
            raise ValueError("细节源稿必须使用等分正方形象限，禁止拉伸或放大。")
        atlas.paste(image, (index * TILE_SIZE, 0))
    atlas = atlas.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    common_ground = max(atlas.getcolors(atlas.width * atlas.height), key=lambda item: item[0])[1]
    tiles = []
    for index in range(len(images)):
        tile = atlas.crop((index * TILE_SIZE, 0, (index + 1) * TILE_SIZE, TILE_SIZE))
        pixels = tile.load()
        for position in range(TILE_SIZE):
            pixels[0, position] = common_ground
            pixels[TILE_SIZE - 1, position] = common_ground
            pixels[position, 0] = common_ground
            pixels[position, TILE_SIZE - 1] = common_ground
        tiles.append(tile)
    return tiles


def build_preview(tiles: list[Image.Image]) -> Image.Image:
    columns = 12
    rows = 8
    # 高分辨率素材的预览独立缩略，运行图集不受影响。
    preview_tile_size = min(TILE_SIZE, 72)
    preview = Image.new("RGB", (columns * preview_tile_size, rows * preview_tile_size))
    for y in range(rows):
        for x in range(columns):
            coordinate_hash = (x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)
            variant_hash = (coordinate_hash >> 8) % len(VARIANT_LOOKUP)
            variant = VARIANT_LOOKUP[variant_hash]
            preview.paste(tiles[variant].resize((preview_tile_size, preview_tile_size), Image.Resampling.NEAREST), (x * preview_tile_size, y * preview_tile_size))
    return preview.resize((preview.width * 2, preview.height * 2), Image.Resampling.NEAREST)


def main() -> None:
    global TILE_SIZE
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    source = Image.open(args.input).convert("RGB")
    if args.detail_native:
        if args.native_pixel or source.width != source.height or source.width % 2:
            raise ValueError("原生细节模式需偶数边长正方形源稿，不能与低分辨率模式同时启用。")
        TILE_SIZE = source.width // 2
    quadrants = [quadrant(source, column, row) for row in range(2) for column in range(2)]
    quadrants = normalize_color_balance(quadrants)
    if args.detail_native:
        tiles = make_detail_tiles(quadrants)
    else:
        tiles = make_native_tiles(quadrants) if args.native_pixel else [make_seamless_tile(image) for image in quadrants]

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
