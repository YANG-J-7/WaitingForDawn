"""切片和合成已有生成素材，不程序绘制或插值放大最终美术。"""
from pathlib import Path
import hashlib
import json
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def split(image,name,size,world_cell=None):
    folder=HERE/name
    folder.mkdir(exist_ok=True)
    cells=[]
    rebuilt=Image.new('RGBA',image.size)
    for y in range(0,image.height,size):
        for x in range(0,image.width,size):
            box=(x,y,min(x+size,image.width),min(y+size,image.height))
            tile=image.crop(box).convert('RGBA')
            path=folder/f'{y//size:02d}-{x//size:02d}.png'
            tile.save(path)
            rebuilt.paste(Image.open(path),(x,y))
            cells.append({'file':str(path.relative_to(HERE)).replace('\\','/'),'cell':[x//size,y//size],'source_rect':list(box),'native_size':list(tile.size)})
    assert rebuilt.tobytes()==image.convert('RGBA').tobytes()
    rebuilt.save(HERE/f'{name}-assembled.png')
    return {'tile_pixels':size,'world_cell':world_cell,'cells':cells,'reassembly_exact':True}

overview=Image.open(HERE/'map-overview.png').convert('RGBA')
layout=split(overview,'overview-tiles',128)
grass_path=ROOT/'assets/map_kits/moonlit_v3/meadow.png'
cliff_path=ROOT/'assets/map_kits/moonlit_v3/cliff.png'
grass=Image.open(grass_path).convert('RGBA')
cliff=Image.open(cliff_path).convert('RGBA')
assert grass.width>=1024 and grass.height>=768
sample=grass.crop((0,0,1024,768))
height=round(cliff.height*1024/cliff.width)
assert cliff.width>=1024
cliff=cliff.resize((1024,height),Image.Resampling.LANCZOS)
sample.alpha_composite(cliff,(0,160))
sample.save(HERE/'hd-cliff-sample.png')
detail=split(sample,'detail-tiles',256,36)
assert 256/36 >= 4*1.6
record={'date':'2026-10-29','status':'candidate_preview_only','integrated':False,
        'map_mode':'tile_mode','visual_model':'layered_tilemap','engine_target':'project-native-preview',
        'overview':{'file':'map-overview.png','native_size':list(overview.size),'generator':'built-in-image_gen','prompt':'map-overview.prompt.txt','sha256':sha(HERE/'map-overview.png'),'purpose':'构图预览及固定布局分片；不是全图高清运行资产'},
        'reference':{'file':'user-reference.png','sha256':sha(HERE/'user-reference.png')},
        'overview_tiles':layout,
        'hd_sample':{'file':'hd-cliff-sample.png','native_size':[1024,768],'world_size':[144,108],
                     'source':'复用已生成独立草地与崖体素材；仅合成和向下缩采样，不放大',
                     'tiles':detail,'density':256/36,'required_density_at_4k_zoom_1_6':6.4,
                     'sources':[{'file':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':sha(p)} for p in [grass_path,cliff_path]]},
        'limits':['总览不是4K原生整图，实际1962×801','高清局部重绘三次限流无产物；瓦片样区复用已有生成素材','固定布局切片不是任意重组的自动瓦片库','外围树林只在总览概念中显示，运行时仍应分层','未新增运行碰撞或改资源配置；没有引擎内清晰度和性能验收']}
(HERE/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS: 总览分片逐像素重组一致，数量',len(layout['cells']))
print('PASS: 高清样区12片逐像素重组一致；256/36=%.3f >= 6.4'%detail['tile_pixels'].__truediv__(36))
