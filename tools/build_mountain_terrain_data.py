"""离线细化固定地图岩面格；运行不读取图片颜色，采用登记后的权威JSON。"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/map/moonlit_terrain_detail.png'
OUTPUT = ROOT / 'design/levels/mountain-rock-cells.json'

def build():
    source = Image.open(SOURCE).convert('RGB')
    width, height = source.size
    blocked = []
    coverages = []
    # 36世界像素格，12×12密集取样；面积门槛防止把零散灰草叶当作岩壁。
    for row in range(30):
        for col in range(20, 80):
            samples = 0
            for sy in range(12):
                for sx in range(12):
                    world_x = col * 36 + (sx + 0.5) * 3
                    world_y = row * 36 + (sy + 0.5) * 3
                    r, g, b = source.getpixel((int(world_x / 2880 * width), int(world_y / 1620 * height)))
                    samples += b - g > 8 and b - r > 16 and b > 48
            ratio = samples / 144
            if ratio >= 0.18:
                blocked.append([col, row])
                coverages.append(round(ratio, 4))
    return {
        'schema': 'waiting_for_dawn.mountain_rock_cells.v1',
        'source': 'assets/map/moonlit_terrain_detail.png',
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'world_size': [2880, 1620], 'cell_size': 36,
        'note': '固定地图岩面密集取样登记；范围外不新增阻挡，湖水及资源另行处理，坡道只覆盖路网所在岩壁格。',
        'sampling': {'per_cell': [12, 12], 'min_rock_coverage': 0.18, 'region_cells': [20, 0, 60, 30]},
        'rock_cells': blocked, 'rock_coverages': coverages,
    }

if __name__ == '__main__':
    data = build()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'岩面格: {len(data["rock_cells"])}，已保存权威数据。')
