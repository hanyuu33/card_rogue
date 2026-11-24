# -*- coding: utf-8 -*-
"""探针 3：每 20 帧打一次手牌数，查谁把 5 张还回来。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, "scripts/battle_scene.gd")
lines = open(p, "rb").read().decode("utf-8").split("\r\n")
i = next(i for i, l in enumerate(lines) if l.startswith("func _demo_tick()"))
lines.insert(i + 2, '\tif "--handbonus" in _demo_args and _demo_frame % 20 == 0:')
lines.insert(i + 3, '\t\tprint("[HB3] f=", _demo_frame, " hand=", engine.state.hand.size())')
open(p, "wb").write("\r\n".join(lines).encode("utf-8"))
print("probe3 at", i + 2)
