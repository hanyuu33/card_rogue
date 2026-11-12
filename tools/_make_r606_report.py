# -*- coding: utf-8 -*-
"""R606 交付页：标题字两个活泼方案（原图 + 实机标题页）。

按文件存在与否动态拼页，缺哪张就写「还在出图」，不等整批。
用法：python tools/_make_r606_report.py
"""
import base64
import glob
import io
import os

ROOT = r"E:\work\card_rogue"
OUT = os.path.join(ROOT, "_preview", "r606_title_duck.html")
RAW = os.path.join(ROOT, "art_src", "2026-11-12_开场与标题_R604", "raw")

CANDS = [
    ("9011", "方案 A · 鸭嘴版",
     "两个「嘎」的「口」字旁换成小鸭头，橘黄鸭嘴正好顶住缺口；「杀」的末捺收成脚蹼，"
     "字下两只小白鸭仰头看。字占画面 14%~55% 高。"),
    ("9012", "方案 B · 木牌版",
     "四个字刻在四块木牌上挂着，胖鸭蹲横梁、小鸭叼牌角、还有一只布偶挂件。"
     "字（连木牌）占画面 22%~62% 高。"),
]


def embed(path):
    raw = open(path, "rb").read()
    if len(raw) > 400 * 1024:
        from PIL import Image
        bio = io.BytesIO()
        Image.open(path).convert("RGB").save(bio, "JPEG", quality=90, optimize=True)
        return "image/jpeg", base64.b64encode(bio.getvalue()).decode("ascii")
    return "image/png", base64.b64encode(raw).decode("ascii")


def fig(path, alt):
    mime, data = embed(path)
    return '<img alt="%s" src="data:%s;base64,%s">' % (alt, mime, data)


CSS = """
:root{--bg:#f7f2e8;--pane:#fffdf8;--line:#e0d3bb;--ink:#3a2f22;--dim:#7d6c56;--gold:#b5822a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"Noto Serif SC","Songti SC",Georgia,serif;line-height:1.75}
.wrap{max-width:1180px;margin:0 auto;padding:52px 28px 90px}
h1{font-size:28px;margin:0 0 8px;letter-spacing:.04em}
.sub{color:var(--dim);font-size:14px}
.rule{height:2px;background:linear-gradient(90deg,var(--gold),transparent);margin:18px 0 34px}
.card{background:var(--pane);border:1px solid var(--line);border-radius:12px;
  padding:20px 20px 24px;margin-bottom:30px;box-shadow:0 2px 14px rgba(120,95,60,.07)}
.card h3{margin:0 0 6px;font-size:19px;color:#5a4426}
.card .note{margin:0 0 14px;color:var(--dim);font-size:13.5px}
.card img{width:100%;display:block;border-radius:8px;border:1px solid var(--line)}
.lbl{font-size:12.5px;color:#8a6a2f;margin:16px 0 6px;letter-spacing:.08em}
.wait{color:var(--dim);font-size:14px;font-style:italic}
footer{margin-top:52px;padding-top:16px;border-top:1px solid var(--line);
  color:var(--dim);font-size:12.5px}
"""


def main():
    blocks, missing = [], []
    for cid, title, note in CANDS:
        raws = sorted(glob.glob(os.path.join(RAW, "%s_*.png" % cid)))
        if not raws:
            missing.append(title)
            continue
        shot = os.path.join(ROOT, "_review", "r606_title_%s.png" % cid)
        inner = ['<h3>%s</h3><p class="note">%s</p>' % (title, note)]
        inner.append('<div class="lbl">原图（codex 出图）</div>')
        inner.append(fig(raws[-1], title + " 原图"))
        if os.path.exists(shot):
            inner.append('<div class="lbl">实机标题页（1280×800，按钮压在原图上）</div>')
            inner.append(fig(shot, title + " 实机"))
        else:
            inner.append('<p class="wait">实机截图还没跑。</p>')
        blocks.append('<section class="card">%s</section>' % "\n".join(inner))

    if missing:
        blocks.append('<section class="card"><h3>还在出图</h3>'
                      '<p class="note">%s —— codex 单张 3~5 分钟，出来会自动补进这一页。</p>'
                      '</section>' % "、".join(missing))

    shot_cur = os.path.join(ROOT, "_review", "r605_title.png")
    if os.path.exists(shot_cur):
        blocks.append('<section class="card"><h3>现用版（R605 合成，作参照）</h3>'
                      '<p class="note">底图是 codex 9001 的空白羊皮横幅，金色标题由 Python 合成；'
                      '没有鸭子花活，但排版完全可控。R607 起不再画英文副标。</p>'
                      '<div class="lbl">实机标题页</div>%s</section>'
                      % fig(shot_cur, "现用版实机"))

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R606 标题字·鸭子版候选</title><style>%s</style></head><body><div class="wrap">
<h1>嘎嘎乱杀 · 标题字两个活泼方案</h1>
<div class="sub">同一套画风锚、同一个 16:9 画布，只换「字」的画法。定稿权在店长。</div>
<div class="rule"></div>
%s
<footer>生成：codex 图生图（画风锚 assets/ui/title_bg.png）· 驱动 _run6.py ·
实机截图 tools/_preview_r606_candidates.py · 拼页 tools/_make_r606_report.py</footer>
</div></body></html>""" % (CSS, "\n".join(blocks))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("WROTE %s  %.1f KB  缺=%s" % (OUT, os.path.getsize(OUT) / 1024.0, missing or "无"))


if __name__ == "__main__":
    main()
