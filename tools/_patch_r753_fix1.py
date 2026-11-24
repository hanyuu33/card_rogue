# -*- coding: utf-8 -*-
"""修正 _patch_r753_gallery.py：乱码字 + 一条会误红的断言。"""
import io

P = "tools/_patch_r753_gallery.py"
s = io.open(P, "r", encoding="utf-8", newline="").read()

bad = "\u6ca1\u89c1\u8fc7\ufffd\ufffd\u4f4d\u7f6e"   # 没见过<乱码>位置
good = "\u6ca1\u89c1\u8fc7\u7684\u4f4d\u7f6e"          # 没见过的位置
assert s.count(bad) == 1, s.count(bad)
s = s.replace(bad, good)

lines = s.split("\n")
out = []
dropped = 0
for ln in lines:
    if "and not r753_gs_src.contains" in ln:
        dropped += 1
        continue
    out.append(ln)
assert dropped == 1, dropped
s = "\n".join(out)

assert "\ufffd" not in s
io.open(P, "w", encoding="utf-8", newline="").write(s)
print("fixed; dropped", dropped)
for ln in s.split("\n"):
    if "gallery_locked(c, GameBuild" in ln or "\u6ca1\u89c1\u8fc7\u7684\u4f4d\u7f6e" in ln:
        print("  >", ln.strip())
