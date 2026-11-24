# -*- coding: utf-8 -*-
"""R836b 补丁二：把单层深褐菱形换成「深褐外廓 + 金芯」两层（才有描边感）。"""
ROOT = "E:/work/card_rogue/"
BS = "scripts/battle_scene.gd"
b = open(ROOT + BS, "rb").read()

old = (
    "\t# 针尖小菱形（时针的读法，也遮住金芯的圆头）\r\n"
    "\tvar side := Vector2(-dir.y, dir.x)\r\n"
    "\tdraw_colored_polygon(PackedVector2Array([\r\n"
    "\t\t\ttip + dir * (4.6 * s), tip + side * (3.4 * s),\r\n"
    "\t\t\ttip - dir * (3.2 * s), tip - side * (3.4 * s)]), hb)\r\n"
).encode("utf-8")

new = (
    "\t# 针尖小菱形（时针的读法）：先深褐外廓、再金芯，才有描边感\r\n"
    "\tvar side := Vector2(-dir.y, dir.x)\r\n"
    "\tdraw_colored_polygon(PackedVector2Array([\r\n"
    "\t\t\ttip + dir * (6.0 * s), tip + side * (4.4 * s),\r\n"
    "\t\t\ttip - dir * (3.6 * s), tip - side * (4.4 * s)]), hb)\r\n"
    "\tdraw_colored_polygon(PackedVector2Array([\r\n"
    "\t\t\ttip + dir * (4.0 * s), tip + side * (2.5 * s),\r\n"
    "\t\t\ttip - dir * (2.2 * s), tip - side * (2.5 * s)]), hg)\r\n"
).encode("utf-8")

assert b.count(old) == 1, b.count(old)
b = b.replace(old, new)
open(ROOT + BS, "wb").write(b)
print("菱形改成双层描边")
