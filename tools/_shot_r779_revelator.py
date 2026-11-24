# -*- coding: utf-8 -*-
"""把启示者那一段 article 单拎出来出图，便于核对三张阶段卡的版式。"""
import io
import re

ROOT = "E:/work/card_rogue/"
h = io.open(ROOT + "_preview/r778_enemy_config.html", encoding="utf-8").read()

style = h[h.find("<style"):h.find("</style>") + 8]
i = h.find("boss_revelator")
a = h.rfind("<article", 0, i)
b = h.find("</article>", i) + len("</article>")
seg = h[a:b]

out = ("<!DOCTYPE html><html lang=\"zh\"><head><meta charset=\"utf-8\">"
       + style + "</head><body style=\"background:#120f18;padding:24px\">"
       + seg + "</body></html>")
io.open(ROOT + "_preview/_shot_r779_revelator.html", "w", encoding="utf-8", newline="\n").write(out)
print("article chars", len(seg), "-> _preview/_shot_r779_revelator.html")
