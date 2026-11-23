# -*- coding: utf-8 -*-
"""9201 舰炮 v2 对比页：旧图 / 新图 / 两种取图口径，base64 内嵌单文件 HTML。

跑法：python _make_preview.py  → _preview/9201_v2_compare.html
"""
import base64
import os
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(D, "..", ".."))
P = os.path.join(D, "_preview")
os.makedirs(P, exist_ok=True)


def b64(path, scale=1.0):
    im = Image.open(path).convert("RGB")
    if scale != 1.0:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    buf = os.path.join(P, "_tmp.png")
    im.save(buf, optimize=True)
    with open(buf, "rb") as f:
        s = base64.b64encode(f.read()).decode()
    os.remove(buf)
    return "data:image/png;base64," + s


old = b64(os.path.join(ROOT, "assets", "pics", "9201.png"), 1.6)
new = b64(os.path.join(D, "processed", "9201.png"), 1.6)
top = b64(os.path.join(D, "processed", "9201_view_top.png"), 1.6)
ctr = b64(os.path.join(D, "processed", "9201_view_center.png"), 1.6)
raw = b64(os.path.join(D, "raw", "9201_cannon_blast.png"), 0.62)

HTML = """<!doctype html><html lang="zh"><meta charset="utf-8">
<title>9201 舰炮 v2 对比</title>
<style>
*{box-sizing:border-box}
body{margin:0;background:#12141a;color:#e8e6e1;font:14px/1.7 "Microsoft YaHei",system-ui,sans-serif;padding:28px 32px 48px}
h1{font-size:20px;margin:0 0 4px;font-weight:600;letter-spacing:.5px}
.sub{color:#8b8f9a;font-size:12.5px;margin-bottom:22px}
h2{font-size:14px;margin:30px 0 10px;color:#c9c2b4;font-weight:600;border-left:3px solid #b8892f;padding-left:9px}
.row{display:flex;gap:22px;flex-wrap:wrap;align-items:flex-start}
.cell{background:#1b1e26;border:1px solid #2b2f3a;border-radius:8px;padding:10px}
.cell img{display:block;border-radius:4px;image-rendering:auto}
.cap{font-size:12px;color:#8b8f9a;margin-top:8px;text-align:center}
.cap b{color:#d8b25e;font-weight:600}
.tag{display:inline-block;font-size:11px;padding:1px 7px;border-radius:10px;margin-left:6px;vertical-align:1px}
.old{background:#3a2b2b;color:#d39a9a}
.nw{background:#2b3a2b;color:#9ad39a}
ul{margin:8px 0 0;padding-left:20px;color:#b9bdc7;font-size:13px}
li{margin:3px 0}
.note{background:#191d24;border-left:3px solid #4a7fb5;padding:10px 14px;border-radius:0 6px 6px 0;color:#a8b3c2;font-size:12.5px;margin-top:14px}
</style>
<h1>9201 舰炮 · 重出对比（R854）</h1>
<div class="sub">启示者一阶段效果卡 · 参考店长给的「方界雷霆」炮击光效（只借光效，不吃卡框/文字/怪兽/紫电）</div>

<h2>① 定稿尺寸 448×404</h2>
<div class="row">
  <div class="cell"><img src="%s" width="358"><div class="cap">旧版 <span class="tag old">现役</span><br>三炮塔静置，没开火</div></div>
  <div class="cell"><img src="%s" width="358"><div class="cap">新版 <span class="tag nw">候选 v1</span><br>主炮开火 · 白热核心 + 金色光柱</div></div>
</div>

<h2>② 卡面上真正的取图口径</h2>
<div class="row">
  <div class="cell"><img src="%s" width="420"><div class="cap"><b>战斗</b> · 顶部优先（0..291 行）</div></div>
  <div class="cell"><img src="%s" width="420"><div class="cap"><b>商店 / 图鉴</b> · 居中（56..347 行）</div></div>
</div>
<div class="note">卡图区比例 448:291，素材上下会各切一点。<b>两处交集是 56..291 行</b>，炮塔与光柱都完整在带内，底座被切不影响识别。</div>

<h2>③ 原图（1672×941）</h2>
<div class="cell" style="display:inline-block"><img src="%s" width="720"></div>

<h2>这次照参考图学了什么</h2>
<ul>
  <li>光效语言：<b>白热核心 → 金色主体 → 琥珀外焰</b>，硬边分层，不做渐变糊光。</li>
  <li>炮口位置：<b>同心冲击环</b> + 沿光轴向外扩的<b>放射状细光条</b>，光柱一路溢出画面右缘。</li>
  <li>只参考光效：没画卡框、没画文字、没画卡面那只怪兽、没有紫色闪电。</li>
  <li>沿用的自家设计：冷灰圆顶炮塔 + 红色斜纹 + 青色传感镜头 + 青色接缝；电弧改成青色，跟职业配色一致。</li>
</ul>
<div class="note">还没入库。点头之后我再替换 <code>assets/pics/9201.png</code>、跑 <code>--import</code> 与回归。</div>
""" % (old, new, top, ctr, raw)

out = os.path.join(P, "9201_v2_compare.html")
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(HTML)
print("wrote", out, os.path.getsize(out), "字节")
