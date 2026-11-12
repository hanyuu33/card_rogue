# -*- coding: utf-8 -*-
"""R629：独行吞卡演出提速对比页（R628 两拍 vs R629 重叠）。"""
import base64
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREV = os.path.join(ROOT, "_preview")


def b64(name):
    """缩到 760 宽转 JPEG —— 7 张 1080p PNG 直接内嵌会撑到 13MB。"""
    p = os.path.join(PREV, name)
    if not os.path.exists(p):
        return ""
    from PIL import Image
    import io as _io
    im = Image.open(p).convert("RGB")
    w = 760
    im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)
    buf = _io.BytesIO()
    im.save(buf, "JPEG", quality=84, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


SHOTS = [
    ("r628_t110.png", "R628 · 120ms", "吸取段刚起手：手卡处收束环，光柱才露出一小截"),
    ("r628_t300.png", "R628 · 300ms", "吸取走满，光柱到顶，头部漩涡前推"),
    ("r628_t620.png", "R628 · 620ms", "吞噬段（430ms 才开始）：整段 850ms 才演完"),
    ("r629_t120.png", "R629 · 120ms", "① 吸取段早期（吞噬尚未起手）"),
    ("r629_t200.png", "R629 · 200ms", "② 吞噬已起手（170ms）：光柱还在吸，目标处已张嘴"),
    ("r629_t280.png", "R629 · 280ms", "③ 伤害数字落地（260ms）：独行 -15"),
    ("r629_t370.png", "R629 · 370ms", "④ 全清（430ms 收干净）：卡面 90→75 / 力量 4→1"),
]

rows = []
for f, title, note in SHOTS:
    d = b64(f)
    if not d:
        continue
    rows.append(
        '<figure><img src="data:image/png;base64,%s" alt="%s">'
        "<figcaption><b>%s</b><span>%s</span></figcaption></figure>"
        % (d, title, title, note)
    )

html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R629 独行吞卡演出提速</title>
<style>
body{margin:0;padding:28px 30px 48px;background:#14121c;color:#e8e4f2;
     font:15px/1.7 "Microsoft YaHei","PingFang SC",sans-serif}
h1{font-size:22px;margin:0 0 4px;font-weight:600;letter-spacing:.5px}
.sub{color:#8d86a6;font-size:13px;margin-bottom:22px}
.bar{display:flex;gap:14px;flex-wrap:wrap;margin-bottom:26px}
.card{background:#1d1a29;border:1px solid #2e2945;border-radius:10px;
      padding:12px 18px;min-width:150px}
.card .k{color:#8d86a6;font-size:12px}
.card .v{font-size:20px;font-weight:600;color:#c9a9ff}
.card .v small{font-size:12px;color:#8d86a6;font-weight:400}
h2{font-size:15px;color:#a898d8;margin:30px 0 12px;font-weight:600;
   border-left:3px solid #7d55d8;padding-left:9px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:16px}
figure{margin:0;background:#1d1a29;border:1px solid #2e2945;border-radius:10px;
       overflow:hidden}
figure img{width:100%;display:block}
figcaption{padding:9px 12px 12px;font-size:13px;color:#c8c1dc}
figcaption b{color:#fff;display:block;margin-bottom:2px;font-weight:600}
figcaption span{color:#8d86a6;font-size:12px;line-height:1.5}
.tl{margin:10px 0 0;padding:0;list-style:none;font-size:13px;color:#b6aed0}
.tl li{padding:3px 0 3px 16px;position:relative}
.tl li:before{content:"▸";position:absolute;left:0;color:#7d55d8}
.tl b{color:#e8e4f2}
</style></head><body>
<h1>R629 · 独行吞卡演出提速</h1>
<div class="sub">店长口径：「太慢了，能不能吸取到一半就开始吞噬，减少吞噬时间，让总体在 1 秒内」</div>

<div class="bar">
  <div class="card"><div class="k">整段时长</div><div class="v">850 → 430 <small>ms</small></div></div>
  <div class="card"><div class="k">吸取段</div><div class="v">430 → 340 <small>ms</small></div></div>
  <div class="card"><div class="k">吞噬起手</div><div class="v">430 → 170 <small>ms（吸取过半）</small></div></div>
  <div class="card"><div class="k">吞噬段</div><div class="v">420 → 260 <small>ms</small></div></div>
</div>

<h2>时间轴（R629 重叠版）</h2>
<ul class="tl">
  <li><b>0 ms</b> — 手卡处紫色收束环由外向内收，光柱沿路径长出</li>
  <li><b>170 ms</b> — <b>吸取过半，吞噬提前张嘴</b>（原来要等 430ms 走满）</li>
  <li><b>260 ms</b> — 「独行 -15」大号暗紫字落地，卡面同帧掉血</li>
  <li><b>340 ms</b> — 光柱淡尽交棒（让位系数 tsink：0.45 → 0.75）</li>
  <li><b>350 ms</b> — 「独行 力量 -4」压后 90ms 起飘，下移一行不打架</li>
  <li><b>430 ms</b> — 特效全清</li>
</ul>

<h2>R628（两拍：吸完才吞）</h2>
<div class="grid">__R628__</div>

<h2>R629（重叠：吸到一半就吞）</h2>
<div class="grid">__R629__</div>
</body></html>"""
html = html.replace("__R628__", "".join(rows[:3])).replace("__R629__", "".join(rows[3:]))

out = os.path.join(PREV, "r629_lone_timing_report.html")
open(out, "w", encoding="utf-8").write(html)
print("written", out, len(html))
