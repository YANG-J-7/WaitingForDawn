"""处理生成回卷浪：固定原格坐标去底、消残色、切片与导出。"""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/fx/reverse_wave_v1'

def main():
    clean=Image.open(OUT/'raw-sheet-clean.png').convert('RGBA')
    frames=[]
    atlas=Image.new('RGBA',(1536,768))
    for i in range(8):
        x,y=i%4,i//4
        # 直接保留生成格的共享接触点，禁止逐帧按包围盒重新居中。
        frame=clean.crop((round(x*clean.width/4),round(y*clean.height/2),round((x+1)*clean.width/4),round((y+1)*clean.height/2))).resize((384,384),Image.Resampling.LANCZOS)
        data=np.array(frame)
        green=data[:,:,1].astype(float)
        data[:,:,0]=np.minimum(data[:,:,0],green*.89)
        data[:,:,2]=np.minimum(data[:,:,2],green*1.16)
        frame=Image.fromarray(data)
        assert frame.getbbox() is not None
        alpha=np.array(frame)[:,:,3]
        assert not np.any(np.concatenate([alpha[0],alpha[-1],alpha[:,0],alpha[:,-1]])>5)
        frame.save(OUT/f'impact-{i+1}.png')
        frames.append(frame)
        atlas.paste(frame,(x*384,y*384))
    atlas.save(OUT/'sheet-transparent.png')
    frames[0].save(OUT/'animation.gif',save_all=True,append_images=frames[1:],duration=150,loop=0,disposal=2)
    record={'frames':8,'grid':[4,2],'cell_size':[384,384],'contact_uv':[.26,.70],
            'scale':'原格统一缩放，不逐帧重新居中','raw_sha256':hashlib.sha256((OUT/'raw-sheet.png').read_bytes()).hexdigest(),
            'output_edge_touch':False}
    (OUT/'processing-contract.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False))

if __name__=='__main__': main()
