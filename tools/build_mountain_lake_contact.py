"""从现有山体轮廓编译临湖遮挡与规则，不重绘山体或湖岸原画。"""
from pathlib import Path
import json
from collections import defaultdict
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/levels/level_001"
OUT = BASE / "mountain/contact"
WORLD = (7056,2880)

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def write(name, data):
    (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def outlines(mask):
    # 沿二值轮廓的外露格边追踪闭环；仅合并共线边，不改变山脚形状。
    edges = defaultdict(list)
    height,width = mask.shape
    for y,x in zip(*np.nonzero(mask)):
        x,y = int(x),int(y)
        if y==0 or not mask[y-1,x]: edges[(x,y)].append((x+1,y))
        if x==width-1 or not mask[y,x+1]: edges[(x+1,y)].append((x+1,y+1))
        if y==height-1 or not mask[y+1,x]: edges[(x+1,y+1)].append((x,y+1))
        if x==0 or not mask[y,x-1]: edges[(x,y+1)].append((x,y))
    polygons=[]
    while edges:
        start=next(iter(edges))
        current=start
        points=[]
        while True:
            points.append(current)
            nxt=edges[current].pop()
            if not edges[current]: del edges[current]
            current=nxt
            if current==start: break
        if len(points)<12: continue
        simple=[]
        for i,b in enumerate(points):
            a,c=points[i-1],points[(i+1)%len(points)]
            if (b[0]-a[0])*(c[1]-b[1]) != (b[1]-a[1])*(c[0]-b[0]):
                simple.append([b[0]*4,b[1]*4])
        polygons.append(simple)
    return polygons

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    spec=read(BASE/"mountain/layout.json")
    original=read(BASE/"lake/module.json")
    layout=read(BASE/"lake/layout.json")
    image=Image.open(BASE/"mountain/mountain.png").convert("RGBA")
    alpha=image.getchannel("A").resize((round(image.width*spec["scale"]),round(image.height*spec["scale"])),Image.Resampling.BILINEAR)
    land=Image.new("L",WORLD)
    land.paste(alpha,tuple(spec["origin"]))
    mask=np.asarray(land)>100
    water=Image.new("L",WORLD)
    draw=ImageDraw.Draw(water)
    for polygon in original["water_polygons"]: draw.polygon([tuple(p) for p in polygon],fill=255)
    a=np.array(water)
    for y in range(1660):
        hits=np.flatnonzero(mask[y])
        old=np.flatnonzero(a[y])
        if len(hits) and len(old):
            a[y,min(int(hits[-1]),int(old[0])):]=255
    # 湖水铺在山体下，规则中剔除全部可见山体，避免画面为陆地却被判成水。
    background=a.copy()
    a[mask]=0
    water=Image.fromarray(a)
    control=np.array(Image.open(BASE/"lake/water-control.png").convert("RGBA").resize(WORLD,Image.Resampling.NEAREST))
    control[:,:,0]=background
    control[:1660,:,1]=0
    control[:,:,2]=np.array(Image.fromarray(background).filter(ImageFilter.GaussianBlur(45)))
    Image.fromarray(control).resize((1764,720),Image.Resampling.LANCZOS).save(OUT/"water-control.png")
    shore=np.array(Image.open(BASE/"lake/shore-overlay.png").convert("RGBA"))
    fade=np.clip((np.arange(2880)-1660)/120,0,1)
    shore[:,:,3]=np.rint(shore[:,:,3]*fade[:,None]).astype(np.uint8)
    shore[shore[:,:,3]==0,:3]=0
    Image.fromarray(shore).save(OUT/"shore-overlay.png")
    # 静态小地图、湖水规则与画面使用同一轮廓；南部双湾保持旧边界。
    small=np.asarray(land.resize((1764,720),Image.Resampling.NEAREST))>100
    islands=outlines(small)
    # 背景水域的右侧行包络转为单一闭合多边形。
    boundary=[]
    for y in range(0,2880,4):
        hits=np.flatnonzero(background[y])
        if len(hits): boundary.append([int(hits[0]),y])
    polygon=boundary+[[boundary[-1][0],2880],[7056,2880],[7056,0]]
    cells=[]
    for y in range(80):
        for x in range(196):
            patch=a[y*36:(y+1)*36,x*36:(x+1)*36]
            mountain=mask[y*36:(y+1)*36,x*36:(x+1)*36]
            if patch.any() and not mountain.any(): cells.append([x,y])
    original.update({"water_polygons":[polygon],"island_polygons":islands,"terrain":{"water":cells},
                     "visual_layout":"res://assets/levels/level_001/mountain/contact/layout.json"})
    layout["water_control_texture"]="res://assets/levels/level_001/mountain/contact/water-control.png"
    layout["shore_texture"]="res://assets/levels/level_001/mountain/contact/shore-overlay.png"
    if (BASE/"beach/layout.json").exists():
        layout["beach_layout"]="res://assets/levels/level_001/beach/layout.json"
    # 上部旧岸移除后，不再在湖中残留原岸边水花；南侧七处保持。
    layout["splash_sites"]=[site for site in layout["splash_sites"] if site["anchor"][1]>=1660]
    write("lake-module.json",original)
    write("layout.json",layout)
    mountain_module=read(BASE/"mountain/module.json")
    mountain_cells={tuple(p) for p in mountain_module["navigation"]["mountainCells"]}
    cliffs={tuple(p) for p in mountain_module["navigation"]["cliffCells"]}
    for y in range(80):
        for x in range(196):
            if mask[y*36:(y+1)*36,x*36:(x+1)*36].any() and (x,y) not in mountain_cells:
                mountain_cells.add((x,y))
                cliffs.add((x,y))
    mountain_module["navigation"]["mountainCells"]=[list(p) for p in sorted(mountain_cells)]
    mountain_module["navigation"]["cliffCells"]=[list(p) for p in sorted(cliffs)]
    write("mountain-module.json",mountain_module)
    write("build-qc.json",{"date":"2026-11-16","water_cells":len(cells),"islands":len(islands),
                          "splash_sites":len(layout["splash_sites"]),"removed_shore_y":[0,1660],
                          "说明":"湖水/旧岸在下，完整山体在上。外围山体格保守禁行禁建，九段石梯路线未改。"})
    print("临湖轮廓编译完成：",len(cells),"水格，",len(islands),"山体轮廓")

if __name__=="__main__":
    main()
