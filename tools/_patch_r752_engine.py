# -*- coding: utf-8 -*-
"""R752 补丁：GameEngine —— 万能牌 7009 / 快送鸭 7010 / 神秘牌 7011 的结算口。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:120])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/game_engine.gd", [
    # ---- ① pending 字段 ----
    (
        """var _wild_totem_atk:= 0   # R745 野性图腾：本场已用出的那份力量加成（0 = 还没用；引擎每场重建 → 自动复位）
""",
        """var _wild_totem_atk:= 0   # R745 野性图腾：本场已用出的那份力量加成（0 = 还没用；引擎每场重建 → 自动复位）
## R752：**选卡型工具**（万能牌 7009 / 神秘牌 7011）的待选状态。
## 与 `wish_pending` 那批并列，但触发口在**工具栏**而不是手牌（`begin_tool_pick`）。
##   * `tool_pick_kind` —— "" = 没有待选；"deck_copy" / "random3" = 正在选什么；
##   * `tool_pick_id`   —— 触发它的工具 id（日志 / 提示用）；
##   * `_tool_pick_deck` —— deck_copy 的候选：抽牌库**下标**（顺序即牌库顺序）；
##   * `_tool_pick_cards` —— random3 的候选：已经摇定的 3 张卡（**必须**在开面板那一刻就定下来，
##     否则「开一次面板摇一次」会让同一份存档读两次出现两组不同的卡）。
## ⚠️ 选卡期间**工具还在工具栏里**（`RunState.traps` 没动）：确认才由界面摘槽，
##    取消就什么也没发生 —— 一个消耗品不能因为「打开了面板又关掉」而消失。
var tool_pick_kind := ""
var tool_pick_id := 0
var _tool_pick_deck: Array[int] = []
var _tool_pick_cards: Array = []
""",
    ),
    # ---- ② use_tool：加 slot 参数 + fill_toolbar 分支 ----
    (
        """func use_tool(id: int) -> bool:
	## R690：**使用型工具**（7005 小血瓶 / 7006 法力药剂）的唯一结算口。
	## 与 `place_trap` 并列：放置型拖到战场空格，这两个点一下直接结算，
	## 结算完由界面调 `RunState.consume_trap(slot)` 从栏位移除。
	## 回血走 `_op_heal`（吃「黄桃罐头」以外的既有回血口径 / 触发 game_over 检查），
	## 回费直接 `state.energy +=`（与拆解 8049 同口径：不污染 self_energy_spent，允许超额）。
	var t: TrapData = TrapRepo.load_json().get_trap(id)
	if t == null or state == null or not t.is_usable():
		return false
	var healed := 0
""",
        """func use_tool(id: int, slot := -1) -> bool:
	## R690：**使用型工具**（7005 小血瓶 / 7006 法力药剂 / 7007 烤肉 / 7008 野性图腾 /
	## R752 快送鸭 7010）的唯一结算口。
	## 与 `place_trap` 并列：放置型拖到战场空格，这些轻点两下直接结算，
	## 结算完由界面调 `RunState.consume_trap(slot)` 从栏位移除。
	## 回血走 `_op_heal`（吃「黄桃罐头」以外的既有回血口径 / 触发 game_over 检查），
	## 回费直接 `state.energy +=`（与拆解 8049 同口径：不污染 self_energy_spent，允许超额）。
	## ⚠️ R752：`slot` 只有 fill_toolbar（快送鸭）用得上 —— 它要**先把自己那一格腾空**
	##    再填满，否则「用掉自己 + 填满 3 格」差一格（-1 = 调用方没给，按只有 2 格可填算）。
	## ⚠️ 需要选卡的工具（`pick_kind != ""`）**不走这里** —— 它们走 `begin_tool_pick()`，
	##    因为「点了工具」到「效果真正发生」之间还隔着一次玩家选择。
	var t: TrapData = TrapRepo.load_json().get_trap(id)
	if t == null or state == null or not t.is_usable():
		return false
	if t.pick_kind != "":
		return false      # 选卡型：见 begin_tool_pick（这里返回 false 让界面知道没结算）
	var healed := 0
