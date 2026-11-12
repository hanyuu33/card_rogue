"""R611 交付页：UI/背景纹理 71.8MB 该怎么瘦。

数据全部来自导出 PCK 实测（174.9MB / 1564 文件），不是按目录体积估的。
注意：模板里不要用 % 或 .format 拼 HTML（CSS 里的 % 会被当格式符），统一用 @@N@@ 占位。
"""
import base64
import io
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "_preview", "r611_tex_decide.html")


def b64(rel):
    p = os.path.join(ROOT, rel)
    raw = open(p, "rb").read()
    if len(raw) > 300 * 1024:
        bio = io.BytesIO()
        Image.open(p).convert("RGB").save(bio, "JPEG", quality=90, optimize=True)
        return "image/jpeg", base64.b64encode(bio.getvalue()).decode("ascii")
    return "image/png", base64.b64encode(raw).decode("ascii")


def img(rel, cap):
    mime, data = b64(rel)
    return ('<figure><img alt="' + cap + '" src="data:' + mime + ';base64,' + data +
            '"><figcaption>' + cap + '</figcaption></figure>')


def bar(label, mb, total, color):
    pct = mb / total * 100.0
    return ('<div class="br"><span class="bl">' + label + '</span>'
            '<span class="bt"><i style="width:{:.1f}%;background:{}"></i></span>'
            '<span class="bv">{:.1f} MB</span></div>').format(pct, color, mb)


TPL = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R611 · UI/背景 71.8MB 怎么处理</title>
<style>
:root{--bg:#15130f;--pn:#1d1a15;--br:#3a332a;--gold:#c69a4a;--tx:#e6ddcc;--dim:#a09580;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);
 font:16px/1.75 "Source Han Sans CN","Noto Sans SC","Microsoft YaHei",sans-serif;}
