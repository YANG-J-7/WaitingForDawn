"""只对已生成素材做周期闭边、分层遮罩与透明边缘处理，不生成美术。"""
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
import json, hashlib

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'runtime'
OUT.mkdir(exist_ok=True)
water=np.asarray(Image.open(ROOT/'water.png').convert('RGB'),dtype=np.float32).copy()
# 两侧以同一对称权重收敛，内部像素保持原样。
for axis in (0,1):
    src=water.copy()
    n=water.shape[axis]
    for i in range(48):
        weight=0.5*(1-i/47)**2
        a=[slice(None)]*3; b=a.copy()
        a[axis]=i; b[axis]=n-1-i
        water[tuple(a)]=src[tuple(a)]*(1-weight)+src[tuple(b)]*weight
        water[tuple(b)]=src[tuple(b)]*(1-weight)+src[tuple(a)]*weight
water=np.rint(water).astype(np.uint8)
assert np.array_equal(water[0],water[-1]) and np.array_equal(water[:,0],water[:,-1])
Image.fromarray(water).save(OUT/'water-periodic.png')
shore=np.array(Image.open(ROOT/'shore-transparent.png').convert('RGBA'))
# 去除去底后仍混在抗锯齿里的紫色背景污染，不触碰正常灰蓝岩面。
color=shore[:,:,:3].astype(float)
spill=np.clip((color[:,:,0]-color[:,:,1]-3)/30,0,1)*np.clip((color[:,:,2]-color[:,:,1]-15)/40,0,1)
shore[:,:,3]=np.rint(shore[:,:,3]*(1-spill)).astype(np.uint8)
# 对原图已有的稀碎水缘做局部透明过渡，防止去底轮廓成为紫蓝硬线。
soft_alpha=np.array(Image.fromarray(shore[:,:,3]).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(2)))
shore[:,:,3]=np.minimum(shore[:,:,3],soft_alpha)
h,w=shore.shape[:2]
# 人工核对的岩脚接触线；只作为本样区美术遮罩，不参与导航。
points=[[0,245],[150,286],[300,296],[450,273],[570,296],[700,377],[820,416],[950,369],[1050,277],[1150,209],[1250,214],[1350,252],[1450,293],[1600,320],[1724,245]]
line=np.interp(np.arange(w),*[np.array(points)[:,i] for i in (0,1)])
y=np.arange(h)[:,None]
rgb=shore[:,:,:3].astype(float)
# 保守提取纯青蓝水面；石头、砾石和边缘一律保留在静态原画中。
# 动态层只采样独立水纹，绝不再偏移这张混有石头的原画。
water_only=((rgb[:,:,0]<rgb[:,:,1]*0.42)&(rgb[:,:,2]>rgb[:,:,1]*1.20)&(shore[:,:,3]>200)&(y>line[None,:]+10)).astype(np.uint8)*255
water_only=np.array(Image.fromarray(water_only).filter(ImageFilter.MinFilter(9)))
Image.fromarray(water_only).save(OUT/'water-only.png')
# 淡出交界下的湖水也受同一保护图约束，防止动态底纹从静态岸石下透出。
rock_only=((shore[:,:,3]>=230)&(water_only==0)).astype(np.uint8)*255
Image.fromarray(rock_only).save(OUT/'rock-only.png')
# 仅在岩脚窄带提取源画已有水线；源图与动画层共享采样，不另画水花。
band=np.clip(1-np.abs(y-line[None,:])/16,0,1)
bright=np.clip((rgb[:,:,0]-85)/70,0,1)*np.clip((rgb[:,:,1]-100)/60,0,1)
foam=band*bright*(shore[:,:,3]/255)
foam_img=shore.copy(); foam_img[:,:,3]=np.rint(foam*210).astype(np.uint8)
Image.fromarray(foam_img).save(OUT/'foam-source.png')
control=np.zeros((h,w,4),dtype=np.uint8)
# R：静态岸石保护；G：拍岸水线；B：原图上缘转接，避免矩形草地板。
control[:,:,0]=np.rint(np.clip((line[None,:]-y)/28,0,1)*255).astype(np.uint8)
control[:,:,1]=np.rint(foam*255).astype(np.uint8)
alpha=shore[:,:,3]
top=np.argmax(alpha>100,axis=0)
blend=np.clip((y-top[None,:]-12)/140,0,1)
control[:,:,2]=np.rint(blend*255).astype(np.uint8)
control[:,:,3]=np.rint(np.clip(1-(y-line[None,:]-20)/85,0,1)*255).astype(np.uint8)
Image.fromarray(control).save(OUT/'shore-control.png')
contact=np.zeros((1,w,3),dtype=np.uint8)
contact[0,:,0]=np.rint(line/h*255).astype(np.uint8)
Image.fromarray(contact).save(OUT/'contact.png')
Image.fromarray(shore).save(OUT/'shore.png')
data={'version':1,'shore_pixels':[w,h],'contact_line':points,'source':'res://assets/map/lake_shore_v1/shore-transparent.png','world_origin':[-200,150],'world_scale':1.35,'water_world_period':[500,500],'animation_period':12.0,'说明':'本样区固定轮廓；控制图为美术数据，未批准导航或碰撞。'}
(OUT/'layout.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'water_edge_exact':True,'water_periodic_size':list(water.shape[:2]),'foam_pixel_count':int(np.count_nonzero(foam>0.05)),'input_sha256':hashlib.sha256((ROOT/'shore-transparent.png').read_bytes()).hexdigest(),'说明':'水面48像素对称闭边；水花从已有原画接触线提取，非新生成序列帧。'}
(OUT/'preparation-qc.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
