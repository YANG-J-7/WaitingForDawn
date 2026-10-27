"""一次迁移旧关卡语义数据；只生成组件数据和渲染控制图，不绘制美术。"""
from pathlib import Path
import json
import hashlib
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/levels/level_001'
SRC=ROOT/'assets/map/dawn_wide_v3'
CELL=36
SCALE=2

def dump(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def local_cell(pair,origin): return [int(pair[0])-origin[0]//CELL,int(pair[1])-origin[1]//CELL]
def local_point(pair,origin): return [pair[0]-origin[0],pair[1]-origin[1]]
def world(pair): return [2448+pair[0]/1672*4608,288+pair[1]/941*2592]

def mask_for(cells,origin,size):
    image=Image.new('L',size)
    draw=ImageDraw.Draw(image)
    for cell in cells:
        x=(cell[0]*CELL-origin[0])/SCALE
        y=(cell[1]*CELL-origin[1])/SCALE
        draw.rectangle((x,y,x+CELL/SCALE-1,y+CELL/SCALE-1),fill=255)
    return image

def build():
    old=json.loads((SRC/'map.json').read_text(encoding='utf-8'))
    nav=json.loads((SRC/'mountain-navigation.json').read_text(encoding='utf-8'))
    visual=json.loads((SRC/'visual.json').read_text(encoding='utf-8'))
    all_mount=nav['mountainCells']+nav['cliffCells']+[e['cell'] for e in nav['cells']]
    origin=[min(p[0] for p in all_mount)*CELL-72,min(p[1] for p in all_mount)*CELL-72]
    end=[(max(p[0] for p in all_mount)+1)*CELL+72,(max(p[1] for p in all_mount)+1)*CELL+72]
    size=[(end[i]-origin[i])//SCALE for i in range(2)]
    mountain={'origin':origin,'world_size':[end[i]-origin[i] for i in range(2)],'terrain':{k:[local_cell(p,origin) for p in old['cells'][k]] for k in ['cliff','road','ramp']},'navigation':{k:[local_cell(p,origin) for p in nav[k]] for k in ['mountainCells','cliffCells']}}
    mountain['navigation']['cells']=[dict(e,cell=local_cell(e['cell'],origin)) for e in nav['cells']]
    mountain['navigation'].update({k:nav[k] for k in ['routes','stairs']})
    mountain['paths']=[]
    for kind,entries in [('road',nav['routes']),('stair',nav['stairs'])]:
        for index,e in enumerate(entries): mountain['paths'].append({'id':f'{kind}_{index}','kind':kind,'points':[local_point(world(p),origin) for p in e['points']], 'width':float(e.get('halfWidth',12))*4608/1672*2})
    # 控制图保存轮廓，不从图像颜色反推碰撞，也不生成岩石/草叶纹理。
    mountain['land_polygon']=[local_point(world(p),origin) for p in nav['region']]
    mountain['cliff_polygons']=[[local_point(world(p),origin) for p in polygon] for polygon in old['cliffs']]
    region=Image.new('L',size); region_draw=ImageDraw.Draw(region)
    region_draw.polygon([(p[0]/SCALE,p[1]/SCALE) for p in mountain['land_polygon']],fill=255)
    region=region.filter(ImageFilter.GaussianBlur(8))
    cliff=Image.new('L',size); cliff_draw=ImageDraw.Draw(cliff)
    for polygon in mountain['cliff_polygons']: cliff_draw.polygon([(p[0]/SCALE,p[1]/SCALE) for p in polygon],fill=255)
    cliff=cliff.filter(ImageFilter.GaussianBlur(.9))
    road=Image.new('L',size); ramp=Image.new('L',size)
    for path in mountain['paths']:
        target=road if path['kind']=='road' else ramp
        draw=ImageDraw.Draw(target)
        draw.line([(p[0]/SCALE,p[1]/SCALE) for p in path['points']],fill=255,width=round((path['width'] if path['kind']=='road' else 64)/SCALE),joint='curve')
    road=road.filter(ImageFilter.GaussianBlur(2)); ramp=ramp.filter(ImageFilter.GaussianBlur(.6))
    OUT.mkdir(parents=True,exist_ok=True)
    Image.merge('RGBA',(cliff,road,ramp,region)).save(OUT/'mountain-control.png')
    mountain['control']='assets/levels/level_001/mountain-control.png'
    dump(OUT/'mountain.json',mountain)
    lake={'origin':[0,0],'world_size':old['worldSize'],'terrain':{'water':old['cells']['water']},'water_polygons':[[world(p) for p in points] for points in old['water']],'island_polygons':[[world(p) for p in points] for points in old['islands']]}
    water=Image.new('L',(3528,1440)); draw=ImageDraw.Draw(water)
    for polygon in lake['water_polygons']: draw.polygon([(p[0]/2,p[1]/2) for p in polygon],fill=255)
    for polygon in lake['island_polygons']: draw.polygon([(p[0]/2,p[1]/2) for p in polygon],fill=0)
    # 岸带/深度都是规则轮廓的低频派生数据，不含最终可见美术。
    shore=water.filter(ImageFilter.GaussianBlur(10))
    depth=water.filter(ImageFilter.GaussianBlur(45))
    Image.merge('RGBA',(water.filter(ImageFilter.GaussianBlur(.6)),shore,depth,Image.new('L',water.size,255))).save(OUT/'lake-control.png')
    lake['control']='assets/levels/level_001/lake-control.png'
    dump(OUT/'lake.json',lake)
    boundary={'origin':[0,0],'terrain':{k:old['cells'][k] for k in ['forest','boundary']}}
    dump(OUT/'boundary.json',boundary)
    markers={'origin':[0,0],'resource_sites':old['resourceSites'],'spawn_points':old['spawns'],'forest_visuals':[]}
    for e in visual['forests']:
        a=world(e['sourceRect'][:2]); b=world(e['sourceRect'][2:])
        markers['forest_visuals'].append({'id':e['id'],'path':e['path'],'rect':[a[0],a[1],b[0]-a[0],b[1]-a[1]]})
    dump(OUT/'markers.json',markers)
    parts={'Ground':('ground',[0,0]),'Mountain':('mountain',origin),'Lake':('lake',[0,0]),'Boundary':('boundary',[0,0]),'Markers':('markers',[0,0])}
    scenes=ROOT/'src/levels/modules'; scenes.mkdir(parents=True,exist_ok=True)
    for name,(role,pos) in parts.items():
        data='' if role=='ground' else f'data_path = "res://assets/levels/level_001/{role}.json"\n'
        (scenes/f'{role}.tres').write_text(f'[gd_resource type="Resource" script_class="TerrainModuleDefinition" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://src/gameplay/map/terrain_module_definition.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\nmodule_id = &"moonlit_{role}_v1"\nrole = "{role}"\n{data}',encoding='utf-8')
        (scenes/f'{role}.tscn').write_text(f'[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/gameplay/map/terrain_module.gd" id="1"]\n[ext_resource type="Resource" path="res://src/levels/modules/{role}.tres" id="2"]\n\n[node name="{name}" type="Node2D"]\nscript = ExtResource("1")\ndefinition = ExtResource("2")\n',encoding='utf-8')
    assembly=['[gd_scene load_steps=6 format=3]','']+[f'[ext_resource type="PackedScene" path="res://src/levels/modules/{role}.tscn" id="{i+1}"]' for i,(name,(role,pos)) in enumerate(parts.items())]+['','[node name="Level001Assembly" type="Node2D"]']
    for i,(name,(role,pos)) in enumerate(parts.items()): assembly+=['',f'[node name="{name}" parent="." instance=ExtResource("{i+1}")]',f'position = Vector2({pos[0]}, {pos[1]})']
    (ROOT/'src/levels/level_001.tscn').write_text('\n'.join(assembly)+'\n',encoding='utf-8')
    (ROOT/'src/levels/level_001.tres').write_text('[gd_resource type="Resource" script_class="LevelDefinition" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/gameplay/map/level_definition.gd" id="1"]\n[ext_resource type="PackedScene" path="res://src/levels/level_001.tscn" id="2"]\n\n[resource]\nscript = ExtResource("1")\nassembly = ExtResource("2")\n',encoding='utf-8')
    dump(OUT/'migration-record.json',{'source':'dawn_wide_v3 semantics only','source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [SRC/'map.json',SRC/'mountain-navigation.json']},'world_size':old['worldSize'],'note':'旧图只用于一次语义迁移，组件JSON与场景是后续编辑源；控制图不含可见美术'})
    print('已迁移5类独立组件及局部控制图；未切割或绘制最终美术。')

if __name__=='__main__': build()
