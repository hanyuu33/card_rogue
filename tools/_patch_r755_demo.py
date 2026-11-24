# -*- coding: utf-8 -*-
"""R755：`--toolclaim` 出图参数 —— 工具栏**有空位**时的工具详情页（核验「领取」按钮还在）。

为什么要它：`--tooldemo` 同时被 battle_scene 认领，那边会把 `RunState.traps` 塞满
（`[7001, 7005, 7006]`），而本面板设空表又发生在 attach 时（更早）→ 永远进不了「有空位」
那一支。所以在**延时回调里**再清一次，晚于 battle_scene 的参数解析。
"""
import io

P = "E:/work/card_rogue/scripts/reward_panel.gd"
raw = io.open(P, "r", encoding="utf-8", newline="").read()

OLD = """		tmt.timeout.connect(func():
			open()
			if "--tooldetail" in args:
				_open_entry(0)
			elif "--toolfull" in args:
				_open_entry(0))
"""
NEW = """		tmt.timeout.connect(func():
			# R755：`--toolclaim` = 空栏详情页。延后清表，压过 battle_scene 的 `--tooldemo`
			# （那边会把工具栏塞满，同步清会被它覆盖）。
			if "--toolclaim" in args:
				RunState.traps = [-1, -1, -1]
			open()
			if "--tooldetail" in args or "--toolclaim" in args:
				_open_entry(0)
			elif "--toolfull" in args:
				_open_entry(0))
"""

assert raw.count(OLD) == 1, raw.count(OLD)
raw = raw.replace(OLD, NEW)
io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("ok")
