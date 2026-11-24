# -*- coding: utf-8 -*-
"""评估 AI 动画素材压进游戏内的体积代价（一次性测量脚本）。

对同一条素材跑多种编码方案，输出体积/画质对照表。
只读素材、只写 release/trailer/probe/anim_eval/，不动工程资源。

python tools/_eval_anim_compress.py
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CG = ROOT / "release" / "trailer" / "raw" / "cg"
WORK = ROOT / "release" / "trailer" / "probe" / "anim_eval"
FFBIN = Path("C:/Users/Administrator/AppData/Local/Microsoft/WinGet/Packages/"
             "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/"
             "ffmpeg-9.0.2-full_build/bin")
FF = str(FFBIN / "ffmpeg.exe")

ALL = [
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-44-45.mp4", "knight"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-47-11.mp4", "archer"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-37-06.mp4", "rogue"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-49-29.mp4", "mech"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-59-51.mp4", "forest"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T12-02-25.mp4", "bard"),
    ("ref", "2D_anime_cel_shaded_animation__2026-11-17T11-12-47.mp4", "wind"),
]


def sh(args):
    p = subprocess.run([FF, "-y", "-hide_banner", "-loglevel", "error"] + args,
                       capture_output=True, text=True, encoding="utf-8",
                       errors="replace")
    if p.returncode != 0:
        print("[fail]", " ".join(args)[:120])
        print((p.stderr or "")[-600:])
        return False
    return True


def mb(p):
    return p.stat().st_size / 1048576.0 if p.exists() else 0.0


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    sub, fname, tag = ALL[0]
    src = CG / sub / fname
    print("source: %.2f MB  1344x768  5.17s\n" % mb(src))

    rows = []

    # A. Ogg Theora（Godot 4 原生唯一可直接播放的格式）
    for w, h, q, label in [(1280, 720, 7, "theora 720p q7"),
                           (960, 540, 6, "theora 540p q6"),
                           (640, 360, 5, "theora 360p q5")]:
        dst = WORK / ("knight_%dp.ogv" % h)
        ok = sh(["-i", str(src), "-vf", "scale=%d:%d,fps=24" % (w, h),
                 "-c:v", "libtheora", "-q:v", str(q), "-an", str(dst)])
        if ok:
            rows.append((label, "%.2f MB" % mb(dst), "%.0f KB/s" % (mb(dst) * 1024 / 5.17)))

    # B. VP9 WebM（体积基准；Godot 4.3 需第三方插件才能播）
    for h, crf in [(720, 36), (360, 36)]:
        dst = WORK / ("knight_vp9_%dp.webm" % h)
        ok = sh(["-i", str(src), "-vf", "scale=-2:%d,fps=24" % h,
                 "-c:v", "libvpx-vp9", "-crf", str(crf), "-b:v", "0",
                 "-row-mt", "1", "-an", str(dst)])
        if ok:
            rows.append(("vp9 %dp crf%d" % (h, crf), "%.2f MB" % mb(dst), "%.0f KB/s" % (mb(dst) * 1024 / 5.17)))

    # C. WebP 序列帧（Godot 原生导入，可做 AtlasTexture / SpriteFrames）
    for w, h, fps in [(640, 360, 12), (640, 360, 8), (480, 270, 12)]:
        d = WORK / ("seq_%dx%d_%dfps" % (w, h, fps))
        if d.exists():
            for f in d.glob("*.webp"):
                f.unlink()
        d.mkdir(exist_ok=True)
        ok = sh(["-i", str(src), "-vf", "scale=%d:%d,fps=%d" % (w, h, fps),
                 "-c:v", "libwebp", "-quality", "78", "-an",
                 str(d / "f%03d.webp")])
        if ok:
            files = sorted(d.glob("*.webp"))
            total = sum(f.stat().st_size for f in files) / 1048576.0
            rows.append(("webp seq %dx%d@%d (%d帧)" % (w, h, fps, len(files)),
                         "%.2f MB" % total, "%.0f KB/帧" % (total * 1024 / max(1, len(files)))))

    print("%-30s %10s %12s" % ("方案", "5.17s 体积", "码率/单帧"))
    print("-" * 56)
    for r in rows:
        print("%-30s %10s %12s" % r)

    # D. 七段全部按 360p@12fps 序列帧估算
    print("\n=== 七段总重（640x360@12fps WebP q78）===")
    total_all = 0.0
    for sub, fname, tag in ALL:
        src = CG / sub / fname
        d = WORK / ("all_%s" % tag)
        d.mkdir(exist_ok=True)
        for f in d.glob("*.webp"):
            f.unlink()
        ok = sh(["-i", str(src), "-vf", "scale=640:360,fps=12",
                 "-c:v", "libwebp", "-quality", "78", "-an",
                 str(d / "f%03d.webp")])
        if not ok:
            continue
        files = sorted(d.glob("*.webp"))
        t = sum(f.stat().st_size for f in files) / 1048576.0
        total_all += t
        print("  %-8s %2d帧  %.2f MB" % (tag, len(files), t))
    print("  合计 %.2f MB  （等长 Theora 360p 约 %.1f MB）" % (total_all, total_all * 0.75))


if __name__ == "__main__":
    main()
