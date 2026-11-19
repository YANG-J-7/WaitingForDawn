"""检查真实GL连续帧并导出高帧率预览，不绘制美术。"""
from pathlib import Path
from PIL import Image
import numpy as np
import json, subprocess, argparse
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
P=ROOT/'tests/reports/images/lake-shore-runtime'
parser=argparse.ArgumentParser()
parser.add_argument('--fps',type=int,choices=[30,60],default=60)
FPS=parser.parse_args().fps
COUNT=FPS*12
PREFIX='smooth-60-' if FPS==60 else 'smooth-'
def pixels(name): return np.asarray(Image.open(P/name).convert('RGBA')).astype(np.int16)
split=np.abs(pixels('01-static.png')-pixels('single-water.png'))
loop=np.abs(pixels('loop-start.png')-pixels('loop-end.png'))
assert split.max()<=1 and loop.max()<=1
regions=[(100,800,300,200),(750,850,300,180),(1550,800,300,200),(130,610,100,35),(1270,485,120,40),(1680,575,100,35)]
diff=np.abs(pixels('waves-zero.png')[:,:,:3]-pixels('03-waves.png')[:,:,:3]).max(axis=2)
coverage=[float((diff[y:y+h,x:x+w]>2).mean()) for x,y,w,h in regions]
assert all(v>0.35 for v in coverage[:3]) and all(v>0.10 for v in coverage[3:])
assert not diff[:200,500:1300].any()
assert not diff[450:520,850:920].any(), '岩石主体应固定'
previous=None
first=None
steps=[]
for i in range(COUNT):
    frame=np.asarray(Image.open(P/f'{PREFIX}{i:03}.png').convert('RGB'),dtype=np.int16)
    if first is None: first=frame.copy()
    if previous is not None: steps.append(float(np.abs(frame-previous).mean()))
    previous=frame
wrap=float(np.abs(previous-first).mean())
assert min(steps)>0, '连续帧不应重复停顿'
assert wrap<=max(steps)*1.1, '循环末尾不应突然跳帧'
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
output=P/f'lake-animation-splashes-{FPS}fps.mp4'
subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate',str(FPS),'-i',str(P/f'{PREFIX}%03d.png'),'-frames:v',str(COUNT),'-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],check=True)
probe=subprocess.run([ffmpeg,'-i',str(output),'-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace')
assert probe.returncode==0 and f'{FPS} fps' in probe.stderr and '00:00:12.00' in probe.stderr
decoded_count,decoded_seconds=imageio_ffmpeg.count_frames_and_secs(str(output))
assert decoded_count==COUNT and abs(decoded_seconds-12.0)<0.01
# 固定调色板避免逐帧量化闪色，GIF仍为15fps，主交付为视频。
frames=[Image.open(P/f'{PREFIX}{i:03}.png').convert('RGB').resize((640,360),Image.Resampling.LANCZOS) for i in range(0,COUNT,FPS//15)]
palette=frames[0].quantize(colors=256)
indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
indexed[0].save(P/'lake-animation-preview.gif',save_all=True,append_images=indexed[1:],duration=[60,70,70]*60,loop=0,optimize=False)
timings=json.loads((P/'frame-times.json').read_text(encoding='utf-8'))
report={'split_max_channel_difference':int(split.max()),'loop_max_channel_difference':int(loop.max()),'wave_coverage_without_moon':coverage,'consecutive_frame_mean_difference_min':min(steps),'consecutive_frame_mean_difference_max':max(steps),'wrap_frame_mean_difference':wrap,'video_fps':FPS,'frames':COUNT,'duration_seconds':12,'gif_fps':15,'runtime_frame_times':timings,'说明':f'真实GL{COUNT}独立渲染帧；六个水区关闭月光仍变化，岩石/草地固定。视频{FPS}fps解码通过；帧间采样不含截图读回，不等于全关性能。'}
(P/f'metrics-{FPS}fps.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
