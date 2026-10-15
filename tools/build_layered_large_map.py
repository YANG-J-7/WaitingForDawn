"""按已确认母图拆层与生成权威标注；只合成、裁切已有图，不程序绘制美术。"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/map/dawn_large_v1'
REFERENCE = ROOT / 'design/art/concepts/mountain-redesign-2026-10-13/mountain-redesign-preview-v2.png'
SCALE = np.array([4608/1672, 2592/941])

# 标注使用母图像素坐标，运行时不从颜色推断地形。
CLIFFS = [
    [[474,110],[544,120],[623,123],[677,148],[710,148],[751,156],[782,177],[774,218],[743,227],[703,200],[656,198],[620,178],[553,170],[491,156]],
    [[585,0],[610,3],[638,38],[698,55],[760,66],[826,83],[887,99],[946,95],[968,106],[1005,102],[1027,119],[1040,159],[1004,182],[956,178],[912,157],[856,157],[813,134],[756,123],[718,104],[666,87],[628,65],[598,45]],
    [[681,172],[736,189],[785,207],[827,214],[859,218],[888,237],[908,279],[879,291],[848,277],[808,271],[768,257],[737,240],[687,224]],
    [[948,249],[992,267],[1031,271],[1074,263],[1092,278],[1091,314],[1059,337],[1012,355],[982,351],[952,332],[925,316]],
    [[1109,48],[1143,65],[1214,73],[1284,92],[1354,100],[1410,100],[1448,88],[1477,100],[1491,141],[1481,173],[1430,184],[1380,180],[1328,169],[1286,149],[1239,146],[1189,134],[1143,116],[1119,96]],
    [[1135,211],[1189,227],[1269,240],[1338,250],[1370,251],[1404,241],[1420,256],[1420,293],[1387,315],[1345,319],[1298,303],[1258,283],[1213,282],[1174,268],[1125,254]],
    [[1106,351],[1132,365],[1179,366],[1206,352],[1243,365],[1269,367],[1294,375],[1317,401],[1305,455],[1270,470],[1234,459],[1206,439],[1166,436],[1128,419],[1105,394]],
    [[1425,272],[1464,285],[1500,288],[1535,271],[1568,276],[1597,299],[1610,336],[1596,371],[1556,387],[1510,380],[1479,359],[1441,348],[1408,321]],
    [[1583,148],[1617,160],[1650,168],[1672,169],[1672,207],[1639,209],[1610,196]],
    [[1017,550],[1061,534],[1100,527],[1108,540],[1092,560],[1054,574],[1016,571]],
    [[1266,508],[1321,516],[1388,527],[1438,555],[1436,585],[1398,603],[1344,594],[1297,574],[1262,552]],
    [[1062,691],[1105,701],[1150,728],[1196,739],[1240,741],[1248,756],[1220,782],[1170,786],[1120,766],[1090,742],[1060,730]],
]
WATER = [[680,941],[663,887],[709,858],[779,838],[831,819],[889,799],[938,776],[994,772],[1038,741],[1038,717],[994,686],[938,668],[918,643],[940,611],[954,583],[999,563],[1030,565],[1090,565],[1120,540],[1120,513],[1134,494],[1190,479],[1252,465],[1291,454],[1310,484],[1380,486],[1450,461],[1490,423],[1536,413],[1592,415],[1672,400],[1672,941]]
ISLANDS = [
    [[1185,468],[1260,466],[1288,479],[1288,505],[1238,520],[1208,502]],
    [[1265,491],[1320,488],[1356,500],[1400,504],[1454,534],[1450,572],[1410,591],[1330,580],[1270,544]],
    [[998,681],[1062,674],[1099,691],[1150,726],[1228,729],[1240,753],[1205,778],[1150,771],[1090,741],[1050,725]],
]
RAMPS = [
    [[613,201],[637,168],[650,134]], [[678,111],[699,78],[713,44]],
    [[1042,96],[1086,55]], [[1416,83],[1446,118],[1472,159]],
    [[1100,285],[1131,253],[1155,215]], [[994,390],[1028,353],[1070,310]],
    [[1175,448],[1203,411],[1235,366]], [[1463,293],[1485,329],[1514,361]],
]
ROADS = [
    [[500,670],[618,561],[797,495],[991,390],[1055,328],[1097,285],[1180,305],[1240,347],[1300,338],[1390,348],[1455,385]],
    [[991,390],[820,322],[683,254],[613,201]],
    [[613,201],[676,165],[740,141],[820,176],[943,214],[1042,96]],
    [[650,134],[678,111]], [[713,44],[830,38],[980,91],[1086,55]],
    [[1155,215],[1194,182],[1402,186],[1472,159]],
    [[1235,366],[1317,351],[1400,329],[1463,293]],
]
FORESTS = [
    ('forest_02', [530,258,717,417], [620,381]),
    ('forest_04', [380,378,610,567], [500,518]),
    ('forest_03', [714,379,914,541], [815,505]),
    ('forest_05', [585,606,796,793], [694,750]),
]
BORDER = [[0,0],[565,0],[565,99],[440,105],[396,90],[330,94],[280,104],[210,93],[192,195],[190,245],[208,318],[149,370],[130,420],[185,461],[233,509],[250,600],[180,610],[163,663],[200,766],[275,750],[388,750],[466,770],[543,770],[624,816],[697,857],[716,941],[0,941]]

def world(p): return (np.array(p)*SCALE).tolist()
def save_json(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def mask_polygon(points,size):
    mask=Image.new('L',size); ImageDraw.Draw(mask).polygon([tuple(p) for p in points],fill=255); return mask
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    original=Image.open(REFERENCE).convert('RGB')
    generated=Image.open(OUT/'ground-fill-source.png').convert('RGB').resize(original.size,Image.Resampling.LANCZOS)
    base=np.asarray(original).copy(); src=np.asarray(generated).astype(float)
    masks=[]; overlays=[]
    for sid,box,foot in FORESTS:
        mask=Image.new('L',original.size); ImageDraw.Draw(mask).rounded_rectangle((box[0],box[1],box[2]-1,box[3]-1),radius=12,fill=255)
        masks.append((sid,mask,box,foot))
    bm=mask_polygon(BORDER,original.size)
    masks.append(('border-forest',bm,list(bm.getbbox()),[0,0]))
    for sid,mask,box,foot in masks:
        # 限定在拆层区域补地，原图其它地形像素完全保持。
        alpha=np.asarray(mask)/255.0
        inside=np.asarray(mask.filter(ImageFilter.GaussianBlur(8)))/255.0
        weight=np.clip((inside-0.45)/0.25,0,1)*alpha
        edge=(alpha>0)&(weight<0.6)
        a=np.asarray(original).astype(float)
        # 消除生成补地的整体偏亮；局部边缘以母图草地色调为依据。
        grass=edge & (a[:,:,1]>a[:,:,2]*0.9) & (a[:,:,0]>35)
        ratio=np.median(a[grass],axis=0)/np.maximum(np.median(src[grass],axis=0),1) if grass.any() else np.array([.72,.75,.85])
        fill=np.clip(src*ratio,0,255)
        base=np.rint(base*(1-weight[:,:,None])+fill*weight[:,:,None]).astype(np.uint8)
        rgba=original.convert('RGBA'); rgba.putalpha(mask)
        rgba.crop(tuple(box)).save(OUT/f'{sid}.png')
        overlays.append(dict(id=sid,sprite=f'assets/map/dawn_large_v1/{sid}.png',sourceRect=box,sourceFoot=foot,occlusionClass='tall',occupantPolicy='hide_on_claim_keep_opaque_near_actor'))
    Image.fromarray(base).save(OUT/'base.png')
    preview=Image.fromarray(base).convert('RGBA')
    for layer in overlays:
        box=layer['sourceRect']; preview.alpha_composite(Image.open(ROOT/layer['sprite']),tuple(box[:2]))
    preview.convert('RGB').save(OUT/'layered-preview.png')
    diff=np.abs(np.asarray(preview.convert('RGB')).astype(int)-np.asarray(original).astype(int))
    assert diff.max()==0, '初态合成偏离母图'
    original.resize((256,144),Image.Resampling.LANCZOS).save(OUT/'minimap.png')
    chunks=[]
    for y in range(3):
        for x in range(4):
            box=[x*418,y*314,min((x+1)*418,1672),min((y+1)*314,941)]
            path=f'assets/map/dawn_large_v1/ground-{x}-{y}.png'
            Image.fromarray(base).crop(tuple(box)).save(ROOT/path)
            chunks.append(dict(path=path,sourceRect=box))
    sites=[]
    for layer in overlays[:4]:
        p=np.round(np.array(world(layer['sourceFoot']))/36)*36
        sites.append(dict(id=layer['id'],siteType='forest',position=dict(x=p[0],y=p[1]),placementRadius=110,sprite=layer['sprite'],sourceRect=layer['sourceRect'],sourceFoot=layer['sourceFoot'],blockedSourceRect=layer['sourceRect']))
    for sid,typ,p in [('stone_01','stone_deposit',[800,46]),('stone_02','stone_deposit',[988,241]),('iron_01','iron_deposit',[1360,218]),('iron_02','iron_deposit',[600,100])]:
        pos=np.round(np.array(world(p))/36)*36
        sites.append(dict(id=sid,siteType=typ,position=dict(x=pos[0],y=pos[1]),placementRadius=90))
    # 生成权威格清单。多边形按格中心取样，石阶仅开放预先标注的有限通道。
    def gridmask(polygons):
        m=Image.new('L',original.size)
        d=ImageDraw.Draw(m)
        for poly in polygons: d.polygon([tuple(p) for p in poly],fill=255)
        return m
    cliff=gridmask(CLIFFS); water=gridmask([WATER]); lands=gridmask(ISLANDS)
    wm=np.asarray(water).copy(); wm[np.asarray(lands)>0]=0
    ramps=Image.new('L',original.size); roads=Image.new('L',original.size)
    for points in RAMPS: ImageDraw.Draw(ramps).line([tuple(p) for p in points],fill=255,width=24)
    for points in ROADS: ImageDraw.Draw(roads).line([tuple(p) for p in points],fill=255,width=28)
    cells={t:[] for t in ['cliff','water','ramp','road','forest']}
    cm=np.asarray(cliff); rm=np.asarray(ramps); pm=np.asarray(roads); fm=np.asarray(bm)
    for y in range(72):
        for x in range(128):
            px=int((x+.5)*36/SCALE[0]); py=int((y+.5)*36/SCALE[1])
            typ='water' if wm[py,px] else ('forest' if fm[py,px] else ('ramp' if rm[py,px] else ('cliff' if cm[py,px] else ('road' if pm[py,px] else 'grass'))))
            if typ in cells: cells[typ].append([x,y])
    occluders=[]
    for index,poly in enumerate(CLIFFS):
        mask=mask_polygon(poly,original.size); box=list(mask.getbbox())
        rgba=original.convert('RGBA'); rgba.putalpha(mask)
        path=f'assets/map/dawn_large_v1/cliff-{index}.png'
        rgba.crop(tuple(box)).save(ROOT/path)
        occluders.append(dict(path=path,sourceRect=box,occupantPolicy='fade_near_actor'))
    data=dict(schema='waiting-for-dawn.layered-map.v1',worldSize=[4608,2592],cellSize=36,gridSize=[128,72],sourceSize=[1672,941],city=[1728,1620],spawns=[[756,216],[2808,36],[468,1116],[828,2160]],chunks=chunks,border=overlays[-1],resourceSites=sites,cells=cells,cliffs=CLIFFS,water=[WATER],islands=ISLANDS,ramps=RAMPS,roads=ROADS,occluders=occluders,plateauSamples=[[557,94],[800,46],[988,241],[1340,209]],qc=dict(initialCompositeMaxChannelDifference=int(diff.max()),sourceSHA256=hashlib.sha256(REFERENCE.read_bytes()).hexdigest()),artSource='母图提取和内置image_gen补地；未增加母图之外的高清地形细节')
    save_json(OUT/'map.json',data)
    save_json(OUT/'generation-record.json',dict(date='2026-10-13',tool='built-in image_gen',attempts=['HTTP429','成功'],source='ground-fill-source.png',reference=str(REFERENCE.relative_to(ROOT)),usage='仅树林遮挡下的补地，母图其它像素保持',originalSize=list(Image.open(OUT/'ground-fill-source.png').size)))
    print('分层合成与母图最大通道差：',diff.max(),'; 权威格：',{k:len(v) for k,v in cells.items()})
if __name__=='__main__': main()
