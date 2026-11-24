# -*- coding: utf-8 -*-
"""R777 修：彩虹诗返回文案用「实际入手张数」，不用总张数。

手牌满时会「打出 1 张 → 腾出 1 个位 → 第 1 张补进去、剩下 2 张进弃牌区」，
原文案报 3 张加入手卡与实际不符。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENG = os.path.join(ROOT, "scripts", "game_engine.gd")

s = io.open(ENG, "rb").read().decode("utf-8")

old = (
    '\t\t\tif rb_landed == 0:\r\n'
    '\t\t\t\treturn "手牌已满，%d 张改投弃牌区" % rb_list.size()\r\n'
    '\t\t\treturn "%d 张加入手卡，其费用本局 -%d" % [rb_list.size(), RAINBOW_CUT]\r\n'
)
new = (
    '\t\t\tif rb_landed == rb_list.size():\r\n'
    '\t\t\t\treturn "%d 张加入手卡，其费用本局 -%d" % [rb_landed, RAINBOW_CUT]\r\n'
    '\t\t\tif rb_landed == 0:\r\n'
    '\t\t\t\treturn "手牌已满，%d 张改投弃牌区" % rb_list.size()\r\n'
    '\t\t\t# 手牌只装得下一部分：报实际入手张数，别把进弃牌区的也算成「加入手卡」。\r\n'
    '\t\t\treturn "手牌只装下 %d 张（另 %d 张进弃牌区），其费用本局 -%d" % [\r\n'
    '\t\t\t\t\trb_landed, rb_list.size() - rb_landed, RAINBOW_CUT]\r\n'
)
n = s.count(old)
assert n == 1, "锚点命中 %d 次" % n
s = s.replace(old, new)
assert "\n" not in s.replace("\r\n", "")
io.open(ENG, "wb").write(s.encode("utf-8"))
print("[ok] 彩虹诗返回文案改用实际入手张数")
