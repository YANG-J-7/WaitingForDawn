"""核对生成来源、原生密度与运行图集完整重组，不以数值替代最终审美。"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]/'assets/map_kits/reference_hd_20261102'
data=json.loads((root/'map.json').read_text(encoding='utf-8'))
master=Image.open(root/'terrain-master.png').convert('RGB')
assert master.size==(7056,2880)
assert Image.open(root/'map-7056x2880.png').size==master.size
assert len(data['regions'])==18
for region in data['regions']:
    source=root/region['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==region['sha256']
    assert all(d>=1 for d in region['native_density'])
    assert (root/region['prompt']).read_text(encoding='utf-8').strip()
restored=Image.new('RGB',master.size)
for y in range(2):
    for x in range(7):
        path=root/f'atlases/ground-{x}-{y}.png'
        page=Image.open(path)
        assert page.size==(1024,1456)
        assert 'mipmaps/generate=true' in Path(str(path)+'.import').read_text(encoding='utf-8')
        restored.paste(page.crop((8,8,1016,1448)),(x*1008,y*1440))
assert np.array_equal(np.asarray(master),np.asarray(restored)), '图集重组必须逐像素等于母图'
forest=json.loads((root/'forest.json').read_text(encoding='utf-8'))
assert len(forest['trees'])==124 and len({t['id'] for t in forest['trees']})==124
for name in forest['sprites']:
    image=Image.open(root/name)
    assert image.mode=='RGBA' and image.getchannel('A').getextrema()[0]==0
print('PASS: 7056×2880、18原稿来源/密度/提示词、14页无损重组/mipmap、124独立树木与透明素材')
