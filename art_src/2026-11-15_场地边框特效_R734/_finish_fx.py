# -*- coding: utf-8 -*-
"""R734 场地边框特效：codex 黑底图 → 透明 RGBA 贴图 + 实机预演验收页。

与 R675 的差别（**环不能 trim + 等比 fit**）：
  R675 是中心爆点，裁边后等比塞进画布、留黑边无所谓。
  本批是**整格边框环**：环的外沿必须精确贴在贴图四边，内沿留空。
  所以走「按 alpha 外接框归一化」——取 alpha>阈值 的 bbox（= 环的外沿），
  crop 后**直接拉伸**到目标尺寸。这样环带厚度比例被归一，铺到格子 rect 时
  外沿刚好贴住格线，不会缩成中间一个小方框。

目标尺寸按格子实尺寸定（不是正方形）：
  · 格子 CELL_W 124 × CELL 110 → 环 496×440（4x）
  · 火墙一整行 3 格 372 × 110 → 条 1488×440（4x）
  正方形素材铺到 124×110 会被压扁 12.7%，环带左右变窄、上下变厚 —— 直接按
  真实比例出图就没这问题。

层级（店长 2026-11-15）：特效画在**单位卡之下**。验收页同时给「压卡上」「垫卡下」
两张预演，一眼能看出挡不挡卡面。

成品落 `assets/fx/fld_<id>.png`（fld = field）。

用法：
    python _finish_fx.py            # 处理 raw/ 下**已存在**的所有图
    python _finish_fx.py field_8028 # 只处理指定 key
"""
import base64
import io
import os
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-15_场地边框特效_R734"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
FX = ROOT / "assets" / "fx"

# key -> (输出名, 目标尺寸, 形态)
JOBS = {
    "field_8028": ("fld_8028.png", (496, 440), "ring"),
    "field_8036": ("fld_8036.png", (496, 440), "ring"),
    "field_8037": ("fld_8037.png", (496, 440), "ring"),
    "field_9186": ("fld_9186.png", (496, 440), "ring"),
    "field_8082": ("fld_8082.png", (496, 440), "ring"),
    "field_9224": ("fld_9224.png", (496, 440), "ring"),
    "firewall_9084": ("fld_firewall.png", (1488, 440), "banner"),
}
ORDER = list(JOBS)

# 预演用的实机素材（3 倍画：格子 372×330，卡 230×277）
CELL3 = (372, 330)
CARD3 = (230, 277)
BG_SRC = ROOT / "assets" / "ui" / "adventure_shared" / "battlefield_1.png"
CARD_SRC = ROOT / "assets" / "pics" / "1011.png"


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


def outer_bbox(im: Image.Image, thresh: int = 24) -> tuple:
    """环/条的外沿：按 alpha>thresh 的包围盒，忽略零星噪点。"""
    a = im.split()[3].point(lambda v: 255 if v > thresh else 0)
    bb = a.getbbox()
    return bb if bb else (0, 0, im.width, im.height)


def normalize(im: Image.Image, size: tuple) -> Image.Image:
    """外接框 → 精确拉伸到 size（**不**等比、**不**留黑边）。"""
    x0, y0, x1, y1 = outer_bbox(im)
    if x1 - x0 < 8 or y1 - y0 < 8:
        return Image.new("RGBA", size, (0, 0, 0, 0))
    return im.crop((x0, y0, x1, y1)).resize(size, Image.LANCZOS)


def ring_metrics(im: Image.Image) -> str:
    """量四边的环带覆盖率（各取外侧 22% 的带，数 alpha>24 的占比）。

    ⚠️ 别用「从中线连续往里扫」：水纹这类淡元素最外一两行 alpha 可能只有十几个，
    一遇到就停会把「上边明明在」量成 0。按面积占比才稳。
    """
    a = im.split()[3].load()
    w, h = im.size

    def fill(box):
        x0, y0, x1, y1 = box
        n = t = 0
        for y in range(y0, y1, 2):
            for x in range(x0, x1, 2):
                t += 1
                if a[x, y] > 24:
                    n += 1
        return 100.0 * n / max(1, t)

    bh, bw = int(h * 0.22), int(w * 0.22)
    edges = {
        "上": fill((0, 0, w, bh)), "下": fill((0, h - bh, w, h)),
        "左": fill((0, 0, bw, h)), "右": fill((w - bw, 0, w, h)),
    }
    weak = [k for k, v in edges.items() if v < 6.0]
    s = "环带覆盖 上%.0f%% 下%.0f%% 左%.0f%% 右%.0f%%" % (
        edges["上"], edges["下"], edges["左"], edges["右"])
    return s, weak


