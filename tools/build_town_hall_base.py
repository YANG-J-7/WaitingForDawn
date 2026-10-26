"""从独立生成并去底的底座原稿，确定性裁边、缩放、调色和羽化透明边缘。"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/buildings/town_hall_v2/ground-base'
DISPLAY_RECT = [-166, -120, 320, 198]


def grade_and_fade(canvas, inner=.66):
    pixels = np.asarray(canvas).copy()
    height, width = pixels.shape[:2]
    y, x = np.indices((height, width))
    radius = np.sqrt(((x - (width - 1) / 2) / (width * .489)) ** 2 +
                     ((y - (height - 1) / 2) / (height * .475)) ** 2)
    fade = np.clip((radius - inner) / (1.04 - inner), 0, 1)
    fade = 1 - fade * fade * (3 - 2 * fade)
    pixels[:, :, 3] = np.rint(pixels[:, :, 3] * fade).astype(np.uint8)
    pixels[:, :, :3] = np.rint(pixels[:, :, :3] * np.array([.80, .88, .92])).astype(np.uint8)
    color = pixels[:, :, :3].astype(np.int16)
    magenta = (color[:, :, 0] > color[:, :, 1] + 15) & (color[:, :, 2] > color[:, :, 1] + 15)
    pixels[magenta, 3] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels)


def build():
    source = Image.open(OUT / 'processed/clean.png').convert('RGBA')
    bbox = source.getbbox()
    image = source.crop(bbox)
    image.thumbnail((1200, 552), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (1248, 600))
    canvas.alpha_composite(image, ((1248 - image.width) // 2, (600 - image.height) // 2))
    # 只调整生成素材，不绘制地物。渐疏透明度让外围草叶与原地图相互穿插。
    front = grade_and_fade(canvas)
    rear_source = Image.open(OUT / 'processed-rear-left-v2/clean.png').convert('RGBA')
    rear_bbox = rear_source.getbbox()
    rear = rear_source.crop(rear_bbox)
    rear.thumbnail((420, 470), Image.Resampling.LANCZOS)
    rear_canvas = Image.new('RGBA', (440, 500))
    rear_canvas.alpha_composite(rear, ((440 - rear.width) // 2, (500 - rear.height) // 2))
    rear = grade_and_fade(rear_canvas, .66)
    # 扩大画布向左塔楼侧后方补地面；门前地块仍沿用原世界脚点和比例。
    final = Image.new('RGBA', (1280, 792))
    final.alpha_composite(rear, (88, 40))
    final.alpha_composite(front, (32, 192))
    final.save(OUT / 'ground-base.png')
    record = {
        'status': 'runtime_candidate', 'generator': '内置 image_gen + generate2dsprite去底',
        'source': 'source/raw.png', 'processed': 'processed/clean.png',
        'source_crop': bbox, 'texture_size': list(final.size), 'display_rect': DISPLAY_RECT,
        'tint': [.80, .88, .92], 'edge_fade': {'inner_radius': .66, 'outer_radius': 1.04},
        'layers': {'front': {'rect': [-158, -72, 312, 150]},
                   'rear_left': {'rect': [-144, -110, 110, 125], 'source_crop': rear_bbox}},
        'sources': {str(p.relative_to(OUT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in [OUT/'source/raw.png', OUT/'source/prompt-used.txt', OUT/'processed/clean.png',
                              OUT/'source/rear-left-raw-v2.png', OUT/'source/rear-left-v2.prompt.txt',
                              OUT/'processed-rear-left-v2/clean.png']},
    }
    (OUT / 'manifest.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('PASS: 主城底座裁边/缩放/调色/透明边缘重建', final.size)


if __name__ == '__main__':
    build()