.wrap{max-width:1080px;margin:0 auto;padding:48px 28px 96px}
h1{font-size:30px;margin:0 0 6px;letter-spacing:.03em}
h2{font-size:21px;margin:46px 0 14px;padding-bottom:8px;border-bottom:1px solid var(--br);color:var(--gold)}
h3{font-size:17px;margin:26px 0 8px;color:#d9c9a4}
p{margin:10px 0}
.sub{color:var(--dim);font-size:14px;margin-bottom:28px}
.lead{background:var(--pn);border-left:3px solid var(--gold);padding:18px 20px;margin:22px 0}
.lead b{color:var(--gold)}
table{width:100%;border-collapse:collapse;margin:14px 0;font-size:14.5px}
th,td{padding:9px 10px;border-bottom:1px solid var(--br);text-align:left;vertical-align:top}
th{color:var(--gold);font-weight:600;font-size:13px;letter-spacing:.05em}
td.n{font-variant-numeric:tabular-nums;white-space:nowrap}
.br{display:flex;align-items:center;gap:12px;margin:7px 0;font-size:14px}
.bl{width:232px;flex:none;color:var(--dim)}
.bt{flex:1;height:16px;background:#241f19;border-radius:2px;overflow:hidden}
.bt i{display:block;height:100%}
.bv{width:96px;flex:none;text-align:right;font-variant-numeric:tabular-nums}
figure{margin:18px 0;background:var(--pn);border:1px solid var(--br);padding:12px}
figure img{width:100%;display:block}
figcaption{color:var(--dim);font-size:13px;margin-top:9px}
.ok{color:#8fbf8f}.warn{color:#d99a5b}.bad{color:#d97a6a}
code{background:#241f19;padding:1px 5px;border-radius:2px;font-size:13.5px;color:#d9c9a4}
footer{margin-top:52px;padding-top:18px;border-top:1px solid var(--br);color:var(--dim);font-size:12.5px}
</style></head><body><div class="wrap">

<h1>UI / 背景这 71.8MB，怎么处理</h1>
<div class="sub">R611 · 导出 PCK 实测 174.9MB / 1564 文件 · 2026-11-12</div>

<div class="lead">
<b>先说一件事：我上一条给的预估是错的。</b><br>
上一轮我说「UI/背景 133MB，同口径压缩预计 −40~50MB」。这次真去算才发现，
<b>给这批图开 VRAM 压缩（ASTC）反而会让包变大 20MB</b> —— 328 张里只有 108 张能省，
剩下 220 张压缩后比现在的 PNG 还大。原因是这批图原本的 PNG 编码已经很省（大面积平涂 + 大量透明），
而 ASTC 4×4 是固定 1 字节/像素，不吃这一套。<br>
省下来的空间在<b>分辨率</b>里，不在压缩算法里。
</div>

<h2>一、包里到底装了什么</h2>
@@0@@
<p class="sub" style="margin-top:14px">卡图 320 张已经做过 ASTC（55.5MB），是上一轮的成果；
UI/背景 328 张仍是未压缩 PNG（71.8MB），就是你问的这一块。</p>

<h2>二、为什么「压缩」这条路不通</h2>
<table>
<tr><th>图</th><th>现在占</th><th>改 ASTC 4×4 后</th><th>结果</th></tr>
<tr><td>panel_parchment 1536²</td><td class="n">2.62 MB</td><td class="n">2.25 MB</td><td class="ok">省 0.37</td></tr>
<tr><td>title_art 1920×1080</td><td class="n">2.32 MB</td><td class="n">1.98 MB</td><td class="ok">省 0.34</td></tr>
<tr><td>bg_curtain 1600×900</td><td class="n">1.93 MB</td><td class="n">1.37 MB</td><td class="ok">省 0.56</td></tr>
<tr><td>map_icons/battle 1254²</td><td class="n">0.72 MB</td><td class="n">1.50 MB</td><td class="bad">涨 0.78</td></tr>
<tr><td>reward_icons/relic 1254²</td><td class="n">1.37 MB</td><td class="n">1.50 MB</td><td class="bad">涨 0.13</td></tr>
<tr><td>reward_adventure_v2/18 1613×975</td><td class="n">1.21 MB</td><td class="n">1.50 MB</td><td class="bad">涨 0.29</td></tr>
</table>
<p>328 张全量压一遍：<b>71.8 → 92.0 MB（+20.2）</b>。只压「能省」的那 108 张：
71.8 → 65.9 MB，<b>净省 5.9MB</b> —— 为这点收益折腾 328 个导入文件不值得。</p>

<h2>三、真正的问题：图比显示尺寸大 4~20 倍</h2>
<p>地图图标是 1254×1254，而地图上画出来的边长是 <code>ZONE_ICON = 62</code>；
事件页的核心图标是 <code>CORE_ICON_SIZE = 200</code>。也就是说一张 1254² 的图，
屏幕上最多只用到 200px —— 多出来的像素从来没被人看见过。</p>

<h3>按实机尺寸看：1254² → 256 → 128，肉眼分不出来</h3>
@@1@@

<h3>像素级 1:1 对比：确实变软，但那个尺寸游戏里不会出现</h3>
@@2@@

<h2>四、面板与全屏背景（要谨慎的两类）</h2>
<p><code>panel_parchment</code> 是九宫格面板底，1536² 缩到 512² 后单看没问题，
但它靠<b>平铺</b>填满任意大小 —— 图变小意味着在 1920 宽的面板上平铺次数从 2 次变 4 次，
花纹重复感会更明显。这类我建议<b>保持原样</b>，单张 2.6MB 不值得冒险。</p>
@@3@@
<p><code>bg_curtain</code> 全屏背景 1600×900 缩到 1280×720 后略软（发丝边缘），
但它本来就在 1920 屏上被放大 1.2 倍，已经软了。这类可以缩，收益一般。</p>
@@4@@

<h2>五、三条路，你挑一条</h2>
<table>
<tr><th>方案</th><th>做法</th><th>包体</th><th>改动</th><th>风险</th></tr>
<tr><td><b>A 不动</b></td><td>保持 71.8MB</td><td class="n">174.9 MB</td><td>0 张</td><td class="ok">无</td></tr>
<tr><td><b>B 只缩图标类</b></td><td><code>map_icons</code> / <code>reward_icons</code> 这类显示 ≤200px 的方形图缩到 256</td><td class="n">约 166 MB</td><td>16 张</td><td class="ok">几乎无</td></tr>
<tr><td><b>C 方形图一律 512</b>（推荐）</td><td>边长 &gt;512 的方形图缩到 512，横图不动</td><td class="n">约 136 MB</td><td>84 张</td><td class="warn">低：实机仍有 2× 以上余量</td></tr>
<tr><td><b>D 方形图一律 256</b></td><td>同上但缩到 256</td><td class="n">约 122 MB</td><td>107 张</td><td class="warn">中：大幅面显示的方形图会糊</td></tr>
</table>
<p class="sub">体积是按 LANCZOS 重采样 + 重存实测的，误差 ±2MB；真正落地还要再跑一次导出验证。</p>

<h2>六、我的建议</h2>
<p>走 <b>C（方形图 512）</b>，包体 174.9 → 约 136MB，省 39MB，观感上看不出差别。
D 再多省 14MB，但要逐张确认那些方形图都是小尺寸显示 —— <code>battle_win_plate</code>
这类可能是大幅面的，缩到 256 会明显糊，我不建议冒这个险。</p>
<p>还有一件事得说：这批图<b>改的是 assets 里的源 PNG</b>。Godot 4.3 的导入设置里没有「限尺寸」选项，
只能把源文件换掉。原始出图在 <code>art_src/</code> 里另有一份，git 也留着历史，
真要回头随时能捞回来 —— 但这一步不可逆的感觉比改导入设置强，所以先问你。</p>

<footer>数据：<code>--export-pack "Android"</code> 导出 174.9MB PCK 后逐条目解析，
用 <code>.import</code> 的哈希反查源图。<br>
工具：<code>tools/_r611_tex_probe.py</code>（只读，不写工程文件）·
样张：<code>_review/r611_*.png</code></footer>
</div></body></html>
"""


def main():
    total = 174.9
    bars = "".join([
        bar("卡图 320 张（已 ASTC）", 55.5, total, "#c69a4a"),
        bar("UI / 背景 328 张（未压缩）", 71.8, total, "#b5533f"),
        bar("音频 ogg", 31.6, total, "#5c7f6a"),
        bar("字体 2 个", 15.2, total, "#6b6f8a"),
        bar("脚本 / 场景 / 其他", 0.8, total, "#4a4a52"),
    ])
    subs = [
        bars,
        img("_review/r611_icon_real.png", "实机 62px 显示，放大 5 倍看 —— 三档没有可见差别"),
        img("_review/r611_icon_pixel.png", "1:1 像素级对比（取中心 320px 裁切）"),
        img("_review/r611_panel.png", "九宫格面板底：1536 与 512 拉伸到 900×520 的观感"),
        img("_review/r611_bg_1280.png", "全屏背景：1600 原图 vs 缩到 1280，按 1920 屏的显示效果裁切"),
    ]
    html = TPL
    for i, v in enumerate(subs):
        html = html.replace("@@%d@@" % i, v)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(html)
    print("wrote", OUT, "%.2f MB" % (os.path.getsize(OUT) / 1048576.0),
          "imgs", html.count("data:image/"), "leftover", html.count("@@"))


if __name__ == "__main__":
    main()
