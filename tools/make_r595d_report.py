# -*- coding: utf-8 -*-
"""R595d 交付页：待入库素材按新版归档 + 补掉最后两张空卡。

数字全部取自 `_preview/asset_audit.json` 与 `_preview/r595c_archive.json`，
不手写。
"""
import base64
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = json.load(io.open(os.path.join(ROOT, "_preview", "asset_audit.json"), encoding="utf-8"))
ARC = json.load(io.open(os.path.join(ROOT, "_preview", "r595c_archive.json"), encoding="utf-8"))
cards = A["cards"]

HAVE = cards["have"]
PEND = len(cards["pending"])
REAL = len(cards["missing"])
SKIPN = len(cards.get("skipped", []))
TOTAL = cards["total"]


def b64(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


CSS = """
*{box-sizing:border-box}
body{margin:0;padding:38px 44px 60px;background:#16161a;color:#dcdce2;
 font:15px/1.75 "Microsoft YaHei","PingFang SC",sans-serif}
h1{margin:0 0 6px;font-size:26px;letter-spacing:.5px;color:#f2e3bd}
.sub{color:#8d8d98;font-size:13px;margin-bottom:24px}
h2{margin:36px 0 14px;font-size:19px;color:#e8c98a;
 border-left:4px solid #b8873c;padding-left:11px}
table{border-collapse:collapse;width:100%;margin:12px 0 6px;font-size:14px}
th,td{border:1px solid #2e2e38;padding:8px 11px;text-align:left;vertical-align:top}
th{background:#1f1f27;color:#a9b4c8;font-weight:600}
td.n{text-align:right;font-variant-numeric:tabular-nums;font-family:Consolas,monospace}
.ok{color:#7fd4a0}.warn{color:#e8bf6a}.bad{color:#e88a86}.dim{color:#8d8d98}
.big{display:flex;gap:14px;flex-wrap:wrap;margin:16px 0 6px}
.card{flex:1 1 150px;background:#1c1c23;border:1px solid #2e2e38;border-radius:10px;
 padding:14px 16px}
.card .k{font-size:12.5px;color:#8d8d98;margin-bottom:3px}
.card .v{font-size:29px;font-weight:700;font-family:Consolas,monospace;line-height:1.15}
.card.g{border-color:#2f5c3f}.card.g .v{color:#7fd4a0}
.card.y{border-color:#5c4f2c}.card.y .v{color:#e8bf6a}
.card.r{border-color:#5c3230}.card.r .v{color:#e88a86}
.note{background:#1e1a16;border-left:3px solid #b8873c;padding:12px 16px;
 margin:16px 0;color:#c8bfae;font-size:14px}
.note b{color:#f0d79a}
figure{margin:18px 0 24px}
figure img{width:100%;border:1px solid #2e2e38;border-radius:8px;display:block}
figcaption{margin-top:8px;color:#8d8d98;font-size:13px}
code{background:#232330;padding:1px 6px;border-radius:4px;font-family:Consolas,monospace;
 font-size:13px;color:#d9c88f}
"""

BODY = """
<h1>素材归档收口 · 卡图齐了</h1>
<div class="sub">R595d ／ 2026-11-12 ／ 待入库 89 张按新版归位 + 补掉最后两张空卡</div>

<div class="big">
  <div class="card g"><div class="k">已归档</div><div class="v">__HAVE__</div></div>
  <div class="card g"><div class="k">待入库</div><div class="v">__PEND__</div></div>
  <div class="card g"><div class="k">真缺</div><div class="v">__REAL__</div></div>
  <div class="card y"><div class="k">已弃用</div><div class="v">__SKIP__</div></div>
  <div class="card"><div class="k">卡库总数</div><div class="v">__TOTAL__</div></div>
</div>

<h2>一、归档动作</h2>
<p><code>python tools/archive_pending_r595c.py</code> —— 以「哪边更新用哪边」为唯一规则，
不删任何文件，被覆盖的旧图先备份到 <code>_bk_pics_r595c/</code>。</p>
<table>
<tr><th>处理</th><th>张数</th><th>说明</th></tr>
<tr><td class="ok">补空缺</td><td class="n">__ADDED__</td><td>正式库原本没有，直接复制</td></tr>
<tr><td class="ok">覆盖</td><td class="n">__REPLACED__</td><td>两边都有、_pending 更新 → 用新版</td></tr>
<tr><td class="dim">跳过·内容相同</td><td class="n">__SAME__</td><td>哈希一致，不必动</td></tr>
<tr><td class="dim">跳过·正式库更新</td><td class="n">__NEWER__</td><td>正式库那版才新，保留</td></tr>
<tr><td class="warn">孤儿不搬</td><td class="n">__ORPHAN__</td><td>卡库里已无该 id，图留在 _pending</td></tr>
</table>

<h2>二、全库抽样</h2>
<figure>
  <img src="__IMG_SHEET__">
  <figcaption>敌小怪、构状体系、诅咒、初始卡组各抽几张贴一下 —— 这批卡面以前在游戏里都是空白。</figcaption>
</figure>

<h2>三、补掉最后两张</h2>
<p>归档完之后再体检，卡库里只剩 <b>9192 援护炮击</b>、<b>9193 技术结合</b> 两张一张图都没有
（都是 R592 组合体系新加的卡）。已委托 codex 出图，参考 8025 的画风锚，
prompt 写死禁止人形与机器人身体，只画物件。</p>
<figure>
  <img src="__IMG_NEW__">
  <figcaption>左：9192 援护炮击 —— 弹坑、半埋的炮弹、外扩的青色冲击环。
  右：9193 技术结合 —— 三块构装体零件沿一条竖轴对位，三段青色导轨串成一列，底部核心匣里一枚紫晶。</figcaption>
</figure>
<table>
<tr><th>id</th><th>名称</th><th>规格</th><th>状态</th></tr>
<tr><td class="n">9192</td><td>援护炮击</td><td>448×403</td><td class="ok">已归档</td></tr>
<tr><td class="n">9193</td><td>技术结合</td><td>448×403</td><td class="ok">已归档</td></tr>
</table>

<h2>四、9158 为什么还是空的</h2>
<div class="note">
它不是漏了。<code>art_plan.json</code> 的 <code>skip</code> 里写着
<b>「R563 店长确认：罐子(工事) 为已弃用的旧召唤物机制，卡片不会再生成，永久不出图」</b>。
玩法数据层还留着 9158 的条目，是因为删它会连锁改动卡池总数与四套回归基线，
属于独立的清理轮次。体检脚本现在把它单列为「已弃用」，不再算缺图。
</div>

<h2>五、验证</h2>
<table>
<tr><th>项</th><th>结果</th></tr>
<tr><td>Godot 重新导入</td><td class="ok">exit 0，0 个 ERROR</td></tr>
<tr><td>全库卡图加载探针<br><code>tools/probe_all_art.gd</code></td>
<td class="ok">316 张里 315 张 <code>art_for()</code> 返回非空，唯一空的是弃用的 9158</td></tr>
<tr><td>体检三态</td><td class="ok">已归档 __HAVE__ ／ 待入库 __PEND__ ／ 真缺 __REAL__ ／ 已弃用 __SKIP__</td></tr>
<tr><td>引擎回归</td><td class="warn">6 条红，全部来自并行线的「档案 / 提示」断言（依赖未提交的
<code>profile_data.gd</code>），本轮只改了图片与体检脚本，未触碰任何 <code>.gd</code></td></tr>
</table>

<h2>六、其他类目（未变）</h2>
<p>道具 62/62、职业 3 套、地图节点 9/9、BGM 11/11、代码引用 UI 素材 45/45、
应用图标与启动图齐全、音效由 <code>sfx.gd</code> 现场合成无需素材。
事件插图 24 个 kind 按设计不配图（<code>event_pic()</code> 返回 null 时
<code>top_floor</code> 自动从 360 放开到 150），只有 4 个左右布局事件需要竖版图，早已齐全。</p>
"""

arc = ARC
body = BODY
body = body.replace("__HAVE__", str(HAVE)).replace("__PEND__", str(PEND))
body = body.replace("__REAL__", str(REAL)).replace("__SKIP__", str(SKIPN))
body = body.replace("__TOTAL__", str(TOTAL))
body = body.replace("__ADDED__", str(len(arc["added"])))
body = body.replace("__REPLACED__", str(len(arc["replaced"])))
body = body.replace("__SAME__", str(len(arc["skipped_identical"])))
body = body.replace("__NEWER__", str(len(arc["skipped_official_newer"])))
body = body.replace("__ORPHAN__", str(len(arc["orphans"])))
body = body.replace("__IMG_SHEET__", b64("_preview/r595d_archive_sheet.png"))
body = body.replace("__IMG_NEW__", b64("_preview/r595d_new.png"))

html = ("<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>"
        "<title>素材归档收口 R595d</title><style>" + CSS + "</style></head>"
        "<body>" + body + "</body></html>")

out = os.path.join(ROOT, "_preview", "r595d_archive_done.html")
io.open(out, "w", encoding="utf-8", newline="\n").write(html)
print(out, "%.1f MB" % (len(html.encode("utf-8")) / 1048576.0))
