# -*- coding: utf-8 -*-
"""R592 交付页：把 10 个字段标志 + 卡面截图 + 图鉴截图拼成一份 base64 内嵌的 HTML。

⚠️ 图片一律 base64 内嵌（项目纪律：交付图片必须能在单文件里直接看，不依赖相对路径）。
"""
import base64
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_字段标志_R592"
PROC = D / "processed"
REVIEW = D / "_review"
FONT = ROOT / "assets" / "fonts" / "SourceHanSansCN-Bold.otf"
FONT_R = ROOT / "assets" / "fonts" / "SourceHanSansCN-Regular.otf"

GLYPHS = [("run", "疾行"), ("taunt", "嘲讽"), ("death", "死亡"), ("ghost", "幻影"),
          ("shield", "护盾"), ("portal", "次元"), ("overload", "超负荷"),
          ("swap", "交换（卡面不画）"), ("save", "保存"), ("share", "共享护盾")]
BG = "#f4ecdc"


def b64(p: Path) -> str:
    return base64.b64encode(p.read_bytes()).decode("ascii")


def make_sheet() -> Path:
    """5 列 × 2 行总览：每个标志画在深色卡图底色上 + 中文名。"""
    cell_w, cell_h = 190, 210
    cols, rows = 5, 2
    im = Image.new("RGB", (cell_w * cols, cell_h * rows), "#1d3a26")
    dr = ImageDraw.Draw(im)
    f_name = ImageFont.truetype(str(FONT), 26)
    f_small = ImageFont.truetype(str(FONT_R), 17)
    for i, (g, label) in enumerate(GLYPHS):
        cx = (i % cols) * cell_w
        cy = (i // cols) * cell_h
        # 交替深浅底，模拟不同卡图
        shade = "#1d3a26" if (i + i // cols) % 2 == 0 else "#2b2a36"
        dr.rectangle([cx, cy, cx + cell_w - 1, cy + cell_h - 1], fill=shade)
        icon = Image.open(PROC / ("affix_%s.png" % g)).convert("RGBA")
        icon = icon.resize((118, 118), Image.LANCZOS)
        im.paste(icon, (cx + (cell_w - 118) // 2, cy + 26), icon)
        tw = dr.textlength(label, font=f_name)
        dr.text((cx + (cell_w - tw) / 2, cy + 152), label, font=f_name, fill="#f3efe4")
        key = "affix_%s.png" % g
        tw2 = dr.textlength(key, font=f_small)
        dr.text((cx + (cell_w - tw2) / 2, cy + 182), key, font=f_small, fill="#9aa79b")
    out = REVIEW / "sheet.png"
    im.save(out)
    return out


def make_compare() -> Path:
    """同一张卡：改前（文字行写字段 + 左下角力+1 角标）vs 改后（右上标志）。
    改前用「矢量 glyph + 文字」近似复刻，只用于说明差异。"""
    base = Image.open(REVIEW / "cards.png")
    return base


def main():
    REVIEW.mkdir(parents=True, exist_ok=True)
    sheet = make_sheet()
    cards = REVIEW / "cards.png"
    gallery = REVIEW / "gallery.png"

    rows = []
    for g, label in GLYPHS:
        rows.append(
            '<div class="b"><img src="data:image/png;base64,%s"><div class="n">%s</div>'
            '<div class="f">affix_%s.png</div></div>' % (b64(PROC / ("affix_%s.png" % g)), label, g))

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R592 字段标志化 · 卡面右上圆形槽位</title>
<style>
  :root{--paper:#f4ecdc;--card:#fffdf7;--ink:#3a2e1e;--dim:#8a7a63;--line:#d8c8a8;
        --brown:#5b4326;--gold:#a8792a;--dimension:#8e3fae}
  *{box-sizing:border-box}
  body{margin:0;padding:32px 20px 64px;background:radial-gradient(circle at 20%% 0%%,#fbf6ea 0%%,var(--paper) 45%%,#e9dcc4 100%%);
       color:var(--ink);font-family:"Noto Serif SC","Songti SC","SimSun",serif;line-height:1.75;font-size:15px}
  .wrap{max-width:1180px;margin:0 auto}
  header{border-bottom:2px solid var(--brown);padding-bottom:18px;margin-bottom:26px}
  h1{margin:0 0 6px;font-size:27px;letter-spacing:.04em}
  .sub{color:var(--dim);font-size:13.5px}
  .sub b{color:var(--brown)}
  h2{font-size:19px;margin:36px 0 14px;padding-left:11px;border-left:4px solid var(--gold)}
  h3{font-size:15.5px;margin:18px 0 8px}
  code{font-family:ui-monospace,Consolas,monospace;font-size:12.5px;background:#efe5d0;padding:1px 5px;border-radius:4px}
  .lead{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 18px}
  .lead p{margin:0 0 8px} .lead p:last-child{margin:0}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}
  .b{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px;text-align:center}
  .b img{width:96px;height:96px}
  .b .n{font-size:15px;font-weight:700;margin-top:2px}
  .b .f{font-family:ui-monospace,Consolas,monospace;font-size:11px;color:var(--dim)}
  figure{margin:14px 0 0}
  figure img{width:100%%;border:1px solid var(--line);border-radius:10px;display:block}
  figcaption{font-size:12.5px;color:var(--dim);margin-top:6px}
  table{width:100%%;border-collapse:collapse;background:var(--card);border:1px solid var(--line);
        border-radius:10px;overflow:hidden;font-size:13.5px}
  th,td{padding:9px 12px;text-align:left;border-bottom:1px solid var(--line);vertical-align:top}
  th{background:#f2e8d4;font-size:13px;letter-spacing:.04em}
  tr:last-child td{border-bottom:none}
  .ok{background:#eef7ee;border-left:3px solid #2f7d4f;padding:10px 14px;border-radius:0 6px 6px 0;margin:14px 0;font-size:13.5px}
  .note{background:#fdf1e6;border-left:3px solid #a8322a;padding:10px 14px;border-radius:0 6px 6px 0;margin:14px 0;font-size:13.5px}
  .note b{color:#a0401a}
  ul{margin:8px 0 0;padding-left:20px} li{margin-bottom:6px}
  footer{margin-top:40px;padding-top:14px;border-top:1px dashed var(--line);color:var(--dim);font-size:12.5px}
</style></head><body><div class="wrap">

<header>
  <h1>R592 · 字段标志化<span style="font-size:15px;color:#8a7a63;font-weight:400">　（R592c 修订：次元→漩涡、交换不上卡面）</span></h1>
  <div class="sub">所有贴在卡上的 buff 不再用纯文字：卡面<b>右上角一个圆形槽位</b>，多字段<b>轮流显示</b>；
    +力 / +生命 从卡面撤掉，只留在<b>详细描述</b>里。</div>
</header>

<div class="lead">
  <p>标志是 10 张 codex 生成的圆形徽章，统一「<b>深色圆底 + 亮色符号 + 粗黑描边</b>」，
     配色直接取 <code>AFFIX_DEFS</code> 里每个字段的语义色 —— 所以它们看起来是一套。</p>
  <p>槽位<b>让开右上角的稀有度缎带</b>（那东西占最右沿约 8.1×k 宽、27×k 高），两者并排不打架；
     尺寸跟数值徽章同一口径（<code>CARD_BADGE_SCALE_CAP</code>），大卡上不会长成一颗巨球。</p>
</div>

<h2>一、十个标志（九个上卡面）</h2>
<div class="grid">%s</div>
<figure><img src="data:image/png;base64,%s"><figcaption>十个标志在深色卡图底上的实际观感（5×2）。
  最后一排第三个「交换」是<b>备用素材</b>：卡面不出它（R592c），素材留着不代表会画出来。</figcaption></figure>

<h2>二、卡面实拍</h2>
<figure><img src="data:image/png;base64,%s">
<figcaption>上排：只有交换（<b>槽位整个不出现</b>）/ 1 个字段「次元·漩涡」/ 2 个字段 / 3 个字段；
下排：同一张 3 字段卡在 t=1.8s / t=3.6s 的样子，以及「战场模式」（交换被过滤，只剩嘲讽）。
注意卡名下面那行<b>已经没有字段名了</b>，左下角也<b>没有「力+1」角标</b>了。</figcaption></figure>

<figure><img src="data:image/png;base64,%s">
<figcaption>图鉴实机：玩家卡牌 241 张里，带 2 个字段的卡（魔像 / 城墙 / 钢铁卫士 / 忒修斯奇械等）
在网格小卡上也能认出标志。</figcaption></figure>

<h2>三、具体规则</h2>
<table>
  <thead><tr><th style="width:20%%">项</th><th>口径</th></tr></thead>
  <tbody>
    <tr><td><b>位置</b></td><td>卡面右上角。槽位是<b>正方形</b>（外接圆 = 圆形区域），
        右沿卡在缎带左边 2×k 处，上下与卡图区间距一致。没有额外画圆形外框 —— 标志自带的圆底就是那个圆。</td></tr>
    <tr><td><b>尺寸</b></td><td>直径 = <code>20 × min(k, 2.2)</code>。手牌 / 战场 / 图鉴三种尺寸下都与数值徽章同级；
        448×403 的大卡不会明显放大。</td></tr>
    <tr><td><b>轮播</b></td><td>每个字段停留 <b>1.8s</b>，最后 240ms 交叉淡化到下一张，末尾环形接回第一张。
        只有一个字段时<b>不轮播</b>（恒显，无淡化）。</td></tr>
    <tr><td><b>战场过滤</b></td><td>沿用 <code>affix_on_board()</code>：幻影上场后不再显示 ——
        与原来那行文字的口径完全一致，没有另起一套判断。</td></tr>
    <tr><td><b>交换</b></td><td><b>卡面一律不出图标</b>（R592c）。它描述的是「放下之前怎么放」，
        卡已经在你手里时一个图标给不出这个信息 —— 所以卡面不画它，只保留在悬停浮层的字段说明里。
        字段本身与引擎判定完全没有变化。只有「交换」一个字段的卡，整个槽位都不会出现（不留空圆）。</td></tr>
    <tr><td><b>次元</b></td><td>图标是<b>漩涡</b>（四条螺旋臂向内收束），不再是菱形框 —— 前者读起来像「被卷走」，
        后者容易和宝石 / 传送门混淆。</td></tr>
    <tr><td><b>+力 / +生命</b></td><td>卡面<b>不再显示</b>成长角标（原来画在卡图左下角）。
        数值本身照旧按「比原型高」染色；具体加了多少去<b>详细描述</b>的「本局永久成长　力+1 生+6」那段看。</td></tr>
    <tr><td><b>缺图回退</b></td><td>标志素材读不到时（没导入 / 导出包异常）回退成「语义色圆底 + 矢量符号」，
        照常可玩，不空白也不报错。</td></tr>
  </tbody>
</table>

<h2>四、范围说明</h2>
<ul>
  <li><b>没动的</b>：商店附魔标记（左上角那条竖列，本来就有自己的图标）、组合印记（费用下方那格）、
      战场左栏的字段说明行（那是信息面板，不是卡面）。</li>
  <li><b>文字接口保留</b>：<code>CardData.affix_line()</code> / <code>field_affix_line()</code> 仍在，
      悬停浮层、战场徽标、回归断言都还在用它们 —— 只是卡面不画了。</li>
  <li><b>轮播只会在会重绘的界面动</b>：战斗页有 22Hz 的节拍，正常转；图鉴 / 牌库 / 奖励三选一是静态页，
      多字段卡会停在第一张。全库只有 <b>6 张</b>卡带 2 个字段（没有 3 个以上），影响面很小 ——
      要它们也转，得给那几个场景挂一个低频重绘节拍，说一声我就加。</li>
</ul>

<div class="ok"><b>回归（六套全绿）：</b>assemble <b>0✗</b> · mana <b>PASS</b> ·
  engine <b>5728✓ / 0✗</b>（R592b 22 条 + R592c 4 条）· reward <b>26✓</b> · bgm <b>39✓</b> · smoke <b>68✓ / 0✗</b>。
  新增断言覆盖：槽位是正方形 / 在卡框内 / 右沿不越缎带 / 战场过滤 / 三字段 1.8s 轮播回到第一张 /
  单字段不轮播 / 文字区不再写字段 / 卡面不再画成长角标 / 详细描述仍写成长 / 每个字段都有 glyph 名；
  R592c 另加：交换在手牌也不出图标 / 只有交换的卡不画槽位 / 幻影口径没被顺带削掉 /
  卡面不出图标的字段有且仅有「交换」。</div>

<div class="note"><b>一处保留判断：</b>你说「一行也可以显示多于一个标志」「有多个则轮流显示」——
  这两句我按<b>后者</b>实现（同一时刻一个，轮流切换）。如果你其实想要<b>并排显示 2 个</b>（超过 2 个再轮播），
  告诉我，我把槽位改成横向双格。</div>

<footer>R592 · 新素材 <code>assets/ui/affix_&lt;glyph&gt;.png</code> ×10（128×128 RGBA）·
  改动 <code>scripts/ui_assets.gd</code> / <code>scripts/card_face.gd</code> /
  <code>scripts/card_data.gd</code> / <code>scripts/test_engine.gd</code> ·
  出图管线 <code>art_src/2026-11-11_字段标志_R592/</code></footer>

</div></body></html>""" % (
        "".join(rows),
        b64(sheet),
        b64(cards),
        b64(gallery),
    )
    out = ROOT / "_preview" / "r592_affix_badges.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print("交付页：", out, "%.1f KB" % (len(html) / 1024))


if __name__ == '__main__':
    main()