""",
    ),
    (
        """	if t.ally_atk > 0:
		# R745 野性图腾：**赋值**而不是累加（用两次还是 +2，与竖琴「不论如何都只 +2」同口径），
		# 然后立刻同步场上的人；之后再登场的人由 `_relic_on_enter_buffs()` 补。
		_wild_totem_atk = t.ally_atk
		_sync_totem()
	_log("使用工具：「%s」（回血 %d / 回费 %d / 盟友力量 +%d → HP %d/%d，费用 %d）" % [
			t.trap_name, healed, t.energy, _wild_totem_atk, state.hp_self, state.max_hp_self,
			state.energy])
	## 纯结算事件：界面据此播数字与提示。不掷随机数，回放确定性不受影响。
	action.emit("tool_used", {"id": id, "name": t.trap_name, "healed": healed,
			"energy": t.energy, "hp": state.hp_self, "max_hp": state.max_hp_self})
	return true
""",
        """	if t.ally_atk > 0:
		# R745 野性图腾：**赋值**而不是累加（用两次还是 +2，与竖琴「不论如何都只 +2」同口径），
		# 然后立刻同步场上的人；之后再登场的人由 `_relic_on_enter_buffs()` 补。
		_wild_totem_atk = t.ally_atk
		_sync_totem()
	var filled := 0
	if t.fill_toolbar:
		# R752 快送鸭：先把自己这一格腾空（它「用掉就没」），再往空槽里填商店工具。
		# 顺序反了就是「3 格里有 1 格永远填不上」——玩家看到的工具栏是 2/3。
		if slot >= 0:
			RunState.consume_trap(slot)
		filled = RunState.fill_toolbar_with_shop_tools()
	_log("使用工具：「%s」（回血 %d / 回费 %d / 盟友力量 +%d / 补工具 %d → HP %d/%d，费用 %d）" % [
			t.trap_name, healed, t.energy, _wild_totem_atk, filled, state.hp_self,
			state.max_hp_self, state.energy])
	## 纯结算事件：界面据此播数字与提示。不掷随机数，回放确定性不受影响。
	action.emit("tool_used", {"id": id, "name": t.trap_name, "healed": healed,
			"energy": t.energy, "hp": state.hp_self, "max_hp": state.max_hp_self,
			"filled": filled, "slots": RunState.traps.duplicate()})
	return true


func begin_tool_pick(id: int) -> bool:
	## R752：**选卡型工具**（万能牌 7009 / 神秘牌 7011）的入口 —— 界面点工具时调这里。
	## 返回 true = 已经在等玩家选卡（界面别再摘槽）；false = 用不了（界面照常提示原因）。
	## 候选在**这一刻**就定下来并缓存（尤其 random3 的随机结果），面板只是把它画出来：
	## 开一次面板摇一次的话，同一份存档读两次会出现两组不同的候选。
	## 随机源走引擎 `rng` → 同种子同结果、回放可复现（与新生 9148 / 随心组装同一口径）。
	var t: TrapData = TrapRepo.load_json().get_trap(id)
	if t == null or state == null:
		return false
	if tool_pick_kind != "":
		return false      # 已经有一个在选（界面的面板挡住点击，这里是防御）
	if current_side != SIDE_SELF:
		return false
	# 「加入手牌」的两种形态都会撞上限 —— 手牌满时直接不让用，
	# 否则会走 `_grant_to_hand` 的「满则进弃牌 / 消失」分支，等于把消耗品丢进垃圾桶。
	if state.hand_full():
		_log("工具「%s」：手牌已满（%d 张），先打出一张再用" % [t.trap_name, FieldState.HAND_LIMIT])
		return false
	match t.pick_kind:
		"deck_copy":
			if state.deck.is_empty():
				_log("工具「%s」：抽牌库是空的，没有可以复制的卡" % t.trap_name)
				return false
			_tool_pick_deck.clear()
			for i in state.deck.size():
				_tool_pick_deck.append(i)
			_tool_pick_cards.clear()
		"random3":
			var pool: Array[CardData] = CardRepo.load_json().reward_pool_for(RunState.player_class)
			if pool.is_empty():
				_log("工具「%s」：本职业奖励卡池是空的" % t.trap_name)
				return false
			_tool_pick_cards.clear()
			var used: Array[int] = []
			for k in mini(3, pool.size()):
				var idx := rng.randi() % pool.size()
				var guard := 0
				while used.has(idx) and guard < pool.size() * 4:
					idx = rng.randi() % pool.size()
					guard += 1
				used.append(idx)
				# **独立副本**：面板里要显示「抽到的是哪张」，而 `turn_free` 以卡对象为键，
				# 直接挂卡库共享实例会让整把牌都变 0 费（R281 的教训）。
				_tool_pick_cards.append(_new_own_card(pool[idx]))
			_tool_pick_deck.clear()
		_:
			return false
	tool_pick_kind = t.pick_kind
	tool_pick_id = id
	_log("使用工具「%s」：等待玩家选卡" % t.trap_name)
	return true


