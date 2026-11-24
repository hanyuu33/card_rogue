# -*- coding: utf-8 -*-
"""探针 2：在 --handbonus 块尾打印最终手牌数。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, "scripts/battle_scene.gd")
lines = open(p, "rb").read().decode("utf-8").split("\r\n")
start = next(i for i, l in enumerate(lines) if "[HB] entered" in l)
end = next(i for i in range(start, start + 30) if lines[i].strip() == "queue_redraw()")
lines.insert(end + 1, '\t\tprint("[HB] after, hand=", engine.state.hand.size(),'
                       ' " first=", engine.state.hand[0].card_name)')
open(p, "wb").write("\r\n".join(lines).encode("utf-8"))
print("probe2 at", end + 1)
