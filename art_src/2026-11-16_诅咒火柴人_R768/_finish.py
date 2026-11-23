# -*- coding: utf-8 -*-
"""R768 懊悔（9265）卡图后期：codex 方图 → 448×404 满幅卡图 + 可见带验收页。

三条硬约束（都是踩过的坑，别简化）：
  1. 卡图必须 448×404 **满幅不透明** —— 与 9260/9261/9262 同规格，CardFace 直接铺。
  2. 主体必须落在**可见带 y=68..335**（高 268）之内。CardFace 还会按
     `CARD_ART_RATIO=0.662` 再居中裁一次，超出去的部分是真看不见，不是「略露一点」。
     所以主体按 bbox 缩到高 ≤250 居中摆，四周留白由画布补。
  3. 验收页直接出**可见带**，不出整图 —— 拿整图看会漏掉被裁掉的东西（R760b 教训）。

背景色不写死：从四边取中位数，主体 bbox = 与背景色距离 > TOL 的像素范围。
交通标志是「深紫底 + 白盘红环」，对比极强，这一套足够；万一模型画成白底，
四边中位数也会是白的，同一套逻辑照样成立。

用法：
    python _finish.py                     # 干跑：切图 + 对比页
    python _finish.py --write 9265        # 额外落地到 assets/pics/9265.png
"""
import base64
import io
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"

CARD_W, CARD_H = 448, 404
BAND_TOP, BAND_BOT = 68, 335          # 可见带（含两端）
BAND_H = BAND_BOT - BAND_TOP + 1      # 268
MAX_SUBJECT_H = 250                  # 比可见带再收一点，留呼吸
MAX_SUBJECT_W = 380
TOL = 16                             # 与背景色的 RGB 距离阈值
# ⚠️ 这个值不能拍脑袋。初版写 42，而「纯黑剪影 vs 深紫底 #1A0F1F」的距离只有 43.2 ——
#    剪影连同抗锯齿边缘几乎整片被判成背景，bbox 只框住了青色裂缝（126×250 那种瘦长条）。
#    深色剪影 + 深色底本来就是低对比，阈值必须压到 16 才框得全。

# 出图顺序即验收顺序
KEYS = ["regret_v2", "flaw", "paralysis", "compensation"]
# 候选 key -> 卡号（落地成 assets/pics/<卡号>.png，卡图是按文件名自动匹配的）
CARD_OF = {"regret_v2": 9265, "flaw": 9154, "paralysis": 9185, "compensation": 9252}
CARD_NAME = {9265: "懊悔", 9154: "破绽", 9185: "麻痹", 9252: "代偿"}
# 只有 9265 是新卡缺图，其余三张是替换现有卡图，落地前记得先备份原件
NEW_CARDS = {9265}


