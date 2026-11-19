"""打包生成水花，并导出真实GL近景动画，不生成美术。"""
from pathlib import Path
import json
import subprocess
import zipfile
from PIL import Image
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'tests/reports/images/rock-splash'
ASSET = ROOT/'assets/fx/rock_splash_v2'

def main():
    frames = [OUT/f'frame-{i:03d}.png' for i in range(96)]
    assert all(path.exists() for path in frames)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    video = OUT/'rock-impact-24fps.mp4'
    subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate','24','-i',str(OUT/'frame-%03d.png'),
                    '-frames:v','96','-c:v','libx264','-crf','18','-pix_fmt','yuv420p',str(video)],check=True)
    count, seconds = imageio_ffmpeg.count_frames_and_secs(str(video))
    assert count==96 and abs(seconds-4)<.01
    preview = [Image.open(path).convert('RGB').crop((440,170,1000,610)).resize((560,440)) for path in frames[::2]]
    preview[0].save(OUT/'rock-impact-preview.gif',save_all=True,append_images=preview[1:],duration=83,loop=0)
    with zipfile.ZipFile(ROOT/'assets/bundles/rock-splash-v2.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for path in ASSET.iterdir():
            if path.is_file() and path.suffix!='.import': archive.write(path,path.name)
    report = {'frames':count,'fps':24,'seconds':seconds,'size':[1280,720],
              '说明':'正式主场景、验证镜头局部放大；24fps实景预览，不是运行刷新率上限。源为六原画连续B样条过渡。'}
    (OUT/'preview-qc.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))

if __name__ == '__main__': main()
