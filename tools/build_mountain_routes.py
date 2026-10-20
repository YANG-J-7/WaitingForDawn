"""按高清地图人工登记山路、石阶入口；仅生成玩法数据与诊断图。"""
from pathlib import Path
import json, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/map/dawn_large_v1/mountain-navigation.json'
SCALE = (4608/1672,2592/941)
# 草台仍可建；山域内只有路网开放行走。高度只约束连接，不增加战斗属性。
REGION = [[450,0],[1672,0],[1672,441],[1455,465],[1285,489],[1135,500],
          [1070,466],[970,410],[930,345],[875,305],[670,270],[615,225],[480,190],[450,130]]
# 用户红圈处为前伸岩壁，阶梯宽度容差也不能覆盖这个区域。
HARD_CLIFFS = [
    [[990,89],[1009,82],[1024,87],[1030,108],[1042,126],[1033,154],
     [1005,169],[980,153],[968,129],[975,103]],
    # 西北石梯左侧的上层岩壁；原道路把坡脚灌木误当作可走路肩。
    [[965,10],[983,21],[1004,31],[1038,40],[1060,48],[1064,59],
     [1059,82],[1041,83],[1019,76],[992,70],[972,65],[963,50],
     [957,40],[957,25]],
    # S6西侧竖直崖面，旧斜线从这里穿岩；两段石梯必须经中间平台折返。
    [[1151,363],[1172,363],[1192,374],[1187,399],[1173,411],[1153,399]],
    # 上段石梯东侧岩墙不能作为抄近路的路肩。
    [[1229,390],[1246,392],[1246,421],[1222,428],[1223,412]],
]
JUNCTION = [980,205]
VALLEY_ROUTE = [JUNCTION,[1000,188],[1030,176],[1055,162],
                [1080,143],[1080,128],[1065,110],[1065,95]]
ROUTES = [
    (0, [[600,242],[613,201]]),
    (0, [[922,420],[994,390]]),
    (0, [[994,390],[1055,406],[1090,445],[1105,467],[1125,475],[1138,459]]),
    (0, [[1520,357],[1535,380],[1570,403],[1605,385],[1640,350],[1655,280],[1672,260]]),
    (1, [[650,134],[635,112],[630,92],[610,77],[580,78],[550,90]]),
    (1, [[610,99],[630,92]]),
    (1, [[650,134],[666,121],[678,111]]),
    (1, [[650,134],[737,144],[818,165],[885,181],[938,195],JUNCTION,[1020,225]]),
    # 东南分支沿前方岩缘北侧土路绕过凸角，不把单格断点当成绕行整山的理由。
    (1, [[988,241],[1015,225],[1044,246],[1070,249],[1098,255],[1121,266]]),
    (1, [[1046,305],[1080,285],[1121,266]]),
    (1, [[1121,266],[1120,287],[1200,327],[1300,310],[1335,300],[1350,280],[1385,260],[1410,270],[1480,305]]),
    (1, [[1222,379],[1230,350],[1200,327]]),
    # 谷底从南侧山路绕到石梯下端；西侧高台在前景石壁处终止，不能直连。
    (1, VALLEY_ROUTE),
    (2, [[713,44],[760,32],[780,20],[820,20],[860,64],[920,70],[945,78],[960,85]]),
    (2, [[800,46],[800,20]]),
    (2, [[1155,215],[1194,182],[1280,194],[1360,204],[1402,186],[1455,200],[1505,190],[1500,148],[1472,159]]),
    (3, [[1086,55],[1120,31],[1200,30],[1300,42],[1390,55],[1416,83]]),
]
STAIRS = [
    (0,1,[[613,201],[637,168],[650,134]]),
    (1,2,[[678,111],[699,78],[713,44]]),
    (1,3,[[1065,86],[1075,75],[1086,62]]),
    (3,2,[[1416,83],[1446,118],[1472,159]]),
    (1,2,[[1121,266],[1137,240],[1155,215]]),
    (0,1,[[994,390],[1014,348],[1046,305]]),
    (0,1,[[1138,459],[1162,430],[1185,426],[1206,418],[1216,396],[1222,379]]),
    (1,0,[[1480,305],[1500,333],[1520,357]]),
]

