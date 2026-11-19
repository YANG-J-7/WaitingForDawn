"""对生成岸段去底、以最小色差路径拼接共享端口、拼装预览和记录QC。"""
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent
CROP = (48, 240, 1726, 728)
W, H = 1678, 488
SOURCE_ROOT = Path('C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712')


def clean(image):
    a = np.asarray(image.convert('RGBA')).copy()
    rgb = a[:, :, :3].astype(np.int16)
    spill = (rgb[:, :, 0] > 80) & (rgb[:, :, 0] > rgb[:, :, 1]+35) & (rgb[:, :, 2] > rgb[:, :, 1]+35)
    a[spill] = 0
    # 清掉抗锯齿里仍混入的品红，并收软原画稀碎边线。
    color = rgb.astype(np.float32)
    contamination = np.clip((color[:, :, 0]-color[:, :, 1]-3)/30, 0, 1)*np.clip((color[:, :, 2]-color[:, :, 1]-15)/40, 0, 1)
    a[:, :, 3] = np.rint(a[:, :, 3]*(1-contamination)).astype(np.uint8)
    soft = np.asarray(Image.fromarray(a[:, :, 3]).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2)))
    a[:, :, 3] = np.minimum(a[:, :, 3], soft)
    # 仅修剪去底后色边，不替换正常岩石或草叶。
    a[:, :, 0] = np.minimum(a[:, :, 0], np.clip(rgb[:, :, 1]*1.15, 0, 255).astype(np.uint8))
    a[a[:, :, 3] == 0, :3] = 0
    return Image.fromarray(a)


def premultiply(a):
    a = a.astype(np.float32)/255.0
    a[:, :, :3] *= a[:, :, 3:]
    return a


def mix(a, b, weight):
    p = premultiply(a)*weight[:, :, None]+premultiply(b)*(1-weight[:, :, None])
    p[:, :, :3] /= np.maximum(p[:, :, 3:], 1e-6)
    result = np.clip(p*255, 0, 255).round().astype(np.uint8)
    result[result[:, :, 3] == 0, :3] = 0
    return result


