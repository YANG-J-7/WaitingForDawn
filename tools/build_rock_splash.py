"""仅处理生成水花残色与山脚布点，不绘制原画。"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/fx/rock_splash_v2'

def main():
    # 纯品红键控留下的薄水膜残色，投回原有冷蓝水色；alpha/轮廓保持。
    for path in [OUT/'sheet-transparent.png', *OUT.glob('impact-*.png')]:
        pixels = np.array(Image.open(path).convert('RGBA'))
        green = pixels[:,:,1].astype(float)
        pixels[:,:,0] = np.minimum(pixels[:,:,0], green*.84)
        pixels[:,:,2] = np.minimum(pixels[:,:,2], green*1.15)
        Image.fromarray(pixels).save(path)
    mountain_path = ROOT/'assets/levels/level_001/mountain/mountain.png'
    mountain = np.asarray(Image.open(mountain_path).convert('RGBA').resize((3548,1774)))[:,:,3]
    sites = []
    for index, y in enumerate([390,690,990,1240,1470]):
        hits = np.flatnonzero(mountain[y+108]>150)
        if len(hits):
            sites.append({'id':f'RockImpact{index+1}', 'anchor':[3528+int(hits[-1])+8,y],
                          'size': [160,190,150,180,145][index], 'phase':[0.0,1.3,2.7,.7,2.1][index]})
    # 西侧末端仍是草坡，不能把水花放在草地；仅保留真正临湖的南端蓝岩。
    for index, x in enumerate([6000]):
        hits = np.flatnonzero(mountain[:,x-3528]>150)
        if len(hits):
            sites.append({'id':f'FootImpact{index+1}', 'anchor':[x,int(hits[-1])-108+5],
                          'size':170, 'phase':[.4,1.8,3.1][index]})
    record = {'version':1,'sites':sites,'raw_sha256':hashlib.sha256((OUT/'raw-sheet.png').read_bytes()).hexdigest(),
              'mountain_sha256':hashlib.sha256(mountain_path.read_bytes()).hexdigest(),
              '说明':'原画实际返回3列2行，六阶段固定底线，共享缩放；山体透明轮廓限定水侧，错峰4秒周期。'}
    (OUT/'contact-sites.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    frames = [Image.open(OUT/f'impact-{i}.png').convert('RGBA') for i in range(1,7)]
    frames[0].save(OUT/'animation.gif',save_all=True,append_images=frames[1:],duration=180,loop=0,disposal=2)
    print(json.dumps(record,ensure_ascii=False))

if __name__ == '__main__':
    main()
