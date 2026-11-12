# -*- coding: utf-8 -*-
"""R609 交付页：按钮恢复原版宽度 220（不改风格）+ 改成两行（上 4 / 下 3）。

用法：python tools/_make_r609_report.py
"""
import base64
import io
import os

ROOT = r"E:\work\card_rogue"
OUT = os.path.join(ROOT, "_preview", "r609_title_rows.html")


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
<h1>嘎嘎乱杀 · 按钮恢复原样式，改两行排</h1>
<div class="sub">R609 · 1280×800 实机截图 · 按钮宽度回到 220，高度交回 Button 自身</div>
<div class="rule"></div>

<section class="card">
<h3>① 无存档：上排 3 / 下排 3</h3>
<p class="note">「继续游戏」没存档时不可见，所以上排是 开始对战 / 百科 / 对战记录，
下排是 设置 / 鸣谢 / 退出。两行都是 220 宽的同款按钮，风格与改动前一致。</p>
%s
</section>

<section class="card">
<h3>② 有存档：上排 4 / 下排 3</h3>
<p class="note">多出「继续游戏」插在「开始对战」之后。上排 4×220 + 3×10 = 910px，
下排 3×220 + 2×10 = 680px，两行各自居中，成阶梯状。这张是临时点亮按钮的验算图。</p>
%s
</section>

<section class="card">
<h3>③ 对照：改动前的竖排（原样式）</h3>
<p class="note">这就是要保留的按键风格 —— 220 宽、字号 20/16、金框主按钮。
上一版我压到 136×52 并写死高度，字号被挤小、观感变了，这次全部退回。</p>
%s
</section>

<section class="card">
<h3>④ 对照：上一版的单行窄按钮（已废弃）</h3>
<p class="note">136 宽 + 强制 52 高，一行 7 个挤成一条。看着整齐，但按钮被压窄、
主次差异也被削弱 —— 换成两行后不需要再压窄。</p>
%s
</section>

<section class="card">
<h3>⑤ 参数（<code>scenes/title.tscn</code> + <code>scripts/title_scene.gd</code>）</h3>
<table>
<tr><th>项目</th><th>现在</th><th>说明</th></tr>
<tr><td>容器</td><td><code>VBoxContainer</code>（Buttons）</td><td>纵向堆两行，贴底居中，<code>separation = 10</code></td></tr>
<tr><td>两行</td><td><code>Buttons/Row1</code>、<code>Buttons/Row2</code>（各 <code>HBoxContainer</code>）</td>
<td>节点路径变成 <code>$Buttons/Row1/StartBtn</code> 这类，代码已同步</td></tr>
<tr><td>按钮宽度</td><td><code>custom_minimum_size = Vector2(220, 0)</code></td>
<td>220 = 旧版竖排时 VBox 拉满容器的宽度，肉眼一致；高度不写死</td></tr>
<tr><td>挤满问题</td><td><code>size_flags_horizontal = SIZE_SHRINK_CENTER</code></td>
<td>HBox 默认把子节点拉满，不设这条按钮会被撑成 910/4 ≈ 227 宽，两行宽度不一致</td></tr>
<tr><td>容器高度</td><td>0，靠 <code>grow_vertical = 0</code> 向上撑</td><td>不写死高度，换字号/换行数都不会顶穿</td></tr>
<tr><td>位置</td><td><code>offset_bottom = -100</code></td><td>两行整体底边距画面底部 100px</td></tr>
<tr><td>主按钮</td><td>仍是「开始对战」</td><td><code>UiTheme.apply_button(btn, true)</code> 金框 + 大字，没动</td></tr>
</table>
</section>

<footer>回归：assemble 0 失败（含 R609 两条新锁）· engine 5766 ✓ 0 ✗ · smoke 68/68<br>
截图：tools/_shot_title_r603.gd · 有存档那张走「临时点亮 → 截图 → 还原」</footer>
"""


def main():
    body = BODY % (
        fig("_review/r609_title_3x3.png", "无存档 3+3"),
        fig("_review/r609_title_4x3.png", "有存档 4+3"),
        fig("_review/r608_title_old_vbox.png", "改动前竖排"),
        fig("_review/r608_title_6btn.png", "上一版单行 136 宽"),
    )
    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R609 标题页两行按钮</title><style>%s</style></head><body>
<div class="wrap">%s</div></body></html>""" % (CSS, body)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("WROTE %s  %.1f KB" % (OUT, os.path.getsize(OUT) / 1024.0))


if __name__ == "__main__":
    main()
