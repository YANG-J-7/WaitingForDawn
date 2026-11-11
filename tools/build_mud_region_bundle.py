"""切分连续母图、重组校验并装配审阅图；不绘制地形美术。"""
from pathlib import Path
import hashlib
import json
import zipfile

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/map/mud_regions_v1"
STYLES = {"01-sparse-grass": "薄草斑驳泥地", "02-stony-earth": "碎石硬泥地", "03-damp-earth": "深色湿润泥地"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    checks = 0
    records = []
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 26)
    small_font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22)
    contact = Image.new("RGB", (1536, 1680), "#0b1724")
    contact_draw = ImageDraw.Draw(contact)
    numbered = Image.new("RGB", (1536, 3 * 300), "#0b1724")
    numbered_draw = ImageDraw.Draw(numbered)
    for style_index, (style, title) in enumerate(STYLES.items()):
        folder = PACK / style
        meta = json.loads((folder / "assembly.json").read_text(encoding="utf-8"))
        side = meta["tile_size"]
        master = Image.open(folder / "assembled.png").convert("RGB")
        grass = Image.open(folder / "grass-companion.png").convert("RGB")
        assert side >= 512 and master.size == (3 * side, 2 * side)
        assert grass.size == (side, side) and meta["resized"] is False
        checks += 2
        rebuilt = Image.new("RGB", master.size)
        tiles = []
        for y in range(2):
            for x in range(3):
                number = y * 3 + x + 1
                filename = f"tile-{number:02}.png"
                box = (x * side, y * side, (x + 1) * side, (y + 1) * side)
                tile = master.crop(box)
                tile.save(folder / filename)
                with Image.open(folder / filename) as saved:
                    saved.load()
                    assert saved.size == (side, side)
                    assert ImageChops.difference(saved.convert("RGB"), master.crop(box)).getbbox() is None
                    rebuilt.paste(saved, (x * side, y * side))
                checks += 2
                tiles.append({"number": number, "file": filename, "column": x, "row": y,
                              "source_rect": [x * side, y * side, side, side], "sha256": sha(folder / filename)})
                thumbnail = tile.resize((256, 256), Image.Resampling.LANCZOS)
                numbered.paste(thumbnail, ((number - 1) * 256, style_index * 300 + 44))
                numbered_draw.text(((number - 1) * 256 + 8, style_index * 300 + 6),
                                   f"{style_index + 1}-{number:02}", font=small_font, fill="#d7e7e5")
        assert len({tile["sha256"] for tile in tiles}) == 6
        assert ImageChops.difference(rebuilt, master).getbbox() is None
        checks += 2
        rebuilt.save(folder / "reassembled.png")

        # 证明七处内部切线前后均保留母图像素，而非强行让泥土边缘变成草。
        internal = []
        for y in range(2):
            for x in [1, 2]:
                box = (x * side - 8, y * side, x * side + 8, (y + 1) * side)
                assert ImageChops.difference(rebuilt.crop(box), master.crop(box)).getbbox() is None
                internal.append({"axis": "x", "column": x, "row": y, "reassembly_difference": 0})
                checks += 1
        for x in range(3):
            box = (x * side, side - 8, (x + 1) * side, side + 8)
            assert ImageChops.difference(rebuilt.crop(box), master.crop(box)).getbbox() is None
            internal.append({"axis": "y", "column": x, "row": 1, "reassembly_difference": 0})
            checks += 1

        # 整个3×2区域的十段外边与配套草地直接比对。
        outer = []
        edge_boxes = []
        n = side
        for x in range(3):
            edge_boxes.extend([("top", x, (x*n, 0, (x+1)*n, 1), (0, n-1, n, n)),
                               ("bottom", x, (x*n, 2*n-1, (x+1)*n, 2*n), (0, 0, n, 1))])
        for y in range(2):
            edge_boxes.extend([("left", y, (0, y*n, 1, (y+1)*n), (n-1, 0, n, n)),
                               ("right", y, (3*n-1, y*n, 3*n, (y+1)*n), (0, 0, 1, n))])
        for direction, index, a, b in edge_boxes:
            delta = ImageChops.difference(master.crop(a), grass.crop(b))
            max_delta = max(v[1] for v in delta.getextrema())
            assert max_delta <= 1, f"外边衔接超量化容差：{style}/{direction}/{index}/{max_delta}"
            outer.append({"edge": direction, "index": index, "max_channel_delta": max_delta})
            checks += 1

        surround = Image.new("RGB", (5*n, 4*n))
        for y in range(4):
            for x in range(5):
                surround.paste(grass, (x*n, y*n))
        surround.paste(rebuilt, (n, n))
        surround.resize((1280, 1024), Image.Resampling.LANCZOS).save(folder / "surrounded-preview.png")
        rebuilt.resize((960, 640), Image.Resampling.LANCZOS).save(folder / "region-preview.png")
        guide = rebuilt.copy()
        draw = ImageDraw.Draw(guide)
        for x in [n, 2*n]:
            draw.line((x, 0, x, 2*n), fill="#c1d8cd", width=2)
        draw.line((0, n, 3*n, n), fill="#c1d8cd", width=2)
        for tile in tiles:
            px, py = tile["column"]*n + 12, tile["row"]*n + 8
            draw.rectangle((px-4, py-2, px+46, py+38), fill="#0b1724")
            draw.text((px, py), str(tile["number"]), font=font, fill="#d7e7e5")
        guide.resize((960, 640), Image.Resampling.LANCZOS).save(folder / "layout-guide.png")
        # 总览每行一款；左侧母图，右侧与纯草地拼接效果。
        row_y = style_index * 560
        contact_draw.text((12, row_y + 8), title + " · 3×2六图块", font=font, fill="#d7e7e5")
        contact.paste(rebuilt.resize((768, 512), Image.Resampling.LANCZOS), (0, row_y+48))
        contact.paste(surround.resize((640, 512), Image.Resampling.LANCZOS), (832, row_y+48))

        map_data = {"schema": "waiting-for-dawn.mud-region.v1", "id": style, "name": title,
                    "status": "candidate", "columns": 3, "rows": 2, "tile_pixels": side,
                    "size_pixels": list(master.size), "placement": "固定3×2，按编号从左到右、从上到下",
                    "allowed_rotation": 0, "independent_random_tile": False, "animation": False,
                    "terrain_visual_only": True, "collision_rules": None,
                    "grass_companion": "grass-companion.png", "tiles": tiles,
                    "source": f"../source/{style}.png", "prompt": f"../source/{style}.prompt.txt",
                    "source_sha256": sha(PACK / "source" / f"{style}.png"),
                    "assembly": meta, "internal_edges": internal, "outer_edges": outer}
        (folder / "map.json").write_text(json.dumps(map_data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        records.append(map_data)

    assert sum(len(record["tiles"]) for record in records) == 18
    assert len({tile["sha256"] for record in records for tile in record["tiles"]}) == 18
    checks += 2
    contact.save(PACK / "contact-sheet.png")
    numbered.save(PACK / "tiles-18-overview.png")
    manifest = {"date": "2026-11-11", "status": "candidate", "generator": "built-in-image_gen",
                "intent": "三款，每款六张固定相邻图块构成3×2连续露土区域", "region_count": 3, "tile_count": 18,
                "source_native_size": [record["assembly"]["source_size"] for record in records],
                "image_generation_requested_size": [3072, 2048], "upscaled": False,
                "base_grass": "../grass_variants_v1/grass.png", "animation": False,
                "scope": "素材与拼接审阅，未迁移F6场景或正式第一关", "validation_checks": checks,
                "internal_edge_count": 21, "outer_edge_count": 30,
                "processing": "Godot仅装配整片外围草地，内部不改；Pillow精确裁切、重组校验、审阅图和元数据",
                "regions": [{"id": r["id"], "name": r["name"], "map": r["id"]+"/map.json"} for r in records]}
    (PACK / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"PASS: {checks} checks; 18 unique tiles; 21 internal cuts exact; 30 outer edges within 1/255")


def package():
    archive = PACK / "mud-regions-3x6-final.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for relative in ["README.md", "manifest.json", "contact-sheet.png", "tiles-18-overview.png"]:
            bundle.write(PACK / relative, relative)
        for style in STYLES:
            folder = PACK / style
            for relative in ["map.json", "grass-companion.png", "assembled.png", "layout-guide.png", "surrounded-preview.png"]:
                bundle.write(folder / relative, f"{style}/{relative}")
            for tile in sorted(folder.glob("tile-*.png")):
                bundle.write(tile, f"{style}/{tile.name}")
            bundle.write(PACK / "source" / f"{style}.prompt.txt", f"source/{style}.prompt.txt")
    print("Bundle:", archive)


if __name__ == "__main__":
    main()
    if (PACK / "README.md").is_file():
        package()
