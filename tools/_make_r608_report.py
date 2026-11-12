# -*- coding: utf-8 -*-
"""R608 交付页：9011 主视觉 + 按钮改贴底横排（6 / 7 个两种状态）。

用法：python tools/_make_r608_report.py
"""
import base64
import io
import os

ROOT = r"E:\work\card_rogue"
OUT = os.path.join(ROOT, "_preview", "r608_title_layout.html")


def embed(rel):
    p = os.path.join(ROOT, rel)
    raw = open(p, "rb").read()
    if len(raw) > 400 * 1024:
        from PIL import Image
        bio = io.BytesIO()
        Image.open(p).convert("RGB").save(bio, "JPEG", quality=90, optimize=True)
        return "image/jpeg", base64.b64encode(bio.getvalue()).decode("ascii")
    return "image/png", base64.b64encode(raw).decode("ascii")


def fig(rel, alt):
    mime, data = embed(rel)
    return '<img alt="%s" src="data:%s;base64,%s">' % (alt, mime, data)


CSS = """
:root{--bg:#f7f2e8;--pane:#fffdf8;--line:#e0d3bb;--ink:#3a2f22;--dim:#7d6c56;--gold:#b5822a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"Noto Serif SC","Songti SC",Georgia,serif;line-height:1.75}
.wrap{max-width:1180px;margin:0 auto;padding:52px 28px 90px}
h1{font-size:28px;margin:0 0 8px;letter-spacing:.04em}
.sub{color:var(--dim);font-size:14px}
.rule{height:2px;background:linear-gradient(90deg,var(--gold),transparent);margin:18px 0 34px}
.card{background:var(--pane);border:1px solid var(--line);border-radius:12px;
  padding:20px 20px 24px;margin-bottom:30px;box-shadow:0 2px 14px rgba(120,95,60,.07)}
.card h3{margin:0 0 6px;font-size:19px;color:#5a4426}
.card .note{margin:0 0 14px;color:var(--dim);font-size:13.5px}
.card img{width:100%;display:block;border-radius:8px;border:1px solid var(--line)}
table{border-collapse:collapse;width:100%;font-size:13.5px;margin-top:6px}
th,td{border-bottom:1px solid var(--line);padding:7px 10px;text-align:left}
th{color:#8a6a2f;font-weight:600}
td code{background:#f3e7cf;border-radius:4px;padding:1px 5px;font-size:12.5px}
footer{margin-top:52px;padding-top:16px;border-top:1px solid var(--line);
  color:var(--dim);font-size:12.5px}
"""

BODY = """
<h1>嘎嘎乱杀 · 标题页换 9011 + 按钮改贴底横排</h1>
<div class="sub">R608 · 1280×800 实机截图，未缩放的原始按钮行</div>
<div class="rule"></div>

<section class="card">
<h3>① 现在这样（无存档，6 个按钮）</h3>
<p class="note">四个字完整露出，按钮一整行贴在画面下方三分之一，压在石板路上。</p>
%s
</section>

<section class="card">
<h3>② 有存档时（7 个按钮，最宽情况）</h3>
<p class="note">多出「继续游戏」，整行 7×136 + 6×12 = 1024px，两侧各剩 128px，
不顶边、也不压到角落那两只鸭。这一张是临时把按钮点亮的验算图。</p>
%s
</section>

<section class="card">
<h3>③ 换之前（竖排，同一张 9011）</h3>
<p class="note">同一张图、只把按钮从竖排改横排的对照 —— 竖排时「开始对战」压在
「嘎」「乱」之间，字和按钮互相打架。</p>
%s
</section>

<section class="card">
<h3>④ 主视觉原图（9011）</h3>
<p class="note">已按 16:9 铺成 1920×1080 存为 <code>assets/ui/title_art.png</code>；
字是画在图里的，不加任何合成文字，所以没有副标题、也不会错位。</p>
%s
</section>

<section class="card">
<h3>⑤ 布局参数（都在 <code>scenes/title.tscn</code> + <code>title_scene.gd</code>）</h3>
<table>
<tr><th>项目</th><th>值</th><th>说明</th></tr>
<tr><td>容器类型</td><td><code>VBoxContainer</code> → <code>HBoxContainer</code></td>
<td>只是换容器，子节点名字和顺序全不变，<code>$Buttons/StartBtn</code> 这些路径照旧</td></tr>
<tr><td>锚点</td><td>居中 → 底部居中（preset 7）</td><td>贴底走，不跟着画面高度飘</td></tr>
<tr><td>纵向位置</td><td><code>offset_top = -152</code> / <code>bottom = -100</code></td>
<td>按钮带 52px 高，即画面 648~700（800 高）</td></tr>
<tr><td>按钮尺寸</td><td><code>136 × 52</code>（代码里统一设）</td>
<td>按最宽 7 个算的；不设的话每个按文字宽度排，一行会参差不齐</td></tr>
<tr><td>间距</td><td><code>separation = 12</code>，<code>alignment = 1</code></td><td>居中排</td></tr>
<tr><td>主按钮</td><td>仍是「开始对战」</td><td>金框 + 大字走 <code>UiTheme.apply_button(btn, true)</code>，没动</td></tr>
</table>
</section>

<footer>回归：assemble 0 失败 · engine 5766 ✓ 0 ✗<br>
截图：tools/_shot_title_r603.gd（6 键）· tools/_shot_title_7btn.gd（7 键验算，走临时开关）</footer>
"""


def main():
    body = BODY % (
        fig("_review/r608_title_6btn.png", "6 个按钮实机"),
        fig("_review/r608_title_7btn.png", "7 个按钮实机"),
        fig("_review/r608_title_old_vbox.png", "换之前的竖排"),
        fig("art_src/2026-11-12_开场与标题_R604/raw/9011_标题字鸭嘴版_v1.png", "9011 原图"),
    )
    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R608 标题页布局</title><style>%s</style></head><body>
<div class="wrap">%s</div></body></html>""" % (CSS, body)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("WROTE %s  %.1f KB" % (OUT, os.path.getsize(OUT) / 1024.0))


if __name__ == "__main__":
    main()
