"""规范已生成地形图并建立瓦片图集；只缩小/切片/QC，不生成美术。"""
from pathlib import Path
from PIL import Image
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/tilesets/dawn_20261029'
source=OUT/'source/foundation.png'
image=Image.open(source).convert('RGB')
assert image.width>=1960 and image.height>=800
atlas=image.resize((1960,800),Image.Resampling.LANCZOS)
atlas.save(OUT/'terrain.png')
rebuilt=Image.new('RGB',atlas.size)
cells=[]
for y in range(20):
    for x in range(49):
        tile=atlas.crop((x*40,y*40,(x+1)*40,(y+1)*40))
        rebuilt.paste(tile,(x*40,y*40))
        cells.append({'cell':[x,y],'atlas':[x,y],'world_rect':[x*144,y*144,144,144]})
assert rebuilt.tobytes()==atlas.tobytes()
record={'version':1,'source_native_size':list(image.size),'atlas_size':[1960,800],
 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt':'source/foundation.prompt.txt',
 'world_size':[7056,2880],'visual_tile_world_size':144,'gameplay_cell_size':36,'atlas_tile_size':40,
 'geometry_source':'assets/levels/level_001/*.json；独立于像素和瓦片显示',
 'detail_sources':['assets/map/grass_hd_v1/detail.png','assets/map_kits/moonlit_v2/materials/rock.png','assets/map_kits/moonlit_v2/materials/water.png','assets/map_kits/moonlit_v2/materials/soil.png','assets/map_kits/moonlit_v3/meadow.png','assets/map_kits/moonlit_v3/cliff-tall.png','assets/map_kits/moonlit_v3/shore.png'],
 'reference':'design/art/concepts/tile-map-2026-10-29/map-overview.png',
 'limits':'底色与轮廓0.278纹素/世界单位；共享高清细节6.5～8.0，不能称轮廓/石梯均为4K原生；固定布局瓦片不是自动拼接库',
 'cells':cells,'reassembly_exact':True}
(OUT/'tiles.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for p in [OUT/'terrain.png',ROOT/'assets/map/grass_hd_v1/detail.png',ROOT/'assets/map_kits/moonlit_v2/materials/rock.png',ROOT/'assets/map_kits/moonlit_v2/materials/water.png']:
    side=p.with_suffix('.png.import')
    if side.exists(): side.write_text(side.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
    else: side.write_text(f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="res://{p.relative_to(ROOT).as_posix()}"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/size_limit=0\n',encoding='utf-8')
print('PASS: 980 tiles; exact reassembly; 7056x2880 world; no source upscaling')