def distance(p, line):
    best = math.inf
    for a,b in zip(line,line[1:]):
        dx,dy = b[0]-a[0],b[1]-a[1]
        t = max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
        best=min(best,math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy))
    return best

def build():
    data=json.loads((ROOT/'assets/map/dawn_large_v1/map.json').read_text(encoding='utf-8'))
    region=Image.new('L',(1672,941));ImageDraw.Draw(region).polygon(REGION,fill=255)
    hard_cliff=Image.new('L',region.size)
    for poly in HARD_CLIFFS:ImageDraw.Draw(hard_cliff).polygon([tuple(p) for p in poly],fill=255)
    # 硬岩壁同样预留脚点余量，石梯宽度容差不能重新开放这些格。
    hard_cliff=hard_cliff.filter(ImageFilter.MaxFilter(9))
    cliff=Image.new('L',region.size)
    cliffs=data['cliffs'].copy()
    cliffs[3]=[[925,257],[953,270],[996,283],[1029,280],[1059,268],[1081,262],
               [1085,269],[1066,291],[1048,311],[1040,337],[1015,355],[982,351],[952,332],[925,316]]
    # 高清图东侧岩缘与旧图有偏移，分别登记阶梯两旁岩壁，留出真实的中层山路。
    cliffs[5]=[[1160,217],[1210,221],[1265,217],[1300,228],[1334,235],[1336,260],
               [1315,280],[1280,298],[1240,309],[1200,303],[1170,284],[1142,273],[1142,247]]
    # S6为两段错位石梯，旧单块岩面误盖住上端土路；分开登记西侧崖面和下层前缘。
    cliffs[6]=[[1106,345],[1132,350],[1179,354],[1206,365],[1210,374],[1194,404],
               [1180,419],[1158,412],[1138,414],[1112,397],[1105,378]]
    cliffs.append([[1106,414],[1132,418],[1148,430],[1135,447],[1120,452],[1105,445]])
    cliffs.append([[1174,437],[1200,436],[1234,440],[1270,448],[1294,455],[1310,473],
                   [1290,490],[1250,482],[1220,476],[1180,468],[1157,466],[1169,450]])
    cliffs[7]=[[1360,291],[1390,278],[1425,293],[1465,305],[1485,305],[1510,324],
               [1520,350],[1490,347],[1450,332],[1410,320],[1380,316],[1355,305]]
    cliffs.append([[1425,235],[1445,232],[1480,250],[1520,262],[1550,264],[1580,262],
                   [1600,283],[1600,310],[1560,302],[1520,288],[1480,278],[1440,265],[1420,255]])
    for poly in cliffs+HARD_CLIFFS:ImageDraw.Draw(cliff).polygon([tuple(p) for p in poly],fill=255)
    # 扩四个源像素保护岩缘，避免格中心落草地但脚点半格碰岩。
    cliff=cliff.filter(ImageFilter.MaxFilter(9))
    blocked={tuple(c) for t in ['water','forest'] for c in data['cells'][t]}
    cells=[];rocks=[];mountain=[]
    for y in range(72):
        for x in range(128):
            p=((x+.5)*36/SCALE[0],(y+.5)*36/SCALE[1]);pixel=(int(p[0]),int(p[1]))
            if region.getpixel(pixel):mountain.append([x,y])
            stair=min(enumerate(STAIRS),key=lambda s:distance(p,s[1][2]))
            is_stair=distance(p,stair[1][2])<=12
            if hard_cliff.getpixel(pixel):
                rocks.append([x,y]);continue
            if cliff.getpixel(pixel) and not is_stair:rocks.append([x,y])
            if (x,y) in blocked:continue
            if is_stair:
                i,(a,b,line)=stair
                ends=[]
                if math.dist(p,line[0])<=23:ends.append(a)
                if math.dist(p,line[-1])<=23:ends.append(b)
                cells.append(dict(cell=[x,y],kind='ramp',level=-1,stair=i,ends=ends))
            elif not cliff.getpixel(pixel):
                level,line=min(ROUTES,key=lambda r:distance(p,r[1]))
                # 谷底收窄，保持脚点位于土路内，避免贴着石梯侧墙接入。
                half_width=11 if line is VALLEY_ROUTE else 14
                if distance(p,line)<=half_width:cells.append(dict(cell=[x,y],kind='road',level=level,stair=-1,ends=[]))
    # 岩缘裁切偶尔留下单格路肩，不能作为与主路断开的落脚点。
    lookup={tuple(c['cell']):c for c in cells}
    def joined(a,b):
        if b is None:return False
        if a['stair']>=0:return a['stair']==b['stair'] or b['level'] in a['ends']
        if b['stair']>=0:return a['level'] in b['ends']
        return a['level']==b['level']
    cells=[c for c in cells if c['kind']=='ramp' or any(joined(c,lookup.get((c['cell'][0]+dx,c['cell'][1]+dy))) for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])]
    # 矿点的永久2×2占区也参加连通校核；去除被矿点隔开的单格路肩。
    reserved=set()
    for site in data['resourceSites']:
        sx=round(site['position']['x']/36)-1;sy=round(site['position']['y']/36)-1
        reserved.update((sx+dx,sy+dy) for dx in range(2) for dy in range(2))
    lookup={tuple(c['cell']):c for c in cells if tuple(c['cell']) not in reserved}
    seen=set();strays=set()
    for origin in lookup:
        if origin in seen:continue
        pending=[origin];seen.add(origin)
        for point in pending:
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                neighbor=(point[0]+dx,point[1]+dy)
                if neighbor not in seen and joined(lookup[point],lookup.get(neighbor)):
                    seen.add(neighbor);pending.append(neighbor)
        if len(pending)<=2 and all(lookup[p]['kind']=='road' for p in pending):strays.update(pending)
    cells=[c for c in cells if tuple(c['cell']) not in strays]
    result=dict(schema='waiting-for-dawn.mountain-navigation.v1',sourceSize=[1672,941],
                worldSize=[4608,2592],region=REGION,hardCliffs=HARD_CLIFFS,mountainCells=mountain,cliffCells=rocks,
                junctions=[dict(id='central_mountain_fork',level=1,point=JUNCTION)],
                routes=[dict(level=l,points=p,halfWidth=11 if p is VALLEY_ROUTE else 14) for l,p in ROUTES],
                stairs=[dict(id=i,fromLevel=a,toLevel=b,points=p) for i,(a,b,p) in enumerate(STAIRS)],cells=cells)
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # 诊断图只用于核对标注，绝不作为游戏地形贴图。
    image=Image.open(ROOT/'assets/map/dawn_large_hd_v2/layered-preview.png').resize((1672,941)).convert('RGBA')
    layer=Image.new('RGBA',image.size);d=ImageDraw.Draw(layer)
    for c in rocks:
        x,y=c;d.rectangle((x*36/SCALE[0],y*36/SCALE[1],(x+1)*36/SCALE[0],(y+1)*36/SCALE[1]),fill=(255,50,30,90))
    for c in cells:
        x,y=c['cell'];color=(255,220,10,150) if c['stair']>=0 else [(20,240,80,130),(30,180,250,150),(200,80,250,150),(255,160,40,150)][c['level']]
        d.rectangle((x*36/SCALE[0],y*36/SCALE[1],(x+1)*36/SCALE[0],(y+1)*36/SCALE[1]),fill=color)
    image=Image.alpha_composite(image,layer)
    target=ROOT/'.codex-temp/mountain-navigation-overlay.png';target.parent.mkdir(exist_ok=True)
    image.crop((400,0,1672,510)).save(target)
    print('山域',len(mountain),'岩壁',len(rocks),'道路/台阶',len(cells))
    return result

if __name__=='__main__':build()
