"""编译已生成沙滩的曲岸采样坐标与旧岸遮罩，不绘制新美术。"""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image
from build_level_lake import LOWER_CONTACT, lower_world

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/levels/level_001/beach'
CONTACT = ROOT / 'assets/levels/level_001/mountain/contact'
WORLD = (7056, 2880)

def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)

def coordinates(points, xx, yy):
    """最近岸线弧长与有符号距离；正值朝湖水，端点外保守渐隐。"""
    best = np.full(xx.shape, np.inf)
    along = np.zeros_like(xx)
    across = np.zeros_like(xx)
    length = 0.0
    for p, q in zip(points[:-1], points[1:]):
        delta = q-p
        segment = np.linalg.norm(delta)
        tangent = delta/segment
        fraction = np.clip(((xx-p[0])*delta[0]+(yy-p[1])*delta[1])/segment**2, 0, 1)
        dx = xx-p[0]-fraction*delta[0]
        dy = yy-p[1]-fraction*delta[1]
        distance2 = dx*dx+dy*dy
        take = distance2 < best
        along[take] = length+fraction[take]*segment
        signed = dx*tangent[1]-dy*tangent[0]
        across[take] = (np.where(signed >= 0, 1, -1)*np.sqrt(distance2))[take]
        best[take] = distance2[take]
        length += segment
    return along, across, np.sqrt(best), length

def packed16(value):
    encoded = np.rint(np.clip(value, 0, 1)*65535).astype(np.uint16)
    return [(encoded >> 8).astype(np.uint8), (encoded & 255).astype(np.uint8)]

def curved(points):
    # 插值原岸点为连续曲线，避免将逻辑折线拐角直接当美术接缝。
    padded = np.vstack([2*points[0]-points[1], points, 2*points[-1]-points[-2]])
    result = []
    for i in range(len(points)-1):
        a,b,c,d = padded[i:i+4]
        for t in np.linspace(0, 1, max(3, int(np.linalg.norm(c-b)/10)), endpoint=False):
            result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return np.vstack([result,points[-1]])

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 全岸连续：上段贴完整山脚，下段沿既有凸岬与双湾。
    shore = np.array([lower_world(p) for p in LOWER_CONTACT])
    mountain = np.asarray(Image.open(ROOT/'assets/levels/level_001/mountain/mountain.png').convert('RGBA').resize((3548,1774)))[:,:,3]
    upper = []
    for y in range(0,1620,40):
        row = mountain[max(0,y+108-12):min(1774,y+108+13)]>100
        hits = np.flatnonzero(row.any(axis=0))
        if len(hits): upper.append([min(7080,3528+float(hits[-1])+85),y])
    control = np.vstack([[upper[0][0],-400],upper,shore[shore[:,1]>1640],[shore[-1][0],3300]])
    patches = []
    for name, control_points in [('whole_coast',control)]:
        points = curved(control_points)
        margin = 360
        lo = np.floor((points.min(axis=0)-margin)/2)*2
        hi = np.ceil((points.max(axis=0)+margin)/2)*2
        size = (hi-lo).astype(int)
        # 控制图每四世界单位一采样；16位编码保证插值精度，不采样颜色/绘制原画。
        size = np.ceil(size/4).astype(int)*4
        fy, fx = np.mgrid[0:size[1]//4, 0:size[0]//4].astype(float)*4
        s, d, distance, length = coordinates(points, fx+lo[0]+2, fy+lo[1]+2)
        # 两个16位无色彩变换通道：沿岸弧长/正负距离。非美术图，不生成法线。
        assert length<16384
        channels = packed16(s/16384)+packed16((d+512)/1024)
        Image.fromarray(np.stack(channels, axis=-1)).save(OUT/f'{name}-field.png')
        patches.append({'id': name, 'rect': [*lo.astype(int).tolist(), *size.tolist()],
                        'field': f'res://assets/levels/level_001/beach/{name}-field.png',
                        'length': float(length), 'end_fade': 180.0,
                        'coast_points': control_points.tolist(), 'width_scale': 1.3})
    source_layout = json.loads((CONTACT/'layout.json').read_text(encoding='utf-8'))
    removed = [site['id'] for site in source_layout['splash_sites']]
    layout = {'version': 1, 'asset': 'ASSET-0025', 'world_size': list(WORLD),
              'patches': patches, 'rock_cutout': 'res://assets/levels/level_001/beach/rock-cutout.png',
              'disabled_splashes': removed, 'period': 12.0, 'replace_all_rock_shore': True,
              'reverse_waves_enabled': False, 'mountain_sand_extension': 100.0,
              '说明': '全岸连续沙滩；山体主体保持，沙滩位于山脚/湖面之间。既有水域禁行规则保持。'}
    (OUT/'layout.json').write_text(json.dumps(layout, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    source_layout['beach_layout'] = 'res://assets/levels/level_001/beach/layout.json'
    (CONTACT/'layout.json').write_text(json.dumps(source_layout, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    sources = ['assets/map/beach_v1/sand.png', 'assets/map/beach_v1/foam.png',
               'assets/levels/level_001/mountain/contact/lake-module.json']
    qc = {'date': '2026-11-17', 'patches': len(patches), 'disabled_splashes': removed,
          'input_sha256': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}}
    (OUT/'build-qc.json').write_text(json.dumps(qc, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(qc, ensure_ascii=False))

if __name__ == '__main__':
    main()
