"""将实际GL水花特写编码为60fps，验证帧数与原始时长。"""
from pathlib import Path
import json
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'tests/reports/images/lake-shore-runtime'
output = OUT/'shore-splash-closeup-60fps.mp4'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
assert all((OUT/f'splash-closeup-60-{i:03}.png').is_file() for i in range(720))
subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-framerate', '60', '-i',
                str(OUT/'splash-closeup-60-%03d.png'), '-frames:v', '720', '-c:v',
                'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(output)], check=True)
count, seconds = imageio_ffmpeg.count_frames_and_secs(str(output))
probe = subprocess.run([ffmpeg, '-i', str(output), '-f', 'null', '-'], capture_output=True,
                       text=True, encoding='utf-8', errors='replace')
assert probe.returncode == 0 and '60 fps' in probe.stderr
assert count == 720 and abs(seconds-12) < 0.01
report = {'fps': 60, 'frames': count, 'seconds': seconds, 'resolution': [1440, 320],
          'panels': ['凸岩', '小湾', '碎石岸'],
          '说明': '三栏为GL真实渲染，水面与石岸冻结，仅水花按原4/6/4秒节奏推进；透明休止期为设计间歇。'}
(OUT/'splash-60fps-metrics.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
