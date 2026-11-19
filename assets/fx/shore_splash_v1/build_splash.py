"""只去除生成图品红底、统一根点、打包与校验；不绘制水花。"""
from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib,zipfile
ROOT=Path(__file__).resolve().parent
raw=Image.open(ROOT/'raw-sheet.png').convert('RGB')
rgb=np.asarray(raw,dtype=np.float32)
# 水花原稿含品红混色的半透明像素，按绿色覆盖恢复alpha与前景色。
alpha=np.clip(rgb[:,:,1]/240.0,0,1)
alpha[alpha<0.10]=0
foreground=rgb.copy()
# 去掉品红对红通道的污染，并保留水花原稿的蓝白亮部。
foreground[:,:,0]=np.minimum(foreground[:,:,0],foreground[:,:,1]*0.95)
foreground[:,:,2]=np.minimum(255,np.maximum(foreground[:,:,1]*1.15,np.minimum(foreground[:,:,2],foreground[:,:,1]*1.35+15)))
rgba=np.dstack([foreground,alpha*255]).round().astype(np.uint8)
clean=Image.fromarray(rgba)
clean.save(ROOT/'raw-clean.png')
size=(512,256)
atlas=Image.new('RGBA',(1024,768))
scale=512/887
roots=[(443,241),(443,241),(443,225),(443,225),(443,207),(443,207)]
target=(256,190)
records=[]
frames=[]
for i in range(6):
    x=(i%2)*887; y=(i//2)*295
    cell=clean.crop((x,y,x+887,y+295)).resize((512,round(295*scale)),Image.Resampling.LANCZOS)
    dx=round(target[0]-roots[i][0]*scale); dy=round(target[1]-roots[i][1]*scale)
    frame=Image.new('RGBA',size)
    frame.alpha_composite(cell,(dx,dy))
    a=np.array(frame.getchannel('A'))
    assert a.max()>40 and not a[:3].any() and not a[-3:].any() and not a[:,:3].any() and not a[:,-3:].any(), (i,int(a.max()),int(a[:3].max()),int(a[-3:].max()),int(a[:,:3].max()),int(a[:,-3:].max()))
    frame.save(ROOT/f'frame-{i+1:02}.png')
    atlas.alpha_composite(frame,((i%2)*512,(i//2)*256))
    frames.append(frame)
    records.append({'frame':i,'source_cell':[x,y,887,295],'reviewed_root':roots[i],'translation':[dx,dy],'output_root':target,'scale':scale,'bbox':frame.getbbox()})
atlas.save(ROOT/'splash-atlas.png')
frames[0].save(ROOT/'splash-review.gif',save_all=True,append_images=frames[1:],duration=[200,180,160,180,250,400],loop=0,disposal=2)
manifest={'id':'ASSET-0021','status':'candidate','generator':'built-in-image_gen','raw_size':list(raw.size),'grid':[2,3],'cell_size':size,'anchor':target,'frames':records,'source':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-8bd9e216-ee7d-4a25-ad2e-6ac84e52a282.png','raw_sha256':hashlib.sha256((ROOT/'raw-sheet.png').read_bytes()).hexdigest(),'reference_sha256':hashlib.sha256((ROOT.parents[1]/'map/lake_shore_v1/shore-transparent.png').read_bytes()).hexdigest(),'说明':'六阶段源图统一缩放，以人工复核的水花根点平移到共享锚点；不做逐帧bbox放大。GIF为关键帧审阅，运行时连续交叉淡入。'}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if (ROOT/'playback-60fps.json').exists():
    manifest['runtime_playback']={'fps':60,'contract':'playback-60fps.json','active_frame_counts':[135,162,126],'原画关键帧':6,'interpolation':'cubic-bspline-premultiplied','runtime_clock':'continuous','说明':'六关键帧预乘B样条过渡，运行连续时间，导出60fps；透明逐帧PNG可由export_60fps.py导出。'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(ROOT/'shore-splash-v1.zip','w',zipfile.ZIP_DEFLATED) as bundle:
    names=['raw-sheet.png','raw-clean.png','splash-atlas.png','splash-review.gif','manifest.json','sites.json','prompt-used.txt','README.md','build_splash.py']
    names += [f'frame-{i+1:02}.png' for i in range(6)]
    if (ROOT/'playback-60fps.json').exists(): names += ['playback-60fps.json','export_60fps.py']
    for name in names: bundle.write(ROOT/name,name)
    bundle.write(ROOT/'processed/pipeline-meta.json','qc/pipeline-meta.json')
with zipfile.ZipFile(ROOT/'shore-splash-v1.zip') as bundle: assert bundle.testzip() is None
print('六帧去底、共享尺度、根点与透明边界检查通过',list(raw.size))
