import base64
import os

from PIL import Image

ROOT = '_preview'
PAIR = '_review/r596g_after.png'
GAL = '_review/r596g_gallery.png'

im = Image.open(PAIR)
im.crop((0, 1300, 900, 1959)).save('_review/r596g_zoom_final.png')
Image.open(GAL).crop((0, 0, 1280, 800)).save('_review/r596g_gal_crop.png')


def b64(p):
    return base64.b64encode(open(p, 'rb').read()).decode()


PAIR_B64 = b64(PAIR)
ZOOM_B64 = b64('_review/r596g_zoom_final.png')
GAL_B64 = b64('_review/r596g_gal_crop.png')

TPL = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R596g 包体瘦身验收</title>
<style>
body{margin:0;background:#14161a;color:#e8e6e1;font:15px/1.75 "Microsoft YaHei","PingFang SC",sans-serif}
.wrap{max-width:1080px;margin:0 auto;padding:40px 28px 80px}
h1{font-size:26px;margin:0 0 6px;font-weight:700;letter-spacing:.5px}
.sub{color:#8b93a1;font-size:13px;margin-bottom:34px}
h2{font-size:18px;margin:44px 0 14px;padding-left:10px;border-left:3px solid #c9a24a}
table{width:100%;border-collapse:collapse;margin:14px 0;font-size:14px}
th,td{padding:9px 12px;text-align:left;border-bottom:1px solid #262a31}
th{color:#9aa3b2;font-weight:600;font-size:13px;background:#1a1d22}
td.num{font-variant-numeric:tabular-nums;text-align:right}
tr.hi td{background:#1d2027}
.good{color:#6fd08c}.warn{color:#e0b355}.bad{color:#dd6b6b}
.card{background:#1a1d22;border:1px solid #262a31;border-radius:10px;padding:18px 20px;margin:16px 0}
.kv{display:flex;flex-wrap:wrap;gap:10px 34px;font-size:14px}
.kv div span{color:#8b93a1;margin-right:8px}
img{width:100%;border-radius:8px;display:block;margin:10px 0}
.note{color:#8b93a1;font-size:13px;margin-top:6px}
.tag{display:inline-block;padding:1px 8px;border-radius:11px;font-size:12px;background:#2a2f38;color:#c9d1de;margin-left:6px}
</style></head><body><div class="wrap">
<h1>R596g 发布前包体瘦身验收</h1>
<div class="sub">`.gdignore` 落地 · 导入缓存回收 · 卡图 VRAM 压缩 · 全部实测数据</div>

<div class="card">
<div class="kv">
<div><span>包体</span>312 MB <span style="color:#6fd08c">→ 预估 281 MB</span></div>
<div><span>导出 PCK 实测</span>236.2 MB / 1700 文件</div>
<div><span>卡图 PSNR</span><b class="good">47.4–50.0 dB</b></div>
<div><span>六套回归</span><b class="good">全通过</b></div>
</div>
</div>

<h2>一、`.gdignore`：29 个临时/备份目录不再进包</h2>
<table>
<tr><th>目录</th><th class="num">处理前</th><th>结果</th></tr>
<tr><td>assets/pics/_pending</td><td class="num">114 张进包 / 20.8 MB</td><td class="good">已完全移出 PCK</td></tr>
<tr><td>_preview（246 张）</td><td class="num">0 MB</td><td>导出过滤本就挡住了，加了更保险</td></tr>
<tr><td>根目录 24 个 _bk_*</td><td class="num">0 MB</td><td>仅省编辑器导入</td></tr>
<tr><td>_review / _pkg_hold / pics/_backup_*</td><td class="num">0 MB</td><td>同上</td></tr>
<tr class="hi"><td>导入缓存回收</td><td class="num">156.9 MB</td><td>251 个死 ctex 删除，.godot 693→522 MB</td></tr>
</table>
<div class="note">上一轮的结论「只泄漏 0.1 MB」是错的：`.import` 只是路标，图片数据在 `.godot/imported/*.ctex` 里，按 <code>md5(res://路径)</code> 命名，肉眼扫目录看不见。这次用哈希逐个对号才查实。</div>

<h2>二、卡图改 VRAM 压缩：三档口径实测</h2>
<table>
<tr><th>方案</th><th class="num">进包体积</th><th class="num">省下</th><th class="num">PSNR</th><th>显存占用</th><th>观感</th></tr>
<tr><td>原来：无损（mode=0）</td><td class="num">70.1 MB</td><td class="num">—</td><td class="num">∞</td><td class="bad">32 bpp</td><td>基准</td></tr>
<tr class="hi"><td><b>现在：VRAM 高质量（ASTC/BPTC）</b></td><td class="num">55.5 MB</td><td class="num good">−14.6 MB</td><td class="num good">47.4–50.0 dB</td><td class="good">8 bpp</td><td class="good">2× 放大也看不出</td></tr>
<tr><td>VRAM 普通质量（ETC2/S3TC）</td><td class="num">27.7 MB</td><td class="num good">−42.4 MB</td><td class="num warn">32.9–34.5 dB</td><td class="good">4–8 bpp</td><td class="warn">2× 放大有轻微块状渐变</td></tr>
<tr><td>有损 WebP q90（估算）</td><td class="num">≈14.7 MB</td><td class="num good">−55.4 MB</td><td class="num warn">≈38–48 dB</td><td class="bad">32 bpp</td><td>未采用</td></tr>
</table>
<div class="note">「高质量」开关把格式从 ETC2 换成 ASTC/BPTC：同码率画质从 33 dB 拉到 47 dB，代价是体积翻倍（27.7→55.5 MB）。Android 导出只打 ASTC 一份，PCK 里已确认没有 bptc 变体。</div>

<div class="card">
<b>左边原图 / 右边压缩后</b>，三张卡各一对，最下面是 2 倍放大
<img src="data:image/png;base64,__PAIR__">
<img src="data:image/png;base64,__ZOOM__">
<div class="note">放大区：上排原图、下排压缩后。青蓝光边与肩甲渐变处最容易被压坏，这里看不出差异。</div>
</div>

<div class="card">
<b>图鉴实机</b>（1280×800）
<img src="data:image/png;base64,__GAL__">
<div class="note">卡图、稀有度缎带、费用徽章、字段标志全部正常；无黑块、无错位。</div>
</div>

<h2>三、顺手修掉的运行时回归</h2>
<div class="card">
压缩纹理让 <code>ui_assets.gd</code> 的 <code>filtered()</code> / <code>small_icon()</code> 报
<code>Cannot resize in compressed or custom image formats</code>（图鉴一次刷 50 条）。
按 <code>test_smoke.gd</code> 里既有的 <code>is_compressed() → decompress()</code> 口径补了两处守卫，重拍图鉴已无报错。
</div>

<h2>四、包体还压在哪</h2>
<table>
<tr><th>项</th><th class="num">体积</th><th>说明</th></tr>
<tr><td>纹理合计</td><td class="num">188.8 MB</td><td>卡图 ASTC 55.5 + <b>其他纹理 133.4</b></td></tr>
<tr><td>lib/armeabi-v7a</td><td class="num">66.2 MB</td><td>32 位 ABI，可关</td></tr>
<tr><td>lib/arm64-v8a</td><td class="num">63.9 MB</td><td>主力 ABI</td></tr>
<tr><td>BGM（ogg）</td><td class="num">28.5 MB</td><td>11 首</td></tr>
<tr><td>字体（fontdata）</td><td class="num">15.2 MB</td><td>2 个中文全字库</td></tr>
</table>
<div class="note">真正的下一块肉不在卡图，在 UI/背景那 133.4 MB —— 单张 <code>panel_parchment</code> 就 2.6 MB，<code>bg_curtain</code> 1.9 MB。同样的 VRAM 压缩用上去，预计还能再砍 60–70 MB。</div>

<h2>五、验证</h2>
<table>
<tr><th>项</th><th>结果</th></tr>
<tr><td>probe_all_art（315 张卡图逐个加载）</td><td class="good">315/316，唯一缺是弃用的 9158</td></tr>
<tr><td>probe_all_assets（295 个取图口）</td><td class="good">缺 58，与 R596 基线逐条一致，无新增</td></tr>
<tr><td>导出 PCK 实测临时目录残留</td><td class="good">0</td></tr>
<tr><td>六套回归</td><td class="good">assemble 0 / engine 全过 / reward 26 / bgm 39 / smoke 68 / mana PASS</td></tr>
</table>
</div></body></html>"""

html = (TPL.replace('__PAIR__', PAIR_B64)
           .replace('__ZOOM__', ZOOM_B64)
           .replace('__GAL__', GAL_B64))
os.makedirs(ROOT, exist_ok=True)
out = os.path.join(ROOT, 'r596g_pack_slim.html')
open(out, 'w', encoding='utf-8').write(html)
print(out, round(len(html) / 1048576, 2), 'MB')
