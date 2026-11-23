# -*- coding: utf-8 -*-
"""修 R819 用例里用错的 rfind（GDScript 版只有 2 个参数）。"""
import io

PATH = "scripts/test_engine.gd"
s = io.open(PATH, encoding="utf-8", newline="").read()

OLD = (
    '\tvar r819_cost_line := ev_src.find(\r\n'
    "\t\t\t'\"（占卜的代价：失去 %d 点最大生命 → %d / %d）\"')\r\n"
    '\tcheck_src(r819_cost_line > 0\r\n'
    '\t\t\tand ev_src.rfind("GameI18n.source(", 0, r819_cost_line) > 0\r\n'
    '\t\t\tand r819_cost_line - ev_src.rfind("GameI18n.source(", 0, r819_cost_line) < 80,\r\n'
    '\t\t\t"R819 代价结果行包在 GameI18n.source() 里（含三个动态数值）")\r\n'
)
NEW = (
    '\tvar r819_cost_line := ev_src.find(\r\n'
    "\t\t\t'\"（占卜的代价：失去 %d 点最大生命 → %d / %d）\"')\r\n"
    '\tvar r819_src_at := ev_src.substr(0, maxi(0, r819_cost_line)).rfind("GameI18n.source(")\r\n'
    '\tcheck_src(r819_cost_line > 0 and r819_src_at > 0\r\n'
    '\t\t\tand r819_cost_line - r819_src_at < 80,\r\n'
    '\t\t\t"R819 代价结果行包在 GameI18n.source() 里（含三个动态数值）")\r\n'
)
assert s.count(OLD) == 1, "锚点不唯一：%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
io.open(PATH, "w", encoding="utf-8", newline="").write(s)
b = io.open(PATH, "rb").read()
print("ok crlf", b.count(b"\r\n"), "lf", b.count(b"\n"))
