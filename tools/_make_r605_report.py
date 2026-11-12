# -*- coding: utf-8 -*-
"""R605 交付页：把徽记 / 片头六帧 / 鸣谢新段 / 标题页拼成一份 base64 内嵌 HTML。

店长在多机会话里看不到 `_review/` 的裸 PNG，图片一律走这份网页交付。
"""
import base64
import os

ROOT = r"E:\work\card_rogue"
OUT = os.path.join(ROOT, "_preview", "r605_delivery.html")

FRAMES = [
    (0.42, "_review/r604_f0.png", "0.42s · 勾线起笔，只有一圈残弧"),
    (0.72, "_review/r604_f1.png", "0.72s · 轮廓过半，鸭形未成"),
    (1.05, "_review/r604_f2.png", "1.05s · 勾线闭合，金环开始外扩"),
    (1.40, "_review/r604_f3.png", "1.40s · 名号逐字浮现（ris…）"),
    (1.85, "_review/r604_f4.png", "1.85s · 全名到位，金线自中心生长"),
    (2.40, "_review/r604_f5.png", "2.40s · 定格，等待交接"),
]


def b64(rel):
    """大图转 JPEG 再内嵌：1920×1080 的 PNG 塞 base64 会让网页涨到 6MB 以上。"""
    p = os.path.join(ROOT, rel)
    raw = open(p, "rb").read()
    if len(raw) > 400 * 1024:
        from PIL import Image
        bio = __import__("io").BytesIO()
        Image.open(p).convert("RGB").save(bio, "JPEG", quality=88, optimize=True)
        return ("image/jpeg", base64.b64encode(bio.getvalue()).decode("ascii"))
    return ("image/png", base64.b64encode(raw).decode("ascii"))


def img(rel, alt, cls="", style=""):
    mime, data = b64(rel)
    return ('<img class="%s" style="%s" alt="%s" src="data:%s;base64,%s">'
            % (cls, style, alt, mime, data))


CSS = """
:root{--bg:#12100e;--pane:#1b1815;--line:#332c25;--ink:#efe6d6;--dim:#a2957f;--gold:#e8c46a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"Noto Serif SC","Songti SC",Georgia,serif;line-height:1.7}
.wrap{max-width:1120px;margin:0 auto;padding:48px 28px 80px}
h1{font-size:30px;margin:0 0 6px;letter-spacing:.06em}
.sub{color:var(--dim);font-size:14px;margin-bottom:34px}
h2{font-size:19px;margin:52px 0 6px;padding-left:12px;border-left:3px solid var(--gold)}
.note{color:var(--dim);font-size:13.5px;margin:0 0 16px}
.pane{background:var(--pane);border:1px solid var(--line);border-radius:10px;padding:18px}
.mark{display:flex;gap:26px;align-items:center;flex-wrap:wrap}
.mark img{width:240px;height:240px;background:#0b0a08;border-radius:8px;
  border:1px solid var(--line);padding:8px}
.spec{font-size:13px;color:var(--dim);line-height:2}
.spec b{color:var(--ink);font-weight:600}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
.cell img{width:100%;display:block;border-radius:6px;border:1px solid var(--line)}
.cap{font-size:12.5px;color:var(--dim);padding:7px 2px 0}
.hint{font-size:13px;color:#c9a45c;background:#1e1a12;border:1px dashed #4a3c22;
  border-radius:8px;padding:10px 14px;margin:14px 0 0}
.full img{width:100%;display:block;border-radius:8px;border:1px solid var(--line)}
footer{margin-top:56px;padding-top:18px;border-top:1px solid var(--line);
  color:var(--dim);font-size:12.5px}
"""


def main():
    frames = "\n".join(
        '<div class="cell">%s<div class="cap">%s</div></div>' % (img(rel, label), label)
        for _, rel, label in FRAMES)

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R605 交付：厂牌徽记 / 片头 / 鸣谢</title>
<style>%s</style></head><body><div class="wrap">

<h1>嘎嘎乱杀 · Quackill</h1>
<div class="sub">R604–R605 交付：工作室徽记 · 片头小动画 · 鸣谢页 AI 素材说明 · 标题页</div>

<h2>一、工作室徽记 risusumai</h2>
<p class="note">纯黑底金线稿，已按亮度抠成透明 PNG；片头卡与启动 splash 共用这一张。</p>
<div class="pane mark">
  %s
  <div class="spec">
    <b>尺寸</b> 512 × 512（透明底）<br>
    <b>线稿覆盖率</b> 5.4%%（够细，放大不糊）<br>
    <b>文件</b> assets/ui/studio_mark.png · 73 KB<br>
    <b>用途</b> 片头动画主体 + project.godot 启动 splash<br>
    <b>色</b> 金 #e8c46a，底 #0f0d0b（与片头底色同色）
  </div>
</div>

<h2>二、片头小动画（六帧定格）</h2>
<p class="note">总长 2.7 秒交接标题页：勾线 → 金环外扩 → 名号逐字浮现 → 金线生长 → 整体退场。
下面六帧是同一套动画在固定时间点的定格（不是连拍，可复现）。</p>
<div class="grid">
%s
</div>
<div class="hint">这六张是 640×400 验收尺寸；实机是全屏，金线按 176px 徽记边长等比放大。</div>

<h2>三、鸣谢页新增「素材说明」（R605）</h2>
<p class="note">Steam 只要求在后台内容调查表里填生成式 AI，不强制游戏内标注。
这里主动写明，属于加分项——被截图质疑时不必临时解释。</p>
<div class="pane full">%s</div>

<h2>四、标题主视觉 + 实机标题页</h2>
<p class="note">codex 9001 已出图：一张挂着空白羊皮横幅的村庄全景，横幅正中留白给游戏名。
金色标题是按实测坐标合成的（1920×1080），不是画在图里的。</p>
<div class="pane full">%s</div>
<p class="note" style="margin-top:14px">实机跑起来是这样 —— 横幅在画面上方，六颗按钮压在横幅下沿。
英文副标 QUACKILL 试过四个位置，都会被「开始对战」或「百科」盖掉一半，所以图里没画；
英文名由窗口标题与 Steam 商店页承载。</p>
<div class="pane full">%s</div>

<footer>产物：_review/r604_f0..f5.png · _review/r605_credits_ai.png · _review/r605_title.png ·
assets/ui/title_art.png<br>
截图工具：tools/_shot_opening_r604.gd · tools/_shot_credits_r605.gd · tools/_shot_title_r603.gd</footer>
</div></body></html>""" % (
        CSS,
        img("assets/ui/studio_mark.png", "工作室徽记 risusumai", "markimg"),
        frames,
        img("_review/r605_credits_ai.png", "鸣谢页素材说明"),
        img("assets/ui/title_art.png", "标题主视觉"),
        img("_review/r605_title.png", "实机标题页"),
    )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("WROTE", OUT, "%.1f KB" % (os.path.getsize(OUT) / 1024.0))


if __name__ == "__main__":
    main()
