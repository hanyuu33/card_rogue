# -*- coding: utf-8 -*-
"""由 corner_tr.txt 派生 corner_br.txt：只换「哪个角」与咬痕的走向。

同一份 prompt 只动这几处，其余一字不改 —— 两个候选的差异只有「远角 / 近角」，
味道（锡纸、画风、构图、禁用项）严格同源，便于直接对比。
"""
import pathlib

P = pathlib.Path(r"E:\work\card_rogue\art_src\2026-11-16_巧克力图标_R765\prompts")
src = (P / "corner_tr.txt").read_text(encoding="utf-8")

REPL = [
    ("FAR-TOP-RIGHT CORNER of the bar. That corner is simply GONE",
     "NEAR-BOTTOM-RIGHT CORNER of the bar (the corner closest to the viewer). That corner is simply GONE"),
    ("a broad concave arc sweeping from the TOP EDGE diagonally across into the RIGHT END of the bar, "
     "so the outline of the bar is cut away at the corner and the bite opens up and to the right",
     "a broad concave arc sweeping from the BOTTOM EDGE diagonally up into the RIGHT END of the bar, "
     "so the outline of the bar is cut away at the corner and the bite opens down and to the right"),
    ("the bite must be at the CORNER where the top edge meets the right end",
     "the bite must be at the CORNER where the bottom edge meets the right end"),
]

out = src
for a, b in REPL:
    assert out.count(a) == 1, "anchor not unique: %r" % a[:60]
    out = out.replace(a, b)

(P / "corner_br.txt").write_text(out, encoding="utf-8", newline="\n")
print("wrote corner_br.txt", len(out), "chars")
print("anchors replaced:", len(REPL))
