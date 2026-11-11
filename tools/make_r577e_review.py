# -*- coding: utf-8 -*-
"""R577e 验收页：右栏局部放大 + 2x2 拼图 + base64 内嵌 HTML（可重跑）。"""
import base64
import io
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PRE = ROOT / "_preview"
CROP = (780, 330, 1150, 600)

CASES = [
    ("旧版 R314（对照）", "r577e_before_r314.png", "r577e_zoom_before.png"),
    ("新版 R314：3 亮 / 2 灭", "r577e_r314.png", "r577e_zoom_r314.png"),
    ("混合演示 --relichl：6 亮 / 6 灭", "r577e_mixed.png", "r577e_zoom_mixed.png"),
    ("12 件默认状态 --reliccount 12", "r577e_count12.png", "r577e_zoom_count12.png"),
]


def b64(path):
    return base64.b64encode(io.open(str(path), "rb").read()).decode("ascii")


def main():
    zooms = []
    for title, full_name, zoom_name in CASES:
        full = PRE / full_name
        if not full.is_file():
            print("MISS", full_name)
            continue
        im = Image.open(str(full)).convert("RGB")
        z = im.crop(CROP).resize(
            ((CROP[2] - CROP[0]) * 3, (CROP[3] - CROP[1]) * 3), Image.LANCZOS)
        z.save(str(PRE / zoom_name))
        zooms.append((title, str(full), str(PRE / zoom_name)))
        print("ZOOM", zoom_name, z.size)

    # 2x2 拼图（带标题条）
    if len(zooms) == 4:
        cw, ch = 1110, 810
        pad, bar = 16, 34
        sheet = Image.new("RGB", (cw * 2 + pad * 3, (ch + bar) * 2 + pad * 3), "#f3efe4")
        draw = ImageDraw.Draw(sheet)
        for k, (title, _full, zp) in enumerate(zooms):
            col, row = k % 2, k // 2
            x = pad + col * (cw + pad)
            y = pad + row * (ch + bar + pad)
            draw.rectangle((x, y, x + cw, y + bar), fill="#e6dcc4")
            draw.text((x + 12, y + 10), title, fill="#4a3c14")
            sheet.paste(Image.open(zp).convert("RGB"), (x, y + bar))
        sheet.save(str(PRE / "r577e_compare.png"))
        print("SHEET r577e_compare.png", sheet.size)

    # base64 内嵌 HTML（占位 + replace，不用 % 格式化，CSS 里的 % 会炸）
    cards = []
    for title, full, zp in zooms:
        cards.append(
            '<section class="case"><h2>PLACE_TITLE</h2>'
            '<div class="pair"><figure><img src="data:image/png;base64,PLACE_ZOOM" />'
            '<figcaption>右栏放大 3×</figcaption></figure>'
            '<figure><img class="full" src="data:image/png;base64,PLACE_FULL" />'
            '<figcaption>整页 1280×720</figcaption></figure></div></section>'
            .replace("PLACE_TITLE", title)
            .replace("PLACE_ZOOM", b64(zp))
            .replace("PLACE_FULL", b64(full)))
    html = """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8" />
<title>R577e 道具图标高亮验收</title>
<style>
body{margin:0;padding:28px;background:#f7f3e8;color:#4a3c14;
 font-family:"Microsoft YaHei","PingFang SC",sans-serif;}
h1{font-size:24px;margin:0 0 6px} .lead{color:#7a6230;margin:0 0 24px;font-size:14px}
.case{margin:0 0 30px;background:#fffdf6;border:1px solid #d9cba4;border-radius:10px;padding:16px}
h2{font-size:17px;margin:0 0 12px}
.pair{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start}
figure{margin:0;flex:1;min-width:320px}
img{width:100%;border:1px solid #cdbb8f;border-radius:6px;display:block;background:#fff}
img.full{max-height:330px;object-fit:contain;object-position:top left}
figcaption{font-size:12px;color:#8a7a52;margin-top:6px}
table{border-collapse:collapse;margin:0 0 24px;font-size:14px;background:#fffdf6}
th,td{border:1px solid #d9cba4;padding:7px 12px;text-align:left}
th{background:#efe4c8}
</style></head><body>
<h1>R577e · 道具图标高亮</h1>
<p class="lead">亮的判据 = 「将要在下一次生效 / 本回合生效」；一直被动生效的不亮。
图标本体提亮成青白 + 外圈呼吸环（画在图标之后）+ fx_glow 柔光，不再有硬边圆盘。</p>
<table><tr><th>新增判定的道具</th><th>亮的时刻</th></tr>
<tr><td>6012 一袋米 / 6022 荒野形态 / 6036 思想钢印 / 6053 骑士剑</td><td>本场（本回合）那一次还没触发</td></tr>
<tr><td>6037 荆棘指环 / 6058 咒缚 / 6060 三个机器人</td><td>本回合第一次受伤 / 第一张牌 / 差一个盟友</td></tr>
<tr><td>6015 鸭语耳环 / 6016 冰淇淋 / 6040 水晶骰子</td><td>首回合或骰出的前 X 回合</td></tr>
<tr><td>6010 鸭之低语 / 6055 烟斗</td><td>我方回合的强化 / 点着时下一场首回合生效</td></tr>
<tr><td>6006 鸭嘴 / 6044 储物箱 / 6041 不锈钢盆</td><td>常驻被动 → <b>不亮</b></td></tr></table>
PLACE_CARDS
</body></html>""".replace("PLACE_CARDS", "\n".join(cards))
    out = PRE / "r577e_highlight.html"
    with open(str(out), "wb") as f:
        f.write(html.encode("utf-8"))
    print("HTML", out.name, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
