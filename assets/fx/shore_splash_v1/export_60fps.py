"""将已生成的六关键帧确定性插值为60fps透明序列，不生成新原画。"""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
FPS = 60


def smooth(a, b, value):
    t = np.clip((value-a)/(b-a), 0.0, 1.0)
    return float(t*t*(3.0-2.0*t))


def sample(phase, duration):
    progress = min(phase/duration, 1.0)*5.0
    current = min(int(progress), 5)
    u = progress-current
    return {
        'source_frames': [max(current-1, 0), current, min(current+1, 5), min(current+2, 5)],
        'weights': [(1-u)**3/6, (3*u**3-6*u*u+4)/6, (-3*u**3+3*u*u+3*u+1)/6, u**3/6],
        'envelope': smooth(0.0, 0.18, phase)*(1.0-smooth(duration-0.5, duration, phase)),
    }


def srgb_to_linear(rgb):
    return np.where(rgb <= 0.04045, rgb/12.92, ((rgb+0.055)/1.055)**2.4)


def linear_to_srgb(rgb):
    return np.where(rgb <= 0.0031308, rgb*12.92, 1.055*np.maximum(rgb, 0)**(1/2.4)-0.055)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='透明逐帧目录；省略时只更新轻量播放契约')
    args = parser.parse_args()
    sites = json.loads((ROOT/'sites.json').read_text(encoding='utf-8'))['sites']
    manifest = {'version': 2, 'fps': FPS, 'keyframes': 6, 'interpolation': 'cubic-bspline-premultiplied', 'runtime_clock': 'continuous', 'frame_size': [512, 256],
                'anchor': [256, 190], 'clips': {},
                '说明': '六张生成原画的预乘三次B样条插值，非独立生成原画；运行连续时间，导出按60fps采样，节点不重复减速归零。动作后透明休止。'}
    arrays = [np.asarray(Image.open(ROOT/f'frame-{i+1:02}.png').convert('RGBA'), dtype=np.float32)/255 for i in range(6)]
    colors = [srgb_to_linear(a[:, :, :3])*a[:, :, 3:] for a in arrays]
    for site in sites:
        duration = float(site['active_duration'])
        count = round(duration*FPS)
        assert abs(count/FPS-duration) < 1e-8
        frames = [sample(i/FPS, duration) for i in range(count)]
        clip = {'frame_count': count, 'duration_seconds': duration,
                'cycle_seconds': site['cycle'], 'phase_offset_seconds': site['phase_offset'],
                'rest_frames': round((site['cycle']-duration)*FPS), 'frames': frames}
        manifest['clips'][site['id']] = clip
        if args.output is None:
            continue
        directory = args.output/site['id']
        directory.mkdir(parents=True, exist_ok=True)
        hashes = []
        for i, entry in enumerate(frames):
            alpha = sum(arrays[k][:, :, 3:]*w for k, w in zip(entry['source_frames'], entry['weights']))
            premult = sum(colors[k]*w for k, w in zip(entry['source_frames'], entry['weights']))
            rgb = linear_to_srgb(premult/np.maximum(alpha, 0.001)*1.15)
            # 与GL材质一致；样点强度和水侧裁切留给场景，不烘焙岸石。
            alpha = np.clip(alpha*1.8, 0, 1)*entry['envelope']
            output = np.clip(np.dstack((rgb, alpha))*255, 0, 255).round().astype(np.uint8)
            output[output[:, :, 3] == 0, :3] = 0
            assert not output[:3, :, 3].any() and not output[-3:, :, 3].any()
            assert not output[:, :3, 3].any() and not output[:, -3:, 3].any()
            image = Image.fromarray(output)
            image.save(directory/f'{i:03}.png')
            hashes.append(hashlib.sha256(output.tobytes()).hexdigest())
        assert len(set(hashes)) == count, f'{site["id"]}存在重复帧'
        clip['export_unique_frames'] = len(set(hashes))
    (ROOT/'playback-60fps.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    if args.output is not None:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output/'playback-60fps.json').write_bytes((ROOT/'playback-60fps.json').read_bytes())
        with zipfile.ZipFile(args.output.parent/'shore-splash-60fps.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(args.output.rglob('*')):
                if path.is_file():
                    bundle.write(path, str(path.relative_to(args.output)))
            for name in ['README.md', 'sites.json', 'export_60fps.py', 'manifest.json']:
                bundle.write(ROOT/name, name)
        with zipfile.ZipFile(args.output.parent/'shore-splash-60fps.zip') as bundle:
            assert bundle.testzip() is None
    print(json.dumps({key: value['frame_count'] for key, value in manifest['clips'].items()}, ensure_ascii=False))


if __name__ == '__main__':
    main()