func tool_pick_cards() -> Array:
	## 选卡面板要画的东西：deck_copy = 抽牌库里那几张（按牌库顺序）；random3 = 摇定的 3 张。
	if tool_pick_kind == "deck_copy":
		var out: Array = []
		for i: int in _tool_pick_deck:
			if i >= 0 and i < state.deck.size():
				out.append(state.deck[i])
		return out
	if tool_pick_kind == "random3":
		return _tool_pick_cards.duplicate()
	return []


func tool_pick_confirm(index: int) -> bool:
	## 选卡型工具的**结算唯一口**（面板确认时调）。`index` = `tool_pick_cards()` 的下标。
	##   * deck_copy（万能牌）→ 幻影复制：独立副本 + `is_ephemeral`（回合结束消失）+
	##     「次元」（用后消失，不进弃牌区）+ 在手期间费用 0（`state.hand_free`）。
	##     原卡**留在抽牌库里** —— 这是「复制」，不是「取走」（许愿 9168 才是取走）。
	##   * random3（神秘牌）→ 就是一个**正常的**新实例 + 本回合费用 0（`state.turn_free`，
	##     `end_turn` 清空）。它不消失，用不掉就进弃牌区，之后照常洗回牌库。
	var ok := false
	match tool_pick_kind:
		"deck_copy":
			if index >= 0 and index < _tool_pick_deck.size():
				var di: int = _tool_pick_deck[index]
				if di >= 0 and di < state.deck.size():
					var proto: CardData = state.deck[di]
					var clone := _new_own_card(proto)
					clone.traits = (proto.traits as Array).duplicate()
					clone.is_ephemeral = true          # 幻影：回合结束消失、离场不进弃牌区
					clone.affixes.erase(AFFIX_PHANTOM)  # 不带「幻影」字段（否则打出还能再链一张）
					if not clone.affixes.has(AFFIX_DIMENSION):
						clone.affixes.append(AFFIX_DIMENSION)
					state.hand_free[clone] = true       # 在手期间费用 0（离手自动恢复，见 cost_of）
					if _grant_to_hand(clone, "万能牌"):
						_log("万能牌：%s 的幻影复制加入手卡（费用 0）" % clone.card_name)
						action.emit("tool_pick_done", {"tool": tool_pick_id,
								"how": "deck_copy", "card": clone.card_name})
						ok = true
		"random3":
			if index >= 0 and index < _tool_pick_cards.size():
				var c: CardData = _tool_pick_cards[index]
				state.turn_free[c] = true               # 本回合费用 0（end_turn 清空）
				if _grant_to_hand(c, "神秘牌"):
					_log("神秘牌：%s 加入手卡（本回合费用 0）" % c.card_name)
					action.emit("tool_pick_done", {"tool": tool_pick_id,
							"how": "random3", "card": c.card_name})
					ok = true
	tool_pick_cancel()
	return ok


func tool_pick_cancel() -> void:
	## 取消（面板「放弃」/ Esc）：**什么都不发生** —— 工具还在工具栏里（界面没摘槽）。
	tool_pick_kind = ""
	tool_pick_id = 0
	_tool_pick_deck.clear()
	_tool_pick_cards.clear()
""",
    ),
])

print("OK")
