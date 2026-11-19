"""编译已确认山体原画的去底、关卡摆放和人工山路标注；不生成岩壁原画。"""
from pathlib import Path
import json
import hashlib
import heapq
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/levels/level_001/mountain"
SOURCE = ROOT / "design/art/concepts/mountain-2026-11-14/design-matched-01/processed/raw-sheet-clean.png"
ORIGIN = (3528, -108)
SCALE = 2.0
CELL = 36

# 以下为1774×887原稿上人工核对的路径中心线，不用旧地图导航覆盖新山体。
STAIRS = [
    ("S1", (318, 414), (354, 338)),
    ("S2", (402, 321), (435, 237)),
    ("S3", (935, 307), (960, 255)),
    ("S4", (1500, 352), (1446, 274)),
    ("S5", (1006, 511), (1040, 450)),
    ("S6", (860, 629), (912, 542)),
    ("S7", (1120, 690), (1150, 641)),
    ("S8", (1030, 747), (1058, 712)),
    ("S9", (1553, 631), (1499, 563)),
]
ROUTES = [
    [(280,430),(318,414),(378,359),(402,321)],
    [(435,237),(484,220),(640,244),(760,268)],
    [(378,359),(524,399),(694,426),(856,388),(935,307)],
    [(960,255),(975,214),(1170,170),(1360,185),(1446,274)],
    [(856,388),(900,431),(1006,511)],
    [(1040,450),(1120,433),(1250,411),(1360,423),(1450,390),(1500,352)],
    [(1450,390),(1400,459),(1450,510),(1499,563)],
    [(280,430),(310,468),(467,515),(626,562),(754,608),(860,629)],
    [(912,542),(950,521),(1006,511)],
    [(860,629),(948,664),(1030,747)],
    [(1058,712),(1105,702),(1120,690)],
    [(1150,641),(1240,607),(1380,581),(1499,563)],
    [(1553,631),(1590,655),(1620,672)],
    [(1620,672),(1450,710),(1260,752),(1130,785),(1030,747)],
]


def world(point):
    return [ORIGIN[i] + point[i] * SCALE for i in range(2)]


