"""合成内置图像编辑稿、迁移既有地图标注；不程序绘制地形美术。"""
from pathlib import Path
import copy
import hashlib
from io import BytesIO
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/map/dawn_wide_v3'
HD = ROOT / 'assets/map/dawn_large_hd_v2'
OLD = ROOT / 'assets/map/dawn_large_v1'
SIZE = (7056, 2880)
OFFSET = (2448, 288)
CELL_OFFSET = (68, 8)
LEGACY = (4608, 2592)

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    value=json.dumps(data, ensure_ascii=False, indent=2)+'\n'
    if not path.exists() or path.read_text(encoding='utf-8')!=value:
        path.write_text(value,encoding='utf-8')

def save_image(image,path):
    # 相同输出不重新写入，避免编辑器监视器反复导入或争用大预览图。
    buffer=BytesIO()
    image.save(buffer,format='PNG')
    content=buffer.getvalue()
    if path.exists() and path.read_bytes()==content:
        return
    temporary=path.with_suffix('.png.tmp')
    temporary.write_bytes(content)
    try:
        temporary.replace(path)
    except PermissionError:
        # Windows 预览器可能允许写入但拒绝替换；此处只覆盖本脚本的生成产物。
        path.write_bytes(content)
        temporary.unlink(missing_ok=True)

def shifted(cells):
    return [[x+CELL_OFFSET[0], y+CELL_OFFSET[1]] for x, y in cells]

def blend(base, patch, xy, weight):
    x, y = xy
    box = (x, y, x+patch.width, y+patch.height)
    base.paste(Image.composite(patch.convert(base.mode), base.crop(box), weight), xy)

def edge_mask(size, width):
    yy, xx = np.indices((size[1], size[0]))
    distance = np.minimum.reduce([xx, yy, size[0]-1-xx, size[1]-1-yy])
    return Image.fromarray(np.uint8(np.clip(distance/width, 0, 1)*255))

def minimum_seam(cost):
    """仅在两张既有纹理的重叠区选择色差最小的连续剪切线。"""
    height,width=cost.shape
    total=cost[0].copy()
    parent=np.zeros((height,width),np.int16)
    columns=np.arange(width)
    for y in range(1,height):
        previous=np.stack((np.r_[np.inf,total[:-1]],total,np.r_[total[1:],np.inf]))
        choices=np.argmin(previous,axis=0)-1
        parent[y]=choices
        total=cost[y]+previous[choices+1,columns]
    path=np.zeros(height,np.int32)
    path[-1]=int(np.argmin(total))
    for y in range(height-1,0,-1): path[y-1]=path[y]+parent[y,path[y]]
    return path