def composite(ring: Image.Image, under: bool) -> Image.Image:
    """实机预演。under=True 就是真实层级：背景 → 特效 → 卡（卡盖住中间的环）。"""
    bg = Image.open(BG_SRC).convert("RGB").resize(CELL3, Image.LANCZOS)
    fx = ring.resize(CELL3, Image.LANCZOS).convert("RGB")
    card = Image.open(CARD_SRC).convert("RGB").resize(CARD3, Image.LANCZOS)
    cx = (CELL3[0] - CARD3[0]) // 2
    cy = (CELL3[1] - CARD3[1]) // 2
    if under:
        base = ImageChops.add(bg, fx)
        base.paste(card, (cx, cy))
        return base
    base = bg.copy()
    base.paste(card, (cx, cy))
    return ImageChops.add(base, fx)


def b64(p: Path, max_w: int = 0, jpeg: bool = False) -> str:
    """内嵌图。预演转 JPEG（不透明，省 10 倍），成品 PNG 缩宽再嵌。

    不压的话 7 张 × 3 图的内嵌 HTML 会到 6.8MB，一次提交就把仓库喂胖。
    """
    im = Image.open(p)
    if max_w and im.width > max_w:
        im = im.copy()
        im.thumbnail((max_w, 10 ** 6), Image.LANCZOS)
    buf = io.BytesIO()
    if jpeg:
        im.convert("RGB").save(buf, "JPEG", quality=90)
    else:
        im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>R734 场地边框特效 · 增量验收</title>
