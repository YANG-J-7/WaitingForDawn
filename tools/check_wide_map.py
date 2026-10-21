"""校核扩边素材、提示词来源、共边切片、旧山区与确定性构建。"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/map/dawn_wide_v3'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    data=read(OUT/'map.json')
    visual=read(OUT/'visual.json')
    nav=read(OUT/'mountain-navigation.json')
    old=read(ROOT/'assets/map/dawn_large_v1/map.json')
    old_nav=read(ROOT/'assets/map/dawn_large_v1/mountain-navigation.json')
    assert data['worldSize']==visual['worldSize']==nav['worldSize']==[7056,2880]
    assert data['gridSize']==[196,80] and data['cellSize']==36
    assert data['city']==[4176,1908] and data['sourceWorldOrigin']==[2448,288]
    assert len(visual['chunks'])==18 and len(data['resourceSites'])==8
    assert nav['routes']==old_nav['routes'] and nav['stairs']==old_nav['stairs']
    for key in ('mountainCells','cliffCells'):
        assert nav[key]==[[x+68,y+8] for x,y in old_nav[key]]
    for a,b in zip(old_nav['cells'],nav['cells']):
        expected=dict(a,cell=[a['cell'][0]+68,a['cell'][1]+8])
        assert expected==b
    for a,b in zip(old['resourceSites'],data['resourceSites']):
        assert a['id']==b['id'] and b['position']==dict(x=a['position']['x']+2448,y=a['position']['y']+288)
    base=Image.open(OUT/'base.png')
    assert base.size==(7056,2880) and base.mode=='RGB'
    reconstructed=Image.new('RGB',base.size)
    for entry in visual['chunks']:
        image=Image.open(ROOT/entry['path'])
        assert list(image.size)==entry['pixelSize']
        x,y,w,h=entry['worldRect']
        assert (w,h)==image.size
        reconstructed.paste(image,(x,y))
    assert np.array_equal(np.asarray(base),np.asarray(reconstructed)), '切片必须严格重建同一连续地表'
    for entry in visual['forests']+visual['occluders']:
        image=Image.open(ROOT/entry['path'])
        assert image.mode=='RGBA' and image.getchannel('A').getextrema()==(0,255)
    for index in (1,4):
        original_alpha=Image.open(ROOT/f'assets/map/dawn_large_hd_v2/cliff-{index}.png').getchannel('A')
        repaired_alpha=Image.open(OUT/f'cliff-{index}-repaired.png').getchannel('A')
        assert np.array_equal(np.asarray(original_alpha),np.asarray(repaired_alpha)), '北部岩缘修图必须保持独立遮挡轮廓'
    border=Image.open(OUT/'border-forest.png')
    assert border.size==base.size and border.mode=='RGBA' and border.getchannel('A').getextrema()==(0,255)
    record=read(OUT/'generation-record.json')
    assert record['revision']=='join-repair-v4'
    assert len(record['generatedAssets'])==8
    for entry in record['generatedAssets']:
        path=OUT/entry['path']
        assert Image.open(path).size==tuple(entry['nativeSize']) and digest(path)==entry['sha256']
        assert (OUT/entry['prompt']).read_text(encoding='utf-8').strip()
        assert (OUT/entry['reference']).is_file()
    before=np.asarray(Image.open(ROOT/'assets/map/dawn_large_hd_v2/base.png')).astype(float)
    after=np.asarray(Image.open(OUT/'legacy-repaired.png')).astype(float)
    v0=np.abs(before[1000:2100,1253]-before[1000:2100,1254]).mean()
    v1=np.abs(after[1000:2100,1253]-after[1000:2100,1254]).mean()
    h0=np.abs(before[941,850:1550]-before[942,850:1550]).mean()
    h1=np.abs(after[941,850:1550]-after[942,850:1550]).mean()
    assert v1<v0*.6 and h1<h0*.6, '历史母图局部接缝指标应保持；不代表扩边接缝视觉验收'
    plain=np.asarray(Image.open(OUT/'plain-material-mask-v2.png'))
    assert np.all(plain[:,1800:3000]==255), '用户反馈的全高交界必须完全共用同一草地材质'
    # 北部补绘仅占顶部440世界像素；其下山区保护区应保持原地形像素。
    from PIL import ImageDraw
    protection=Image.new('L',base.size)
    ImageDraw.Draw(protection).polygon([(round(x/1672*4608)+2448,round(y/941*2592)+288) for x,y in old_nav['region']],fill=255)
    protected_pixels=np.asarray(protection)>0
    protected_pixels[:440]=False
    protected_pixels[250:530,3820:4150]=False
    protected_pixels[250:510,4400:5000]=False
    original=Image.new('RGB',base.size)
    original.paste(Image.open(OUT/'legacy-repaired.png').resize((4608,2592),Image.Resampling.LANCZOS),(2448,288))
    assert np.array_equal(np.asarray(base)[protected_pixels],np.asarray(original)[protected_pixels]), '北部修复范围以下的山区不得被重绘'
    files=[p for p in OUT.rglob('*') if p.suffix in ('.png','.json','.txt')]
    protected=[ROOT/'assets/map/dawn_large_v1/map.json',ROOT/'assets/map/dawn_large_v1/mountain-navigation.json',ROOT/'assets/map/dawn_large_hd_v2/base.png']
    hashes={p:digest(p) for p in files+protected}
    subprocess.run([sys.executable,'-X','utf8',str(ROOT/'tools/build_wide_map.py')],check=True)
    assert all(digest(p)==value for p,value in hashes.items()), '输出应可重复且旧地图源不能改变'
    print('PASS: 7056×2880素材、196×80格及八资源保持同步')
    print('PASS: 原547路格/八石梯/所有岩壁格仅按68列8行迁移')
    print('PASS: 18片地表重组与连续底图逐像素一致')
    print('PASS: 复用树簇/岩缘/边界alpha与八张生成稿的提示词、参考、尺寸和哈希有效')
    print('PASS: 原竖带区域完全共用统一草地；顶部补绘及两处局部植被清理区外原山区逐像素保持，视觉另查GL')
    print(f'PASS: 横缝均差{h0:.3f}→{h1:.3f}，竖缝{v0:.3f}→{v1:.3f}；此为局部指标，仍需GL目检')
    print(f'PASS: {len(files)}项素材/数据/提示词确定性重建一致，旧源文件哈希保持')

if __name__=='__main__':
    main()
