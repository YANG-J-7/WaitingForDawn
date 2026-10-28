"""只裁切、闭合、羽化生成原稿；不绘制草、岩或湖岸。"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/map_kits/moonlit_v3'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def close_edges(pixels, axes):
    # 在预乘颜色空间处理透明边缘，避免黑色渗边。
    for axis in axes:
        original = pixels.copy()
        for distance in range(32):
            weight = .5 * (1 - distance / 32) ** 2
            near, far = [slice(None)] * 3, [slice(None)] * 3
            near[axis], far[axis] = distance, -1-distance
            a, b = tuple(near), tuple(far)
            pixels[a] = original[a] * (1-weight) + original[b] * weight
            pixels[b] = original[b] * (1-weight) + original[a] * weight
    return pixels

def build():
    records = {}
    for name in ['cliff', 'shore', 'meadow', 'cliff-tall']:
        source = OUT / 'source' / f'{name}.png'
        if not source.exists():
            continue
        original = Image.open(source).convert('RGBA')
        box = original.getchannel('A').point(lambda value:255 if value >= 8 else 0).getbbox() if name != 'meadow' else (0,0,*original.size)
        # 条带保留横向周期接口；只去掉上下透明空白。
        box = (0, box[1], original.width, box[3])
        if name == 'cliff-tall': box=(64,200,960,1350)
        image = original.crop(box)
        pixels = np.asarray(image, dtype=np.float32).copy() / 255
        if name != 'meadow':
            pixels[:,:,3][pixels[:,:,3] < 8/255] = 0
        alpha = pixels[:,:,3:4].copy()
        pixels[:,:,:3] *= alpha
        pixels = close_edges(pixels, [1] if name in ['cliff','shore'] else [0,1])
        pixels[:,:,:3] /= np.maximum(pixels[:,:,3:4], 1/255)
        if name in ['cliff','shore']:
            # 接口草色只保留轻羽化，中央岩石保持原生细节。
            height = pixels.shape[0]
            v = np.linspace(0,1,height)[:,None]
            fade = np.minimum(np.minimum(v/.12, (1-v)/.12), 1).clip(0,1)
            pixels[:,:,3] *= fade
        target = OUT / f'{name}.png'
        Image.fromarray(np.rint(pixels.clip(0,1)*255).astype('uint8')).save(target)
        sidecar = target.with_suffix('.png.import')
        if sidecar.exists():
            text = sidecar.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true')
        else:
            text = f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="res://{target.relative_to(ROOT).as_posix()}"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/size_limit=0\n'
        sidecar.write_text(text,encoding='utf-8')
        records[name] = {'source': source.relative_to(ROOT).as_posix(), 'source_sha256': sha(source),
                         'native_size': list(original.size), 'crop': list(box), 'runtime_size': list(image.size),
                         'output_sha256': sha(target), 'prompt': f'assets/map_kits/moonlit_v3/source/{name}.prompt.txt'}
    refs = ['foundation-reference.png','dressed-reference.png']
    record = {'date':'2026-10-28','generator':'built-in-image_gen',
              'processing':'透明条带上下有效裁切、预乘边缘32像素周期闭合、上下12%透明羽化；草地双向闭合；无放大或程序新增美术',
              'references': {name:sha(ROOT/'assets/map_kits/moonlit_v2/references'/name) for name in refs}, 'assets':records}
    (OUT/'generation-record.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # 复用地物同样需要mipmap，避免总览的高频枝叶闪烁。
    reused = [ROOT/'assets/art_candidates/night_set_v1/pine_tree.png', ROOT/'assets/art_candidates/night_set_v1/boulder.png']
    reused += list((ROOT/'assets/map/dawn_large_hd_v2').glob('forest_*.png'))
    for path in reused:
        sidecar = path.with_suffix('.png.import')
        if sidecar.exists():
            sidecar.write_text(sidecar.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
        else:
            sidecar.write_text(f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="res://{path.relative_to(ROOT).as_posix()}"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/size_limit=0\n',encoding='utf-8')
    print(json.dumps(records,ensure_ascii=False))

if __name__ == '__main__':
    build()
