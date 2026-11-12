# -*- coding: utf-8 -*-
"""R595b 发布前素材体检·更正版。

R595 报告把 92 张判成「待生成」，实际 89 张早在 `assets/pics/_pending/` 待审。
本页撤回旧结论、给出三态数字。**不评价任何成品的画风与版本优劣** ——
版本一律以店长敲定为准，取最新那一版。
"""
import base64
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = json.load(io.open(os.path.join(ROOT, "_preview", "asset_audit.json"), encoding="utf-8"))
cards = A["cards"]
real, pend, orphan = cards["missing"], cards["pending"], cards.get("orphan", [])
total, have = cards["total"], cards["have"]


def b64(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


CSS = """
*{box-sizing:border-box}
body{margin:0;padding:38px 44px 60px;background:#16161a;color:#dcdce2;
 font:15px/1.75 "Microsoft YaHei","PingFang SC",sans-serif}
h1{margin:0 0 6px;font-size:26px;letter-spacing:.5px;color:#f2e3bd}
.sub{color:#8d8d98;font-size:13px;margin-bottom:26px}
h2{margin:38px 0 14px;font-size:19px;color:#e8c98a;
 border-left:4px solid #b8873c;padding-left:11px}
table{border-collapse:collapse;width:100%;margin:12px 0 6px;font-size:14px}
th,td{border:1px solid #2e2e38;padding:8px 11px;text-align:left;vertical-align:top}
th{background:#1f1f27;color:#a9b4c8;font-weight:600}
td.n{text-align:right;font-variant-numeric:tabular-nums;font-family:Consolas,monospace}
.ok{color:#7fd4a0}.warn{color:#e8bf6a}.bad{color:#e88a86}
.big{display:flex;gap:16px;flex-wrap:wrap;margin:18px 0 8px}
.card{flex:1 1 200px;background:#1c1c23;border:1px solid #2e2e38;border-radius:10px;
 padding:16px 18px}
.card .k{font-size:13px;color:#8d8d98;margin-bottom:4px}
.card .v{font-size:30px;font-weight:700;font-family:Consolas,monospace;line-height:1.2}
.card.g{border-color:#2f5c3f}.card.g .v{color:#7fd4a0}
.card.y{border-color:#5c4f2c}.card.y .v{color:#e8bf6a}
.card.r{border-color:#5c3230}.card.r .v{color:#e88a86}
.note{background:#1e1a16;border-left:3px solid #b8873c;padding:12px 16px;
 margin:16px 0;color:#c8bfae;font-size:14px}
.note b{color:#f0d79a}
figure{margin:18px 0 26px}
figure img{width:100%;border:1px solid #2e2e38;border-radius:8px;display:block}
figcaption{margin-top:8px;color:#8d8d98;font-size:13px}
code{background:#232330;padding:1px 6px;border-radius:4px;font-family:Consolas,monospace;
 font-size:13px;color:#d9c88f}
ul{margin:8px 0 8px 4px;padding-left:20px}li{margin:4px 0}
.tag{display:inline-block;padding:1px 8px;border-radius:10px;font-size:12px;
 border:1px solid;margin-right:6px}
.tag.g{color:#7fd4a0;border-color:#2f5c3f}
"""

BODY = """
<h1>发布前素材体检 · 更正版</h1>
<div class="sub">R595b ／ 2026-11-12 ／ 撤回 R595 的「缺 92 张」结论</div>

<div class="note">
<b>先说错在哪。</b>R595 的体检脚本只扫 <code>assets/pics/*.png</code>，
漏掉了 <code>assets/pics/_pending/</code> —— 那是「已出图、等入库」的暂存层，
里面躺着 <b>114 张 448×403 成品</b>。于是 89 张早已完成的图被报成「没做」。
脚本已修（三态判定），本页数字为修正后结果。
</div>

<div class="big">
  <div class="card g"><div class="k">已归档</div><div class="v">__HAVE__</div></div>
  <div class="card y"><div class="k">待入库 _pending</div><div class="v">__PEND__</div></div>
  <div class="card r"><div class="k">真缺</div><div class="v">__REAL__</div></div>
  <div class="card"><div class="k">卡库总数</div><div class="v">__TOTAL__</div></div>
</div>

<h2>一、三态口径</h2>
<table>
<tr><th>状态</th><th>判据</th><th>张数</th><th>含义</th></tr>
<tr><td class="ok">已归档</td><td><code>assets/pics/&lt;id&gt;.png</code> 存在，
或公用初始卡三职业变体齐全</td><td class="n">__HAVE__</td><td>游戏里已经在用</td></tr>
<tr><td class="warn">待入库</td><td>正式库没有、<code>_pending/&lt;id&gt;.png</code> 有</td>
<td class="n">__PEND__</td><td>图已完成，只差搬进正式库</td></tr>
<tr><td class="bad">真缺</td><td>两边都没有</td><td class="n">__REAL__</td><td>确实要新跑</td></tr>
</table>

<h2>二、真缺的 3 张</h2>
__REAL_TABLE__

<div class="note">
<b>9158 罐子（工事）是个误记。</b>R563 的 <code>_batch.log</code> 在 00:38:41 记了
<code>OK 9158 罐子_工事</code>，但同次运行的 <code>_log_9158_v1.jsonl</code> 里
<b>没有任何 <code>generated_images</code> 记录</b>，raw 目录也没有 9158 的文件 ——
那次 codex 只回了一句话、没出图，批处理却按成功记账了。
9158 是 9157 那只罐子的「工事版」：同一只罐子放大立地、加铆钉铁箍＋钢底座，
按 9157 的定稿改版即可。
</div>

<h2>三、诅咒四张：已完成，只差入库</h2>
<p>四张全部在 <code>_pending/</code>，均为各卡最后一次出图的成品，规格 448×403 合规。
没进正式库不是质量问题，是流程停在「未 approve、未 commit」这一步。</p>

<figure>
  <img src="__IMG_CURSES__">
  <figcaption>9149 疲惫 / 9154 破绽 / 9157 罐子 / 9185 麻痹（取自 _pending，448×403 原尺寸）。</figcaption>
</figure>

<table>
<tr><th>id</th><th>名称</th><th>成品文件</th><th>状态</th></tr>
<tr><td class="n">9149</td><td>疲惫</td><td><code>_pending/9149.png</code></td>
<td class="ok"><span class="tag g">已完成</span>待入库</td></tr>
<tr><td class="n">9154</td><td>破绽</td><td><code>_pending/9154.png</code></td>
<td class="ok"><span class="tag g">已完成</span>待入库</td></tr>
<tr><td class="n">9157</td><td>罐子</td><td><code>_pending/9157.png</code></td>
<td class="ok"><span class="tag g">已完成</span>待入库</td></tr>
<tr><td class="n">9185</td><td>麻痹</td><td><code>_pending/9185.png</code></td>
<td class="ok"><span class="tag g">已完成</span>待入库</td></tr>
</table>

<h2>四、待入库 89 张的分布</h2>
__PEND_TABLE__
<p>这 89 张与 R563 那 27 张不是同一批 —— R563 只补了 27 张，<code>_pending</code> 里另有
更早期批次积压的成品。共同点：图已完成、规格合规，但从未搬进正式库，
所以游戏里一直显示空白卡面。</p>

<div class="note">
<b>下一步只需你一句话：</b>待入库 89 张要不要整批搬进 <code>assets/pics/</code>？
按纪律我不会擅自搬。搬完卡面就不再空白。
</div>

<h2>五、其他类目（与 R595 一致，未变）</h2>
<table>
<tr><th>类目</th><th>状态</th></tr>
<tr><td>道具图标 + 边缘光</td><td class="ok">62 / 62 全齐</td></tr>
<tr><td>职业 CG / 头像 / 灰阶态 / 徽章</td><td class="ok">3 职业全齐</td></tr>
<tr><td>地图节点图标</td><td class="ok">9 / 9</td></tr>
<tr><td>BGM 槽位</td><td class="ok">11 / 11</td></tr>
<tr><td>代码引用 UI 素材</td><td class="ok">45 个全在</td></tr>
<tr><td>应用图标 / 启动图</td><td class="ok">icon.ico + 安卓四件齐全</td></tr>
<tr><td>音效</td><td class="ok">sfx.gd 现场合成 PCM，无素材需求</td></tr>
<tr><td>事件插图</td><td class="ok">仅 4 个事件走左右布局，竖版图恰好齐全；其余 22 个按设计不配图</td></tr>
</table>
__ORPHAN__

<h2>六、脚本</h2>
<p><code>python tools/audit_release_assets.py</code> —— 已修成三态判定，
结果落在 <code>_preview/asset_audit.txt</code> / <code>.json</code>。
补完图再跑一次，三个数字会自己动。</p>
"""


def mk_real_table():
    if not real:
        return "<p class='ok'>无 —— 全部卡图齐备。</p>"
    rows = ["<table><tr><th>id</th><th>名称</th><th>种类</th><th>稀有度</th>"
            "<th>职业</th><th>备注</th></tr>"]
    note = {9158: "R563 批处理误记成功，实际未出图；按 9157 定稿改工事版",
            9192: "R592 新卡（援护炮击），从未出图",
            9193: "R592 组合体系新卡，从未出图"}
    for m in real:
        rows.append("<tr><td class='n'>%d</td><td>%s</td><td>%s</td><td class='n'>%d</td>"
                    "<td>%s</td><td>%s</td></tr>"
                    % (m["id"], m["name"], m["kind"], m["rarity"],
                       m["card_class"] or "—", note.get(m["id"], "")))
    rows.append("</table>")
    return "".join(rows)


def mk_pend_table():
    by = {}
    for m in pend:
        by.setdefault(m["group"], []).append(m)
    rows = ["<table><tr><th>阵营</th><th>张数</th><th>包含</th></tr>"]
    for g, v in sorted(by.items(), key=lambda x: -len(x[1])):
        names = "、".join("%s(%d)" % (m["name"], m["id"]) for m in v)
        rows.append("<tr><td>%s</td><td class='n'>%d</td><td>%s</td></tr>"
                    % (g, len(v), names))
    rows.append("</table>")
    return "".join(rows)


body = BODY
body = body.replace("__HAVE__", str(have)).replace("__PEND__", str(len(pend)))
body = body.replace("__REAL__", str(len(real))).replace("__TOTAL__", str(total))
body = body.replace("__REAL_TABLE__", mk_real_table())
body = body.replace("__PEND_TABLE__", mk_pend_table())
body = body.replace("__IMG_CURSES__", b64("_preview/r595b_curses.png"))
body = body.replace("__ORPHAN__",
                    ("<p class='sub'>另有 <code>_pending/8083.png</code> 是孤儿 —— "
                     "卡库里已无 8083 这个 id，图留着不删。</p>") if orphan else "")

html = ("<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>"
        "<title>发布前素材体检 · 更正版 R595b</title><style>" + CSS + "</style></head>"
        "<body>" + body + "</body></html>")

out = os.path.join(ROOT, "_preview", "r595b_asset_audit.html")
io.open(out, "w", encoding="utf-8", newline="\n").write(html)
print(out, "%.1f MB" % (len(html.encode("utf-8")) / 1048576.0))
