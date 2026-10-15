"""独立校核高清素材的实际密度、透明轮廓、清单路径和确定性重建。"""
from pathlib import Path
import hashlib, json, subprocess, sys
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/map/dawn_large_hd_v2'
OLD = ROOT/'assets/map/dawn_large_v1'
hd = json.loads((OUT/'visual.json').read_text(encoding='utf-8'))
old = json.loads((OLD/'map.json').read_text(encoding='utf-8'))
assert hd['worldSize'] == old['worldSize'] == [4608,2592]
assert hd['sourceSize'] == old['sourceSize']
assert len(hd['chunks'])==12 and len(hd['forests'])==4 and len(hd['rawAssets'])==24
for new, original in zip(hd['chunks'],old['chunks']):
    assert new['sourceRect']==original['sourceRect']
    image = Image.open(ROOT/new['path'])
    assert image.size==tuple(new['pixelSize'])
    assert image.width/((new['sourceRect'][2]-new['sourceRect'][0])*4608/1672) >= 1.08
for raw in hd['rawAssets']:
    assert Image.open(OUT/raw['path']).size==tuple(raw['nativeSize'])
    assert (OUT/raw['prompt']).is_file() and (OUT/raw['reference']).is_file()
    assert hashlib.sha256((OUT/raw['path']).read_bytes()).hexdigest()==hd['rawSHA256'][raw['path']]
for entry in hd['forests']+[hd['border']]+hd['occluders']:
    path = ROOT/entry['path']
    image = Image.open(path)
    assert image.mode=='RGBA' and image.getchannel('A').getextrema()==(0,255)
    original = Image.open(OLD/path.name)
    factor = image.width//original.width
    assert image.size==(original.width*factor,original.height*factor)
    if path.name.startswith('forest_'):
        assert (np.asarray(image.getchannel('A'))>240).mean()<.75, '树簇不能再带整块不透明草地'
    else:
        assert np.array_equal(np.asarray(image.getchannel('A')),np.asarray(original.getchannel('A').resize(image.size,Image.Resampling.NEAREST)))
files = [OUT/'visual.json']+[p for p in OUT.glob('*.png') if not p.name.startswith(('raw-','cutout-','border-reference-'))]
hashes = {p:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
geometry_hash = hashlib.sha256((OLD/'map.json').read_bytes()).hexdigest()
subprocess.run([sys.executable,'-X','utf8',str(ROOT/'tools/build_large_map_hd.py')],check=True)
assert all(hashlib.sha256(p.read_bytes()).hexdigest()==digest for p,digest in hashes.items())
assert hashlib.sha256((OLD/'map.json').read_bytes()).hexdigest()==geometry_hash
print('PASS: 24张原生生成稿及提示词/参考路径/哈希真实存在')
print('PASS: 12地形分块位置与原地图一致，实际密度不低于1.08源像素/世界像素')
print('PASS: 四处树林去掉矩形草地，边界和岩缘透明轮廓保持')
print(f'PASS: {len(files)}项输出确定性重建一致，权威玩法JSON未改')
