# -*- coding: utf-8 -*-
"""R595e 交付页：援护炮击重画 + 技术结合按「核心装进构装体」重出。

数字取自 `_preview/asset_audit.json`，不手写。
"""
import base64
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = json.load(io.open(os.path.join(ROOT, "_preview", "asset_audit.json"), encoding="utf-8"))
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
.pair{display:flex;gap:16px;flex-wrap:wrap}
.pair figure{flex:1 1 340px;margin:10px 0}
"""

BODY = """
<h1>R595e · 援护炮击重画 / 技术结合按新思路重出</h1>
<div class="sub">2026-11-12　codex 纯文生图　448×403 已归档</div>

<div class="big">
  <div class="card g"><div class="k">已归档</div><div class="v">{HAVE}</div></div>
  <div class="card y"><div class="k">待入库</div><div class="v">{PEND}</div></div>
  <div class="card r"><div class="k">真缺</div><div class="v">{REAL}</div></div>
  <div class="card"><div class="k">已弃用</div><div class="v">{SKIPN}</div></div>
</div>

<h2>一、9192 援护炮击 · 三次演进</h2>
<figure><img src="{IMG_9192_EVOLVE}" alt="9192 三次演进">
<figcaption>① 炮弹立在坑里　② 斜插地面（成了坠地导弹）　③ 聚焦火炮开火（采用）　最右为已存在的 9241 激光巨炮，用于比对区分度</figcaption></figure>

<div class="note">
第一版把「炮击」画成了<b>爆炸之后的现场</b>：一枚炮弹安静地立在坑中央，外圈一道均匀青色细环，读起来像罐子加魔法阵。<br>
第二版改成命中瞬间，为了不让弹体被读成柱子而加了尾翼 —— 结果<b>成了坠地导弹</b>。这两版的共同错误是：
<b>画面里只有弹、没有炮</b>，而「援护炮击」的主角本来就是那门开火的炮。
</div>

<table>
<tr><th>项</th><th>① 立在坑里</th><th>② 斜插地面</th><th>③ 聚焦火炮（定稿）</th></tr>
<tr><td>主体</td><td>一枚炮弹</td><td>一枚带尾翼的弹体</td><td><b>整门火炮</b>，炮身占画面约 80%</td></tr>
<tr><td>动作</td><td>静止</td><td>命中瞬间</td><td>开火那一瞬：橙白爆焰 + 后坐筒已沿导轨退开</td></tr>
<tr><td>读作什么</td><td>罐子 + 魔法阵</td><td>坠地导弹</td><td>一尊重炮正在为别处提供火力支援</td></tr>
<tr><td>构图</td><td>主体占一半、四周空旷</td><td>主体组 70%</td><td>低机位斜前视，炮口在右上三分之一，底座略微出血</td></tr>
</table>

<div class="note">
<b>需要你定夺的一点</b>：这一版和已存在的 <code>9241 激光巨炮</code>（敌方工事）在<b>方形钢基座、深蓝灰配青色、粗管朝向</b>上偏近。
区别是 9241 为水平正侧视、无开火、后部有大片青色叶轮；本卡为斜前视上扬、正在开火、带后坐装置。
若你觉得两张放一起太像，可以把 9192 改成<b>履带式自行火炮</b>（两根宽履带 + 炮盾，去掉方形基座）或换<b>钢白装甲配色</b>，我按你说的再出一版。
</div>

<h2>二、9193 技术结合 · 按「把构装体核心放进构装体」重出</h2>
<div class="note">
造型不是我拟的 —— 参考图锁定 <code>8026 构装体</code>：黄铜土黄装甲板、深灰内构关节、板缘一圈小铆钉、
圆润铆边肩甲、尖顶方头暗色面罩、胸口一枚<b>青色发光圆球嵌在细密同心车削环座里</b>。
prompt 里要求复制这套构造语言，只换构图、姿态、背景与光照。
</div>
<div class="pair">
  <figure><img src="{IMG_9193_V1}" alt="9193 v1"><figcaption>v1：核心飘在胸甲左外侧 —— 像「递过去」，不是「装进去」</figcaption></figure>
  <figure><img src="{IMG_9193_V2}" alt="9193 v2"><figcaption>v2（采用）：核心与胸槽同心，两片胸甲 V 形外翻，双臂持握</figcaption></figure>
</div>
<table>
<tr><th>项</th><th>v1</th><th>v2（定稿）</th></tr>
<tr><td>核心位置</td><td>贴在胸外左侧，与槽口错开</td><td>与槽口同心，只差半个核心直径，压住洞口前缘</td></tr>
<tr><td>胸甲</td><td>只见一个大洞，翻开关系不清</td><td>左右两片对称外翻成 V 形，内壁受青光照亮</td></tr>
<tr><td>装配臂</td><td>一只，位置偏下</td><td>两只，一左一右，末端三指卡爪</td></tr>
</table>

<h2>三、手牌实际尺寸（88px 宽插画区）</h2>
<figure><img src="{IMG_SMALL}" alt="手牌尺寸对比">
<figcaption>每行左侧 448px 原图、右侧缩到 88px。新版两张在手机手牌上仍能读出「斜插的弹体」与「胸口的青色圆核」。</figcaption></figure>

<h2>四、验证</h2>
<table>
<tr><th>项</th><th>结果</th></tr>
<tr><td>素材体检</td><td class="ok">已归档 {HAVE} / 待入库 {PEND} / 真缺 {REAL} / 已弃用 {SKIPN}（9158）</td></tr>
<tr><td>全库取图探针</td><td class="ok">ART_TOTAL n=316 ok=315 missing=1（唯一空的是弃用的 9158）</td></tr>
<tr><td>六套回归</td><td class="ok">assemble 0 / mana PASS / engine 5738✓ 0✗ / reward 26 / bgm 39 / smoke 68</td></tr>
<tr><td>Godot 导入</td><td class="ok">exit=0，0 条 ERROR</td></tr>
<tr><td>旧图留档</td><td><code>_bk_pics_r595e/9192.png</code>、<code>9193.png</code>；v1 原图在 <code>art_src/2026-11-12_重画与结合_R595e/raw/</code></td></tr>
</table>
"""

TOPIC = "r595e_art_redraw"


def main():
    html = (
        "<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>"
        "<title>R595e 卡图重画</title><style>" + CSS + "</style></head><body>"
        + BODY.replace("{HAVE}", str(HAVE))
              .replace("{PEND}", str(PEND))
              .replace("{REAL}", str(REAL))
              .replace("{SKIPN}", str(SKIPN))
              .replace("{IMG_9192_EVOLVE}", b64("_preview/r595e_9192_evolve.png"))
              .replace("{IMG_9193_V1}", b64("_preview/r595e_9193_v1.png"))
              .replace("{IMG_9193_V2}", b64("assets/pics/9193.png"))
              .replace("{IMG_SMALL}", b64("_preview/r595e_small.png"))
        + "</body></html>"
    )
    out = os.path.join(ROOT, "_preview", TOPIC + ".html")
    io.open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(html))


if __name__ == "__main__":
    main()
