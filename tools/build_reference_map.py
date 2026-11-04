"""装配生成素材、校准色域并登记来源；不绘制最终美术。"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw
import hashlib, json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/map_kits/reference_20261029'
SRC = OUT / 'source'
world = np.array([7056, 2880])
reference = np.array([1962, 801])
base = Image.open(SRC / 'foundation.png').convert('RGB')
assert base.width >= 1960 and base.height >= 800
base.resize((1960,800), Image.Resampling.LANCZOS).save(OUT / 'terrain.png')
guide = base.resize(tuple(reference), Image.Resampling.LANCZOS)
guide.filter(ImageFilter.GaussianBlur(48)).save(OUT/'terrain-low.png')
# 美术区域遮罩，绝不用于玩法碰撞。连贯覆盖平原，保留山脚/水岸结构。
plain = Image.new('L',tuple(reference),0)
ImageDraw.Draw(plain).polygon([(0,0),(1055,0),(1055,80),(1040,130),(1040,220),(1150,310),(1290,370),(1320,470),(1280,560),(1260,620),(1200,660),(1100,740),(1030,801),(0,801)],fill=255)
plain = plain.filter(ImageFilter.GaussianBlur(3))
# 水面只接受与地图右边缘连通的蓝色区域；孤立蓝岩不属于水。
rgb=np.asarray(guide,dtype=float)
blue=(rgb[:,:,2]>rgb[:,:,1]*1.65)&(rgb[:,:,0]<rgb[:,:,1]*.7)
connected=Image.fromarray(np.uint8(blue)*255).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
for row in range(connected.height):
    if connected.getpixel((connected.width-1,row))==255:
        ImageDraw.floodfill(connected,(connected.width-1,row),128)
ocean=np.asarray(connected)==128
water=Image.fromarray(np.uint8(ocean)*255).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1))
Image.merge('RGB',(plain,water,Image.new('L',plain.size,0))).save(OUT/'region-mask.png')
for name in ['grass-detail', 'water-detail']:
    art = Image.open(SRC / (name+'.png')).convert('RGB')
    art.save(OUT / (name+'.png'))
    art.filter(ImageFilter.GaussianBlur(32)).save(OUT / (name+'-low.png'))
regions = json.loads((SRC / 'regions.json').read_text())
regions = [r for r in regions if r['id'] not in ['mountain-southwest','shore-east']]
regions.append(dict(id='cliff-detail',reference_rect=[1040,110,460,300],reference_file='cliff-detail-reference.png'))
patches = []
def seam_mask(cost, band):
    """仅裁定已有素材的拼接遮罩；沿最小色差路径避开结构双影。"""
    strip=cost[:,:band].copy()
    strip+=((np.arange(band)/band-.5)**2)[None,:]*120
    accum=strip[0].copy()
    steps=np.zeros(strip.shape,dtype=np.int8)
    for row in range(1,len(strip)):
        choices=np.stack((np.r_[np.inf,accum[:-1]],accum,np.r_[accum[1:],np.inf]))
        pick=choices.argmin(axis=0)
        steps[row]=pick-1
        accum=strip[row]+choices[pick,np.arange(band)]
    path=np.zeros(len(strip),dtype=int)
    path[-1]=accum.argmin()
    for row in range(len(strip)-1,0,-1):path[row-1]=path[row]+steps[row,path[row]]
    return np.clip((np.arange(cost.shape[1])[None,:]-path[:,None]+2)/4,0,1)
for region in regions:
    source = SRC / (region['id']+'.png')
    if not source.exists(): continue
    art = Image.open(source).convert('RGB')
    x,y,w,h = region['reference_rect']
    assert abs(art.width/art.height-w/h) < .03, source.name
    # 放大低频色域引导不提供轮廓或细节；输出细节像素始终来自新生成原稿。
    target = guide.crop((x,y,x+w,y+h)).resize(art.size,Image.Resampling.BILINEAR)
    radius = max(16,art.width/24)
    low = np.asarray(art.filter(ImageFilter.GaussianBlur(radius)),dtype=float)+8
    tint = np.asarray(target.filter(ImageFilter.GaussianBlur(radius)),dtype=float)+8
    pixels = np.asarray(art,dtype=float)*np.clip(tint/low,.55,1.6)
    # 不再沿PNG矩形边缘交接；四边沿同坐标底图的最小色差曲线切换。
    cost=np.mean((pixels-np.asarray(target,dtype=float))**2,axis=2)
    horizontal=max(24,int(art.width*.14)); vertical=max(24,int(art.height*.14))
    join=seam_mask(cost,horizontal)
    join*=seam_mask(cost[:,::-1],horizontal)[:,::-1]
    join*=seam_mask(cost.T,vertical).T
    join*=seam_mask(cost[::-1].T,vertical).T[::-1]
    raw=np.asarray(art,dtype=float)
    original=np.asarray(target,dtype=float)
    wrong_water=np.zeros(raw.shape[:2],dtype=bool)
    if region['id']=='mountain-west':
        wrong_water=(raw[:,:,2]>raw[:,:,1]*1.75)&(raw[:,:,0]<raw[:,:,1]*.55)&(original[:,:,1]>original[:,:,2]*.9)
        # 假水面连同湿岸一起移除，不能只挖掉蓝像素留下碎片轮廓。
        wrong_water[:int(art.height*.26),:int(art.width*.20)]=True
    if region['id']=='shore-south':
        # 新稿误添一段原图不存在的石阶；该局部回退到权威底层，避免提示假通路。
        wrong_water[int(art.height*.32):int(art.height*.54),int(art.width*.43):int(art.width*.56)]=True
    alpha=Image.fromarray(np.uint8(~wrong_water)*255).filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(2))
    # 只对硬质结构使用窄最小差接缝；草地区域保留原片，由材质宽过渡。
    structure=np.clip((raw[:,:,2]/np.maximum(raw[:,:,1],1)-1.0)/.2,0,1)
    alpha=Image.fromarray(np.uint8(np.asarray(alpha,dtype=float)*(1-structure+structure*join)))
    result=Image.fromarray(np.uint8(np.clip(pixels,0,255))).convert('RGBA')
    result.putalpha(alpha)
    result.save(OUT / (region['id']+'.png'))
    patches.append(dict(id=region['id'],file=region['id']+'.png',
        world_rect=[x*world[0]/reference[0],y*world[1]/reference[1],w*world[0]/reference[0],h*world[1]/reference[1]],
        native_size=list(art.size),source=source.relative_to(ROOT).as_posix(),
        prompt='source/cliff-detail.prompt.txt' if region['id']=='cliff-detail' else ('source/shore-middle.prompt.txt' if region['id']=='shore-middle' else 'source/region-redraw.prompt.txt')))
record = dict(version=1,world_size=world.tolist(),reference_size=reference.tolist(),
    foundation='terrain.png',foundation_prompt='source/foundation.prompt.txt',
    gameplay_geometry='assets/levels/level_001/*.json',patches=patches,
    grass_world_size=[156,156],water_world_size=[192,128],
    missing_regions=[r['id'] for r in regions if not (SRC/(r['id']+'.png')).exists()],
    files={p.relative_to(OUT).as_posix():dict(size=list(Image.open(p).size),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in OUT.glob('*.png')},
    generation_source='builtin_imagegen',
    derived_control_files={'region-mask.png':'2026-11-02美术区域遮罩，不是生成美术或玩法碰撞','terrain-low.png':'foundation低频底色，不提供新增结构细节'},
    source_files={p.name:dict(size=list(Image.open(p).size),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in SRC.glob('*.png')},
    retained_geometry_note='玩法数据沿用独立36格；美术重绘不代表逐像素碰撞已重新人工验收',
    covered_alternatives={'mountain-southwest':'cliff-detail与相邻山片覆盖','shore-east':'peninsula/shore-middle与独立水面材质覆盖'})
(OUT/'map.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for p in OUT.glob('*.png'):
    side=p.with_suffix('.png.import')
    if side.exists():
        side.write_text(side.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
    else:
        side.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+p.relative_to(ROOT).as_posix()+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/size_limit=0\n',encoding='utf-8')
print('PASS: 新底层、草水原生细节及%d个重绘区域已装配；缺少区域：%s'%(len(patches),record['missing_regions']))
