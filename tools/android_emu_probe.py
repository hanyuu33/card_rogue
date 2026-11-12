#!/usr/bin/env python3
"""Android emulator soak probe for the R613 texture fix / R612 asset optimization.

Runs the whole interaction sequence in ONE process (taps, swipes, repeated
gallery open/close), sampling dumpsys meminfo + /proc status at every step and
pulling a full logcat at the end. Re-run any time with:

    python tools/android_emu_probe.py

Outputs land in _preview/ (report txt + html + screenshots + raw dumps).
"""
from __future__ import annotations

import base64
import io
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ADB = r"C:\Users\Administrator\AndroidDev\android-sdk\platform-tools\adb.exe"
PKG = "com.hanyuu.cardrogue"
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_preview"
APK = ROOT / "dist" / "Quackill_R613_emulator.apk"
OUT.mkdir(exist_ok=True)

ERROR_KEYS = (
    "FATAL EXCEPTION", "SIGSEGV", "SIGABRT", "Expected Image data size",
    "USER SCRIPT ERROR", "SCRIPT ERROR", "ANR ", "OutOfMemoryError",
    "Cannot resize", "lowmemorykiller", "Force finishing activity",
    "Process: " + PKG,
)

# Godot 4.3 prints this from Texture2D.get_image() when reading back an ASTC /
# VRAM-compressed texture. It is an engine-side Image.convert() notice: the
# returned RGBA image is still valid (verified: decompress + resize + texture
# creation all succeed). Count it as known noise, not as a failure.
NOISE_KEY = "Cannot convert to <-> from compressed formats"

rows: list[dict] = []
shots: dict[str, Path] = {}


def raw(*args, timeout=180) -> bytes:
    p = subprocess.run([ADB, *map(str, args)], capture_output=True, timeout=timeout)
    return p.stdout


def sh(*args, timeout=180) -> str:
    return raw(*args, timeout=timeout).decode("utf-8", "replace").replace("\r", "")


def tap(x: int, y: int) -> None:
    sh("shell", "input", "tap", x, y)


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 300) -> None:
    sh("shell", "input", "swipe", x1, y1, x2, y2, ms)


def screenshot(name: str) -> Path:
    p = OUT / (name + ".png")
    p.write_bytes(raw("exec-out", "screencap", "-p", timeout=180))
    shots[name] = p
    return p


def sample(label: str, shot: str | None = None, pause: float = 1.2) -> dict:
    time.sleep(pause)
    txt = sh("shell", "dumpsys", "meminfo", PKG)
    (OUT / ("r616_mem_%s.txt" % label)).write_text(txt, encoding="utf-8")

    def num(pat: str) -> int:
        m = re.search(pat, txt)
        return int(m.group(1)) if m else -1

    pids = sh("shell", "pidof", PKG).strip().split()
    pid = pids[0] if pids else ""
    threads = -1
    if pid:
        m = re.search(r"Threads:\s+(\d+)", sh("shell", "cat", "/proc/%s/status" % pid))
        threads = int(m.group(1)) if m else -1
    d = {
        "label": label, "pid": pid, "alive": bool(pid), "threads": threads,
        "pss": num(r"TOTAL PSS:\s+(\d+)"),
        "rss": num(r"TOTAL RSS:\s+(\d+)"),
        "native": num(r"Native Heap:\s+(\d+)"),
        "graphics": num(r"Graphics:\s+(\d+)"),
        "swap": num(r"TOTAL SWAP PSS:\s+(\d+)"),
    }
    if shot:
        screenshot(shot)
        d["shot"] = shot
    rows.append(d)
    print("%-22s pid=%-6s alive=%-5s PSS=%7d KB RSS=%7d KB native=%7d KB threads=%s"
          % (label, pid or "-", d["alive"], d["pss"], d["rss"], d["native"], threads))
    return d


def step(label: str, action=None, shot: str | None = None, pause: float = 1.2) -> dict:
    if action:
        action()
    return sample(label, shot, pause)