def write(name, data):
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def line_cells(points):
    # 格中心四连通超采样，窄石梯也不会因斜线只触角而断开。
    result = []
    for start, end in zip(points, points[1:]):
        a, b = np.array(world(start)), np.array(world(end))
        for t in np.linspace(0, 1, max(2, int(np.linalg.norm(b-a)/4)+1)):
            cell = tuple(int(v) for v in np.floor((a+(b-a)*t)/CELL))
            if result and cell != result[-1] and all(cell[i] != result[-1][i] for i in range(2)):
                result.append((cell[0], result[-1][1]))
            if not result or result[-1] != cell:
                result.append(cell)
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    im = Image.open(SOURCE).convert("RGBA")
    rgba = np.array(im)
    rgb = rgba[:, :, :3].astype(float)
    # 仅清理去底残留的红蓝同高、绿色明显不足像素，蓝灰岩面保持。
    spill = np.clip((rgb[:, :, 0]-rgb[:, :, 1]-5)/25, 0, 1) * np.clip((rgb[:, :, 2]-rgb[:, :, 1]-18)/35, 0, 1)
    rgba[:, :, 3] = np.rint(rgba[:, :, 3]*(1-spill)).astype(np.uint8)
    alpha = Image.fromarray(rgba[:, :, 3])
    rock_edge = np.array(alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(.45)))
    grass_edge = np.array(alpha.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(2)))
    grass = (rgb[:, :, 1] > rgb[:, :, 0]*1.05) & (rgb[:, :, 1] > rgb[:, :, 2]*.86)
    rgba[:, :, 3] = np.minimum(rgba[:, :, 3], np.where(grass, grass_edge, rock_edge))
    residual = (rgb[:,:,0]>rgb[:,:,1]+40) & (rgb[:,:,2]>rgb[:,:,1]+40)
    rgba[residual,3] = 0
    rgba[rgba[:, :, 3] == 0, :3] = 0
    Image.fromarray(rgba).save(OUT/"mountain.png")
    water = {tuple(p) for p in json.loads((ROOT/"assets/levels/level_001/lake/module.json").read_text(encoding="utf-8"))["terrain"]["water"]}
    mountain = set()
    for y in range(80):
        for x in range(196):
            sx, sy = ((x+.5)*CELL-ORIGIN[0])/SCALE, ((y+.5)*CELL-ORIGIN[1])/SCALE
            if 0 <= sx < im.width and 0 <= sy < im.height and rgba[int(sy), int(sx), 3] > 100 and (x,y) not in water:
                mountain.add((x,y))
    roads = set()
    stairs = {}
    layout_stairs = []
    for index, (name, lower, upper) in enumerate(STAIRS):
        cells = line_cells([lower, upper])
        stairs.update({p: index for p in cells})
        layout_stairs.append({"id": name, "lower_world": world(lower), "upper_world": world(upper),
                              "source_lower": lower, "source_upper": upper,
                              "cells": [list(p) for p in cells]})
    # 手画折线只提供路线意图；格中心落在岩面的点不可直接开放。
    # 用原画5×5岩面覆盖率排除硬岩，再在地面上求连接，避免直线穿崖。
    safe = set()
    for y in range(80):
        for x in range(196):
            if (x,y) in water: continue
            sx,sy = int(((x+.5)*CELL-ORIGIN[0])/SCALE),int(((y+.5)*CELL-ORIGIN[1])/SCALE)
            if not (3<=sx<im.width-3 and 3<=sy<im.height-3):
                continue
            pixels = rgb[sy-2:sy+3,sx-2:sx+3]
            blue = ((pixels[:,:,2]>pixels[:,:,1]*1.08)&(pixels[:,:,2]>pixels[:,:,0]*1.15)).mean()
            if blue < .45 or rgba[sy,sx,3] < 30: safe.add((x,y))
    safe.update(set(stairs)-water)

    def nearest(cell):
        return min(safe, key=lambda p:(p[0]-cell[0])**2+(p[1]-cell[1])**2)

    def connect(points):
        seeds = line_cells(points)
        start, goal = nearest(seeds[0]), nearest(seeds[-1])
        # 种子距离场只影响路线偏好，不改变禁止岩面和水域的硬约束。
        cost = {start:0.}
        previous = {}
        queue = [(0., start)]
        while queue:
            total,cell = heapq.heappop(queue)
            if total != cost[cell]: continue
            if cell == goal: break
            for dx,dy in [(1,0),(0,1),(-1,0),(0,-1)]:
                nxt = (cell[0]+dx,cell[1]+dy)
                if nxt not in safe: continue
                if cell in stairs and nxt in stairs and stairs[cell]!=stairs[nxt]: continue
                deviation = min((nxt[0]-p[0])**2+(nxt[1]-p[1])**2 for p in seeds)**.5
                value = total+1+deviation*.25
                if value < cost.get(nxt,float("inf")):
                    cost[nxt]=value
                    previous[nxt]=cell
                    heapq.heappush(queue,(value,nxt))
        if goal not in cost:
            raise ValueError(f"路径端口无法沿原画地面连接：{points[0]} -> {points[-1]}")
        path = [goal]
        while path[-1] != start: path.append(previous[path[-1]])
        return path

    resolved = [connect(points) for points in ROUTES]
    for path in resolved: roads.update(path)
    entries = []
    # 岩壁/离路山草默认关闭；只开放人工标注的道路与石梯，水域优先。
    for cell in sorted((roads | set(stairs))-water):
        if not (0 <= cell[0] < 196 and 0 <= cell[1] < 80): continue
        stair = stairs.get(cell, -1)
        entries.append({"cell": list(cell), "kind": "ramp" if stair >= 0 else "road",
                        "level": 0, "stair": stair, "ends": [0] if stair >= 0 else []})
    # 蓝色岩面仅用于加严离路禁建；实际开放格仍以人工路径为准。
    cliffs = []
    for x,y in sorted(mountain):
        sx,sy = int(((x+.5)*CELL-ORIGIN[0])/SCALE),int(((y+.5)*CELL-ORIGIN[1])/SCALE)
        r,g,b = rgb[sy,sx]
        if b > g*1.08 and b > r*1.15 and (x,y) not in roads and (x,y) not in stairs:
            cliffs.append([x,y])
    layout = {"version":1, "texture":"res://assets/levels/level_001/mountain/mountain.png",
              "source_size":list(im.size), "origin":list(ORIGIN), "scale":SCALE,
              "stairs":layout_stairs, "routes":ROUTES,
              "说明":"按原设计图东北布置，顶端延伸到地图外；只平移与统一缩放，不旋转或镜像。石梯/道路为新图人工标注，非旧八梯拓扑。"}
    write("layout.json", layout)
    # 组件保持零平移，关卡世界坐标在布局里明确记录，避免负原点的格越界。
    write("module.json", {"visual_layout":"res://assets/levels/level_001/mountain/layout.json",
                         "navigation":{"mountainCells":[list(p) for p in sorted(mountain)],
                                       "cliffCells":cliffs, "cells":entries}})
    write("build-qc.json", {"native_size":list(im.size), "mountain_cells":len(mountain),
                           "cliff_cells":len(cliffs), "route_cells":len(entries),
                           "stairs":len(STAIRS), "water_overlap_cells":len((roads|set(stairs)) & water),
                           "source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                           "output_sha256":hashlib.sha256((OUT/"mountain.png").read_bytes()).hexdigest(),
                           "说明":"9段石梯共用高度标签0，岩面和离路禁行隔离平台；非连续高度场，后续需细化逐层建造约束。"})
    # 调试图只作标注证据，不用作游戏可见原画。
    debug = Image.fromarray(rgba)
    draw = ImageDraw.Draw(debug)
    for path in resolved:
        points = [(((x+.5)*CELL-ORIGIN[0])/SCALE,((y+.5)*CELL-ORIGIN[1])/SCALE) for x,y in path]
        draw.line(points, fill=(245,205,85,255), width=3)
    for name,a,b in STAIRS:
        draw.line([a,b], fill=(255,100,80,255), width=4)
        draw.text(a,name,fill="white")
    debug.save(OUT/"routes-debug.png")
    print(json.dumps({"mountain_cells":len(mountain),"routes":len(entries),"stairs":len(STAIRS)}))


if __name__ == "__main__":
    main()
