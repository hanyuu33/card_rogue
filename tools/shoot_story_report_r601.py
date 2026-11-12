# -*- coding: utf-8 -*-
"""R601 · 把 story_report.html 输出成 PNG（整张长图 + 两段切图）。

步骤：注入测量脚本 -> Chrome 无头 dump-dom 取区块边界 -> 按边界截图 -> 裁两段。
只碰 _preview/ 下的产物，不动游戏工程文件。
"""
import io
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "_preview", "story_report_r601")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

HTML = os.path.join(DIR, "story_report.html")
PROBE = os.path.join(DIR, "_probe2.html")
RAW = os.path.join(DIR, "story_report_full.png")


def file_url(p):
    return "file:///" + p.replace("\\", "/")


def shoot(w, h, out):
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
           "--no-sandbox", "--window-size=%d,%d" % (w, h),
           "--force-device-scale-factor=2", "--virtual-time-budget=3000",
           "--screenshot=" + out, file_url(HTML)]
    subprocess.run(cmd, capture_output=True, check=False)


src = io.open(HTML, encoding="utf-8").read()
js = ("<script>var els=[].slice.call(document.querySelectorAll("
      "'.masthead,.sec-head,.card,.ach-grid,.foot'));"
      "document.title='EDGES='+JSON.stringify(els.map(function(e){"
      "var r=e.getBoundingClientRect();"
      "return [Math.round(r.top),Math.round(r.bottom),e.className.split(' ')[0]];}));"
      "</script>")
io.open(PROBE, "w", encoding="utf-8", newline="\n").write(
    src.replace("</body>", js + "</body>"))

dom = subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
                      "--window-size=1080,500", "--virtual-time-budget=3000",
                      "--dump-dom", file_url(PROBE)],
                     capture_output=True, text=True, encoding="utf-8",
                     errors="replace").stdout
m = re.search(r"EDGES=(\[\[.*?\]\])", dom)
if not m:
    raise SystemExit("EDGES 解析失败，dump-dom 里没有测量结果")
edges = json.loads(m.group(1))
H = int(round(edges[-1][1] + 48))  # .foot 底部 + wrap 的 padding-bottom
print("edges:", len(edges), "content height =", H)

shoot(1080, H, RAW)

from PIL import Image  # noqa: E402
im = Image.open(RAW)
print("full png:", im.size)

# 切点：PART II 的 sec-head 顶部（正篇 / 档案分界）
cut = None
for top, bot, cls in edges:
    if cls == "sec-head" and top > 3000:
        cut = top
        break
if cut is None:
    raise SystemExit("没找到 PART II 分界")

p1 = os.path.join(DIR, "story_report_p1_zhengpian.png")
p2 = os.path.join(DIR, "story_report_p2_dangan.png")
im.crop((0, 0, im.size[0], cut * 2)).save(p1)
im.crop((0, cut * 2, im.size[0], im.size[1])).save(p2)
print("cut at", cut)
for f in (RAW, p1, p2):
    print(os.path.basename(f), Image.open(f).size,
          round(os.path.getsize(f) / 1048576, 2), "MB")
