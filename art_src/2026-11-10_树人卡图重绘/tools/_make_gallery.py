# -*- coding: utf-8 -*-
"""生成树人卡图重绘的验收画廊（base64 内嵌，避免预览服务不搬图）。"""
import base64
import io
import os

from PIL import Image

ROOT = r"E:\work\card_rogue"
OUT = os.path.join(ROOT, "_preview", "treant_8003_gallery.html")

def b64(path, max_w=None, q=93):
    im = Image.open(path).convert("RGB")
    if max_w and im.size[0] > max_w:
        h = int(round(im.size[1] * max_w / im.size[0]))
        im = im.resize((max_w, h), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=q)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

old = os.path.join(ROOT, "assets", "pics", "8003.png")
new = os.path.join(ROOT, "assets", "pics", "_pending", "8003.png")
raw = os.path.join(ROOT, "art_src", "2026-11-10_树人卡图重绘", "raw", "8003_树人_v1.png")

# 对比图：左右并排，各 448 宽，缩到 900 宽以内
o = Image.open(old).convert("RGB")
n = Image.open(new).convert("RGB")
W = 448
gap = 24
label_h = 44
canvas = Image.new("RGB", (W * 2 + gap * 3, 403 + label_h + 12), (28, 30, 34))
canvas.paste(o, (gap, label_h))
canvas.paste(n, (W + gap * 2, label_h))
from PIL import ImageDraw, ImageFont
d = ImageDraw.Draw(canvas)
try:
    f = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 26)
except Exception:
    f = ImageFont.load_default()
d.text((gap, 8), "旧版（写实厚涂）", fill=(255, 200, 90), font=f)
d.text((W + gap * 2, 8), "新版（赛璐璐重绘）", fill=(120, 255, 140), font=f)
cmp_buf = io.BytesIO()
canvas.save(cmp_buf, "JPEG", quality=93)
cmp_b64 = "data:image/jpeg;base64," + base64.b64encode(cmp_buf.getvalue()).decode()

old_b64 = b64(old, max_w=448, q=93)
new_b64 = b64(new, max_w=448, q=93)
raw_b64 = b64(raw, max_w=900, q=92)

html = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>树人 8003 卡图重绘 · 验收</title>
<style>
  body { margin:0; background:#17181c; color:#e8e6df; font-family:"Microsoft YaHei",sans-serif; padding:28px; }
  h1 { font-size:20px; font-weight:600; margin:0 0 4px; }
  .sub { color:#9a988f; font-size:13px; margin-bottom:24px; }
  h2 { font-size:15px; margin:28px 0 10px; color:#f2c14e; border-bottom:1px solid #33343a; padding-bottom:6px; }
  .card { background:#222329; border:1px solid #33343a; border-radius:12px; padding:18px; margin-bottom:14px; }
  img { max-width:100%; height:auto; border-radius:8px; display:block; }
  .grid2 { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
  .grid2 .cell { background:#1c1d22; border-radius:10px; padding:12px; }
  .cap { font-size:12px; color:#b6b3a8; margin-top:8px; text-align:center; }
  .note { font-size:13px; color:#b6b3a8; line-height:1.7; }
  .tag { display:inline-block; padding:2px 9px; border-radius:6px; font-size:12px; margin-right:6px; }
  .tag.old { background:#5a4020; color:#ffc85a; }
  .tag.new { background:#1f4a2a; color:#78ff8c; }
</style>
</head>
<body>
  <h1>树人 8003 · 卡图重绘验收</h1>
  <div class="sub">森林精魄 · 3 费 3/8 盟友 · 稀有 —— 由 codex 内置 image_gen 全新生成（未参考旧图）</div>

  <div class="card">
    <img src="__CMP__" alt="新旧对比">
    <div class="cap"><span class="tag old">旧版 8003（写实厚涂）</span><span class="tag new">新版 8003（赛璐璐）</span>游戏实际尺寸 448×403</div>
  </div>

  <h2>全尺寸原图（1024×1024）</h2>
  <div class="card"><img src="__RAW__" alt="全尺寸原图"></div>

  <h2>裁切候选（448×403，游戏内待确认）</h2>
  <div class="card">
    <img src="__NEW__" alt="裁切候选" style="width:448px;">
    <div class="cap">已放 assets/pics/_pending/8003.png（带黄色角标）</div>
  </div>

  <h2>结论</h2>
  <div class="note">
    新版已对齐当前美术方向「日式二次元赛璐璐 + 西幻」：干净线稿、硬边阴影、主体亮背景暗、清晰深色外轮廓；
    旧版与 9067 大树守卫一样偏写实厚涂。<b>主目录 assets/pics/8003.png 尚未覆盖</b>——等你点头再转正。
  </div>
</body>
</html>
"""

html = html.replace("__CMP__", cmp_b64).replace("__RAW__", raw_b64).replace("__NEW__", new_b64)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print("written:", OUT)
print("size:", os.path.getsize(OUT), "bytes")
