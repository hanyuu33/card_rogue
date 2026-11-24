# -*- coding: utf-8 -*-
"""R755：换装条加「取消」命中（回列表，条目留在待领队列）。"""
import io

P = "E:/work/card_rogue/scripts/reward_panel.gd"

OLD = """					for ti in RunState.TRAP_SLOTS:
						if _tool_swap_rect(ti).has_point(pos):
							_swap_tool(ti)
							return
"""

NEW = """					# R755（店长口径「也可以取消」）：取消 = 回列表，条目**留在待领队列**、
					# 什么都不丢；下次再点进来换也行。
					if _tool_swap_cancel_rect().has_point(pos):
						_back_to_list()
						return
					for ti in RunState.TRAP_SLOTS:
						if _tool_swap_rect(ti).has_point(pos):
							_swap_tool(ti)
							return
"""

raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert raw.count(OLD) == 1, raw.count(OLD)
raw = raw.replace(OLD, NEW)
io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("cancel hit test added")
