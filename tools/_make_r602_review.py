# -*- coding: utf-8 -*-
"""R602 验收页：把三张实拍图 base64 内嵌进单页 HTML（可直接发给店长看）。"""
import base64
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIC = os.path.join(ROOT, "_preview", "r602")
OUT = os.path.join(PIC, "r602_review.html")


def b64(name):
    with open(os.path.join(PIC, name), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


ROWS = [
    ("图鉴 · 卡牌详情", "卡名 Label 固定 236px 宽、不折行不裁切；长卡名实测 330px，直接画到右侧面板框线外",
     "Label 先量框再写字：236px 放不下就缩字号（20→14），缩到底才裁（clip_text）"),
    ("图鉴 · 卡面姓名牌", "文字区下界没让开底部数值徽章，卡名整行骑在力量 / 生命徽章上；基线用字体 ascent，"
     "而该 FontFile 的 ascent 按字号跳变（10px 返回 30、17px 返回 34），越缩越往下压",
     "下界改取 `text_zone_bottom()`（徽章带顶），基线按字号比例 0.88em 定位并夹在下界内"),
    ("战斗 · 左栏详情", "内容从面板 +10 / +24 起，而九宫格面板四角各有 34px 木框边饰 —— 卡名与"
     "「技能 · 费用」直接压在左边框花纹上",
     "内容安全区按边饰内缩（左 44 / 右 34 / 上 54），卡名 · 费用 · 词条三行再按栏宽缩字号"),
    ("选卡 / 组合 · 详情浮层", "卡名、种类、数值、成长行都是单行 draw_string，超宽只裁尾巴",
     "全部先问 `fit_font_size()` 要字号；效果正文改「先折行再缩字号」"),
    ("卡组浏览 · 详情", "同上，且效果文写死 7 行、末行「卡组中共 N 张」可能落到面板外",
     "同一套缩字号 + 末行夹进框内"),
    ("事件 · 正文", "Desc 是 Label，长文案会把 VBox 撑高，末位选项被挤出屏幕",
     "统一挂 `_fit_event_text()`：先缩字号（16→10），缩到底才裁"),
    ("战斗 · 顶栏状态", "固定 180px 单行，长消息直接省略尾部（实测 302px 被截 122px）",
     "缩字号（17→10）把整句塞进去，缩到底才省略"),
]

cards = []
for i, (title, bad, fix) in enumerate(ROWS, 1):
    cards.append(
        '<div class="row"><div class="no">%02d</div><div class="body">'
        '<div class="t">%s</div>'
        '<div class="bad"><b>原来</b>%s</div>'
        '<div class="fix"><b>现在</b>%s</div>'
        '</div></div>' % (i, title, bad, fix)
    )

HTML = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R602 框内文字体检</title>
<style>
:root{--paper:#f3eee2;--ink:#2a2622;--muted:#6b6355;--line:#d9cfba;--brass:#b99a5e;--green:#3f7a4a;}
*{box-sizing:border-box;}
body{margin:0;background:#1c1a17;color:var(--ink);
 font-family:"Source Han Sans CN","Microsoft YaHei",system-ui,sans-serif;}
.wrap{max-width:1120px;margin:0 auto;padding:34px 26px 60px;}
h1{color:#f0e9da;font-size:26px;letter-spacing:2px;margin:0 0 6px;}
.sub{color:#a89d88;font-size:13px;margin-bottom:26px;}
.panel{background:var(--paper);border:1px solid var(--brass);border-radius:14px;
 padding:22px 24px;margin-bottom:22px;}
h2{font-size:17px;margin:0 0 12px;padding-left:10px;border-left:4px solid var(--green);}
.row{display:flex;gap:14px;padding:11px 0;border-bottom:1px dashed var(--line);}
.row:last-child{border-bottom:0;}
.no{flex:0 0 34px;color:var(--brass);font-weight:700;font-size:13px;padding-top:2px;}
.t{font-weight:700;font-size:14px;margin-bottom:4px;}
.bad,.fix{font-size:13px;line-height:1.65;color:var(--muted);}
.bad b,.fix b{display:inline-block;min-width:38px;font-size:12px;
 padding:1px 6px;border-radius:4px;margin-right:8px;color:#fff;font-weight:600;}
.bad b{background:#9a5b4b;}
.fix b{background:var(--green);}
.shot{margin:0 0 18px;}
.shot img{width:100%;display:block;border:1px solid var(--brass);border-radius:10px;}
.cap{font-size:12px;color:var(--muted);margin-top:7px;}
.kpi{display:flex;gap:14px;flex-wrap:wrap;margin-bottom:8px;}
.k{background:#fffdf7;border:1px solid var(--line);border-radius:10px;padding:12px 16px;min-width:150px;}
.k .n{font-size:22px;font-weight:700;color:var(--green);}
.k .l{font-size:12px;color:var(--muted);margin-top:2px;}
code{background:#e8e1d0;padding:1px 5px;border-radius:4px;font-size:12px;}
.note{font-size:12px;color:var(--muted);line-height:1.7;margin-top:10px;}
</style></head><body><div class="wrap">
<h1>R602 · 框内文字体检</h1>
<div class="sub">「所有有框的，文字会不会和外框重叠？文字太多会不会溢出？」——先量框，再写字。</div>

<div class="panel">
<h2>实测口径</h2>
<div class="kpi">
 <div class="k"><div class="n">19 / 19</div><div class="l">场景实例化成功</div></div>
 <div class="k"><div class="n">82</div><div class="l">带框 Label（70 个有文本）</div></div>
 <div class="k"><div class="n">94</div><div class="l">按钮（93 个有文本）</div></div>
 <div class="k"><div class="n">0</div><div class="l">当前溢出项</div></div>
</div>
<div class="note">探针 <code>tools/probe_ui_text.gd</code>：逐个实例化场景，按真实字体与真实布局量
「文本占位 vs 控件矩形」，不靠读代码猜。批量出图 <code>tools/_shot_scenes.gd</code> 覆盖 13 个界面。</div>
</div>

<div class="panel"><h2>本次修掉的七处</h2>__CARDS__</div>

<div class="panel"><h2>实拍核验</h2>
<div class="shot"><img src="__IMG1__"><div class="cap">图鉴详情 · 最长卡名「量产型阿斯克勒庇厄斯（#9207）」：完整落在右侧框内（原来 330px 顶穿 236px 的框）</div></div>
<div class="shot"><img src="__IMG2__"><div class="cap">战斗左栏 · 卡名 / 费用 / 词条：全部让开木框边饰，不再压在花纹上</div></div>
<div class="shot"><img src="__IMG3__"><div class="cap">选卡 / 组合的卡牌详情浮层：卡名与正文都在面板内，效果文放不下时先缩字号</div></div>
</div>

<div class="panel"><h2>回归</h2>
<div class="note">assemble 0 失败 · mana PASS · engine 5765✓ / 0✗ · reward 26✓ · bgm 39✓ · smoke 68✓ / 0✗。
新增源码锁 4 条（<code>test_assemble</code>），防止「缩字号」与「让开徽章」被改回去。</div>
</div>

</div></body></html>"""

HTML = HTML.replace("__CARDS__", "".join(cards))
HTML = HTML.replace("__IMG1__", b64("gallery_longname.png"))
HTML = HTML.replace("__IMG2__", b64("battle_info.png"))
HTML = HTML.replace("__IMG3__", b64("detail_overlay.png"))
with open(OUT, "w", encoding="utf-8") as f:
    f.write(HTML)
print("written", OUT, os.path.getsize(OUT))
