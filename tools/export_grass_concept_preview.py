"""导出已有生成素材的草簇历史样片；昆虫方案已取消，不再叠合。"""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageSequence
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "design/art/concepts/grass-redesign-2026-10-26"
GEN = Path("C:/Users/y1971/.codex/generated_images/01a176f1-6b84-7492-923a-d75973af9a54")
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save_json(p, obj): p.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")

# 对草叶缝隙残留的洋红溢色做确定性色键净化；只改RGB，透明度和形状保持。
spill_counts=[]
clean_wind=[]
for i in range(1,7):
    path=OUT/f"wind/idle-{i}.png"
    pixels=np.array(Image.open(path).convert("RGBA"))
    rgb=pixels[:,:,:3].astype(float)
    spill=(rgb[:,:,0]>rgb[:,:,1]*1.3)&(rgb[:,:,2]>rgb[:,:,1]*1.3)&(rgb[:,:,0]>35)&(pixels[:,:,3]>0)
    spill_counts.append(int(spill.sum()))
    pixels[:,:,0][spill]=pixels[:,:,1][spill]
    cleaned=Image.fromarray(pixels)
    cleaned.save(path)
    clean_wind.append(cleaned)
sheet=Image.new("RGBA",(1152,768))
for i,im in enumerate(clean_wind): sheet.paste(im,((i%3)*384,(i//3)*384))
sheet.save(OUT/"wind/sheet-transparent.png")
clean_wind[0].save(OUT/"wind/animation.gif",save_all=True,append_images=clean_wind[1:],duration=200,loop=0,disposal=2)

# 所有创作像素来自内置图像生成；这里只做缩放、透明叠合与GIF导出。
ground = Image.open(OUT/"detail-native.png").convert("RGBA")
scale = 1.6 * (1280/960)
size = (round(384*scale), round(288*scale))
background = ground.resize(size, Image.Resampling.LANCZOS)
background.save(OUT/"detail-max-zoom-1280.png")
wind = [Image.open(OUT/f"wind/idle-{i}.png").convert("RGBA") for i in range(1,7)]
# 固定示例摆位，与实际地图导航或碰撞无关。世界坐标/画布边长/周期数/相位。
clumps = [(44,52,24,2,.15),(138,43,21,3,.62),(301,60,27,2,.82),
          (83,153,23,3,.34),(265,184,26,4,.71),(331,247,22,2,.48),(165,254,24,3,.09)]
frames=[]
for k in range(72):
    t=k/10
    frame=background.copy()
    for x,y,s,cycles,phase in clumps:
        index=int(((t/7.2*cycles+phase)%1)*6)
        sprite=wind[index].resize((round(s*scale),round(s*scale)),Image.Resampling.LANCZOS)
        frame.alpha_composite(sprite,(round((x-s*.5)*scale),round((y-s*361/384)*scale)))
    frames.append(frame.convert("RGB"))
# 统一调色板减少GIF逐帧调色引起的闪烁，PNG保留真彩。
palette=frames[18].quantize(colors=256)
indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
indexed[0].save(OUT/"scene-motion-preview.gif",save_all=True,append_images=indexed[1:],duration=100,loop=0,optimize=False,disposal=1)
frames[18].save(OUT/"scene-motion-still.png")
sources=[
("overall-v1.png","exec-1c1a3981-5204-48d1-b2e8-992d396e38bd.png","overall-prompt.txt",["assets/map/dawn_wide_v3/layered-preview.png"],"首稿，草团偏大，保留对照"),
("overall-v2.png","exec-9f62a0de-0418-4946-9e1e-1f93992a4a72.png","overall-v2-prompt.txt",["design/art/concepts/grass-redesign-2026-10-26/overall-v1.png"],"整体样式候选，非运行底图"),
("detail-native.png","exec-18370e6b-b80e-44c9-b639-0ddbcee1cead.png","detail-prompt.txt",["assets/map/dawn_wide_v3/layered-preview.png","tests/reports/images/town-hall-base-rear-left-2026-10-26/1280x720-close.png"],"近景细节候选，非无缝地砖"),
("wind/generated-source.png","exec-8d3838bb-74fb-49bf-992a-934af9e3ccf9.png","wind-prompt.txt",["tests/reports/images/town-hall-base-rear-left-2026-10-26/1280x720-close.png"],"稀疏长草点缀风动样片；raw-sheet为处理器重编码RGBA副本"),
("beetle/generated-source.png","exec-3a410b8f-9bdc-4e0c-a66f-fc628de9f128.png","beetle-prompt.txt",["tests/reports/images/town-hall-base-rear-left-2026-10-26/1280x720-close.png"],"单种步甲六帧爬行样片；raw-sheet为处理器重编码RGBA副本")]
records=[]
for file,original,prompt,refs,note in sources:
    p=OUT/file
    with Image.open(p) as im: dims=list(im.size)
    # 外部生成缓存仅用于本机原始文件复核；仓库内保留完整原稿，换机器仍可导出。
    if (GEN/original).exists():
        assert sha(p)==sha(GEN/original), file
    records.append(dict(image=file,source=str(GEN/original),size=dims,sha256=sha(p),prompt=prompt,notes=note,
                        references=[dict(path=r,sha256=sha(ROOT/r)) for r in refs]))
checks={}
for name in ["wind","beetle"]:
    assert np.array_equal(np.asarray(Image.open(OUT/name/"generated-source.png").convert("RGBA")),
                          np.asarray(Image.open(OUT/name/"raw-sheet.png").convert("RGBA")))
    meta=json.loads((OUT/name/"pipeline-meta.json").read_text())
    checks[name]=meta["qc_summary"]
    for key in ["edge_touch_frames","empty_frames","paste_clamped_frames"]: assert not meta[key]
    assert len(meta["frames"])==6
    # 按生成身份变化的动画检查无空帧、完整边界及相同缩放；不将QC当作最终美术接受。
    assert len(set(round(f["source_to_output_scale"],8) for f in meta["frames"]))==1
    with Image.open(OUT/name/"animation.gif") as im:
        assert im.n_frames==6
    for label in meta["frame_labels"]:
        im=Image.open(OUT/name/(label+".png"))
        a=np.asarray(im)
        assert im.mode=="RGBA" and im.size==(384,384)
        assert a[0,:,3].max()==a[-1,:,3].max()==a[:,0,3].max()==a[:,-1,3].max()==0
with Image.open(OUT/"scene-motion-preview.gif") as im:
    # GIF编码器合并连续相同帧，应验证播放总时长和解码后的时间轴。
    assert 1 < im.n_frames <= 72 and im.size==size
    encoded_frame_count=im.n_frames
    cursor=0
    for decoded in ImageSequence.Iterator(im):
        ticks=decoded.info.get("duration",0)//100
        for i in range(cursor,cursor+ticks):
            assert np.array_equal(np.asarray(decoded.convert("RGB")),np.asarray(indexed[i].convert("RGB")))
        cursor+=ticks
    assert cursor==72
    duration=sum(f.info.get("duration",0) for f in ImageSequence.Iterator(im))
    assert duration==7200
density=ground.width/384
save_json(OUT/"generation-record.json",dict(date="2026-10-26",verified_date="2026-10-27",generator="内置 image_gen",
    status="static-detail-integrated-animation-historical",integrated=True,sources=records,
    runtime_material="assets/map/grass_hd_v1/material-record.json",
    detail=dict(native_size=list(ground.size),world_coverage=[384,288],texels_per_world_pixel=density,
                camera_zoom=1.6,window=[1280,720],logical_viewport=[960,540],
                physical_pixels_per_source_pixel=scale/density,
                note="此为历史离线样区预算；正式静态接入覆盖216×162，参见runtime_material"),
    animation=dict(wind_frames=6,beetle_frames=0,archived_beetle_frames=6,sample_gif_seconds=7.2,encoded_frame_count=encoded_frame_count,instance_count=dict(wind=7,beetle_max=0),
        note="昆虫取消，原稿仅留溯源；此GIF仅保留历史草簇演示，不是新全图风方案；游戏先静态接入"),
    postprocess=dict(wind_despill="可见像素R>1.3G且B>1.3G且R>35时R置为G；不改alpha；幂等"),
    qc=checks))
outputs={}
for p in sorted(OUT.rglob("*")):
    if p.suffix.lower() in [".png",".gif"]:
        with Image.open(p) as im:
            im.verify()
        outputs[p.relative_to(OUT).as_posix()]=sha(p)
save_json(OUT/"artifact-checks.json",dict(date="2026-10-27",result="通过",
    image_count=len(outputs),outputs=outputs,
    checks=["5张原稿归档，外部缓存存在时校验SHA256","2张处理器RGBA原稿与生成RGB像素等价","12帧RGBA透明边界","两套6帧严格QC","共享缩放无逐帧归一化",
            "72个采样时刻/7.2秒场景GIF解码与源帧逐像素相符","原生像素与最大倍率算式"],
    not_verified=["此工具不验证Godot，运行证据见静态草地QA","最终美术接受","全图风动尚未实现"] ))
print(json.dumps(dict(result="通过",images=len(outputs),scene_size=size,density=density,qc=checks),ensure_ascii=False))

