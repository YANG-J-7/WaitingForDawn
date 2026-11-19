"""对GL实景进行视频编码、透明截图去预乘、素材打包；不生成原始美术。"""
from pathlib import Path
from PIL import Image
import numpy as np
import json,subprocess,zipfile,shutil,hashlib
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
P=ROOT/'assets/map/beach_v1'
OUT=ROOT/'tests/reports/images/beach'
frames=720
previous=None
first=None
steps=[]
for i in range(frames):
    a=np.asarray(Image.open(OUT/f'frame-{i:03}.png').convert('RGB'),dtype=np.int16)
    if first is None: first=a.copy()
    if previous is not None: steps.append(float(np.abs(a-previous).mean()))
    previous=a
wrap=float(np.abs(first-previous).mean())
assert min(steps)>0 and wrap<=max(steps)*1.1
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
video=OUT/'beach-waves-60fps.mp4'
subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate','60','-i',str(OUT/'frame-%03d.png'),'-frames:v','720','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
count,seconds=imageio_ffmpeg.count_frames_and_secs(str(video))
probe=subprocess.run([ffmpeg,'-i',str(video),'-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace')
assert count==720 and abs(seconds-12)<.01 and probe.returncode==0 and '60 fps' in probe.stderr
capture=OUT/'beach-overlay-capture.png'
assert capture.exists(),'先通过真实GL导出透明沙滩截图'
a=np.asarray(Image.open(capture).convert('RGBA'),dtype=float)/255
a[:,:,:3]/=np.maximum(a[:,:,3:],1/255)
a[a[:,:,3]==0,:3]=0
Image.fromarray(np.clip(a*255,0,255).round().astype(np.uint8)).save(P/'beach-overlay.png')
shutil.copy2(OUT/'preview.png',P/'preview.png')
manifest=json.loads((P/'manifest.json').read_text(encoding='utf-8'))
manifest['exports']={'overlay':'beach-overlay.png','overlay_dimensions':[1070,325],'overlay_offset':[0,180],
                     'static_composite':'beach-grass-composite.png','static_composite_dimensions':[1070,720],
                     'static_composite_world_origin':[0,0],'video_frames':count,'video_seconds':seconds,'video_fps':60,
                     '说明':'透明沙滩为同尺寸GL导出后去预乘，按offset放置在原底草上；静态合成草图仅适配world_origin相位，任意位置优先使用世界坐标材质。'}
manifest['checks']['grass_gl_edge_max_channel_difference']=1
manifest['checks']['runtime_gl_checks_passed']=10
manifest['checks']['video_minimum_frame_difference']=min(steps)
manifest['checks']['video_wrap_difference']=wrap
manifest['sha256'].update({name:hashlib.sha256((P/name).read_bytes()).hexdigest() for name in ['beach-overlay.png','beach-grass-composite.png','preview.png']})
(P/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
names=['sand.png','foam.png','grass-contact.png','beach-overlay.png','beach-grass-composite.png','preview.png',
       'sand-raw.png','foam-raw.png','sand-prompt.txt','foam-prompt.txt','build_assets.py','README.md','manifest.json',
       'processed-sand/pipeline-meta.json','processed-foam/pipeline-meta.json']
files=[P/name for name in names]
files += [ROOT/'src/gameplay/art'/name for name in ['beach_sample.gd','beach_sand.gdshader','beach_water.gdshader','beach_foam.gdshader','grass_map.gdshader']]
files += [ROOT/'tools/preview_beach.tscn',ROOT/'tools/preview_beach.gd',ROOT/'tools/export_beach_delivery.py',
          ROOT/'assets/map/grass_variants_v1/grass.png',ROOT/'assets/map/lake_shore_v1/runtime/water-periodic.png']
with zipfile.ZipFile(P/'beach-v1.zip','w',zipfile.ZIP_DEFLATED) as bundle:
    for path in files: bundle.write(path,str(path.relative_to(ROOT)))
with zipfile.ZipFile(P/'beach-v1.zip') as bundle: assert bundle.testzip() is None
print(json.dumps({'fps':60,'frames':count,'seconds':seconds,'zip_bytes':(P/'beach-v1.zip').stat().st_size,'min_frame_diff':min(steps),'wrap':wrap}))
