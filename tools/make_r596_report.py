# -*- coding: utf-8 -*-
"""R596 交付页：除卡图之外，全项目素材盘点（真缺口 3 处 / 6 项素材）。

数字全部取自 `_preview/asset_audit.txt` 与探针实测，不手写。
"""
import base64
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def b64(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


CSS = """
*{box-sizing:border-box}
body{margin:0;padding:38px 44px 64px;background:#16161a;color:#dcdce2;
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
figure img{width:100%;max-width:700px;border:1px solid #2e2e38;border-radius:8px;display:block}
figcaption{margin-top:8px;color:#8d8d98;font-size:13px}
code{background:#232330;padding:1px 6px;border-radius:4px;font-family:Consolas,monospace;
 font-size:13px;color:#d9c88f}
"""

BODY = """
<h1>R596 · 除卡图之外，全项目素材盘点</h1>
<div class="sub">2026-11-12　口径：代码取图口逐个实测（不是猜文件名）</div>

<div class="big">
  <div class="card g"><div class="k">齐全类目</div><div class="v">14</div></div>
  <div class="card r"><div class="k">真缺口</div><div class="v">3 处 / 6 项</div></div>
  <div class="card y"><div class="k">探针实测</div><div class="v">295 项</div></div>
  <div class="card"><div class="k">孤儿图</div><div class="v">0</div></div>
</div>

<h2>一、三处真缺口</h2>
<div class="note">
卡图已经 315/316 收口（唯一空的是弃用的 9158）。剩下的缺口**不在卡图**，而是三处
「有也别扭、没有就露馅」的地方 —— 它们都不会崩、不报错，靠代码里的降级兜着，
所以之前的体检一直没抓出来。
</div>

<table>
<tr><th>缺口</th><th>影响面</th><th>现在的降级表现</th></tr>
<tr>
  <td><code>assets/ui/map_icons/boss.png</code></td>
  <td>地图上**每层的首领节点**（<code>rogue_map.LINE_TYPES</code> 含 boss）</td>
  <td>其余 9 类节点都是图标，boss 退回 <code>TYPE_MARKS</code> 的汉字「<b>王</b>」—— 同一张地图上，图标与汉字混排</td>
</tr>
<tr>
  <td><code>assets/ui/ribbon_6.png</code></td>
  <td>**4 张诅咒卡**：疲惫 9149 / 破绽 9154 / 罐子 9157 / 麻痹 9185（<code>rarity=6</code>）</td>
  <td><code>rarity_ribbon()</code> 返回 null → 回退成 9k×22k 的程序小三角旗；其他 312 张是 27k 高、带金绣燕尾的缎带素材，**尺寸差三倍**</td>
</tr>
<tr>
  <td><code>bg_bluefish / bg_delivery_done / bg_relic_chest / bg_treasure / bg_whisper</code></td>
  <td>5 个事件页（蓝鱼 / 送达完成 / 遗物宝箱 / 宝藏 / 低语）</td>
  <td>只有 <code>_add_fallback_bg()</code> 画的暗底 + 主题色光晕 + 纹章；26 类里另外 16 个有整屏插画</td>
</tr>
</table>

<h2>二、事件：26 类到底缺在哪</h2>
<figure><img src="{IMG_MATRIX}" alt="事件覆盖矩阵">
<figcaption>■ 有素材　□ 缺　— 该布局不用。金色行 = 左右布局（只吃竖版图），蓝色行 = 居中布局。</figcaption></figure>

<table>
<tr><th>层</th><th>覆盖</th><th>说明</th></tr>
<tr><td>左右布局竖版 <code>side_</code></td><td class="ok">4 / 4 齐</td><td>lake_lady / martial / rest / apple_doctor，这四个走整屏分栏，不缺</td></tr>
<tr><td>整屏背景 <code>bg_</code></td><td class="warn">16 / 26</td><td>居中布局 22 个里 16 个有；左右布局本来就不用这层</td></tr>
<tr><td>居中插图 <code>event_</code></td><td class="dim">1 / 22</td><td>只剩 <code>event_gaze</code> 一张，其余 21 个已改用整屏背景，**这一层实际已废弃**</td></tr>
<tr><td>只剩程序化底色</td><td class="bad">5</td><td>bluefish / delivery_done / relic_chest / treasure / whisper</td></tr>
<tr><td>有插图、无整屏 bg</td><td class="warn">1</td><td>gaze —— 视觉不空，但和另外 16 个带整屏插画的不统一</td></tr>
</table>

<h2>三、其余类目逐项</h2>
<table>
<tr><th>类目</th><th>覆盖</th><th>判据</th></tr>
<tr><td>卡图</td><td class="ok">315 / 316</td><td>唯一空的是弃用的 9158（<code>art_plan.json.skip</code>）</td></tr>
<tr><td>道具图标 + 边缘光</td><td class="ok">62 + 62</td><td><code>relic_icon()</code> / <code>relic_rim()</code> 全量实测</td></tr>
<tr><td>职业四件套</td><td class="ok">3 × 4 = 12</td><td>CG / 头像 / 锁定剪影 / 徽章</td></tr>
<tr><td>地图节点图标</td><td class="bad">9 / 10</td><td>缺 boss（见第一节）</td></tr>
<tr><td>地图底图 / 迷雾 / 桥</td><td class="ok">3 + 1 + 1</td><td><code>map_bg(1..3)</code>、<code>map_fog</code>、<code>bridge_icon</code></td></tr>
<tr><td>稀有度缎带</td><td class="bad">6 / 7</td><td>缺 <code>ribbon_6</code>（诅咒）</td></tr>
<tr><td>卡面艺术框</td><td class="ok">5 / 5</td><td>common / enemy / forest / mech / shadow</td></tr>
<tr><td>字段标志</td><td class="ok">10 / 10</td><td>疾行 嘲讽 死亡 幻影 护盾 次元 超负荷 交换 保存 共享护盾</td></tr>
<tr><td>数值徽章图标</td><td class="ok">5 / 5</td><td>cost / power / range / health / speed</td></tr>
<tr><td>附魔图标</td><td class="ok">7 / 7</td><td><code>ENCHANT_DEFS</code> 全量</td></tr>
<tr><td>商店 / 奖励图标</td><td class="ok">10 + 7</td><td>含 deck_delete / gold / core / legendary 等</td></tr>
<tr><td>特效图</td><td class="ok">15 / 15</td><td>全部被代码引用，无孤儿</td></tr>
<tr><td>BGM</td><td class="ok">11 / 11</td><td>槽位与 <code>.ogg</code> 一对一</td></tr>
<tr><td>字体</td><td class="ok">2 / 2</td><td>思源黑体 Regular + Bold（中文全字集）</td></tr>
<tr><td>应用图标 / 启动图</td><td class="ok">9 / 9</td><td>含安卓 legacy / fg / bg 三件与 icon.ico</td></tr>
<tr><td>音效</td><td class="ok">无素材需求</td><td><code>sfx.gd</code> 现场合成 PCM</td></tr>
</table>

<h2>四、几处「看起来缺、其实不算缺」</h2>
<table>
<tr><th>项</th><th>为什么不算缺</th></tr>
<tr><td><code>card_frame(rarity)</code> 与 <code>frame_0..6.png</code></td><td>死代码：全库只有定义、零调用（边框已由 <code>art_frame</code> + <code>ribbon</code> 承担），素材从来没进过库</td></tr>
<tr><td><code>event_pic</code>（320×240）缺 21 个</td><td>这一层已被整屏背景取代，只剩 gaze 一张历史遗留</td></tr>
<tr><td>左右布局四个事件的 <code>bg_</code></td><td>该布局不走整屏背景，走 <code>_add_fallback_bg()</code></td></tr>
<tr><td>两条 <code>res://</code> 路径「不存在」</td><td><code>map_boss.png</code> / <code>bg_rest.png</code> 是测试里的**命名断言字符串**，不是取图</td></tr>
</table>

<h2>五、附带发现：冗余（不是缺，但会影响包体）</h2>
<div class="note">
<b>待入库目录里还留着 116 张已归档的图</b>：<code>assets/pics/_pending/</code> 走的是复制不是移动，
归档后源文件仍在，而且这些 png **都有 <code>.import</code>**，会被 <code>export_filter="all_resources"</code>
一起打进包。同样情况还有根目录的 <code>_bk_pics_r595c/</code>（11 张）与 <code>_bk_pics_r595e/</code>（2 张）。<br>
实测 <code>dist/DuckCardsRogue_R563.apk</code> 已是 <b>312 MB</b>，其中 <code>assets/.godot/imported</code> 占 263 MB。
给这几个目录加 <code>.gdignore</code>（<code>_pending/raw</code> 已经这么做了）即可让它们留档但不进包。
</div>

<h2>六、工具</h2>
<table>
<tr><th>脚本</th><th>作用</th></tr>
<tr><td><code>tools/audit_release_assets.py</code></td><td>按数据表反推应有清单：卡图（三态）/ 道具 / 事件（按布局分类）/ 缎带（按卡库实际 rarity）/ 职业 / 地图 / BGM / 字面量</td></tr>
<tr><td><code>tools/audit_assets_extra.py</code></td><td>硬判据：扫全库 <code>res://assets</code> 引用逐个查存在性；孤儿图；导出过滤可疑点</td></tr>
<tr><td><code>tools/probe_all_assets.gd</code></td><td>Godot 内实测：<b>295 项</b>取图口逐个调 <code>UiAssets</code>，报 null（「文件在」≠「导出包能加载」）</td></tr>
<tr><td><code>tools/probe_all_art.gd</code></td><td>卡图专项：逐张 <code>CardFace.art_for()</code></td></tr>
</table>
"""


def main():
    html = ("<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>"
            "<title>R596 素材盘点</title><style>" + CSS + "</style></head><body>"
            + BODY.replace("{IMG_MATRIX}", b64("_preview/r596_event_matrix.png"))
            + "</body></html>")
    out = os.path.join(ROOT, "_preview", "r596_asset_gap.html")
    io.open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(html))


if __name__ == "__main__":
    main()
