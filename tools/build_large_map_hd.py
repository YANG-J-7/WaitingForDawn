"""拼接内置image_gen高清编辑稿，按母图调色并保留透明轮廓及玩法坐标。"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT/'assets/map/dawn_large_v1'
OUT = ROOT/'assets/map/dawn_large_hd_v2'
GROUND_SCALE = 3
FOREST_SCALE = 6

def json_save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def assembled_detail(original, generated, size, edge=0):
    """原图约束整体调色，编辑稿提供实际细节，接缝边缘回到共同底色。"""
    reference = original.convert('RGB').resize(size, Image.Resampling.LANCZOS)
    generated = generated.convert('RGB').resize(size, Image.Resampling.LANCZOS)
    original_low = np.asarray(reference.filter(ImageFilter.GaussianBlur(30)),dtype=np.float32)
    generated_low = np.asarray(generated.filter(ImageFilter.GaussianBlur(30)),dtype=np.float32)
    ratio = np.clip((original_low+12)/(generated_low+12),.65,1.5)
    corrected = np.asarray(generated,dtype=np.float32)*ratio
    yy, xx = np.indices((size[1], size[0]))
    distance = np.minimum.reduce([xx, yy, size[0]-1-xx, size[1]-1-yy])
    weight = np.minimum(distance/edge, 1).astype(np.float32) if edge else np.ones((size[1],size[0]),dtype=np.float32)
    result = np.clip(np.asarray(reference, dtype=np.float32)*(1-weight[...,None])+corrected*weight[...,None], 0,255)
    return Image.fromarray(np.rint(result).astype(np.uint8))

def main():
    data = json.loads((OLD/'map.json').read_text(encoding='utf-8'))
    OUT.mkdir(exist_ok=True)
    base_source = Image.open(OLD/'base.png')
    base = base_source.resize((1672*GROUND_SCALE,941*GROUND_SCALE), Image.Resampling.LANCZOS)
    chunks = []
    raw = []
    for y in range(3):
        for x in range(4):
            entry = data['chunks'][y*4+x]
            box = entry['sourceRect']
            target = tuple(p*GROUND_SCALE for p in box)
            size = (target[2]-target[0],target[3]-target[1])
            raw_path = OUT/f'raw-{x}-{y}.png'
            generated = Image.open(raw_path)
            original = base_source.crop(tuple(box))
            patch = assembled_detail(original,generated,size)
            # 使用整张母图的同一重采样结果作为接缝处的共同底色。
            shared = np.asarray(base.crop(target),dtype=np.float32)
            independent = np.asarray(original.resize(size,Image.Resampling.LANCZOS),dtype=np.float32)
            patch = Image.fromarray(np.clip(np.rint(np.asarray(patch,dtype=np.float32)+shared-independent),0,255).astype(np.uint8))
            base.paste(patch,target[:2])
            path = OUT/f'ground-{x}-{y}.png'
            patch.save(path)
            chunks.append(dict(path=str(path.relative_to(ROOT)).replace('\\','/'),sourceRect=box,pixelSize=list(size)))
            raw.append(dict(path=raw_path.name,reference=f'../dawn_large_v1/ground-{x}-{y}.png',prompt='terrain.prompt.txt',nativeSize=list(generated.size)))
    base.save(OUT/'base.png')
    overlays = []
    for entry in data['resourceSites']:
        if 'sourceRect' not in entry: continue
        name = entry['id']
        original = Image.open(OLD/f'{name}.png').convert('RGBA')
        generated = Image.open(OUT/f'cutout-{name}.png').convert('RGBA')
        size = tuple(p*FOREST_SCALE for p in original.size)
        # 真正透明的树冠/树干层，去掉整块草地，不再把矩形地面叠在底图上。
        old_rgb = np.asarray(original.convert('RGB'),dtype=np.float32)
        new_rgb = np.asarray(generated.convert('RGB'),dtype=np.float32)
        old_pine = (old_rgb[...,2]>old_rgb[...,1]) & (old_rgb[...,2]>old_rgb[...,0]*1.25)
        new_pine = (new_rgb[...,2]>new_rgb[...,1]) & (np.asarray(generated.getchannel('A'))>240)
        ratio = np.clip(np.median(old_rgb[old_pine],axis=0)/np.maximum(np.median(new_rgb[new_pine],axis=0),1),.65,1.2)
        patch = Image.fromarray(np.clip(np.rint(new_rgb*ratio),0,255).astype(np.uint8)).convert('RGBA')
        patch.putalpha(generated.getchannel('A'))
        patch = patch.resize(size,Image.Resampling.LANCZOS)
        patch.save(OUT/f'{name}.png')
        overlays.append(dict(id=name,path=f'assets/map/dawn_large_hd_v2/{name}.png',sourceRect=entry['sourceRect'],pixelSize=list(size)))
        raw.append(dict(path=f'raw-{name}.png',reference=f'../dawn_large_v1/{name}.png',prompt='forest.prompt.txt',nativeSize=list(Image.open(OUT/f'raw-{name}.png').size)))
        raw.append(dict(path=f'cutout-{name}.png',reference=f'raw-{name}.png',prompt='forest-cutout.prompt.txt',nativeSize=list(generated.size)))
    original = Image.open(OLD/'border-forest.png').convert('RGBA')
    border = original.resize(tuple(p*GROUND_SCALE for p in original.size),Image.Resampling.LANCZOS)
    for y in range(2):
        for x in range(2):
            box = (x*358,y*471,358 if x==0 else original.width,471 if y==0 else original.height)
            source = original.crop(box)
            generated = Image.open(OUT/f'raw-border-{x}-{y}.png')
            size = tuple(p*GROUND_SCALE for p in source.size)
            patch = assembled_detail(source,generated,size,edge=12).convert('RGBA')
            patch.putalpha(source.getchannel('A').resize(size,Image.Resampling.NEAREST))
            border.paste(patch,(box[0]*GROUND_SCALE,box[1]*GROUND_SCALE))
            raw.append(dict(path=f'raw-border-{x}-{y}.png',reference=f'border-reference-{x}-{y}.png',prompt='forest.prompt.txt',nativeSize=list(generated.size)))
    border.save(OUT/'border-forest.png')
    occluders = []
    for index, entry in enumerate(data['occluders']):
        box = entry['sourceRect']
        target = tuple(p*GROUND_SCALE for p in box)
        patch = base.crop(target).convert('RGBA')
        mask = Image.open(ROOT/entry['path']).getchannel('A').resize(patch.size,Image.Resampling.NEAREST)
        patch.putalpha(mask)
        patch.save(OUT/f'cliff-{index}.png')
        occluders.append(dict(path=f'assets/map/dawn_large_hd_v2/cliff-{index}.png',sourceRect=box))
    preview = base.convert('RGBA')
    preview.alpha_composite(border,(0,0))
    for entry in overlays:
        patch = Image.open(ROOT/entry['path'])
        box = entry['sourceRect']
        patch = patch.resize(((box[2]-box[0])*GROUND_SCALE,(box[3]-box[1])*GROUND_SCALE),Image.Resampling.LANCZOS)
        preview.alpha_composite(patch,(box[0]*GROUND_SCALE,box[1]*GROUND_SCALE))
    preview.convert('RGB').save(OUT/'layered-preview.png')
    preview.resize((256,144),Image.Resampling.LANCZOS).convert('RGB').save(OUT/'minimap.png')
    raw_hashes = {e['path']:hashlib.sha256((OUT/e['path']).read_bytes()).hexdigest() for e in raw}
    json_save(OUT/'visual.json',dict(schema='waiting-for-dawn.hd-visual.v2',sourceSize=[1672,941],worldSize=[4608,2592],groundScale=GROUND_SCALE,forestScale=FOREST_SCALE,chunks=chunks,forests=overlays,border=dict(path='assets/map/dawn_large_hd_v2/border-forest.png',sourceRect=data['border']['sourceRect']),occluders=occluders,geometrySource='../dawn_large_v1/map.json',artSource='内置image_gen固定构图高清编辑；母图低频调色、共同接缝底色及原透明轮廓合成，不声称逐像素还原',rawAssets=raw,rawSHA256=raw_hashes))
    print('高清地形',base.size,'四树簇倍率',FOREST_SCALE,'原生生成稿',len(raw),'张；玩法坐标未改')

if __name__ == '__main__': main()
