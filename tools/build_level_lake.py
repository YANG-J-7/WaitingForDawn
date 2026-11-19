"""由生成的定向岸段适配图编译水域、静态岸层与动态保护；不绘制湖岸原画。"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import json, hashlib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/levels/level_001/lake'
WORLD=(7056,2880)
ORIGIN=3500
LOWER_RECT=(3776,1438,3280,1640)
LOWER_CONTACT=[(1484,0),(1465,50),(1360,85),(1290,120),(1220,135),(1110,120),(1000,110),(900,120),(820,155),(730,180),(650,215),(600,260),(595,285),(650,320),(740,350),(840,355),(930,375),(980,405),(1005,455),(930,490),(820,515),(720,515),(650,495),(600,520),(550,550),(480,525),(425,550),(350,575),(270,595),(220,595),(180,625),(180,670),(245,720),(290,760),(335,810),(330,830)]

def smooth(t):
    t=np.clip(t,0,1)
    return t*t*(3-2*t)

def cleaned(image):
    a=np.asarray(image.convert('RGBA')).copy()
    c=a[:,:,:3].astype(np.float32)
    spill=np.clip((c[:,:,0]-c[:,:,1]-3)/30,0,1)*np.clip((c[:,:,2]-c[:,:,1]-15)/40,0,1)
    a[:,:,3]=np.rint(a[:,:,3]*(1-spill)).astype(np.uint8)
    soft=np.asarray(Image.fromarray(a[:,:,3]).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2)))
    a[:,:,3]=np.minimum(a[:,:,3],soft)
    a[a[:,:,3]==0,:3]=0
    return Image.fromarray(a)

def write_json(name,data):
    (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def lower_world(point):
    return [LOWER_RECT[0]+point[0]/1774*LOWER_RECT[2],LOWER_RECT[1]+point[1]/887*LOWER_RECT[3]]

def main():
    upper=cleaned(Image.open(OUT/'processed/raw-sheet-clean.png'))
    upper.save(OUT/'upper-shore.png')
    upper=upper.resize((1733,1870),Image.Resampling.LANCZOS)
    upper_array=np.asarray(upper).copy()
    upper_contact=[]
    upper_layer=Image.new('RGBA',(WORLD[0]-ORIGIN,WORLD[1]))
    for y in range(1600):
        shift=round(145*(y/1869)**6)
        row=upper_array[y].copy()
        valid=np.flatnonzero(row[:,3]>110)
        if not len(valid): continue
        left,right=int(valid[0]),int(valid[-1])
        contact=1760 if right==1732 and row[-1,3]>180 else right-25
        if y%16==0: upper_contact.append([5323+shift+contact,y])
        fade=smooth((np.arange(1733)-left)/50)*smooth((right-np.arange(1733))/28)
        row[:,3]=np.rint(row[:,3]*fade*(1-smooth((y-1490)/100))).astype(np.uint8)
        upper_layer.paste(Image.fromarray(row[None,:,:]),(5323-ORIGIN+shift,y))
    join_y=1504
    upper_contact=[p for p in upper_contact if p[1]<=join_y]
    join=upper_contact[-1]
    lower=cleaned(Image.open(OUT/'processed-lower/raw-sheet-clean.png'))
    lower.save(OUT/'lower-shore.png')
    lower=lower.resize(LOWER_RECT[2:],Image.Resampling.LANCZOS)
    a=np.asarray(lower).copy()
    # 原稿透明带仅作少量边缘软化，不以逐行包络擦掉回头湾两侧的石头。
    alpha=Image.fromarray(a[:,:,3])
    soft=np.asarray(alpha.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(3)))
    a[:,:,3]=np.minimum(a[:,:,3],soft)
    world_y=np.arange(a.shape[0])+LOWER_RECT[1]
    a[:,:,3]=np.rint(a[:,:,3]*smooth((world_y[:,None]-1450)/100)).astype(np.uint8)
    coast=upper_layer
    coast.alpha_composite(Image.fromarray(a),(LOWER_RECT[0]-ORIGIN,LOWER_RECT[1]))
    coast.save(OUT/'shore-overlay.png')
    lower_contact=[lower_world(p) for p in LOWER_CONTACT]
    lower_contact=[join]+[p for p in lower_contact if p[1]>join_y+10]
    boundary=list(reversed(lower_contact))+list(reversed(upper_contact[:-1]))
    polygon=boundary+[[7056,0],[7056,2880]]
    water=Image.new('L',WORLD)
    ImageDraw.Draw(water).polygon([tuple(p) for p in polygon],fill=255)
    art=np.asarray(coast)
    rgb=art[:,:,:3].astype(np.float32)
    pure_water=(rgb[:,:,0]<rgb[:,:,1]*0.43)&(rgb[:,:,2]>rgb[:,:,1]*1.08)&(art[:,:,3]>80)
    protected=((art[:,:,3]>35)&~pure_water).astype(np.uint8)*255
    protection=Image.new('L',WORLD)
    protection.paste(Image.fromarray(protected),(ORIGIN,0))
    protection=protection.filter(ImageFilter.MaxFilter(5))
    depth=water.filter(ImageFilter.GaussianBlur(45))
    control=Image.merge('RGBA',(water,protection,depth,Image.new('L',WORLD,255)))
    control.resize((1764,720),Image.Resampling.LANCZOS).save(OUT/'water-control.png')
    Image.fromarray(pure_water.astype(np.uint8)*255).save(OUT/'shore-water-only.png')
    cells=[]
    mask=np.asarray(water)
    for y in range(80):
        for x in range(196):
            if mask[y*36:(y+1)*36,x*36:(x+1)*36].any(): cells.append([x,y])
    sites=[]
    for index in [4,9,12,18,22,27,31]:
        point=np.asarray(lower_world(LOWER_CONTACT[index]))
        before=np.asarray(lower_world(LOWER_CONTACT[max(0,index-1)]))
        after=np.asarray(lower_world(LOWER_CONTACT[min(len(LOWER_CONTACT)-1,index+1)]))
        tangent=after-before
        normal=np.array([tangent[1],-tangent[0]])/np.linalg.norm(tangent)
        # 根点沿水侧探测到原画保护区外，避免整团被岸石遮罩裁掉。
        anchor=point+normal*46
        for reach in [46,62,78,94,110,126]:
            candidate=point+normal*reach
            px,py=np.rint(candidate).astype(int)
            if 0<=px<7056 and 0<=py<2880 and water.getpixel((px,py))>200 and protection.getpixel((px,py))<30:
                anchor=candidate
                break
        if 0<anchor[1]<2850: sites.append({'id':f'cove_{index}','anchor':anchor.tolist()})
    for i,y in enumerate([300,700,1380]):
        x=float(np.interp(y,np.asarray(upper_contact)[:,1],np.asarray(upper_contact)[:,0]))
        if x<6960: sites.append({'id':f'upper_{i}','anchor':[x+36,y+20]})
    for i,site in enumerate(sites):
        site.update({'size':[220 if i%3 else 270,150 if i%3 else 180],
                     'cycle':6.0 if i%3==1 else 4.0,'active_duration':[2.25,2.7,2.1][i%3],
                     'phase_offset':round((i*1.37)%4,2),'intensity':[0.85,0.6,0.7][i%3]})
    layout={'version':2,'world_size':list(WORLD),'shore_origin':[ORIGIN,0],
            'shore_size':list(coast.size),'period':12.0,'fps':60,'splash_sites':sites,
            'source_modules':['gentle','original-connector','cove'],
            'adaptation':'三岸段作为形态/材质参考，经内置生图定向适配；不是旋转水平原画或将概念图直接裁为最终素材。',
            'lower_world_rect':list(LOWER_RECT),'upper_world_rect':[5323,0,1733,1870],
            '说明':'静态岸石原画固定。水域多边形同时用于表现遮罩和36格地形编译。'}
    write_json('layout.json',layout)
    write_json('module.json',{'terrain':{'water':cells},'water_polygons':[polygon],
                             'visual_layout':'res://assets/levels/level_001/lake/layout.json'})
    paths=[OUT/'upper-shore-raw.png',OUT/'lower-shore-raw.png']+[ROOT/f'assets/map/lake_shore_extensions_v1/{n}-shore.png' for n in layout['source_modules']]
    write_json('build-qc.json',{'water_cells':len(cells),'shore_size':list(coast.size),
                              'upper_native_size':list(Image.open(OUT/'upper-shore-raw.png').size),
                              'lower_native_size':list(Image.open(OUT/'lower-shore-raw.png').size),
                              'splash_sites':len(sites),'join':join,
                              'input_hashes':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}})
    write_json('manifest.json',{'id':'ASSET-0023','date':'2026-11-13','status':'candidate','integrated':True,
              'generator':'built-in-image_gen','runtime_scene':'res://src/main/main.tscn',
              'native_sources':{'upper':[1207,1303],'lower':[1774,887]},
              'runtime_overlay_size':list(coast.size),'world_size':list(WORLD),
              'source_paths':{'upper':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-b3cec941-4477-473a-86d0-abcb0af30c48.png',
                              'lower':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-d054e3aa-0034-483f-8a7a-bcbb1569148f.png'},
              'prompts':['upper-shore-prompt.txt','lower-shore-prompt.txt'],
              '说明':'三款水平岸段作为形态/材质参考，新增定向适配生成图；运行覆盖图为关卡装配尺寸，不是原生3556×2880生成。',
              'output_hashes':{name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ['shore-overlay.png','shore-water-only.png','water-control.png','layout.json','module.json']}})
    print(json.dumps({'water_cells':len(cells),'splash_sites':len(sites),'join':join}))

if __name__=='__main__':
    main()
