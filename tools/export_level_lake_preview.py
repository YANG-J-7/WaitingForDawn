"""编码正式湖岸布局实际GL帧为60fps视频，并检查时间轴。"""
from pathlib import Path
import subprocess,json
import numpy as np
from PIL import Image
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'tests/reports/images/level-lake'
assert all((OUT/f'frame-60-{i:03}.png').exists() for i in range(720))
steps=[]
previous=None
first=None
for index in range(720):
    current=np.asarray(Image.open(OUT/f'frame-60-{index:03}.png').convert('RGB'),dtype=np.int16)
    if first is None: first=current.copy()
    if previous is not None: steps.append(float(np.abs(current-previous).mean()))
    previous=current
wrap=float(np.abs(first-previous).mean())
assert min(steps)>0 and wrap<=max(steps)*1.1
output=OUT/'level-lake-60fps.mp4'
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate','60','-i',str(OUT/'frame-60-%03d.png'),'-frames:v','720','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],check=True)
count,seconds=imageio_ffmpeg.count_frames_and_secs(str(output))
probe=subprocess.run([ffmpeg,'-i',str(output),'-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace')
assert probe.returncode==0 and '60 fps' in probe.stderr and count==720 and abs(seconds-12)<0.01
metrics={'fps':60,'frames':count,'seconds':seconds,'resolution':[960,392],
         'minimum_frame_difference':min(steps),'maximum_frame_difference':max(steps),'wrap_difference':wrap,
         'runtime':json.loads((OUT/'frame-times.json').read_text(encoding='utf-8')),
         '说明':'正式第一关同源地表实际GL渲染；720独立帧，无重复；12秒循环，视频帧率不是全关稳定帧率保证。'}
(OUT/'metrics-60fps.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(metrics,ensure_ascii=False))
