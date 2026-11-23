# -*- coding: utf-8 -*-
"""R797：河豚回弹后，move() 的「移动后有无攻击目标」按实际落点判。"""
ROOT = "E:/tmp/wt794/"

BLOCK = '''	# 河豚被弹回之后，`move()` 里「移动后有没有攻击目标」必须按**实际落点**判 ——
	# 否则单位站在 2 排还能打到 3 排旁边的盟友（幽灵攻击），AI 白转一圈还留着行动权。
	var e12 := _engine()
	e12.state.trap_fields[Vector2i(3, 1)] = 7015
	var foe12: Placement = _unit(9012, 60, GameEngine.SIDE_OPPONENT)
	e12.state.board[Vector2i(2, 1)] = foe12
	var ally12: Placement = _unit(9013, 30, GameEngine.SIDE_SELF)
	e12.state.board[Vector2i(4, 1)] = ally12
	e12.move(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(e12.state.unit_at(Vector2i(2, 1)) == foe12,
			"河豚：move() 走完被弹回 (2,1)")
	check(foe12.tapped,
			"河豚：弹回后身边没有目标 → 按新位置判「放弃攻击」（不出现幽灵攻击）")
	check(ally12.health == 30, "河豚：盟友没被隔空打到")

'''

p = ROOT + "scripts/test_traps.gd"
d = open(p, "rb").read().decode("utf-8")
anchor = "\t# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----"
assert d.count(anchor) == 1
d = d.replace(anchor, BLOCK + anchor)
open(p, "wb").write(d.encode("utf-8"))
print("ok LF", open(p, "rb").read().count(b"\n"))