def bg_color(im):
    w, h = im.size
    px = im.load()
    pts = []
    step = max(1, w // 32)
    for x in range(0, w, step):
        pts.append(px[x, 0])
        pts.append(px[x, h - 1])
    for y in range(0, h, step):
        pts.append(px[0, y])
        pts.append(px[w - 1, y])
    ch = []
    for c in range(3):
        vals = sorted(p[c] for p in pts)
        ch.append(vals[len(vals) // 2])
    return tuple(ch)


def subject_bbox(im):
    """与背景色距离 > TOL 的像素外接框。缩到 1/4 找，够准且快。"""
    small = im.resize((im.width // 4, im.height // 4), Image.BILINEAR)
    px = small.load()
    b0, b1, b2 = bg_color(im)
    x0, y0, x1, y1 = small.width, small.height, -1, -1
    for y in range(small.height):
        for x in range(small.width):
            r, g, b = px[x, y][:3]
            if ((r - b0) ** 2 + (g - b1) ** 2 + (b - b2) ** 2) ** 0.5 > TOL:
                if x < x0:
                    x0 = x
                if x > x1:
                    x1 = x
                if y < y0:
                    y0 = y
                if y > y1:
                    y1 = y
    if x1 < 0:
        return (0, 0, im.width, im.height)
    pad = 2
    return (max(0, (x0 - pad) * 4), max(0, (y0 - pad) * 4),
            min(im.width, (x1 + 1 + pad) * 4), min(im.height, (y1 + 1 + pad) * 4))


def compose(key):
    src = RAW / ("%s_codex.png" % key)
    if not src.exists():
        return None
    im = Image.open(src).convert("RGB")
    bg = bg_color(im)
    box = subject_bbox(im)
    sub = im.crop(box)

    scale = min(MAX_SUBJECT_H / sub.height, MAX_SUBJECT_W / sub.width, 4.0)
    nw, nh = max(1, int(round(sub.width * scale))), max(1, int(round(sub.height * scale)))
    sub = sub.resize((nw, nh), Image.LANCZOS)

    canvas = Image.new("RGB", (CARD_W, CARD_H), bg)
    # 只贴「主体」，底色整幅由画布提供 —— codex 出的背景不是严格均匀的，
    # 直接 paste 会带进一块略亮的矩形；深色底下看不见，一提亮就成了明显的补丁。
    mask = Image.new("L", sub.size, 0)
    mp = mask.load()
    sp = sub.load()
    for yy in range(sub.height):
        for xx in range(sub.width):
            r, g, b = sp[xx, yy][:3]
            d = ((r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2) ** 0.5
            # 软边：6 以下算纯背景，16 以上算纯主体，中间按比例 —— 硬切会留锯齿
            if d <= 6:
                continue
            mp[xx, yy] = 255 if d >= 16 else int(255 * (d - 6) / 10.0)
    canvas.paste(sub, ((CARD_W - nw) // 2, (CARD_H - nh) // 2), mask)
    out = canvas.convert("RGBA")
    out.putalpha(255)

    PROC.mkdir(parents=True, exist_ok=True)
    dst = PROC / ("card_%d_%s.png" % (CARD_OF[key], key))
    out.save(dst)

    top = (CARD_H - nh) // 2
    bot = top + nh
    ok = top >= BAND_TOP and bot <= BAND_BOT + 1
    print("%-9s raw=%s bg=%s box=%s -> %dx%d  y=%d..%d  可见带%s" % (
        key, im.size, bg, box, nw, nh, top, bot, "内 ✓" if ok else "外 ✗"))
    return dict(key=key, path=dst, bg=bg, size=(nw, nh), y=(top, bot), ok=ok)


def b64(path):
    return base64.b64encode(Path(path).read_bytes()).decode("ascii")


def review(rows):
    """验收页：每个候选给「整图带参考线」+「可见带实裁」+「缩到 150 宽」，全部按可见带判。"""
    cells = []
    for r in rows:
        im = Image.open(r["path"])
        band = im.crop((0, BAND_TOP, CARD_W, BAND_BOT + 1))
        mini = band.resize((150, int(150 * BAND_H / CARD_W)), Image.LANCZOS)

        # 整图副本上画可见带上下界，胶囊里判位靠它；不碰落地的原图
        full = im.copy()
        dr = ImageDraw.Draw(full)
        for y in (BAND_TOP, BAND_BOT):
            dr.line([(0, y), (CARD_W - 1, y)], fill=(255, 0, 0, 255), width=2)
        dr.line([(0, BAND_TOP - 1), (CARD_W - 1, BAND_TOP - 1)], fill=(255, 80, 80, 255), width=1)
        dr.line([(0, BAND_BOT + 1), (CARD_W - 1, BAND_BOT + 1)], fill=(255, 80, 80, 255), width=1)

        full_u = io.BytesIO()
        full.save(full_u, "PNG")
        band_u = io.BytesIO()
        band.save(band_u, "PNG")
        mini_u = io.BytesIO()
        mini.save(mini_u, "PNG")
        note = "落在可见带内" if r["ok"] else "⚠️ 超出可见带"
        cid = CARD_OF[r["key"]]
        cells.append("""
        <section class="cell">
          <h2>%s <b>%d %s</b> <span class="%s">%s</span></h2>
          <div class="row">
            <figure><img src="data:image/png;base64,%s"><figcaption>整图 448×404（红线=可见带上下界）</figcaption></figure>
            <figure><img src="data:image/png;base64,%s"><figcaption>可见带实裁 448×%d</figcaption></figure>
            <figure><img src="data:image/png;base64,%s"><figcaption>缩到 150 宽（卡面近似）</figcaption></figure>
          </div>
        </section>""" % (r["key"], cid, CARD_NAME.get(cid, ""), "ok" if r["ok"] else "bad", note,
                         base64.b64encode(full_u.getvalue()).decode(),
                         base64.b64encode(band_u.getvalue()).decode(), BAND_H,
                         base64.b64encode(mini_u.getvalue()).decode()))

    # 参考线单独画一张，别在图里改像素
    html = """<!doctype html><meta charset="utf-8">
<title>R768 懊悔 9265 卡图验收</title>
<style>
 body{margin:0;padding:28px;background:#1b1420;color:#efe7f3;
      font:14px/1.6 "Microsoft YaHei",system-ui,sans-serif}
 h1{font-size:20px;margin:0 0 6px}
 .lead{color:#b9a9c4;margin:0 0 22px}
 .cell{background:#241b2b;border:1px solid #3a2c44;border-radius:14px;padding:18px 20px;margin:0 0 20px}
 .cell h2{font-size:15px;margin:0 0 14px;letter-spacing:.5px}
 .ok{color:#8fd6a0;font-weight:400}.bad{color:#f08a8a;font-weight:400}
 .row{display:flex;gap:26px;align-items:flex-start;flex-wrap:wrap}
 figure{margin:0;text-align:center}
 figure img{display:block;border-radius:8px;image-rendering:auto;
            box-shadow:0 4px 18px rgba(0,0,0,.45)}
 figure img.band{border:1px solid #6b4f7d}
 figcaption{color:#a596b0;font-size:12px;margin-top:8px}
 .hint{background:#2d2136;border-left:3px solid #9a6fbd;padding:10px 14px;border-radius:6px;
       color:#cfc0d9;margin:0 0 22px;font-size:13px}
</style>
<h1>R768 诅咒卡火柴人 — 四张卡图验收</h1>
<p class="lead">懊悔 9265 / 破绽 9154 / 麻痹 9185 / 代偿 9252。交通标志的<b>象形火柴人语言</b>，
不带标志牌本身。判定只看<b>可见带</b>（y=68..335，高 268），整图只用来定位。</p>
<p class="hint">CardFace 会把 448×404 按 <code>CARD_ART_RATIO=0.662</code> 再居中裁一次，
所以「整图好看」不算过，得「可见带里完整」才算。</p>
%s
""" % ("".join(cells))
    REVIEW.mkdir(parents=True, exist_ok=True)
    out = REVIEW / "compare.html"
    out.write_text(html, encoding="utf-8", newline="\n")
    print("验收页 ->", out)
    return out


def main():
    targets = []
    if "--write" in sys.argv:
        i = sys.argv.index("--write")
        arg = sys.argv[i + 1] if len(sys.argv) > i + 1 else "all"
        targets = list(KEYS) if arg == "all" else [arg]
        bad = [t for t in targets if t not in KEYS]
        if bad:
            print("--write 后面要跟 key（%s）或 all；不认识：%s" % ("/".join(KEYS), bad))
            return 2
    rows = [r for r in (compose(k) for k in KEYS) if r]
    if not rows:
        print("raw 里没有图（先跑 _run_codex.py）")
        return 1
    review(rows)
    if targets:
        bk = PROC / "_bk_pics"
        bk.mkdir(parents=True, exist_ok=True)
        pics = ROOT / "assets" / "pics"
        for t in targets:
            pick = next(r for r in rows if r["key"] == t)
            cid = CARD_OF[t]
            dst = pics / ("%d.png" % cid)
            # 替换已有卡图前先留原件 —— 美术定稿权在店长，旧版还得能拿回来
            if cid not in NEW_CARDS and dst.exists():
                shutil.copyfile(dst, bk / ("%d_before_r768.png" % cid))
                print("备份旧图 ->", bk / ("%d_before_r768.png" % cid))
            Image.open(pick["path"]).save(dst)
            got = Image.open(dst)
            print("落地 -> %s  %s" % (dst, got.size))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
