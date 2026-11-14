# -*- coding: utf-8 -*-
"""R670 战斗特效补全：codex 黑底图 → 透明 RGBA 贴图 + 增量验收页。

沿用 R628 / R669 的「亮度当 alpha、色相归一化」：发光特效的边缘全是柔和辉光，
白底 flood-fill 会把光雾啃掉，所以必须黑底出图。

成品落 `assets/fx/bx_<key>.png`（bx = battle effect），由 `FxArt` 取用。

用法：
    python _finish_fx.py            # 处理 raw/ 下**已存在**的所有图，落 assets/fx/
    python _finish_fx.py vortex     # 只处理指定 key
"""
import base64
import os
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-13_战斗特效补全_R670"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
FX = ROOT / "assets" / "fx"

JOBS = ["vortex", "air_raid", "blast", "gale", "stun",
        "skill_fire", "skill_ice", "skill_shadow", "skill_holy", "skill_nature"]
# 统一 256×256：棋盘格 102×90，素材按 150~190px 绘制，缩到这个尺寸足够
SIZE = (256, 256)


def load_names():
    p = D / "names.tsv"
    if not p.exists():
        return {}
    out = {}
    for line in p.read_text(encoding="utf-8").splitlines():
        if "\t" in line:
            k, v = line.split("\t", 1)
            out[k.strip()] = v.strip()
    return out


NAMES = load_names()


def black_to_alpha(path: Path) -> Image.Image:
    """黑底发光图 → 直通 alpha：亮度当不透明度，色相归一化保饱和。"""
    im = Image.open(path).convert("RGB")
    out = []
    for r, g, b in im.getdata():
        mx = max(r, g, b)
        if mx < 10:  # 黑底边缘的压缩噪点，不刨掉会撑到全画布
            out.append((0, 0, 0, 0))
            continue
        k = 255.0 / mx
        out.append((min(255, int(r * k)), min(255, int(g * k)),
                    min(255, int(b * k)), int(255.0 * ((mx / 255.0) ** 0.85))))
    dst = Image.new("RGBA", im.size)
    dst.putdata(out)
    return dst


def trim(im: Image.Image, pad: int = 6) -> Image.Image:
    bb = im.getbbox()
    if bb is None:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - pad), max(0, y0 - pad),
                    min(im.width, x1 + pad), min(im.height, y1 + pad)))


def fit(im: Image.Image, w: int, h: int) -> Image.Image:
    """等比缩进 w×h 的透明画布（不拉伸，圆形爆点不能被压扁）。"""
    r = min(w / im.width, h / im.height)
    nw, nh = max(1, round(im.width * r)), max(1, round(im.height * r))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(im, ((w - nw) // 2, (h - nh) // 2))
    return canvas


HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>R670 战斗特效补全 · 增量验收</title>
<style>
body{margin:0;padding:26px;background:#f5f2ea;color:#2b2b33;font-family:"Microsoft YaHei",sans-serif}
.wrap{max-width:1180px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:15px;margin:22px 0 10px;color:#5a4a34;letter-spacing:.5px}
p{font-size:14px;line-height:1.8;color:#555;margin:0 0 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}
.card{background:#fff;border:1px solid #d8cdb6;border-radius:8px;padding:10px 8px 8px;text-align:center}
.chk{height:190px;margin:0 auto 8px;border-radius:6px;border:1px solid #cfc6b3;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#20242e}
.chk img{max-width:180px;max-height:180px}
.nm{font-size:13px;font-weight:700;color:#3b3226;line-height:1.4}
.id{font-size:11px;color:#8a8172;letter-spacing:.5px}
.warn{color:#b04a2f;font-size:11px;line-height:1.4;margin-top:4px}
.sum{font-size:13px;color:#6a5a40;margin:14px 0 0}
</style></head><body><div class="wrap">
<h1>R670 · 战斗特效补全（增量验收 __N__ / __TOTAL__）</h1>
<p>深底看发光贴图在战斗背景上的实际观感。这批是「P0 断链 + P1 技能通用 + P2 B 档」三档共用的素材底：<b>深底看亮度是否够、主体是否居中、有没有黑边残留</b>。落盘后由 <code>FxArt</code> 统一取用，缺图一律退回程序化光环，所以先落几张就能先接几张。</p>
__CARDS__
<p class="sum">已完成 __N__ 张 / 共 __TOTAL__ 张；待补：__MISS__</p>
</div></body></html>"""


def card_html(key: str, path: Path, note: str) -> str:
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    warn = '<div class="warn">⚠ %s</div>' % note if note else ""
    return ('<div class="card"><div class="chk"><img src="data:image/png;base64,__B64__"></div>'
            '<div class="nm">__NAME__</div><div class="id">__ID__</div>__WARN__</div>'
            .replace("__B64__", b64).replace("__NAME__", NAMES.get(key, key))
            .replace("__ID__", path.name).replace("__WARN__", warn))


def main() -> int:
    PROC.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    FX.mkdir(parents=True, exist_ok=True)
    keys = sys.argv[1:] or list(JOBS)
    done, miss, warns, cards = [], [], [], []
    for key in keys:
        if key not in JOBS:
            continue
        src = RAW / ("%s_codex.png" % key)
        if not src.exists():
            miss.append(key)
            continue
        im = fit(trim(black_to_alpha(src)), *SIZE)
        out_name = "bx_%s.png" % key
        dst = PROC / out_name
        im.save(dst, "PNG")
        im.save(FX / out_name, "PNG")
        alpha = im.split()[3]
        nz = sum(1 for v in alpha.tobytes() if v > 8)
        cov = 100.0 * nz / (im.width * im.height)
        note = "疑似黑底未去净（非透光 %.0f%%）" % cov if cov > 80 else ""
        if note:
            warns.append("%s %s" % (key, note))
        print("OK   %-13s raw %dx%d → 裁边 → %dx%d  非透光 %.1f%%  %d KB"
              % (key, *Image.open(src).size, *im.size, cov,
                 (FX / out_name).stat().st_size // 1024), flush=True)
        done.append(key)
        cards.append(card_html(key, dst, note))
    # 验收页按「当前已落盘的成品」动态拼，可反复重跑
    for key in JOBS:
        if key in done or key in miss:
            continue
        p = PROC / ("bx_%s.png" % key)
        if p.exists():
            cards.append(card_html(key, p, ""))
            done.append(key)
    html = (HTML.replace("__CARDS__", '<div class="grid">%s</div>' % "\n".join(cards)
                         if cards else "<p>还没有成品，等后台第一张落盘。</p>")
            .replace("__N__", str(len(done))).replace("__TOTAL__", str(len(JOBS)))
            .replace("__MISS__", ("%d 张" % len(miss)) if miss else "无"))
    (REVIEW / "r670_battle_fx.html").write_text(html, encoding="utf-8")
    print("done=%d miss=%d review=%s" % (len(done), len(miss),
                                         REVIEW / "r670_battle_fx.html"), flush=True)
    for w in warns:
        print("WARN", w, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
