"""从当前导航数据导出山区路线总览；只写说明图和清单，不改玩法数据。"""
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'design/levels/mountain-routes-2026-10-17'
NAV = ROOT / 'assets/map/dawn_large_v1/mountain-navigation.json'
COLORS = [(98, 230, 169), (74, 211, 255), (211, 151, 255), (255, 167, 107)]
GOLD = (255, 219, 89)
# 编号只用于本次说明，对应导航数组的顺序；不新增游戏中的道路实体。
NAMES = [
    '西侧平原入口', '西南平原入口', '南侧两入口连接路', '东部滨岸出口',
    '西侧低台主路', '西侧铁矿支路', '西北石梯接入路', '中层东西主路',
    '中央分叉东南连接路', '西南石梯接入路', '东南中层主路', '南侧石梯接入路',
    '中央分叉北向谷底路', '西北高台主路', '西北石矿支路', '东侧高台主路', '北侧顶层主路',
]
LABELS = [
    ((606,225),(535,230)), ((960,404),(884,420)), ((1108,441),(1080,479)),
    ((1610,382),(1590,439)), ((590,80),(533,61)), ((615,96),(533,119)),
    ((659,125),(735,108)), ((805,162),(812,207)), ((1073,249),(1055,223)),
    ((1084,285),(1100,321)), ((1300,310),(1300,350)), ((1197,352),(1243,387)),
    ((1050,162),(1123,143)), ((859,63),(860,25)), ((800,34),(761,64)),
    ((1300,195),(1283,155)), ((1250,35),(1250,73)),
]
STAIR_LABELS = [(581,161),(735,145),(1124,92),(1517,100),(1198,249),(978,331),(1128,387),(1534,327)]
STAIR_NAMES = ['西侧上山口', '西北高台石梯', '北侧谷底石梯', '东北高台石梯',
               '中央高台石梯', '西南上山口', '南侧上山口', '东侧下山口']
FONT = 'C:/Windows/Fonts/msyh.ttc'


