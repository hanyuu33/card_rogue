# -*- coding: utf-8 -*-
"""R752 补丁 B：battle_scene —— 使用型工具「点两下」的界面状态 / 命中顺序 / 绘制 / 结算口。"""
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
    # ---- ① 常量 ----
    (
        """## R695：丢工具「上膛」的有效期（ms）—— 超过这个时间再点 × 只算重新上膛。
const TOOL_DISCARD_MS := 2600
""",
        """## R695：丢工具「上膛」的有效期（ms）—— 超过这个时间再点 × 只算重新上膛。
const TOOL_DISCARD_MS := 2600
## R752（用户口径「使用型工具需要可以双击使用，或者单击后弹出使用按钮使用」）：
## 用同一个机制同时满足两种说法 —— 第一下点**只上膛**（槽上浮出「使用」罩层），
## 第二下点**同一槽的任何位置**才真正结算。手机上「连点两下」和「点一下再点按钮」
## 是同一条路径（罩层盖满整格，第二下必然落在里面），PC 上双击同理。
## 有效期与丢弃上膛同口径 2.6 秒：过时自动收起，不会一直挂着等误触。
const TOOL_USE_ARM_MS := 2600
""",
    ),
    # ---- ② 状态变量 ----
    (
        """var _trap_discard_arm := -1
var _trap_discard_until := 0
""",
        """var _trap_discard_arm := -1
var _trap_discard_until := 0
## R752：使用型工具「点两下」的上膛槽（-1 = 没有），以及失效时刻（ms）。
## 与 `_trap_discard_arm` 是**两套独立状态**：一个是「要丢掉」，一个是「要用掉」，
## 混用一个变量的话，丢完工具上膛会顺手把使用上膛也点亮（下一击直接白用一件）。
var _tool_use_arm := -1
var _tool_use_until := 0
## R752：选卡型工具（万能牌 / 神秘牌）是从哪个槽点出来的 ——
## 只有「确认」那一刻才该摘槽，所以要记着它（引擎不知道槽号，槽是界面的事）。
var _tool_pick_slot := -1
""",
    ),
    # ---- ③ 结算口 ----
    (
        """func _use_tool_slot(slot: int, td: TrapData) -> void:
	## R690：使用型工具（小血瓶 / 法力药剂 / R743 烤肉 7007）的界面唯一口。
	## 结算在 engine.use_tool，
	## 这里只管「能不能点」「点完摘槽」「说什么」。
	## 回血满了也允许使用（会把栏位浪费掉，但那是玩家的选择，不替他拦）；
	## 敌方回合不允许 —— 与放置型工具同一条闸门。
	if engine == null or td == null or not td.is_usable():
		return
	if engine.current_side != GameEngine.SIDE_SELF:
		_say("现在是敌方回合，等对手行动完再使用工具")
		return
	var id := RunState.trap_at(slot)
	if id <= 0:
		return
	if not engine.use_tool(id):
		return
	RunState.consume_trap(slot)   # 用了就没：从栏位移除（放置型在放下去那一刻移除）
	if td.heal_pct > 0:
		_say("已使用「%s」，回复 %d%% 生命" % [td.trap_name, td.heal_pct])
	else:
		_say("已使用「%s」，回复 %d 点费用" % [td.trap_name, td.energy])
	queue_redraw()
""",
        """func _use_tool_slot(slot: int, td: TrapData) -> void:
	## R690：使用型工具（小血瓶 / 法力药剂 / R743 烤肉 / R745 野性图腾 / R752 快送鸭 /
	## 万能牌 / 神秘牌）的界面唯一口。
	## 结算在 engine，这里只管「能不能点」「点完摘槽」「说什么」。
	## 回血满了也允许使用（会把栏位浪费掉，但那是玩家的选择，不替他拦）；
	## 敌方回合不允许 —— 与放置型工具同一条闸门。
	## R752：本函数只在**第二下**（上膛之后再点）被调用，见 `_gui_input` 的 `_tool_use_arm`。
	## 摘槽分三种，别一刀切：
	##   ① 选卡型（`pick_kind`）→ 现在还不能摘：面板取消时工具必须还在，确认后由
	##      `_on_pick_confirmed` 摘；
	##   ② 快送鸭（`fill_toolbar`）→ 引擎先腾空本格再填满，界面**不能再摘一次**
	##      （再摘一次会把刚填进来的最后一件工具抹掉）；
	##   ③ 其余 → 这里摘。
	if engine == null or td == null or not td.is_usable():
		return
	if engine.current_side != GameEngine.SIDE_SELF:
		_say("现在是敌方回合，等对手行动完再使用工具")
		return
	var id := RunState.trap_at(slot)
	if id <= 0:
		return
	if td.pick_kind != "":
		if not engine.begin_tool_pick(id):
			_say("「%s」现在用不了（手牌已满，或抽牌库里没有可复制的卡）" % td.trap_name)
			return
		_tool_pick_slot = slot
		_say("「%s」：选一张卡，确认后才会从工具栏移除" % td.trap_name)
		queue_redraw()      # 下一帧 `_sync_pick` 把选卡页弹出来
		return
	if not engine.use_tool(id, slot):
		return
	if not td.fill_toolbar:
		RunState.consume_trap(slot)   # 用了就没：从栏位移除（放置型在放下去那一刻移除）
	if td.fill_toolbar:
		_say("已使用「%s」，工具栏用商店工具补满了（%d/%d）" % [td.trap_name,
				RunState.TRAP_SLOTS - RunState.trap_free_slots(), RunState.TRAP_SLOTS])
	elif td.heal_pct > 0:
		_say("已使用「%s」，回复 %d%% 生命" % [td.trap_name, td.heal_pct])
	elif td.ally_atk > 0:
		_say("已使用「%s」，本场所有盟友 +%d 力量" % [td.trap_name, td.ally_atk])
	else:
		_say("已使用「%s」，回复 %d 点费用" % [td.trap_name, td.energy])
	queue_redraw()
""",
    ),
    # ---- ④ 命中顺序：上膛后再点 = 使用 ----
    (
        """			if ts >= 0 and _trap_discard_rect(ts).has_point(event.position) \\
					and RunState.trap_at(ts) > 0:
				_try_discard_tool(ts)
				_trap_press_slot = -1
""",
        """			if ts >= 0 and _trap_discard_rect(ts).has_point(event.position) \\
					and RunState.trap_at(ts) > 0:
				_try_discard_tool(ts)
				_tool_use_arm = -1          # R752：「要丢掉」与「要用掉」不能同时上膛
				_trap_press_slot = -1
""",
    ),
    (
        """			if ts >= 0 and RunState.trap_at(ts) > 0:
				_trap_press_slot = ts
				_trap_press_pos = event.position
""",
        """			# R752：使用型工具已上膛 → 这一下就是「确认使用」（双击的第二下 / 点「使用」）。
			# ⚠️ 必须排在「按在槽上」之前：否则第二下又只是重新上膛，永远用不出去。
			if ts >= 0 and _tool_use_arm == ts and RunState.trap_at(ts) > 0 \\
					and Time.get_ticks_msec() <= _tool_use_until:
				var utd: TrapData = TrapRepo.load_json().get_trap(RunState.trap_at(ts))
				_tool_use_arm = -1
				_tool_use_until = 0
				_trap_press_slot = -1
				_trap_discard_arm = -1
				if utd != null and utd.is_usable():
					_use_tool_slot(ts, utd)
				_press_idx = -1
				_grid_drag_arm = false
				_grid_dragging = false
				_info_drag_arm = false
				_info_dragging = false
				queue_redraw()
				return
			_tool_use_arm = -1     # 点在别处 → 收起「使用」罩层
			_tool_use_until = 0
			if ts >= 0 and RunState.trap_at(ts) > 0:
				_trap_press_slot = ts
				_trap_press_pos = event.position
""",
    ),
    # ---- ⑤ 松手：从「直接用」改成「上膛」 ----
    (
        """			elif _trap_press_slot >= 0:
				# 轻点 = 只读看说明（不消耗）；「用了就没」只发生在成功放置那一刻。
				# R690：使用型工具（小血瓶 / 法力药剂）没有落点 → 轻点即结算，用完从栏位移除。
				var tid := RunState.trap_at(_trap_press_slot)
				var td: TrapData = TrapRepo.load_json().get_trap(tid)
				if td != null and td.is_usable():
					_use_tool_slot(_trap_press_slot, td)
				elif td != null:
					_say("「%s」：%s" % [td.trap_name, td.desc])
""",
        """			elif _trap_press_slot >= 0:
				# 轻点 = 只读看说明（不消耗）；「用了就没」只发生在成功放置那一刻。
				# R690：使用型工具没有落点 → 轻点结算。R752 改成**两段式**：这一下只上膛
				# （槽上浮出「使用」罩层），再点一下同一格才真的结算 —— 消耗品被误触
				# 直接吃掉太贵，而弹模态确认框要两次点击、还挡住战场，同格点两下最省事。
				var tid := RunState.trap_at(_trap_press_slot)
				var td: TrapData = TrapRepo.load_json().get_trap(tid)
				if td != null and td.is_usable():
					_tool_use_arm = _trap_press_slot
					_tool_use_until = Time.get_ticks_msec() + TOOL_USE_ARM_MS
					_say("「%s」：再点一下即使用 —— %s" % [td.trap_name, td.desc])
				elif td != null:
					_say("「%s」：%s" % [td.trap_name, td.desc])
""",
    ),
    # ---- ⑥ 绘制：上膛罩层 ----
    (
        """		if id > 0 and not dragging:
			TrapArt.draw(self, r.grow(-5.0), id, false)
""",
        """		if id > 0 and not dragging:
			TrapArt.draw(self, r.grow(-5.0), id, false)
			# R752：使用型工具已上膛 → 整格盖一层「使用」罩层（这就是那个「使用按钮」）。
			# 判定与命中共用同一个有效期：过时自动收起，不会挂着等人误触。
			if _tool_use_arm == i and Time.get_ticks_msec() <= _tool_use_until:
				draw_rect(r.grow(-2.0), Color(0.05, 0.06, 0.09, 0.80), true)
				draw_rect(r.grow(-2.0), Color("ffd76a"), false, 2.5)
				_draw_string_center(_font_bold, 15, "使用", r.get_center(), Color("ffe6a2"), -1)
""",
    ),
    # ---- ⑦ 状态栏里也要把上膛收起来 ----
    (
        """	if _trap_discard_arm >= 0 and Time.get_ticks_msec() > _trap_discard_until:
		_trap_discard_arm = -1
""",
        """	if _trap_discard_arm >= 0 and Time.get_ticks_msec() > _trap_discard_until:
		_trap_discard_arm = -1
	if _tool_use_arm >= 0 and Time.get_ticks_msec() > _tool_use_until:
		_tool_use_arm = -1      # R752：使用上膛同样会过期
""",
    ),
])

print("OK")