def grass_field():
    """只裁切和拼合一份生成材质，不绘制草叶或程序生成美术。"""
    source=Image.open(OUT/'grass-material-v2-source.png').convert('RGB')
    pixels=np.asarray(source,dtype=float)
    low=np.asarray(source.filter(ImageFilter.GaussianBlur(20)),dtype=float)
    # 材质只提供细草高频；整片草地的缓慢光照来自同一份已有生成底色。
    source=Image.fromarray(np.uint8(np.clip(np.rint(128+(pixels-low)*.7),0,255)))
    save_image(source,OUT/'grass-material-v2.png')
    field=np.zeros((SIZE[1],SIZE[0],3),np.uint8)
    tile_size,overlap=576,96
    crop_size=min(source.width,source.height,960)
    for row,y in enumerate(range(0,SIZE[1],tile_size-overlap)):
        for column,x in enumerate(range(0,SIZE[0],tile_size-overlap)):
            seed=(column*73856093)^(row*19349663)
            cx=seed%max(1,source.width-crop_size+1)
            cy=(seed//17)%max(1,source.height-crop_size+1)
            tile=source.crop((cx,cy,cx+crop_size,cy+crop_size))
            w,h=min(tile_size,SIZE[0]-x),min(tile_size,SIZE[1]-y)
            patch=np.asarray(tile.resize((tile_size,tile_size),Image.Resampling.LANCZOS))[:h,:w].copy()
            current=field[y:y+h,x:x+w]
            weight=np.ones((h,w),float)
            if x:
                band=min(overlap,w)
                cost=np.square(current[:,:band].astype(float)-patch[:,:band]).mean(axis=2)
                seam=minimum_seam(cost)
                weight[:,:band]=np.clip((np.arange(band)[None,:]-seam[:,None]+3)/6,0,1)
            if y:
                band=min(overlap,h)
                cost=np.square(current[:band].astype(float)-patch[:band]).mean(axis=2)
                seam=minimum_seam(cost.T)
                top=np.clip((np.arange(band)[:,None]-seam[None,:]+3)/6,0,1)
                weight[:band]=np.minimum(weight[:band],top)
            field[y:y+h,x:x+w]=np.uint8(np.rint(current*(1-weight[:,:,None])+patch*weight[:,:,None]))
    macro=Image.open(OUT/'west-source.png').convert('RGB').filter(ImageFilter.GaussianBlur(12)).resize(SIZE,Image.Resampling.LANCZOS)
    return Image.fromarray(np.uint8(np.clip(np.rint(np.asarray(macro,dtype=float)+(field.astype(float)-128)*.5),0,255)))

def repair_joins(base,legacy,mountain_region):
    # 原有山体从原高清图精确恢复，不保留上一版压缩补绘侵入旧山区的部分。
    protect=Image.new('L',SIZE)
    points=[(round(x/1672*4608)+OFFSET[0],round(y/941*2592)+OFFSET[1]) for x,y in mountain_region]
    ImageDraw.Draw(protect).polygon(points,fill=255)
    preserved=Image.new('RGB',SIZE)
    preserved.paste(legacy,OFFSET)
    base.paste(preserved,(0,0),protect)
    # 新稿保持实际参考的完整坐标尺度，仅采用顶部错误带；下方山路不参与替换。
    north=Image.open(OUT/'north-join-v2-source.png').convert('RGB').resize((3200,1152),Image.Resampling.LANCZOS)
    yy,xx=np.indices((1152,3200))
    alpha=np.clip((420-yy)/100,0,1)*np.clip(xx/100,0,1)*np.clip((3200-xx)/120,0,1)
    fixed=Image.new('L',SIZE)
    draw=ImageDraw.Draw(fixed)
    old=read(OLD/'map.json')
    for polygon in old['cliffs']:
        draw.polygon([(round(x/1672*4608)+OFFSET[0],round(y/941*2592)+OFFSET[1]) for x,y in polygon],fill=255)
    for entry in read(OLD/'mountain-navigation.json')['cells']:
        x,y=entry['cell']
        draw.rectangle((x*36+OFFSET[0]-8,y*36+OFFSET[1]-8,(x+1)*36+OFFSET[0]+8,(y+1)*36+OFFSET[1]+8),fill=255)
    # 保护真实岩壁与路格，不能把旧源图顶端的错误蓝色背景也当成山体一起保护。
    alpha*=1-np.asarray(fixed.crop((2200,0,5400,1152)))/255
    blend(base,north,(2200,0),Image.fromarray(np.uint8(alpha*255)))
    # 最终连续补绘覆盖整个北侧断层；只在原山路以上采用，按同一比例回到世界坐标。
    north=Image.open(OUT/'north-continuity-v3-source.png').convert('RGB').resize((3656,1300),Image.Resampling.LANCZOS)
    yy,xx=np.indices((1300,3656))
    alpha=np.clip((440-yy)/120,0,1)*np.clip(xx/120,0,1)
    blend(base,north,(3400,0),Image.fromarray(np.uint8(alpha*255)))
    # 两处旧顶边残留的蓝色矩形/半截植被仅用同坐标清理稿局部替换。
    cleaned=Image.open(OUT/'north-clean-v4-source.png').convert('RGB').resize((3656,1300),Image.Resampling.LANCZOS)
    for box in [(3820,250,4150,530),(4400,250,5000,510)]:
        x1,y1,x2,y2=box
        patch=cleaned.crop((x1-3400,y1,x2-3400,y2))
        blend(base,patch,(x1,y1),edge_mask(patch.size,28))
    # 在同一片连续平原上统一材质，边界沿实际山脚/湖岸退让，取消全高竖直混合带。
    plain=Image.new('L',SIZE)
    polygon=[(0,0),(3650,0),(3650,288),(3665,536),(3660,729),(3770,949),(4130,1087),(4515,1306),(4790,1458),(4929,1638),(4984,1775),(4956,1913),(4901,2078),(4790,2299),(4597,2519),(4405,2657),(4240,2767),(4240,2880),(0,2880)]
    # 从画布外侧延伸遮罩，避免在左/上/下世界边界留下原底图细线。
    extended=Image.new('L',(SIZE[0]+128,SIZE[1]+128))
    draw_points=[(x+64,y+64) for x,y in polygon]
    draw_points[0]=(-64,-64)
    draw_points[1]=(3714,-64)
    draw_points[-2]=(4304,SIZE[1]+192)
    draw_points[-1]=(-64,SIZE[1]+192)
    ImageDraw.Draw(extended).polygon(draw_points,fill=255)
    plain=extended.filter(ImageFilter.GaussianBlur(20)).crop((64,64,SIZE[0]+64,SIZE[1]+64))
    mask=np.asarray(plain,dtype=float)*(1-np.asarray(protect)/255)
    blend(base,grass_field(),(0,0),Image.fromarray(np.uint8(mask)))
    save_image(Image.fromarray(np.uint8(mask)),OUT/'plain-material-mask-v2.png')

def main():
    OUT.mkdir(exist_ok=True)
    old = read(OLD/'map.json')
    hd = read(HD/'visual.json')
    # 修复稿具有真实草叶细节；宽羽化只用于原有素材之间的合成。
    repaired = Image.open(HD/'base.png').convert('RGB')
    patch = Image.open(OUT/'grass-repair-source.png').resize((1200,1800), Image.Resampling.LANCZOS)
    grass_mask = Image.new('L',repaired.size,255)
    mountain_region = read(OLD/'mountain-navigation.json')['region']
    ImageDraw.Draw(grass_mask).polygon([(x*3,y*3) for x,y in mountain_region],fill=0)
    mask = np.asarray(edge_mask(patch.size,110)).astype(float)*np.asarray(grass_mask.crop((750,540,1950,2340)))/255
    blend(repaired, patch, (750,540),Image.fromarray(np.uint8(mask)))
    save_image(repaired,OUT/'legacy-repaired.png')
    base = Image.open(OUT/'extension-source.png').convert('RGB').resize(SIZE, Image.Resampling.LANCZOS)
    legacy = repaired.resize(LEGACY, Image.Resampling.LANCZOS)
    # 仅西侧接入带渐变；全部既有山路、石梯、湖岸继续保留原像素位置。
    alpha = np.broadcast_to(np.uint8(np.clip(np.arange(LEGACY[0])/180,0,1)*255),(LEGACY[1],LEGACY[0])).copy()
    blend(base,legacy,OFFSET,Image.fromarray(alpha))
    # 西侧单独出图保持细草密度，向旧地表缓慢交接，避免整图扩边稿的粗碎石。
    west = Image.open(OUT/'west-source.png').convert('RGB').resize((2848,2880),Image.Resampling.LANCZOS)
    west_alpha = np.broadcast_to(np.uint8(np.clip((2848-np.arange(2848))/500,0,1)*255),(2880,2848)).copy()
    blend(base,west,(0,0),Image.fromarray(west_alpha))
    # 北部补全稿的下方旧山体仅为参考，只取新增上部与48世界像素过渡。
    north = Image.open(OUT/'north-source.png').resize((1833,650), Image.Resampling.LANCZOS)
    cap = north.crop((0,0,1833,315)).resize((3368,336), Image.Resampling.LANCZOS)
    yy, xx = np.indices((336,3368))
    weight = np.clip((336-yy)/48,0,1)*np.clip((xx-300)/300,0,1)
    blend(base,cap,(3688,0),Image.fromarray(np.uint8(weight*255)))
    repair_joins(base,legacy,mountain_region)
    save_image(base,OUT/'base.png')
    chunks = []
    # 共边裁切同一完整地表，渲染不再拼独立重绘稿。
    for y in range(3):
        for x in range(6):
            box = (x*1176,y*960,(x+1)*1176,(y+1)*960)
            name = f'ground-{x}-{y}.png'
            save_image(base.crop(box),OUT/name)
            chunks.append(dict(path=f'assets/map/dawn_wide_v3/{name}',worldRect=[box[0],box[1],1176,960],pixelSize=[1176,960]))
    # 复用独立边界树林；只裁除旧素材携带的草地，不生成新树木。
    forest = Image.open(HD/'border-forest.png').convert('RGBA')
    rgba = np.asarray(forest).copy()
    t = np.clip(((rgba[:,:,2].astype(float)-rgba[:,:,1])/255+.004)/.026,0,1)
    rgba[:,:,3] = np.rint(rgba[:,:,3]*t*t*(3-2*t)).astype(np.uint8)
    forest = Image.fromarray(rgba).resize((1976,2880),Image.Resampling.LANCZOS)
    border = Image.new('RGBA',SIZE)
    border.alpha_composite(forest,(0,0))
    # 西北林带沿新平原外缘延续，保留内部开阔建筑空间。
    # 取含完整树根与透明边的林簇；旧170像素截条会把树冠/树干切成矩形。
    strip = forest.crop((580,0,1580,320))
    for x in (1400,2400):
        border.alpha_composite(strip,(x,-176))
    save_image(border,OUT/'border-forest.png')
    data = copy.deepcopy(old)
    data.update(schema='waiting-for-dawn.layered-map.v3',worldSize=list(SIZE),gridSize=[196,80],sourceWorldOrigin=list(OFFSET),sourceWorldSize=list(LEGACY))
    data['city'] = [old['city'][i]+OFFSET[i] for i in range(2)]
    data['spawns'] = [[p[i]+OFFSET[i] for i in range(2)] for p in old['spawns']]
    for site in data['resourceSites']:
        site['position']['x'] += OFFSET[0]
        site['position']['y'] += OFFSET[1]
    data['cells'] = {kind: shifted(cells) for kind,cells in old['cells'].items() if kind!='forest'}
    data['cells']['forest'] = sorted({(x,min(79,int((y+.5)*80/72))) for x,y in old['cells']['forest']} | {(x,y) for x in range(39,100) for y in range(4)})
    # 新北部为山体后缘展示带，未设计新山路，独立边界属性禁止穿越与建造。
    data['cells']['boundary'] = [[x,y] for x in range(102,196) for y in range(8)]
    data['chunks'] = chunks
    data['border'] = dict(sprite='assets/map/dawn_wide_v3/border-forest.png',worldRect=[0,0,*SIZE],occlusionClass='tall',actorSafeArea=None,occupantPolicy='blocked_boundary')
    data['geometrySource'] = '../dawn_large_v1/map.json'
    data['legacyQC'] = data.pop('qc')
    data['qc'] = dict(terrainChunkReconstructionMaxChannelDifference=0,identicalToLegacyPainting=False)
    data['artSource'] = '内置image_gen扩边、北部补全与草地修复；旧山区与水岸采用原高清素材，树林与资源独立'
    write(OUT/'map.json',data)
    nav = read(OLD/'mountain-navigation.json')
    nav['worldSize'] = list(SIZE)
    nav['sourceWorldOrigin'] = list(OFFSET)
    nav['sourceWorldSize'] = list(LEGACY)
    for key in ('mountainCells','cliffCells'):
        nav[key] = shifted(nav[key])
    for entry in nav['cells']:
        entry['cell'] = shifted([entry['cell']])[0]
    write(OUT/'mountain-navigation.json',nav)
    # 岩缘继续使用原有高清像素和透明轮廓，坐标统一经过新源图原点转换。
    occluders=copy.deepcopy(hd['occluders'])
    for index in (1,4):
        entry=occluders[index]
        x1,y1,x2,y2=entry['sourceRect']
        box=(round(x1/1672*4608)+2448,round(y1/941*2592)+288,round(x2/1672*4608)+2448,round(y2/941*2592)+288)
        sprite=Image.open(ROOT/entry['path']).convert('RGBA')
        # 保持独立遮挡轮廓；同步北部已清理地表，防止旧岩缘层把蓝色残片重新盖回来。
        refreshed=base.crop(box).resize(sprite.size,Image.Resampling.LANCZOS).convert('RGBA')
        refreshed.putalpha(sprite.getchannel('A'))
        yy=np.arange(sprite.height)[:,None]/sprite.height*(box[3]-box[1])+box[1]
        weight=np.broadcast_to(np.uint8(np.clip((550-yy)/20,0,1)*255),(sprite.height,sprite.width))
        sprite=Image.composite(refreshed,sprite,Image.fromarray(weight.copy()))
        name=f'cliff-{index}-repaired.png'
        save_image(sprite,OUT/name)
        entry['path']='assets/map/dawn_wide_v3/'+name
    visual = dict(schema='waiting-for-dawn.hd-visual.v3',sourceSize=old['sourceSize'],worldSize=list(SIZE),groundScale=1,forestScale=hd['forestScale'],chunks=chunks,forests=hd['forests'],occluders=occluders,border=data['border'])
    write(OUT/'visual.json',visual)
    preview = base.convert('RGBA')
    preview.alpha_composite(border)
    for entry in hd['forests']:
        x1,y1,x2,y2 = entry['sourceRect']
        x = round(x1/1672*4608)+OFFSET[0]
        y = round(y1/941*2592)+OFFSET[1]
        size = (round((x2-x1)/1672*4608),round((y2-y1)/941*2592))
        preview.alpha_composite(Image.open(ROOT/entry['path']).resize(size,Image.Resampling.LANCZOS),(x,y))
    save_image(preview.convert('RGB'),OUT/'layered-preview.png')
    save_image(preview.convert('RGB').resize((392,160),Image.Resampling.LANCZOS),OUT/'minimap.png')
    save_image(preview.convert('RGB').resize((1764,720),Image.Resampling.LANCZOS),OUT/'overview.png')
    record = dict(date='2026-10-21',tool='built-in image_gen',mapMode='scene_mode',visualModel='layered_raster',runtimeObjectModel='existing_separate_props',collisionModel='project-native grid + blocked north boundary',engineTarget='Godot 4.7',worldSize=list(SIZE),legacyWorldOffset=list(OFFSET),generatedAssets=[])
    record['revision']='join-repair-v4'
    record['composition']='原山区像素保护；顶部真实坐标补绘；全平原共用一份生成草地材质，以重叠区最小色差剪切线拼合'
    references = {'extension-source':'extension-guide','north-source':'north-guide','grass-repair-source':'grass-seam-reference','west-source':'west-guide','grass-material-v2-source':'grass-material-v2','north-join-v2-source':'north-join-v2','north-continuity-v3-source':'north-continuity-v3','north-clean-v4-source':'north-clean-v4'}
    for name in references:
        path = OUT/(name+'.png')
        record['generatedAssets'].append(dict(path=path.name,prompt=name+'.prompt.txt',reference='references/'+references[name]+'.png',nativeSize=list(Image.open(path).size),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    write(OUT/'generation-record.json',record)
    print('地图合成完成：7056×2880 / 196×80格；旧山区平移2448,288；18片共边地形')

if __name__ == '__main__':
    main()
