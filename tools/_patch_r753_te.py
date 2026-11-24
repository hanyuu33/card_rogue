# -*- coding: utf-8 -*-
"""R753 测试段：插在 R642 ② 的断言行**之后**（该 check 跨三行，别插进中间）。"""
import io

P = "scripts/test_engine.gd"
s = io.open(P, "r", encoding="utf-8", newline="").read()
crlf = "\r\n" in s
eol = "\r" if crlf else ""

# ① R642 ② 断言文案：结论不变，理由变了（测试版不再遮蔽）
old_txt = "\"R642 判据：全卡开仍然全部可见，交给绘制层遮蔽成通用未解锁图\")"
new_txt = "\"R642 判据：全卡开仍然全部可见（R753 起测试版直接全解锁，不再遮蔽）\")"
assert s.count(old_txt) == 1, s.count(old_txt)
s = s.replace(old_txt, new_txt)

lines = s.split("\n")
anchor = -1
for i, ln in enumerate(lines):
    if "R753 起测试版直接全解锁" in ln:
        anchor = i
        break
assert anchor >= 0
assert lines[anchor].rstrip("\r").endswith("\")"), repr(lines[anchor])

block = [
    "",
    "\t# ---- R753（店长口径「图鉴锁只用于发布版，测试版默认全解锁」）----",
    "",
    "\t# ① 同一张没见过的卡：测试版不锁、发布版锁",
    "\tcheck(not r642_gs.gallery_locked(r642_new_card, false),",
    "\t\t\t\"R753 判据：测试版图鉴默认全解锁（没见过的卡也不遮成问号）\")",
    "\tcheck(r642_gs.gallery_locked(r642_new_card, true)",
    "\t\t\tand not r642_gs.gallery_locked(r642_seen_card, true),",
    "\t\t\t\"R753 判据：发布版仍然「没见过就锁」\")",
    "",
    "\t# ② 源码锁：锁挂在版本闸门上，不再无条件按「见过」判",
    "\tvar r753_gs_src := FileAccess.get_file_as_string(\"res://scripts/gallery_scene.gd\")",
    "\tcheck_src(r753_gs_src.contains(\"static func gallery_locked(\")",
    "\t\t\tand r753_gs_src.contains(\"return gallery_locked(c, GameBuild.is_release())\"),",
    "\t\t\t\"R753 源码锁：`_locked()` 走 `gallery_locked(c, GameBuild.is_release())`\")",
    "\t# ③ 测试版顶栏不再报「其中 N 张未解锁」",
    "\tcheck_src(not r753_gs_src.contains(\"GALLERY_SUMMARY_LOCKED\"),",
    "\t\t\t\"R753 源码锁：测试版顶栏不再报未解锁张数\")",
]

new_lines = lines[:anchor + 1] + [b + eol for b in block] + lines[anchor + 1:]
io.open(P, "w", encoding="utf-8", newline="").write("\n".join(new_lines))
print("inserted after line", anchor + 1, "crlf =", crlf)

chk = io.open(P, "r", encoding="utf-8", newline="").read()
print("crlf kept:", ("\r\n" in chk) == crlf)
print("block ok:", chk.count("R753 判据：测试版") == 1)
