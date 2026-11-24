# -*- coding: utf-8 -*-
"""R752 补丁：battle_scene —— 使用型工具两段式确认 + 选卡型工具的选卡页接线。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:160])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/battle_scene.gd", [
    # ---- ① 出图入口：三件新工具 ----
    (
        """			elif "--totemtool" in args:
				# R745 出图：工具栏里放野性图腾（核验图标 + 用掉之后的力量来源条）。
				# 出图：`battle.tscn -- --screenshot --totemtool --level 0 --shotframe 200`
				RunState.traps = [7008, 7005, 7006]
""",
        """			elif "--totemtool" in args:
				# R745 出图：工具栏里放野性图腾（核验图标 + 用掉之后的力量来源条）。
				# 出图：`battle.tscn -- --screenshot --totemtool --level 0 --shotframe 200`
				RunState.traps = [7008, 7005, 7006]
			elif "--newtools" in args:
				# R752 出图：三件新工具（万能牌 / 快送鸭 / 神秘牌）核验图标与槽内观感。
				# 出图：`battle.tscn -- --screenshot --tooldemo --newtools --level 0 --shotframe 200`
				RunState.traps = [7009, 7010, 7011]
""",
    ),
    # ---- ② 选卡页 kind ----
    (
        """func _pick_active_kind() -> String:
	## 当前活跃的选卡场景（"" = 无）。优先级同原小面板的拦截顺序。
	if _hero_pick_idx >= 0:
		return "hero"
""",
        """func _pick_active_kind() -> String:
	## 当前活跃的选卡场景（"" = 无）。优先级同原小面板的拦截顺序。
	# R752：选卡型工具（万能牌 7009 / 神秘牌 7011）—— 玩家刚在工具栏上点出来的，
	# 排最前：面板一旦打开就不该被别的待选场景抢走（同一时刻不可能有两个）。
	if engine.tool_pick_kind != "":
		return "toolpick"
	if _hero_pick_idx >= 0:
		return "hero"
""",
    ),
    # ---- ③ 选卡页配置 ----
    (
        """		"wish":
			# R306 许愿（9168）：从**卡组**选一张卡加入手卡。
""",
        """		"toolpick":
			# R752：选卡型工具（万能牌 = 抽牌库复制 / 神秘牌 = 3 张随机本职业奖励卡）。
			# 候选在 `begin_tool_pick()` 那一刻就摇定并缓存了（`engine.tool_pick_cards()`），
			# 这里只负责画；opts[i] = 候选下标，确认时原样交回引擎。
			var tp_cards: Array = engine.tool_pick_cards()
			var tp_opts: Array = []
			for tp_i in tp_cards.size():
				tp_opts.append(tp_i)
			var tp_data: TrapData = TrapRepo.load_json().get_trap(engine.tool_pick_id)
			var tp_name := tp_data.trap_name if tp_data != null else "工具"
			if engine.tool_pick_kind == "deck_copy":
				return {"kind": k, "short": tp_name, "opts": tp_opts,
						"title": "%s：从抽牌库选择一张卡复制进手卡（牌库 %d 张）"
								% [tp_name, engine.state.deck.size()],
						"note": "点卡选中，再点确认 —— 复制品费用为 0、回合结束消失（原卡留在抽牌库里）",
						"cards": tp_cards, "max_sel": 1, "confirm_label": "确认复制",
						"cancel_label": "不使用"}
			return {"kind": k, "short": tp_name, "opts": tp_opts,
					"title": "%s：从这 3 张里选一张加入手卡" % tp_name,
					"note": "点卡选中，再点确认 —— 本回合它的费用为 0",
					"cards": tp_cards, "max_sel": 1, "confirm_label": "确认",
					"cancel_label": "不使用"}
		"wish":
			# R306 许愿（9168）：从**卡组**选一张卡加入手卡。
""",
    ),
    # ---- ④ 确认 ----
    (
        """		"wish":
			# R306 许愿：确认 → 卡组那张进手牌。
""",
        """		"toolpick":
			# R752：确认 → 引擎结算（复制 / 入手 + 费用 0），**成功才摘槽**。
			# 失败（手牌在面板打开后被别的东西塞满之类）→ 工具留在工具栏里。
			var tp_all: Array = engine.tool_pick_cards()
			var tp_pick := int(opts[sel[0]])
			var tp_nm := ""
			if tp_pick >= 0 and tp_pick < tp_all.size():
				tp_nm = (tp_all[tp_pick] as CardData).card_name
			var tp_slot := _tool_pick_slot
			_tool_pick_slot = -1
			if engine.tool_pick_confirm(tp_pick):
				if tp_slot >= 0:
					RunState.consume_trap(tp_slot)
				status_text = "工具：%s 加入手卡（本回合费用 0）" % tp_nm
				_say("「%s」加入手牌" % tp_nm)
			else:
				status_text = "工具没有生效 —— 栏位保留"
				_say("卡没能进入手牌，工具留在工具栏里")
			_clear_selection()
		"wish":
			# R306 许愿：确认 → 卡组那张进手牌。
""",
    ),
    # ---- ⑤ 取消 ----
    (
        """	match _pick.kind():
		"whale":
""",
        """	match _pick.kind():
		"toolpick":
			# R752：取消 = 什么也没发生 —— 工具还在工具栏里（面板里从没摘过槽）。
			engine.tool_pick_cancel()
			_tool_pick_slot = -1
			status_text = "已取消：工具仍在工具栏里（没有消耗）"
			_clear_selection()
		"whale":
""",
    ),
    # ---- ⑥ 空候选兜底 ----
    (
        """	match kind:
		"hero":
			_hero_pick_idx = -1
			_hero_pick_cell = Vector2i(-1, -1)
""",
        """	match kind:
		"toolpick":
			engine.tool_pick_cancel()
			_tool_pick_slot = -1
		"hero":
			_hero_pick_idx = -1
			_hero_pick_cell = Vector2i(-1, -1)
""",
    ),
])

print("OK")
