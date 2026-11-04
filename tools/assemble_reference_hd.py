"""装配内置图像生成的地形原稿和独立树木；只做采样、调色、接缝与导出。"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/map_kits/reference_hd_20261102'
SIZE = (7056, 2880)

def seam(cost):
    """从上到下选最小色差接缝；只在接缝两侧各羽化2像素。"""
    h, w = cost.shape
    back = np.zeros((h, w), np.int16)
    score = cost[0].copy()
    xx = np.arange(w)
    for y in range(1, h):
        candidates = np.stack((np.r_[np.inf, score[:-1]], score, np.r_[score[1:], np.inf]))
        choice = candidates.argmin(axis=0)
        back[y] = xx + choice - 1
        score = cost[y] + candidates[choice, xx]
    path = np.empty(h, np.int32)
    path[-1] = int(score.argmin())
    for y in range(h-1, 0, -1):
        path[y-1] = back[y, path[y]]
    return np.clip((xx[None, :] - path[:, None] + 2) / 4, 0, 1)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def forest_layout():
    """按参考图手工编排脚点、疏密与树高；数据是物件摆放，不生成树形。"""
    rows = [
        (22, [0,34,70,108,145,183,222,262,303,343,386,429,470,510,553,594,633], 112),
        (68, [12,54,96,142,185,232,278,327,392,440,485,535,585], 125),
        (116,[3,46,88,132,181,225,274,478], 118),
        (165,[5,38], 114),
        (210,[9], 103),
        (430,[0,38,77,116], 103),
        (472,[8,50,96,144], 115),
        (514,[0,36,78,114], 101),
        (630,[8,63,113,167,232], 119),
        (681,[0,41,91,147,196,284,338], 110),
        (734,[8,56,110,159,211,267,319,384,459,510,566,614,653], 117),
        (792,[0,38,83,129,175,226,278,331,385,438,490,537,583,633,682], 115),
        (830,[8,56,105,156,209,260,313,365,419,470,522,575,626,677], 109),
        (803,[930,971,1017,1066,1108], 64),
    ]
    points = []
    for row_index, (y, xs, h) in enumerate(rows):
        for index, x in enumerate(xs):
            # 固定的微调避免整齐行列，调试及重开时不随机改变。
            points.append((x+(index*7+row_index*3)%23-11, y+(index*19+row_index*7)%57-28, h+(index*23+row_index*11)%69-34))
    points += [(754,19,96),(969,37,115),(1252,133,63),(1333,311,77),(1454,125,48),(1513,206,67),(1637,94,52),(1717,330,60),(1807,164,53),(1853,255,57),(1886,363,51),(1741,433,62)]
    trees = []
    for index, (x,y,h) in enumerate(points):
        trees.append({'id':f'pine-{index:03}', 'variant':index%2, 'position':[round(x*SIZE[0]/1962,3),round(y*SIZE[1]/801,3)], 'size':[round(h*.56*SIZE[0]/1962,3),round(h*SIZE[1]/801,3)], 'sort_y':round(y*SIZE[1]/801,3), 'layer':'props', 'occlusionClass':'tall', 'collision_source':'既有关卡forest权威格，未按PNG矩形新增碰撞'})
    return sorted(trees,key=lambda t:t['sort_y'])

def main():
    manifest = json.loads((OUT/'production.json').read_text(encoding='utf-8'))
    # 低频色场仅用于离线统一新原稿明暗，运行时没有任何额外草地覆盖。
    tone = Image.open(ROOT/'assets/map_kits/reference_20261029/source/foundation.png').convert('RGB').resize(SIZE, Image.Resampling.BICUBIC)
    tone = np.asarray(tone.filter(ImageFilter.GaussianBlur(110)), dtype=np.float32)
    canvas = np.zeros((SIZE[1],SIZE[0],3),np.float32)
    coverage = np.zeros((SIZE[1],SIZE[0]),bool)
    for entry in manifest['regions']:
        path = OUT/entry['source']
        im = Image.open(path).convert('RGB')
        entry['native_size'] = list(im.size)
        entry['sha256'] = sha(path)
        entry['prompt'] = entry['source'].replace('.png','.prompt.txt')
        x0,y0,x1,y1 = entry['rect']
        w,h=x1-x0,y1-y0
        entry['native_density'] = [im.width/w, im.height/h]
        art=im.resize((w,h),Image.Resampling.LANCZOS)
        blurred=np.asarray(art.filter(ImageFilter.GaussianBlur(110)),dtype=np.float32)
        art=np.clip(np.asarray(art,dtype=np.float32)+np.clip(tone[y0:y1,x0:x1]-blurred,-38,38),0,255)
        old=canvas[y0:y1,x0:x1]
        known=coverage[y0:y1,x0:x1]
        weight=np.ones((h,w),np.float32)
        # 重叠区最小色差接合，避免宽透明叠加产生虚影。
        if x0>0:
            overlap=min(144,w)
            cost=np.mean(np.abs(old[:,:overlap]-art[:,:overlap]),axis=2)
            weight[:,:overlap]=np.minimum(weight[:,:overlap],seam(cost))
        if y0>0:
            overlap=min(144,h)
            cost=np.mean(np.abs(old[:overlap]-art[:overlap]),axis=2)
            weight[:overlap]=np.minimum(weight[:overlap],seam(cost.T).T)
        weight[~known]=1
        canvas[y0:y1,x0:x1]=old*(1-weight[:,:,None])+art*weight[:,:,None]
        coverage[y0:y1,x0:x1]=True
    assert coverage.all(), '地形存在未覆盖像素'
    ground=Image.fromarray(np.rint(canvas).astype('uint8'))
    ground.save(OUT/'terrain-master.png')
    # 每页1008×1440，144像素图集格一比一映射世界；原49×20格保持。
    atlas_dir=OUT/'atlases'
    atlas_dir.mkdir(exist_ok=True)
    padded=Image.fromarray(np.pad(np.asarray(ground),((8,8),(8,8),(0,0)),mode='edge'))
    for row in range(2):
        for col in range(7):
            padded.crop((col*1008,row*1440,(col+1)*1008+16,(row+1)*1440+16)).save(atlas_dir/f'ground-{col}-{row}.png')
    trees=forest_layout()
    preview=ground.convert('RGBA')
    sprites=[]
    for key in ['pine-a','pine-b']:
        source=Image.open(OUT/'source'/f'{key}.png').convert('RGBA')
        bounds=source.getchannel('A').point(lambda a:255 if a>10 else 0).getbbox()
        sprite=source.crop(bounds)
        sprite.save(OUT/f'{key}.png')
        sprites.append(sprite)
    for tree in trees:
        x,y=tree['position']; w,h=tree['size']
        preview.alpha_composite(sprites[tree['variant']].resize((round(w),round(h)),Image.Resampling.LANCZOS),(round(x-w/2),round(y-h)))
    preview.convert('RGB').save(OUT/'map-7056x2880.png')
    preview.convert('RGB').resize((1960,800),Image.Resampling.LANCZOS).save(OUT/'preview.png')
    forest={'version':1, 'world_size':list(SIZE),'sprites':['pine-a.png','pine-b.png'],'trees':trees,'placement_reference':'source/user-reference.png','note':'树木独立对象；参考图轮廓手工编排，不宣称逐棵逐像素复制'}
    (OUT/'forest.json').write_text(json.dumps(forest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    manifest.update({'status':'assembled_candidate','output_size':list(SIZE),'foundation':'terrain-master.png','patches':[],'missing_regions':[],'forest':'forest.json','atlas_count':14,'atlas_tile_size':144,'runtime_scale':1,'low_frequency_tone_source':'../reference_20261029/source/foundation.png','limitation':'7056×2880分区原稿装配，不代表4K窗口最大倍率无源纹素放大；独立树木非逐棵像素复制'})
    manifest['files']={str(p.relative_to(OUT)).replace('\\','/'):{'sha256':sha(p),'size':list(Image.open(p).size)} for p in [OUT/'terrain-master.png',OUT/'map-7056x2880.png',OUT/'pine-a.png',OUT/'pine-b.png',*sorted(atlas_dir.glob('*.png'))]}
    manifest['sprite_sources']=[{'file':f'source/{name}.png','prompt':f'source/{name}.prompt.txt','reference':'source/pine-reference.png','native_size':list(Image.open(OUT/'source'/f'{name}.png').size),'sha256':sha(OUT/'source'/f'{name}.png')} for name in ['pine-a','pine-b']]
    (OUT/'map.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS: 7056×2880地形、14页图集和独立树林已装配')

if __name__=='__main__': main()
