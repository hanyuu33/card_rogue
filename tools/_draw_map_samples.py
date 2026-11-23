# -*- coding: utf-8 -*-
"""R858：把 _map_samples.json 画成 HTML 示意图（验收用，不进游戏资源）。

每张图 = 7×5 格子 + 门（连线）。门画在格子底层，从格心连到格心，
露出来的部分正好是格子之间那条「门缝」—— 与游戏里齿轮连线的观感一致。
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
data = json.loads((ROOT / "tools" / "_map_samples.json").read_text(encoding="utf-8"))

COL, ROW = 7, 5
CW, CH, GAP = 78, 66, 10
PAD = 14
W = COL * CW + (COL - 1) * GAP + PAD * 2
H = ROW * CH + (ROW - 1) * GAP + PAD * 2

COLOR = {
    "battle": "#c2453a", "elite": "#8c3d9e", "event": "#3d6fa8", "rest": "#d9832e",
    "shop": "#4a8f4f", "chest": "#c9a227", "bigchest": "#b8860b",
    "unknown": "#6b7a8f", "start": "#2f9e8f", "boss": "#7a2b2b",
}
LABEL = {
    "battle": "战斗", "elite": "精英", "event": "事件", "rest": "休息", "shop": "商店",
    "chest": "宝箱", "bigchest": "大宝箱", "unknown": "未知", "start": "起点", "boss": "首领",
}


def center(col, row):
    return (PAD + col * (CW + GAP) + CW / 2.0, PAD + row * (CH + GAP) + CH / 2.0)


def cell_rect(col, row):
    return (PAD + col * (CW + GAP), PAD + row * (CH + GAP))


def draw_map(m):
    cells = m["cells"]
    out = ['<svg viewBox="0 0 %d %d" class="map" xmlns="http://www.w3.org/2000/svg">' % (W, H)]
    # 底层：门
    out.append('<g class="doors">')
    seen = set()
    for c in cells:
        a = int(c["id"])
        for b in c["doors"]:
            b = int(b)
            if (b, a) in seen or a == b:
                continue
            seen.add((a, b))
            x1, y1 = center(int(c["col"]), int(c["row"]))
            x2, y2 = center(b % COL, b // COL)
            out.append(
                '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#c8a973" '
                'stroke-width="9" stroke-linecap="round"/>' % (x1, y1, x2, y2))
    out.append("</g>")
    # 上层：格子
    for c in cells:
        col, row = int(c["col"]), int(c["row"])
        t = "unknown" if c["hidden"] else c["type"]
        x, y = cell_rect(col, row)
        colr = COLOR.get(t, "#888")
        out.append('<g class="cell">')
        out.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="7" '
                   'fill="#fdf6e6" stroke="#a8874e" stroke-width="2"/>' % (x, y, CW, CH))
        out.append('<path d="M%.1f %.1f h%d a7,7 0 0 1 7,7 v7 h-%d z" fill="%s" opacity="0.9"/>'
                   % (x + 2, y + 2, CW - 4, CW - 4, colr))
        out.append('<text x="%.1f" y="%.1f" text-anchor="middle" font-size="15" '
                   'fill="#3a2c17">%s</text>' % (x + CW / 2, y + CH / 2 + 9, LABEL.get(t, t)))
        if c.get("shop_mark"):
            out.append('<circle cx="%.1f" cy="%.1f" r="5" fill="#2f6f3a"/>'
                       % (x + CW - 12, y + CH - 12))
        if t == "start":
            out.append('<circle cx="%.1f" cy="%.1f" r="6" fill="#2f9e8f"/>'
                       % (x + CW / 2, y + 13))
        out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)


cards = []
for i, m in enumerate(data["maps"]):
    cards.append(
        '<section class="card"><header><b>种子 %d</b>'
        '<span>重摇 %d 次</span></header>%s</section>'
        % (m["seed"], m["attempts"], draw_map(m)))

html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R858 地图路线冗余度 · 效果图</title>
<style>
  :root { color-scheme: light; }
  body { margin:0; padding:28px 32px 48px; background:#f6ecd8;
         font-family:-apple-system,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;
         color:#3a2c17; }
  h1 { font-size:20px; margin:0 0 6px; letter-spacing:.5px; }
  p.lead { margin:0 0 22px; font-size:13.5px; color:#6b5637; line-height:1.7; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(430px,1fr)); gap:20px; }
  .card { background:#fdf8ec; border:1px solid #ddc79b; border-radius:14px;
          padding:12px 14px 10px; box-shadow:0 2px 10px rgba(120,90,40,.08); }
  .card header { display:flex; justify-content:space-between; align-items:baseline;
                 font-size:12.5px; color:#7a6440; margin-bottom:8px; }
  .card header b { font-size:13px; color:#4a3720; }
  svg.map { width:100%; height:auto; display:block; }
</style></head><body>
<h1>R858 · 地图生成：路线冗余度优化后</h1>
<p class="lead">
每张图 7×5 格、从下中起点出发，门 = 格子之间的连线。<br>
改前实测：平均门数 2.33、每行平均被切成 1.96 段、22.5% 的图到宝箱只有唯一一条路。<br>
改后：平均门数 2.53、每行 1.19 段、单行图 0%，到宝箱的走法均值 16.8 条。
</p>
<div class="grid">
__CARDS__
</div>
</body></html>
"""
html = html.replace("__CARDS__", "\n".join(cards))

out = ROOT / "tools" / "_map_preview_r858.html"
out.write_text(html, encoding="utf-8")
print("已生成：", out)
