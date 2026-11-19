"""导出四处实际GL近景、对照拼图与水花素材包。"""
from pathlib import Path
import json,subprocess,zipfile
from PIL import Image,ImageDraw
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'tests/reports/images/reverse-wave'
ASSET=ROOT/'assets/fx/reverse_wave_v1'

def main():
    ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    clips=[]
    # 主场景相机受地图边界限位，第三处使用右侧实际可见区域。
    crops=[(480,220,1040,660),(500,250,1060,690),(920,180,1280,620),(470,190,1030,630)]
    for index,crop in enumerate(crops,1):
        paths=[OUT/f'site-{index}-{i:03d}.png' for i in range(48)]
        assert all(p.exists() for p in paths)
        frames=[Image.open(p).convert('RGB').crop(crop).resize((560,440)) for p in paths]
        clips.append(frames)
        frames[0].save(OUT/f'site-{index}.gif',save_all=True,append_images=frames[1:],duration=83,loop=0)
        video=OUT/f'site-{index}-12fps.mp4'
        subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate','12','-i',str(OUT/f'site-{index}-%03d.png'),
                        '-frames:v','48','-c:v','libx264','-crf','18','-pix_fmt','yuv420p',str(video)],check=True)
        count,seconds=imageio_ffmpeg.count_frames_and_secs(str(video))
        assert count==48 and abs(seconds-4)<.01
    boards=[]
    for frame_index in range(48):
        board=Image.new('RGB',(1120,880))
        for i,frames in enumerate(clips):
            board.paste(frames[frame_index],((i%2)*560,(i//2)*440))
        boards.append(board)
    boards[0].save(OUT/'four-sites.gif',save_all=True,append_images=boards[1:],duration=83,loop=0)
    boards[22].save(OUT/'four-sites.png')
    with zipfile.ZipFile(ROOT/'assets/bundles/reverse-wave-v1.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for path in ASSET.rglob('*'):
            if path.is_file() and path.suffix!='.import': archive.write(path,path.relative_to(ASSET))
    record={'sites':4,'frames_per_site':48,'fps':12,'seconds':4,'resolution':[1280,720],
            '说明':'真实主场景验证镜头放大取证；预览12fps不约束运行连续时间刷新率；每处另验证水花自身60帧唯一。'}
    (OUT/'preview-qc.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False))

if __name__=='__main__': main()
