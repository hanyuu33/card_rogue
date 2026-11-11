# -*- coding: utf-8 -*-
"""R577d 验收页：四种件数的战斗实机图 → 右栏局部放大拼图 + base64 内嵌 HTML。

⚠️ 生成 HTML 不用 Python % 格式化（CSS 里的 % 会炸）→ 模板占位 + .replace()。
⚠️ 出图源图来自 `--screenshot --reliccount N`（必须带窗口，不能 --headless）。
"""
import base64
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"E:/work/card_rogue")
SRC = ROOT / "_preview"
FONT_PATH = r"C:/Windows/Fonts/msyh.ttc"

# 右栏道具区域：zone = (794,348,338,232)，往四周留一点边看清底板与「鸭之低语」
CROP = (780, 330, 1144, 610)
SCALE = 2

CASES = [
    (4, "r577d_4.png", "4 件 · 一排 [4]", "原本会变成 3+1，现在四个平铺在一行"),
    (7, "r577d_7.png", "7 件 · 两行 [4,3]", "满了才换行；换行后按行平均分配，不是 6+1"),
    (12, "r577d_12.png", "12 件 · [6,6] 满格", "每行六个收紧间距，图标仍是 44×44 不缩小"),
    (16, "r577d_16.png", "16 件 · [6,6] + 溢出摘要", "超过 12 件末位换「+N」，格位仍在同一套布局里"),
]


def font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except OSError:
        return ImageFont.load_default()


def b64_jpeg(im, quality=88, max_w=None):
    if max_w is not None and im.width > max_w:
        h = int(im.height * max_w / im.width)
        im = im.resize((max_w, h), Image.LANCZOS)
    if im.mode != "RGB":
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.convert("RGBA").split()[-1] if im.mode == "RGBA" else None)
        im = bg
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=quality)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def main():
    crops = []
    cards = []
    for n, name, title, note in CASES:
        p = SRC / name
        if not p.is_file():
            print("MISS", name)
            continue
        im = Image.open(p).convert("RGB")
        crop = im.crop(CROP).resize(
            ((CROP[2] - CROP[0]) * SCALE, (CROP[3] - CROP[1]) * SCALE),
            Image.LANCZOS)
        crops.append((title, crop))
        cards.append((n, title, note, b64_jpeg(crop), b64_jpeg(im, max_w=760)))
        print("OK", name, im.size, "->", crop.size)

    # ---- 2x2 拼图（先看整体观感用）----
    if crops:
        cw, ch = crops[0][1].size
        bar = 44
        pad = 16
        W = cw * 2 + pad * 3
        H = (ch + bar) * 2 + pad * 3 + 52
        sheet = Image.new("RGB", (W, H), (24, 26, 32))
        d = ImageDraw.Draw(sheet)
        d.text((pad, 12), "R577d  战斗右栏道具排版 · 按行平均分配（图标 44x44 恒定）",
               font=font(24), fill=(238, 232, 214))
        for idx, (title, crop) in enumerate(crops):
            col, row = idx % 2, idx // 2
            x = pad + col * (cw + pad)
            y = 52 + pad + row * (ch + bar + pad)
            d.rectangle((x, y, x + cw, y + bar), fill=(42, 46, 58))
            d.text((x + 12, y + 9), title, font=font(22), fill=(240, 226, 190))
            sheet.paste(crop, (x, y + bar))
        sheet_path = SRC / "r577d_compare.png"
        sheet.save(sheet_path)
        print("SHEET", sheet_path)

    # ---- base64 内嵌 HTML ----
    card_html = []
    for n, title, note, big, small in cards:
        card_html.append("""
        <section class="card">
          <h2>__TITLE__</h2>
          <p class="note">__NOTE__</p>
          <img class="big" src="__BIG__" alt="__TITLE__ 右栏放大">
          <details><summary>整页实机图</summary><img class="small" src="__SMALL__" alt="__TITLE__ 整页"></details>
        </section>""".replace("__TITLE__", title).replace("__NOTE__", note)
                          .replace("__BIG__", big).replace("__SMALL__", small))

    tpl = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R577d 战斗道具栏 · 数量适应排版验收</title>
<style>
  body { margin:0; padding:28px; background:#f5f1e7; color:#3a3327;
         font-family:"Microsoft YaHei","PingFang SC",system-ui,sans-serif; }
  h1 { font-size:26px; margin:0 0 6px; }
  .lead { color:#6b6250; font-size:14px; margin:0 0 20px; line-height:1.7; }
  .grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:18px; }
  .card { background:#fffdf7; border:1px solid #ddd2b8; border-radius:10px; padding:14px; }
  .card h2 { font-size:18px; margin:0 0 4px; color:#4a3c14; }
  .note { font-size:13px; color:#7a705c; margin:0 0 10px; }
  img.big { width:100%; display:block; border:1px solid #e3d9c2; border-radius:6px; }
  details { margin-top:10px; font-size:13px; color:#6b6250; }
  img.small { width:100%; display:block; margin-top:8px; border:1px solid #e3d9c2; border-radius:6px; }
  table { border-collapse:collapse; margin:22px 0 0; font-size:14px; }
  th,td { border:1px solid #d8cdb4; padding:7px 14px; text-align:left; }
  th { background:#ece3cd; }
  code { background:#eee7d6; padding:1px 5px; border-radius:3px; }
</style></head><body>
<h1>战斗右栏道具栏 · 数量适应排版</h1>
<p class="lead">一行最多 6 个 44×44 图标；数量变多时只收紧间距、不缩图标。放不下才换行，
换行后把总数按行平均分配（每行个数差 &le; 1），不再出现「前几行填满 + 尾巴剩 1 个」。
容量契约仍是 <code>Rect2(794,348,338,232)</code> / 12 格，底板高度按实际行数收拢。</p>
<div class="grid">__CARDS__</div>
<table>
<tr><th>件数</th><th>每行分配</th><th>说明</th></tr>
<tr><td>1 ~ 6</td><td>[n]</td><td>单行，间距随件数收紧</td></tr>
<tr><td>7 / 8 / 9</td><td>[4,3] / [4,4] / [5,4]</td><td>换两行且均分</td></tr>
<tr><td>10 / 11 / 12</td><td>[5,5] / [6,5] / [6,6]</td><td>满格仍是两行</td></tr>
<tr><td>&gt; 12</td><td>[6,6] + 「+N」</td><td>第 12 格改画溢出摘要，点开看全部</td></tr>
</table>
</body></html>"""
    html = tpl.replace("__CARDS__", "".join(card_html))
    out = SRC / "r577d_layout.html"
    out.write_text(html, encoding="utf-8")
    print("HTML", out, len(html) // 1024, "KB")


if __name__ == "__main__":
    main()
