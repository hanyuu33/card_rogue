# -*- coding: utf-8 -*-
"""R797 补：回弹后「移动后有无攻击目标」按实际落点判。"""
BS = chr(92)
p = "E:/tmp/wt794/scripts/game_engine.gd"
d = open(p, "rb").read().decode("utf-8")

o1 = ("\t_trap_path_check(path, side)\r\n\tif p.health <= 0:\r\n\t\treturn\r\n\r\n"
      "\tif attack_targets(dst, side, p.card).is_empty()" + BS + "\r\n")
assert d.count(o1) == 1, ("o1", d.count(o1))
n1 = ("\t_trap_path_check(path, side)\r\n\tif p.health <= 0:\r\n\t\treturn\r\n"
      "\t# R797 河豚：被弹回去之后，单位已经不在 `dst` 上了 —— 下面「移动后有没有攻击目标」\r\n"
      "\t# 必须按**实际落点**算，否则会出现「人站在 2 排、却能打 3 排旁边那个」的幽灵攻击\r\n"
      "\t# （`attack()` 自己会按真位置再判一次，于是 AI 白转一圈、单位还留着行动权）。\r\n"
      "\tvar landed := _cell_of(p)\r\n"
      "\tif landed != Vector2i(-1, -1) and landed != dst:\r\n"
      "\t\tdst = landed\r\n\r\n"
      "\tif attack_targets(dst, side, p.card).is_empty()" + BS + "\r\n")
d = d.replace(o1, n1)

o2 = "\t\t_trap_path_check(path, side)\r\n\t\tif p.health <= 0:\r\n\t\t\treturn\r\n"
assert d.count(o2) == 1, ("o2", d.count(o2))
n2 = ("\t\t_trap_path_check(path, side)\r\n\t\tif p.health <= 0:\r\n\t\t\treturn\r\n"
      "\t\t# R797 河豚：跳过去被弹回起点 → 落地重击按「实际落地的那一格」算。\r\n"
      "\t\tvar leap_landed := _cell_of(p)\r\n"
      "\t\tif leap_landed != Vector2i(-1, -1):\r\n"
      "\t\t\tdst = leap_landed\r\n")
d = d.replace(o2, n2)

open(p, "wb").write(d.encode("utf-8"))
r = open(p, "rb").read()
print("ok CRLF", r.count(b"\r\n"), "LF", r.count(b"\n"))
