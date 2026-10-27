"""规范已生成的独立材质边缘和导入设置；不新增纹理细节。"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/map_kits/moonlit_v2/materials'

def close_edges(image):
    pixels=np.asarray(image.convert('RGB'),dtype=np.float32).copy()
    for axis in [0,1]:
        original=pixels.copy()
        for distance in range(32):
            weight=.5*(1-distance/32)**2
            near=[slice(None)]*3;far=[slice(None)]*3
            near[axis]=distance;far[axis]=-1-distance
            a,b=tuple(near),tuple(far)
            pixels[a]=original[a]*(1-weight)+original[b]*weight
            pixels[b]=original[b]*(1-weight)+original[a]*weight
    return Image.fromarray(np.clip(np.rint(pixels),0,255).astype(np.uint8))

def build():
    record={'generated_by':'内置image_gen；soil复用已生成独立道路素材','processing':'32像素边缘闭合，不放大，不新增细节','materials':{}}
    for name in ['rock','water','soil']:
        source=OUT/'source'/f'{name}-raw.png' if name!='soil' else ROOT/'assets/art_candidates/night_set_v1/terrain_road.png'
        if not source.exists(): continue
        image=Image.open(source)
        target=OUT/f'{name}.png'
        close_edges(image).save(target)
        coverage=[156,156] if name!='soil' else [144,144]
        record['materials'][name]={'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'native_size':list(image.size),'world_coverage':coverage,'min_density':min(image.width/coverage[0],image.height/coverage[1]),'output_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
        sidecar=target.with_suffix('.png.import')
        if sidecar.exists():
            text=sidecar.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true')
        else:
            text=f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="res://{target.relative_to(ROOT).as_posix()}"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/size_limit=0\n'
        sidecar.write_text(text,encoding='utf-8')
    (OUT/'material-record.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False))

if __name__=='__main__': build()