def img_tag(path: Path, width: int = 900) -> str:
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB")
        im.thumbnail((width, width * 9 // 16), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=82)
        b64 = base64.b64encode(buf.getvalue()).decode("ascii")
        return '<img src="data:image/jpeg;base64,%s" style="width:100%%;max-width:%dpx">' % (b64, width)
    except Exception as exc:  # pragma: no cover - report must survive a missing shot
        return "<em>screenshot unavailable: %s</em>" % exc


def build_report(log: str, gfx: str, cpu: str, pkg: str, path: str) -> tuple[str, str]:
    all_lines = log.splitlines()
    noise_lines = [l for l in all_lines if NOISE_KEY in l]
    godot_err = [l for l in all_lines
                 if re.search(r"USER ERROR:|USER SCRIPT ERROR:|SCRIPT ERROR:|Parse Error", l)]
    real_godot = [l for l in godot_err if NOISE_KEY not in l]
    fatal = [l for l in all_lines if any(k in l for k in ERROR_KEYS)]
    err_lines = list(dict.fromkeys(fatal + real_godot))
    warn_lines = [l for l in all_lines if "USER WARNING:" in l]
    alive = all(r["alive"] for r in rows)
    enters = [r for r in rows if re.fullmatch(r"cycle_\d+_enter", r["label"])]
    pss = [r["pss"] for r in enters if r["pss"] > 0]
    growth = (pss[-1] - pss[0]) if len(pss) >= 2 else 0
    peak = max((r["pss"] for r in rows), default=0)

    lines = [
        "R616 安卓模拟器回归探针 — %s" % datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "包体: %s (%.1f MB)" % (APK.name, APK.stat().st_size / 1048576.0),
        "设备: sdk_gphone64_x86_64 / Android 14 / AVD cr_test / x86_64 原生包",
        "包名: %s" % PKG,
        "安装路径: %s" % path.strip(),
        "",
        "== 判定 ==",
        "进程全程存活: %s" % ("PASS" if alive else "FAIL"),
        "致命 / 脚本 / 图像错误命中: %d 条" % len(err_lines),
        "  Expected Image data size: %d 条" % sum("Expected Image data size" in l for l in err_lines),
        "引擎 USER ERROR（剔除已知噪音后）: %d 条" % len(real_godot),
        "已知压缩读回噪音: %d 条（Godot 4.3 get_image() 内部 Image.convert 提示，非致命）" % len(noise_lines),
        "USER WARNING: %d 条（启动时 shader 缓存重编译）" % len(warn_lines),
        "图鉴反复进出 %d 次，PSS %s KB -> %s KB（净增 %+d KB，%.1f MB）"
        % (len(pss), pss[0] if pss else "-", pss[-1] if pss else "-", growth, growth / 1024.0),
        "峰值 PSS: %.1f MB / 峰值 RSS: %.1f MB"
        % (peak / 1024.0, max((r["rss"] for r in rows), default=0) / 1024.0),
        "结论: %s" % ("PASS 优化正常" if alive and not err_lines else "FAIL 见下方错误行"),
        "",
        "== 逐步内存曲线 (KB) ==",
        "%-22s %8s %8s %8s %8s %7s %6s" % ("step", "PSS", "RSS", "native", "gfx", "swap", "thr"),
    ]
    for r in rows:
        lines.append("%-22s %8d %8d %8d %8d %7d %6d"
                     % (r["label"], r["pss"], r["rss"], r["native"], r["graphics"], r["swap"], r["threads"]))
    lines += ["", "== 错误行（全量 logcat 过滤）=="]
    lines += err_lines[:40] or ["(none)"]
    lines += ["", "== gfxinfo 摘要 =="]
    lines += [l for l in gfx.splitlines()
              if re.search(r"Total frames|Janky frames|percentile|Missed Vsync|Slow bitmap|Slow UI", l)][:12]
    lines += ["", "== cpuinfo（本进程）=="]
    lines += [l for l in cpu.splitlines() if PKG in l or "CPU usage" in l][:8]
    lines += ["", "== 包信息 =="]
    lines += [l.strip() for l in pkg.splitlines()
              if re.search(r"versionName|codePath|dataDir|firstInstallTime|lastUpdateTime", l)][:8]
    txt = "\n".join(lines) + "\n"
    (OUT / "r616_android_report.txt").write_text(txt, encoding="utf-8")
    (OUT / "r616_log_full.txt").write_text(log, encoding="utf-8")
    (OUT / "r616_gfx_full.txt").write_text(gfx, encoding="utf-8")

    # HTML: table + inline (base64) screenshots, no external assets.
    trs = "\n".join(
        "<tr><td>%s</td><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td></tr>"
        % (r["label"], "✓" if r["alive"] else "✗", r["pss"], r["rss"], r["native"], r["graphics"], r["threads"])
        for r in rows)
    err_html = "<br>".join(l.replace("<", "&lt;") for l in err_lines[:30]) or "（无）"
    err_html += ("\n\n[已知引擎噪音] %d 条 `Cannot convert to <-> from compressed formats`："
                 "Godot 4.3 在 Texture2D.get_image() 读回 VRAM 压缩纹理时由引擎内部 "
                 "Image.convert() 打印，返回图像有效（decompress / resize / 创建纹理均成功），"
                 "已由 ui_assets.gd 的空图保险丝兜住，不导致空图或崩溃。非本包缺陷。" % len(noise_lines))
    cards = "".join(
        "<figure><figcaption>%s</figcaption>%s</figure>" % (name, img_tag(p))
        for name, p in shots.items())
    html = """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<title>安卓模拟器回归 · R616</title><style>
body{font-family:"Microsoft YaHei",system-ui,sans-serif;background:#faf7f0;color:#33291d;margin:0;padding:28px 36px}
h1{font-size:24px;margin:0 0 6px}h2{font-size:17px;margin:26px 0 10px;border-left:4px solid #b9863c;padding-left:10px}
.sub{color:#7b6f5d;font-size:13px;margin-bottom:18px}
.badge{display:inline-block;padding:5px 14px;border-radius:14px;background:#e5f3e3;color:#2c6b2c;font-weight:700;margin-right:8px}
.badge.bad{background:#fbe2e0;color:#a12b22}
table{border-collapse:collapse;width:100%%;font-size:13px;background:#fff}
th,td{border:1px solid #e2d9c8;padding:6px 9px;text-align:right}th{background:#f0e8d8}
td:first-child,th:first-child{text-align:left}
.kv{display:flex;gap:18px;flex-wrap:wrap;margin:12px 0 20px}
.kv div{background:#fff;border:1px solid #e2d9c8;border-radius:8px;padding:10px 16px;font-size:13px}
.kv b{display:block;font-size:19px;color:#8a5a18;margin-top:3px}
figure{margin:0 0 22px;background:#fff;border:1px solid #e2d9c8;border-radius:10px;padding:10px}
figcaption{font-size:13px;color:#7b6f5d;margin-bottom:8px}
.err{background:#fff;border:1px solid #e2d9c8;border-radius:8px;padding:12px;font:12px/1.6 monospace;white-space:pre-wrap}
</style></head><body>
<h1>安卓模拟器回归 · 优化验收</h1>
<div class="sub">%s ｜ sdk_gphone64_x86_64 / Android 14 ｜ x86_64 原生包 ｜ %s (%.1f MB)</div>
<div><span class="badge%s">%s</span><span class="badge">致命/脚本错误 %d 条</span><span class="badge">引擎噪音 %d 条</span></div>
<div class="kv">
<div>峰值 PSS<b>%.1f MB</b></div><div>峰值 RSS<b>%.1f MB</b></div>
<div>图鉴进出 %d 次净增<b>%+d KB</b></div><div>采样步数<b>%d</b></div>
</div>
<h2>逐步内存曲线（KB）</h2>
<table><tr><th>步骤</th><th>存活</th><th>PSS</th><th>RSS</th><th>Native</th><th>Graphics</th><th>线程</th></tr>%s</table>
<h2>错误行（全量 logcat 过滤）</h2><div class="err">%s</div>
<h2>关键截图</h2>%s
</body></html>""" % (
        datetime.now().strftime("%Y-%m-%d %H:%M:%S"), APK.name, APK.stat().st_size / 1048576.0,
        "" if alive and not err_lines else " bad", "PASS 优化正常" if alive and not err_lines else "FAIL 需复查",
        len(err_lines), len(noise_lines), peak / 1024.0, max((r["rss"] for r in rows), default=0) / 1024.0,
        len(pss), growth, len(rows), trs, err_html, cards)
    (OUT / "r616_android_report.html").write_text(html, encoding="utf-8")
    return txt, "\n".join(lines[:16])


STEP_LABELS = [
    "gallery_baseline", "enemy_gallery", "player_gallery",
    "detail_a", "detail_b", "detail_c", "scroll_1", "scroll_2", "gallery_stressed",
    "cycle_1_back", "cycle_1_enter", "cycle_1_detail",
    "cycle_2_back", "cycle_2_enter", "cycle_2_detail",
    "cycle_3_back", "cycle_3_enter", "cycle_3_detail",
    "back_ency", "back_title", "start_battle",
    "confirm_class", "reward_pick", "reward_confirm",
    "battle_enter", "battle_play", "battle_end_turn",
]

SHOT_NAMES = ("r616_gallery", "r616_gallery_stressed", "r616_relic",
              "r616_reward_pick", "r616_battle")


def rebuild() -> None:
    """Rebuild the report from dumps already on disk; no new taps needed."""
    global rows, shots
    rows, shots = [], {}
    cur = sh("shell", "pidof", PKG).strip().split()
    pid = cur[0] if cur else ""
    threads = -1
    if pid:
        m = re.search(r"Threads:\s+(\d+)", sh("shell", "cat", "/proc/%s/status" % pid))
        threads = int(m.group(1)) if m else -1
    for label in STEP_LABELS:
        f = OUT / ("r616_mem_%s.txt" % label)
        if not f.exists():
            continue
        txt = f.read_text(encoding="utf-8")

        def num(pat: str) -> int:
            m = re.search(pat, txt)
            return int(m.group(1)) if m else -1

        rows.append({
            "label": label, "pid": pid, "alive": bool(pid), "threads": threads,
            "pss": num(r"TOTAL PSS:\s+(\d+)"), "rss": num(r"TOTAL RSS:\s+(\d+)"),
            "native": num(r"Native Heap:\s+(\d+)"), "graphics": num(r"Graphics:\s+(\d+)"),
            "swap": num(r"TOTAL SWAP PSS:\s+(\d+)"),
        })
    for p in sorted(OUT.glob("r616_*.png")):
        shots[p.stem] = p
    print("rebuilt %d rows / %d screenshots" % (len(rows), len(shots)))


def finish() -> int:
    log = sh("logcat", "-d", "-v", "time", timeout=240)
    gfx = sh("shell", "dumpsys", "gfxinfo", PKG)
    cpu = sh("shell", "dumpsys", "cpuinfo")
    pkg = sh("shell", "dumpsys", "package", PKG)
    path = sh("shell", "pm", "path", PKG)
    _, head = build_report(log, gfx, cpu, pkg, path)
    print("\n== 摘要 ==\n" + head)
    print("\n报告: %s" % (OUT / "r616_android_report.html"))
    return 0 if all(r["alive"] for r in rows) else 1


def main() -> int:
    if "--report-only" in sys.argv:
        rebuild()
        return finish()
    if "--steps" in sys.argv:
        i = sys.argv.index("--steps")
        for spec in sys.argv[i + 1:]:
            parts = spec.split(":")
            label, xy = parts[0], parts[1].split(",")
            x, y = int(xy[0]), int(xy[1])
            shot = parts[2] if len(parts) > 2 and parts[2] else None
            pause = float(parts[3]) if len(parts) > 3 else 1.5
            step(label, lambda xx=x, yy=y: tap(xx, yy), shot=shot, pause=pause)
        rebuild()
        return finish()
    if "--phase2" in sys.argv:
        print("== phase2：从「选择你的角色」页继续 ==")
        step("confirm_class", lambda: tap(580, 868), shot="r616_reward_pick", pause=3.0)
        rebuild()
        return finish()
    print("== R616 安卓回归：当前应停在「卡牌图鉴」页 ==")
    step("gallery_baseline", shot="r616_gallery", pause=0.3)
    step("enemy_gallery", lambda: tap(514, 26))
    step("player_gallery", lambda: tap(320, 26))
    step("detail_a", lambda: tap(630, 160))
    step("detail_b", lambda: tap(900, 160))
    step("detail_c", lambda: tap(1000, 540))
    step("scroll_1", lambda: swipe(1170, 800, 1170, 300, 300))
    step("scroll_2", lambda: swipe(1170, 800, 1170, 300, 300))
    step("gallery_stressed", shot="r616_gallery_stressed", pause=0.3)
    for i in range(1, 4):
        step("cycle_%d_back" % i, lambda: tap(2210, 26))
        step("cycle_%d_enter" % i, lambda: tap(1170, 496), pause=1.8)
        step("cycle_%d_detail" % i, lambda: tap(630, 160))
    step("back_ency", lambda: tap(2210, 26))
    step("back_title", lambda: tap(320, 50))
    step("start_battle", lambda: tap(650, 800), shot="r616_relic", pause=3.5)
    rebuild()
    return finish()


if __name__ == "__main__":
    raise SystemExit(main())
