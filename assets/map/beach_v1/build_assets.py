"""仅对生成沙滩和泡沫做去底、周期接边、控制图和QC；不绘制美术。"""
from pathlib import Path
from PIL import Image,ImageFilter
import numpy as np,json,hashlib
ROOT=Path(__file__).resolve().parent
def periodic(image):
    a=np.asarray(image.convert('RGBA'),dtype=np.float32)/255
    a[:,:,:3]*=a[:,:,3:]
    source=a.copy()
    for x in range(96):
        weight=.5*(1-x/95)**2
        a[:,x]=source[:,x]*(1-weight)+source[:,-1-x]*weight
        a[:,-1-x]=source[:,-1-x]*(1-weight)+source[:,x]*weight
    a[:,:,:3]/=np.maximum(a[:,:,3:],1e-6)
    a=np.clip(a*255,0,255).round().astype(np.uint8)
    a[a[:,:,3]==0,:3]=0
    assert np.array_equal(a[:,0],a[:,-1])
    assert not a[:3,:,3].any() and not a[-3:,:,3].any()
    return Image.fromarray(a)
def main():
    sand=np.asarray(Image.open(ROOT/'processed-sand/raw-sheet-clean.png').convert('RGBA')).copy()
    rgb=sand[:,:,:3].astype(float)
    spill=np.clip((rgb[:,:,0]-rgb[:,:,1]-3)/30,0,1)*np.clip((rgb[:,:,2]-rgb[:,:,1]-15)/40,0,1)
    sand[:,:,3]=np.rint(sand[:,:,3]*(1-spill)).astype(np.uint8)
    sand[:,:,3]=np.minimum(sand[:,:,3],np.asarray(Image.fromarray(sand[:,:,3]).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2))))
    sand=periodic(Image.fromarray(sand).crop((64,200,1710,700)))
    sand.save(ROOT/'sand.png')
    alpha=np.asarray(sand)[:,:,3]
    top=np.argmax(alpha>180,axis=0)
    control=np.zeros((1,1646,3),dtype=np.uint8)
    control[0,:,0]=np.rint(top/500*255).astype(np.uint8)
    Image.fromarray(control).save(ROOT/'grass-contact.png')
    c=np.asarray(Image.open(ROOT/'foam-raw.png').convert('RGB'),dtype=float)
    a=np.clip(c[:,:,1]/240,0,1)
    a[a<.08]=0
    c[:,:,0]=np.minimum(c[:,:,0],c[:,:,1]*.96)
    c[:,:,2]=np.minimum(c[:,:,2],c[:,:,1]*1.25+10)
    rgba=np.dstack([c,a*255]).clip(0,255).round().astype(np.uint8)
    foam=periodic(Image.fromarray(rgba).crop((64,340,1710,550)))
    foam.save(ROOT/'foam.png')
    for name in ['sand','foam']:
        qc=json.loads((ROOT/f'processed-{name}/pipeline-meta.json').read_text(encoding='utf-8'))
        assert not any(qc[k] for k in ['empty_frames','source_edge_touch_frames','output_edge_touch_frames','paste_clamped_frames'])
    meta={'id':'ASSET-0025','date':'2026-11-16','status':'candidate','integrated':False,
          'generator':'built-in-image_gen','source_dimensions':[1774,887],
          'sand_dimensions':list(sand.size),'foam_dimensions':list(foam.size),
          'world_tile_width':1070,'sand_world_rect':[0,180,1070,325],
          'grass':'res://assets/map/grass_variants_v1/grass.png','grass_world_period':360,
          'grass_shader':'res://src/gameplay/art/grass_map.gdshader','land_fade_world_pixels':48,
          'edge_mask':'复用原草叶纹理静态扰动渐隐边界，避免宽灰雾带',
          'period_seconds':12,'wave_period_seconds':4,'video_fps':60,
          '说明':'沙滩不含另一套草地；陆侧alpha归零，露出同坐标现有地表。浪花由生成纹理连续推进/退回，不逐关键帧换图。',
          'source_paths':{'sand':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-ac2fb07d-edba-406f-9cdc-b9fe13fed9a9.png','foam':'C:/Users/y1971/.codex/generated_images/01a1cb03-ab11-75d3-b200-54fba06d9712/exec-270a005f-2b5a-4f71-9982-32356fc26efd.png'},
          'checks':{'horizontal_edges_exact':True,'top_bottom_clear':True,'strict_source_qc':True},
          'sha256':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in ['sand-raw.png','foam-raw.png','sand.png','foam.png','grass-contact.png','sand-prompt.txt','foam-prompt.txt']}}
    (ROOT/'manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('沙滩/泡沫去底与水平周期接边通过')
if __name__=='__main__': main()
