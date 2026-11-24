# -*- coding: utf-8 -*-
"""R752 补丁：test_trap_input —— 使用型工具两段式 / 选卡型工具的面板接线。"""
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


NEW_CASES = '''	# ---- ⑧b R752：使用型工具**点两下**才结算 ----
	# 用户口径：「使用型工具需要可以双击使用，或者单击后弹出使用按钮使用」——
	# 两条说法在这套实现里是同一条路径：第一下只上膛（槽上盖出「使用」罩层），
	# 第二下点同一格（罩层盖满整格，必然命中）才真的结算。
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7005)
	_sc.engine.state.max_hp_self = 20
	_sc.engine.state.hp_self = 10
	_sc._tool_use_arm = -1
	_sc._tool_use_until = 0
	s0 = _slot(0)
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	check(_sc._tool_use_arm == 0, "使用型工具：第一下只上膛（槽上出现「使用」）")
	check(RunState.trap_at(0) == 7005, "使用型工具：第一下不消耗")
	check(_sc.engine.state.hp_self == 10, "使用型工具：第一下不结算效果")
	_feed(_mb(s0, true))
	check(_sc._tool_use_arm == -1, "使用型工具：第二下收起罩层")
	check(RunState.trap_at(0) == -1, "使用型工具：第二下才真正用掉（槽清空）")
	check(_sc.engine.state.hp_self == 14, "使用型工具：第二下结算效果（20 的 20%% = 4）")
	check(_sc.engine.state.hand.size() == 0, "使用型工具：结算不碰手牌")

	# 上膛会过期（2.6 秒）：过期后那一下只是重新上膛，不能白用掉一个消耗品。
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7005)
	_sc.engine.state.hp_self = 10
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	check(_sc._tool_use_arm == 0, "使用型工具：重新上膛")
	_sc._tool_use_until = Time.get_ticks_msec() - 1
	_feed(_mb(s0, true))
	check(RunState.trap_at(0) == 7005 and _sc.engine.state.hp_self == 10,
			"使用型工具：上膛过期后点第二下不会白用（栏位与血量都没动）")
	_sc._tool_use_arm = -1
	_sc._tool_use_until = 0

	# ---- ⑧c R752：选卡型工具（万能牌 7009）—— 确认之前**不许**摘槽 ----
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7009)
	_sc.engine.state.deck.clear()
	var wc_proto: CardData = CardRepo.load_json().get_card(8001)
	_sc.engine.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	_sc._tool_pick_slot = -1
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	check(_sc._tool_use_arm == 0, "万能牌：第一下照样只上膛")
	_feed(_mb(s0, true))
	check(_sc.engine.tool_pick_kind == "deck_copy", "万能牌：第二下进入选卡（deck_copy）")
	check(RunState.trap_at(0) == 7009, "万能牌：确认之前工具仍在工具栏里")
	check(_sc._tool_pick_slot == 0, "万能牌：记住了触发它的槽号（确认时才摘）")
	_sc._sync_pick()
	check(_sc._pick != null and _sc._pick.is_picking() and _sc._pick.kind() == "toolpick",
			"万能牌：`_sync_pick` 把选卡页弹出来（kind=toolpick）")
	# 取消 → 工具还在，什么都没发生。
	_sc._on_pick_cancelled()
	check(_sc.engine.tool_pick_kind == "" and RunState.trap_at(0) == 7009,
			"万能牌：取消选卡 → 工具留在工具栏（没有消耗）")
	# 再来一次，这次确认 → 手牌 +1、槽才清空。
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	_feed(_mb(s0, true))
	_sc._sync_pick()
	var wc_hand_n := _sc.engine.state.hand.size()
	_sc._on_pick_confirmed([0])
	check(_sc.engine.state.hand.size() == wc_hand_n + 1, "万能牌：确认后手牌 +1")
	check(RunState.trap_at(0) == -1, "万能牌：确认后才摘槽（用了就没）")
	_sc.engine.tool_pick_cancel()
	_sc._sync_pick()

'''

patch("scripts/test_trap_input.gd", [
    # ① 复位也要清掉两段式/选卡的残留
    (
        """	_sc._press_idx = -1
""",
        """	_sc._press_idx = -1
	# R752：使用上膛 / 选卡型工具的残留也一并清掉（否则上一例的上膛会漏到下一例）
	_sc._tool_use_arm = -1
	_sc._tool_use_until = 0
	_sc._tool_pick_slot = -1
	if _sc.engine != null:
		_sc.engine.tool_pick_cancel()
""",
    ),
    # ② 新用例插在「⑨ 底图合一」之前
    (
        """	# ---- ⑨ 底图合一：两处共用一张，停用版不在 assets/ui ----
""",
        NEW_CASES + """	# ---- ⑨ 底图合一：两处共用一张，停用版不在 assets/ui ----
""",
    ),
])

print("OK")