def splice_left(image, patch):
    # 接口前64列固定；仅在之后的重叠区寻找最小色差切线，窄羽化避免双岩影。
    width = patch.shape[1]
    original = image[:, :width].copy()
    delta = premultiply(original)-premultiply(patch)
    cost = np.mean(delta[:, :, :3]**2, axis=2)+delta[:, :, 3]**2*3
    lo, hi = 64, width-8
    cost = cost[:, lo:hi]
    back = np.zeros(cost.shape, dtype=np.int16)
    dp = cost[0].copy()
    for y in range(1, H):
        choices = np.stack([np.r_[np.inf, dp[:-1]], dp, np.r_[dp[1:], np.inf]])
        step = choices.argmin(axis=0)-1
        back[y] = step
        dp = cost[y]+choices.min(axis=0)
    path = np.zeros(H, dtype=np.int16)
    path[-1] = int(dp.argmin())
    for y in range(H-1, 0, -1):
        path[y-1] = path[y]+back[y, path[y]]
    path += lo
    weight = np.clip((path[:, None]-np.arange(width)[None, :]+2)/4, 0, 1)
    image[:, :width] = mix(patch, original, weight)
    return image


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    native = {}
    records = {}
    for name in ['gentle', 'cove']:
        qc = json.loads((ROOT/f'processed-{name}/pipeline-meta.json').read_text(encoding='utf-8'))
        assert not any(qc[k] for k in ['empty_frames', 'source_edge_touch_frames', 'output_edge_touch_frames', 'paste_clamped_frames'])
        image = clean(Image.open(ROOT/f'processed-{name}/raw-sheet-clean.png'))
        assert image.size == (1774, 887)
        image.save(ROOT/f'{name}-shore-clean.png')
        box = image.getbbox()
        box = (box[0]-8, box[1]-8, box[2]+8, box[3]+8)
        isolated = image.crop(box)
        isolated.save(ROOT/f'{name}-shore-isolated.png')
        native[name] = image
        records[name] = {'raw_size': list(image.size), 'isolated_size': list(isolated.size), 'isolated_crop': box,
                         'raw_sha256': file_hash(ROOT/f'{name}-shore-raw.png'), 'prompt': f'{name}-shore-prompt.txt'}
    reference = np.asarray(native['gentle'])
    # 共享端口来自新生成缓弯岸段同一位置的左右邻域，不镜像美术。
    left = reference[240:728, 280:504].copy()
    right = reference[240:728, 56:281].copy()
    old = clean(Image.open(ROOT.parent/'lake_shore_v1/processed/raw-sheet-clean.png'))
    originals = {'gentle': native['gentle'], 'cove': native['cove'], 'original-connector': old}
    tiles = {}
    for name, image in originals.items():
        a = np.asarray(image.crop(CROP)).copy()
        a = splice_left(a, left)
        a = splice_left(a[:, ::-1].copy(), right[:, ::-1].copy())[:, ::-1].copy()
        # 草地上缘和浅水外缘按原画alpha包络渐隐，保留岩壁主体，不做UV移动。
        alpha = a[:, :, 3]
        top = np.argmax(alpha > 100, axis=0)
        bottom = H-1-np.argmax((alpha > 100)[::-1], axis=0)
        # 按周期平滑包络，避免稀碎水缘造成逐列竖条；共同端口保持同值。
        kernel = np.exp(-(np.arange(-24, 25, dtype=np.float32)**2)/(2*8**2))
        kernel /= kernel.sum()
        top = np.convolve(np.pad(top, (24, 24), mode='wrap'), kernel, mode='valid')
        bottom = np.convolve(np.pad(bottom, (24, 24), mode='wrap'), kernel, mode='valid')
        top[0] = top[-1] = (top[0]+top[-1])*0.5
        bottom[0] = bottom[-1] = (bottom[0]+bottom[-1])*0.5
        y = np.arange(H)[:, None]
        fade = np.clip((y-top[None, :])/60, 0, 1)*np.clip((bottom[None, :]-y)/45, 0, 1)
        fade = fade*fade*(3-2*fade)
        a[:, :, 3] = np.rint(alpha*fade).astype(np.uint8)
        a[a[:, :, 3] == 0, :3] = 0
        assert (a[:, 0] == a[:, -1]).all(), f'{name}端口不一致'
        assert not a[:3, :, 3].any() and not a[-3:, :, 3].any()
        rgb = a[:, :, :3].astype(np.int16)
        assert not ((a[:, :, 3] > 0) & (rgb[:, :, 0] > 180) & (rgb[:, :, 2] > 180) & (rgb[:, :, 1] < 100)).any()
        tiles[name] = Image.fromarray(a)
        tiles[name].save(ROOT/f'{name}-shore.png')
        records.setdefault(name, {})['output_size'] = [W, H]
        records[name]['output_sha256'] = file_hash(ROOT/f'{name}-shore.png')
    pairs = {}
    for name, a in tiles.items():
        for other, b in tiles.items():
            maximum = int(np.abs(np.asarray(a)[:, -1].astype(np.int16)-np.asarray(b)[:, 0].astype(np.int16)).max())
            assert maximum == 0
            pairs[f'{name}->{other}'] = maximum
    grass = Image.open(ROOT.parent/'grass_variants_v1/grass.png').convert('RGB').resize((360, 360), Image.Resampling.LANCZOS)
    water = Image.open(ROOT.parent/'lake_shore_v1/runtime/water-periodic.png').convert('RGB').resize((650, 650), Image.Resampling.LANCZOS)

    def preview(sequence, filename):
        width = W*len(sequence)
        scene = Image.new('RGBA', (width, 800))
        for y in range(0, 800, water.height):
            for x in range(0, width, water.width):
                scene.paste(water, (x, y))
        bank = Image.new('RGBA', (width, H))
        for i, name in enumerate(sequence):
            bank.paste(tiles[name], (i*W, 0))
        alpha = np.asarray(bank)[:, :, 3]
        top = np.argmax(alpha > 230, axis=0)+150+24
        ground = Image.new('RGB', (width, 800))
        for y in range(0, 800, grass.height):
            for x in range(0, width, grass.width):
                ground.paste(grass, (x, y))
        mask = Image.fromarray((np.arange(800)[:, None] < top[None, :]).astype(np.uint8)*255)
        scene.paste(ground, (0, 0), mask)
        scene.alpha_composite(bank, (0, 150))
        scene.convert('RGB').save(ROOT/filename)
        return scene

    preview(['gentle', 'cove'], 'join-preview.png')
    preview(['original-connector', 'gentle', 'cove'], 'three-shores-preview.png')
    rows = []
    for name in tiles:
        for other in tiles:
            scene = preview([name, other], f'qc/{name}-{other}.png')
            # 仅缩小审阅图，不将缩放版本作为原生交付。
            rows.append(scene.crop((W-256, 200, W+256, 690)).convert('RGB'))
    review = Image.new('RGB', (1536, 1470))
    for i, row in enumerate(rows):
        review.paste(row, ((i % 3)*512, (i//3)*490))
    review.save(ROOT/'join-review-3x3.png')
    manifest = {'id': 'ASSET-0022', 'date': '2026-11-13', 'status': 'candidate', 'integrated': False,
                'generator': 'built-in-image_gen', 'variants': records, 'crop': list(CROP),
                'port': {'axis': 'horizontal', 'step_pixels': W, 'canvas': [W, H], 'rotation_allowed': False,
                         'source': 'gentle-shore-clean.png', 'left_source_rect': [280, 240, 224, H],
                         'right_source_rect': [56, 240, 225, H], 'fixed_outer_columns': 64,
                         'feather_pixels': 4, 'grass_fade_pixels': 60, 'water_fade_pixels': 45,
                         'method': '最小色差路径窄拼接；首末列均来自生成原图x=280，外缘alpha渐隐'},
                'source_paths': {'gentle': str(SOURCE_ROOT/'exec-45e4ce53-ada8-45b7-b749-6d7805a8037d.png'),
                                 'cove': str(SOURCE_ROOT/'exec-94bdcf3f-18a2-4178-abda-ca17197d3e36.png')},
                'reference_sha256': file_hash(ROOT.parent/'lake_shore_v1/shore-raw.png'),
                'references': {'map_style_sha256': file_hash(ROOT.parent/'lake_shore_v1/reference.png'),
                               'existing_clean_sha256': file_hash(ROOT.parent/'lake_shore_v1/processed/raw-sheet-clean.png'),
                               'cove_edit_target_sha256': file_hash(ROOT/'gentle-shore-raw.png')},
                'checks': {'strict_raw_qc': True, 'transparent_top_bottom': True, 'no_visible_magenta': True,
                           'directed_pair_max_rgba_difference': pairs},
                'limitations': '仅横向同向连接；原岸段须用另存original-connector-shore.png适配版，不能直接接旧尖端。未提供闭合湖泊转角、动态遮罩或新水花布点；未迁入正式地图。'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    with zipfile.ZipFile(ROOT/'lake-shore-extensions-v1.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
        names = ['gentle-shore.png', 'cove-shore.png', 'original-connector-shore.png',
                 'gentle-shore-isolated.png', 'cove-shore-isolated.png', 'gentle-shore-raw.png', 'cove-shore-raw.png',
                 'gentle-shore-prompt.txt', 'cove-shore-prompt.txt', 'manifest.json', 'README.md', 'build_delivery.py',
                 'join-preview.png', 'three-shores-preview.png', 'join-review-3x3.png']
        for name in names:
            bundle.write(ROOT/name, name)
        for name in ['gentle', 'cove']:
            bundle.write(ROOT/f'processed-{name}/pipeline-meta.json', f'qc/{name}-pipeline-meta.json')
    with zipfile.ZipFile(ROOT/'lake-shore-extensions-v1.zip') as bundle:
        assert bundle.testzip() is None
    print(json.dumps({'dimensions': [W, H], 'pair_checks': pairs, 'zip_bytes': (ROOT/'lake-shore-extensions-v1.zip').stat().st_size}, ensure_ascii=False))


if __name__ == '__main__':
    (ROOT/'qc').mkdir(exist_ok=True)
    main()
