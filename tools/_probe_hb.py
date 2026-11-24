# -*- coding: utf-8 -*-
"""临时探针：确认 --handbonus 分支是否执行。用字节定位，不猜行尾。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, "scripts/battle_scene.gd")
b = open(p, "rb").read()
key = b'--handbonus" in args and engine != null:'
print("命中", b.count(key))
i = b.find(key)
# 打印该行前后字节，看清行尾与缩进
line_start = b.rfind(b"\n", 0, i) + 1
line_end = b.find(b"\n", i) + 1
print("repr:", repr(b[line_start:line_end]))
if b.count(key) == 1:
    nl = b"\r\n" if b[line_start:line_end].endswith(b"\r\n") else b"\n"
    ins = nl + b"\t\tprint(\"[HB] entered, hand=\", engine.state.hand.size())"
    b = b[:line_end] + ins + b[line_end:]
    open(p, "wb").write(b)
    print("探针已插入（行尾", repr(nl), "）")