<style>
body{margin:0;padding:26px;background:#12141a;color:#e6e2d8;font-family:"Microsoft YaHei",sans-serif}
.wrap{max-width:1240px;margin:0 auto}
h1{font-size:20px;margin:0 0 6px;color:#f2d9a0}
h2{font-size:15px;margin:26px 0 12px;color:#c9b489;letter-spacing:.5px}
p{font-size:13px;line-height:1.85;color:#a9a496;margin:0 0 14px}
p b{color:#ecd9b0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(430px,1fr));gap:16px}
.card{background:#1b1e26;border:1px solid #333a48;border-radius:10px;padding:12px}
.hd{font-size:14px;font-weight:700;color:#f0e6cf;margin-bottom:2px}
.id{font-size:11px;color:#7c828f;letter-spacing:.5px;margin-bottom:10px}
.row{display:flex;gap:10px;align-items:flex-start;flex-wrap:wrap}
.cell{position:relative;width:372px;height:330px;border-radius:4px;overflow:hidden;border:1px solid #40485a}
.cell img{width:100%;height:100%;display:block}
.tag{position:absolute;left:6px;top:6px;font-size:11px;background:rgba(0,0,0,.62);color:#ffd9a0;padding:2px 6px;border-radius:4px}
.raw{background:#08090c;border:1px solid #2a303c;border-radius:6px;padding:4px}
.raw img{display:block;width:180px;height:auto}
.meta{font-size:11px;color:#8d9099;margin-top:8px;line-height:1.6}
.warn{color:#ff9d6b;font-size:11px;margin-top:6px}
.sum{font-size:13px;color:#c9b489;margin:18px 0 0}
</style></head><body><div class="wrap">
<h1>R734 · 场地边框特效（增量验收 __N__ / __TOTAL__）</h1>
<p>左：<b>垫在卡下</b>（真实层级，店长定的）——看会不会被卡挡掉太多；中：<b>压在卡上</b>——看环本身完整形态；右：素材原图（深底看发光）。<br>
规格：环 496×440（格子 124×110 的 4 倍），火墙 1488×440（一整行 3 格）。六张场地的环带厚度、四角装饰保持同一套语汇，只换元素。<b>判定只看两件事：卡面有没有被压住 / 环有没有在四边断开。</b></p>
__CARDS__
<p class="sum">已完成 __N__ 张 / 共 __TOTAL__ 张；待补：__MISS__</p>
</div></body></html>"""


def card_html(key, under_img, over_img, raw_img, note):
    meta, warn_txt = note
    warn = '<div class="warn">⚠ %s</div>' % warn_txt if warn_txt else ""
    return (
        '<div class="card">'
        '<div class="hd">__NAME__</div><div class="id">__ID__</div>'
        '<div class="row">'
        '<div class="cell"><img src="data:image/png;base64,__U__"><span class="tag">垫在卡下</span></div>'
        '<div class="cell"><img src="data:image/png;base64,__O__"><span class="tag">压在卡上</span></div>'
        '<div class="raw"><img src="data:image/png;base64,__R__"></div>'
        '</div><div class="meta">__META__</div>__WARN__</div>'
    ).replace("__NAME__", NAMES.get(key, key)).replace("__ID__", JOBS[key][0]) \
     .replace("__U__", under_img).replace("__O__", over_img).replace("__R__", raw_img) \
     .replace("__META__", note[0]).replace("__WARN__", note[1])


def main() -> int:
    for p in (PROC, REVIEW, FX):
        p.mkdir(parents=True, exist_ok=True)
    keys = sys.argv[1:] or ORDER
    done, miss, cards = [], [], []
    for key in keys:
        if key not in JOBS:
            continue
        src = RAW / ("%s_codex.png" % key)
        out_name, size, kind = JOBS[key]
        if not src.exists():
            miss.append(key)
            continue
        im = normalize(black_to_alpha(src), size)
        im.save(PROC / out_name, "PNG")
        im.save(FX / out_name, "PNG")

        alpha = im.split()[3]
        nz = sum(1 for v in alpha.tobytes() if v > 8)
        cov = 100.0 * nz / (im.width * im.height)
        ring_txt, weak = ring_metrics(im)
        meta = "%s；非透光 %.1f%%" % (ring_txt, cov)
        # 判据：环的非透光覆盖率应落在 10%~45%（太低=断边，太高=中间被填满）
        notes = []
        if kind == "ring" and cov > 45:
            notes.append("中心疑似被填满（非透光 %.0f%%），会压到卡面" % cov)
        if kind == "ring" and cov < 10:
            notes.append("环带过细或断边（非透光 %.0f%%）" % cov)
        if kind == "ring" and weak:
            notes.append("%s边环带过淡或断开" % "/".join(weak))

        under = composite(im, True)
        over = composite(im, False)
        up = PROC / ("_prev_under_%s.png" % key)
        op = PROC / ("_prev_over_%s.png" % key)
        under.save(up, "PNG")
        over.save(op, "PNG")
        print("OK   %-14s raw %dx%d → %dx%d  %s" % (
            key, *Image.open(src).size, *im.size, meta), flush=True)
        done.append(key)
        cards.append(card_html(key, b64(up, jpeg=True), b64(op, jpeg=True),
                               b64(PROC / out_name, max_w=248),
                               (meta, "；".join(notes))))
    for key in ORDER:
        if key in done or key in miss:
            continue
        p = PROC / JOBS[key][0]
        if p.exists():
            under = PROC / ("_prev_under_%s.png" % key)
            over = PROC / ("_prev_over_%s.png" % key)
            if under.exists() and over.exists():
                cards.append(card_html(key, b64(under, jpeg=True), b64(over, jpeg=True),
                                       b64(p, max_w=248),
                                       ("已落盘", "")))
                done.append(key)
    html = (HTML.replace("__CARDS__", '<div class="grid">%s</div>' % "\n".join(cards)
                         if cards else "<p>还没有成品，等后台第一张落盘。</p>")
            .replace("__N__", str(len(done))).replace("__TOTAL__", str(len(ORDER)))
            .replace("__MISS__", ("%d 张" % len(miss)) if miss else "无"))
    out = REVIEW / "r734_field_ring.html"
    out.write_text(html, encoding="utf-8")
    print("done=%d miss=%d review=%s" % (len(done), len(miss), out), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