def font(size):
    return ImageFont.truetype(FONT, size)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    raw = NAV.read_bytes()
    nav = json.loads(raw)
    data = json.loads((ROOT / 'assets/map/dawn_large_v1/map.json').read_text(encoding='utf-8'))
    assert len(nav['routes']) == len(NAMES) == len(LABELS)
    assert len(nav['stairs']) == len(STAIR_NAMES) == len(STAIR_LABELS)
    scale = 2
    left, top = 430, 0
    margin, map_y = 42, 178
    map_w, map_h = (1672-left)*scale, 510*scale
    width, height = map_w+margin*2, 1642
    canvas = Image.new('RGB', (width,height), '#0d1924')
    bg = Image.open(ROOT / 'assets/map/dawn_large_hd_v2/layered-preview.png').convert('RGB')
    # 同源高清底图，仅作坐标对照，不覆盖运行时地图。
    crop = bg.crop((left*3,0,1672*3,510*3)).resize((map_w,map_h), Image.Resampling.LANCZOS)
    canvas.paste(crop, (margin,map_y))
    layer = Image.new('RGBA', canvas.size)
    d = ImageDraw.Draw(layer)

    def xy(p):
        return (margin+(p[0]-left)*scale, map_y+(p[1]-top)*scale)

    sx,sy = nav['worldSize'][0]/1672, nav['worldSize'][1]/941
    lookup = {tuple(c['cell']): c for c in nav['cells']}

    def source(cell):
        return ((cell[0]+.5)*36/sx, (cell[1]+.5)*36/sy)

    def step(a,b):
        if a not in lookup or b not in lookup:
            return False
        if a[0] != b[0] and a[1] != b[1]:
            p,q = (a[0],b[1]),(b[0],a[1])
            return step(a,p) and step(p,b) and step(a,q) and step(q,b)
        c,e = lookup[a],lookup[b]
        if c['stair'] >= 0 and e['stair'] >= 0:
            return c['stair'] == e['stair']
        if c['stair'] >= 0:
            return e['level'] in c['ends']
        if e['stair'] >= 0:
            return c['level'] in e['ends']
        return c['level'] == e['level']

    # 直接绘制登记格与合法相邻连接，不把人工参考折线误画成可穿岩壁的路径。
    edges = 0
    for cell,c in lookup.items():
        color = GOLD if c['stair']>=0 else COLORS[c['level']]
        p = xy(source(cell))
        w,h = 36/sx*scale,36/sy*scale
        d.rectangle((p[0]-w/2,p[1]-h/2,p[0]+w/2,p[1]+h/2),fill=(*color,68))
        for dx,dy in [(1,0),(0,1),(1,1),(1,-1)]:
            other = (cell[0]+dx,cell[1]+dy)
            if step(cell,other):
                # 总览只画正交连接，避免把八邻图画成密集的交叉网。
                if dx == 0 or dy == 0:
                    d.line((p,xy(source(other))),fill=(*color,160),width=2)
                edges += 1
        d.ellipse((p[0]-2,p[1]-2,p[0]+2,p[1]+2),fill=(*color,255))
    canvas = Image.alpha_composite(canvas.convert('RGBA'),layer)
    d = ImageDraw.Draw(canvas)

    def badge(anchor, label_pos, text, color, size=26):
        a,p = xy(anchor),xy(label_pos)
        bounds = d.textbbox((0,0),text,font=font(size))
        w,h = bounds[2]+20,size+16
        d.line((a,p),fill=(9,17,25),width=7)
        d.line((a,p),fill=color,width=2)
        d.rounded_rectangle((p[0]-w/2,p[1]-h/2,p[0]+w/2,p[1]+h/2),radius=8,fill='#101e2b',outline=color,width=2)
        d.text((p[0],p[1]-1),text,font=font(size),fill=color,anchor='mm')

    for i,(r,(anchor,pos)) in enumerate(zip(nav['routes'],LABELS)):
        badge(anchor,pos,f'R{i+1:02}',COLORS[r['level']])
    for i,s in enumerate(nav['stairs']):
        badge(s['points'][1],STAIR_LABELS[i],f'S{s["id"]}',GOLD,28)
    junction = nav['junctions'][0]['point']
    p = xy(junction)
    d.ellipse((p[0]-25,p[1]-25,p[0]+25,p[1]+25),outline='white',width=4)
    badge(junction,(942,250),'J 分叉', (255,255,255),25)
    mine_labels = {'iron_02':('西侧铁矿',(535,157)), 'stone_01':('西北石矿',(895,92)),
                   'stone_02':('中央石矿',(938,273)), 'iron_01':('东侧铁矿',(1367,244))}
    for site in data['resourceSites']:
        if site['id'] not in mine_labels:
            continue
        p = (site['position']['x']/sx, site['position']['y']/sy)
        pixel = xy(p)
        d.polygon([(pixel[0],pixel[1]-10),(pixel[0]+10,pixel[1]),(pixel[0],pixel[1]+10),(pixel[0]-10,pixel[1])],fill='white',outline='#0b1822')
        name,pos = mine_labels[site['id']]
        badge(p,pos,name,(245,245,235),23)

    d.text((42,27),'山区路线总览',font=font(43),fill='#f7edcf')
    d.text((width-42,47),'2026-10-17  ·  当前游戏导航数据',font=font(23),fill='#a8bdcb',anchor='rm')
    d.text((42,92),'17 段山路  /  8 处石梯  /  4 个矿点  /  J 中央分叉',font=font(28),fill='white')
    for i,text in enumerate(['L0 山脚','L1 中层','L2 高台','L3 顶层','石梯 S0–S7']):
        x = 50+i*350
        c = COLORS[i] if i<4 else GOLD
        d.line((x,151,x+42,151),fill=c,width=7)
        d.text((x+56,134),text,font=font(23),fill=c)
    y = map_y+map_h+20
    d.text((42,y),'色块和细线为登记路格及合法相邻连接；矿点、建筑占用会进一步限制实际通行。编号用于对照清单。',font=font(23),fill='#b9ccd8')
    y += 47
    for i,name in enumerate(NAMES):
        col,row = divmod(i,6)
        x, yy = 42+col*820,y+row*43
        r = nav['routes'][i]
        d.text((x,yy),f'R{i+1:02}  {name}',font=font(25),fill=COLORS[r['level']])
    d.text((42,height-56),'分叉 J：向西 R08  /  向北 R13 → S2  /  向东南 R09 → R11；上下平台只能经过对应石梯。',font=font(25),fill=GOLD)
    canvas.convert('RGB').save(OUT/'all-mountain-routes.png')

    snapshot = dict(date='2026-10-17',source=str(NAV.relative_to(ROOT)).replace('\\','/'),
                    sourceSha256=hashlib.sha256(raw).hexdigest(),
                    note='编号为文档标识；参考折线不是单位实际路径，实际通行由路格、层级、石梯和占用共同决定。',
                    routes=[dict(id=f'R{i+1:02}',name=NAMES[i],**r) for i,r in enumerate(nav['routes'])],
                    stairs=[dict(name=STAIR_NAMES[i],**s) for i,s in enumerate(nav['stairs'])],
                    junctions=nav['junctions'],registeredCellCount=len(lookup),registeredEdgeCount=edges)
    (OUT/'routes.json').write_text(json.dumps(snapshot,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    rows = ['# 山区全部路线清单','', '整理日期：2026-10-17。依据当前运行导航数据生成；本次只整理路线，不修改游戏规则或地图。','',
            '![山区路线总览](all-mountain-routes.png)','',
            '## 山路','', '| 编号 | 位置/用途 | 层级 | 参考起点 → 终点（母图坐标） |','|---|---|---|---|']
    for r in snapshot['routes']:
        rows.append(f'| {r["id"]} | {r["name"]} | L{r["level"]} | {r["points"][0]} → {r["points"][-1]} |')
    rows += ['', '## 石梯','', 'S编号保留游戏数据原始编号，从0开始；层级只约束通行，不增加移速或战斗属性。','',
             '| 编号 | 位置 | 连接层级 | 相接道路 |','|---|---|---|---|']
    connections = ['R01 ↔ R05 / R07 / R08','R07 ↔ R14','R13 ↔ R17','R17 ↔ R16',
                   'R09 / R10 / R11 ↔ R16','R02 / R03 ↔ R10','R03 ↔ R12','R11 ↔ R04']
    for i,s in enumerate(nav['stairs']):
        rows.append(f'| S{s["id"]} | {STAIR_NAMES[i]} | L{s["fromLevel"]} ↔ L{s["toLevel"]} | {connections[i]} |')
    rows += ['', '## 各入口与矿点','',
             '- 西侧入口：平原 → R01 → S0 → 西侧中层路网。西侧铁矿由R05附近的R06支路接入。',
             '- 西南入口：平原 → R02 → S5 → R10。',
             '- 南侧入口：平原 → R03 → S6 → R12 → R11。R03连接S5、S6下端，平原仍可自由寻路。',
             '- 东侧入口：R04 → S7 → R11；R04另一端通向东侧地图边缘。',
             '- 西北石矿：西侧中层 → R07 → S1 → R14 → R15。西北高台在岩缘终止，不能直接跨崖进入中央谷底。',
             '- 中央石矿：J分叉 → R08末端附近/R09西端附近的合法采集边缘；矿点占地不能穿越，实际入口由当前占用决定。',
             '- 东侧铁矿：R11 → S4 → R16，或北侧顶层R17 → S3 → R16，取当前起点下较短的合法路线。','',
             '## 中央分叉 J','',
             '母图坐标(980,205)，层级L1。向西接R08，向北接R13并经S2抵达R17，向东南经R08末段接R09及R11。单位按目的地与当前占用选择最短合法路径；道路封闭时重算，有替代路才绕行，无路则停止。','',
             '## 阅读边界','',
             '- 共17条参考折线、8处石梯、538个道路/石梯登记格。R编号依导航数组顺序，仅用于文档，并非固定巡逻顺序。',
             '- 图上色块显示已登记道路格，细线连接符合层级/石梯规则的相邻格；资源和建筑的运行时占用还会进一步阻挡。',
             '- 裸岩、垂直石壁和水域不能移动或建造；山区离路草台不能走，仍按既有建造规则判断能否建造。',
             '- 石梯可走、不可建。L2西北高台与L2东侧高台不是同一块连续地面；不能只凭层级相同越过岩壁。',
             '- 36像素网格仍有边缘离散误差；这是当前数据总览，不代表新增了全部岩缘的人工验收。',
             '- 上次真实游戏选路证据：[分叉QA](../../../tests/reports/qa-2026-10-17-junction-routes.md)。本次未重跑玩法测试。','',
             '## 数据与复用','', '[全部路线坐标JSON](routes.json)。源数据：`assets/map/dawn_large_v1/mountain-navigation.json`。',
             f'源数据SHA256：`{snapshot["sourceSha256"]}`。',
             '重建：用带Pillow的Python运行`tools/export_mountain_route_atlas.py`。','']
    (OUT/'README.md').write_text('\n'.join(rows),encoding='utf-8')
    counts = Counter(c['kind'] for c in lookup.values())
    print(json.dumps(dict(routes=len(NAMES),stairs=len(nav['stairs']),cells=dict(counts),edges=edges,output=str(OUT)),ensure_ascii=False))


if __name__ == '__main__':
    build()
