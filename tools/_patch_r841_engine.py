# -*- coding: utf-8 -*-
"""R841 引擎层：锤子直击眩晕 + 润滑油「选一张手卡减费」。

两条判据都复用已有唯一口，不另开分支：
  * 眩晕 → `_apply_stun()`（唯一入口，只加一个 turns 参数）
  * 减费 → `state.hand_cost_delta`（手卡内减费唯一口径，离手自动恢复）
"""
import io

ROOT = "E:/work/card_rogue/"
P = "scripts/game_engine.gd"


def read():
    return io.open(ROOT + P, encoding="utf-8", newline="").read()


def write(s):
    # 写完立刻回读校验：R841 实测出现过「文件中间一个中文字被吞成 0x89」的损坏，
    # 只靠 write 返回值看不出来，必须 decode 一遍整份（bad byte 会当场炸）。
    raw = s.encode("utf-8")
    raw.decode("utf-8")
    with open(ROOT + P, "wb") as f:
        f.write(raw)
    back = open(ROOT + P, "rb").read()
    back.decode("utf-8")
    assert back == raw, "回读与写入不一致（%d vs %d 字节）" % (len(back), len(raw))


def rep(old, new, tag, count=1):
    s = read()
    crlf = "\r\n" in s
    norm = s.replace("\r\n", "\n")
    cnt = norm.count(old)
    assert cnt == count, "%s：锚点命中 %d 次（要求 %d）" % (tag, cnt, count)
    out = norm.replace(old, new)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(out)
    print("ok  %s" % tag)


# ---------- ① 落点候选：锤子和石头同一个口 ----------
rep('''	var t: TrapData = TrapRepo.load_json().get_trap(id)
	if t != null and t.direct_damage > 0:
		return trap_target_cells()
	return trap_legal_cells()''',
    '''	var t: TrapData = TrapRepo.load_json().get_trap(id)
	# R841：锤子 7018 与石头 7012 要的是**同一种落点**（敌方单位格），
	# 所以收在同一个判据里 —— 界面还按旧口径只认 direct_damage 的话，
	# 锤子会被当成放置型，高亮一片空格、砸不中任何人。
	if t != null and (t.direct_damage > 0 or t.direct_stun > 0):
		return trap_target_cells()
	return trap_legal_cells()''',
    "engine: trap_drop_cells 认直击眩晕")

rep('''	##   * 直接伤害型（石头 7012）→ 敌方**存活单位**所在的格子，砸上去当场结算。''',
    '''	##   * 直击型（石头 7012 伤害 / 锤子 7018 眩晕）→ 敌方**存活单位**所在的格子，砸上去当场结算。''',
    "engine: trap_drop_cells 注释")

# ---------- ② use_tool_on_unit 支持眩晕 ----------
rep('''func use_tool_on_unit(id: int, cell: Vector2i) -> bool:
	## R754 石头（7012）：把工具伤害砸到**指定敌方单位**身上的唯一口。''',
    '''func use_tool_on_unit(id: int, cell: Vector2i) -> bool:
	## R754 石头（7012）/ R841 锤子（7018）：把工具效果砸到**指定敌方单位**身上的唯一口。''',
    "engine: use_tool_on_unit 注释")

rep('''	var t: TrapData = TrapRepo.load_json().get_trap(id)
	if t == null or state == null or t.direct_damage <= 0:
		return false
	if not trap_target_cells().has(cell):
		return false
	var p: Placement = state.unit_at(cell)
	if p == null or p.owner != SIDE_OPPONENT or p.health <= 0:
		return false
	_log("工具「%s」砸向 %s：%d 点伤害" % [t.trap_name, cell, t.direct_damage])''',
    '''	var t: TrapData = TrapRepo.load_json().get_trap(id)
	if t == null or state == null or (t.direct_damage <= 0 and t.direct_stun <= 0):
		return false
	if not trap_target_cells().has(cell):
		return false
	var p: Placement = state.unit_at(cell)
	if p == null or p.owner != SIDE_OPPONENT or p.health <= 0:
		return false
	# R841 锤子 7018：**只眩晕、不掉血**。必须走 `_apply_stun`（眩晕唯一入口）——
	# 自己写 `stun_left = N` 的话，`reset_units` 与 `cannot_act_next_turn()` 那两处
	# 只要有一处没同步，就会出现「显示眩晕了但照常行动」。
	if t.direct_stun > 0:
		_log("工具「%s」砸向 %s：眩晕 %d 回合" % [t.trap_name, cell, t.direct_stun])
		_apply_stun(p, t.trap_name, t.direct_stun)
		return true
	_log("工具「%s」砸向 %s：%d 点伤害" % [t.trap_name, cell, t.direct_damage])''',
    "engine: use_tool_on_unit 眩晕分支")

# ---------- ③ _apply_stun 支持回合数 ----------
rep('''func _apply_stun(p: Placement, source: String) -> void:
	## **施加眩晕的唯一入口**（R341，惊奇盒子 9179 被攻击时）。
	## `stun_left > 0` → 下个自己回合开始 `reset_units` 不重置（横置保持 = 不能行动），
	## 同时把 `stun_left` 减 1，所以只挡一个回合，之后自动恢复。
	## 与冰封 / 沉睡共用同一条横置通道，`cannot_act_next_turn()` 也认它。
	if p == null or p.health <= 0:
		return
	p.stun_left = maxi(p.stun_left, STUN_TURNS)
	_log("%s 被眩晕（%s）：下回合不能行动" % [p.card.card_name, source])''',
    '''func _apply_stun(p: Placement, source: String, turns:= STUN_TURNS) -> void:
	## **施加眩晕的唯一入口**（R341，惊奇盒子 9179 被攻击时）。
	## `stun_left > 0` → 下个自己回合开始 `reset_units` 不重置（横置保持 = 不能行动），
	## 同时把 `stun_left` 减 1，所以只挡一个回合，之后自动恢复。
	## 与冰封 / 沉睡共用同一条横置通道，`cannot_act_next_turn()` 也认它。
	## R841：`turns` 默认还是 `STUN_TURNS`（老调用一处都不改）；锤子 7018 传数据里的值。
	if p == null or p.health <= 0:
		return
	p.stun_left = maxi(p.stun_left, maxi(1, turns))
	_log("%s 被眩晕 %d 回合（%s）：这期间不能行动" % [p.card.card_name, maxi(1, turns), source])''',
    "engine: _apply_stun 支持回合数")

# ---------- ④ begin_tool_pick：闸门只挡「往手里加卡」的两种 ----------
rep('''	# 「加入手牌」的两种形态都会撞上限 —— 手牌满时直接不让用，
	# 否则会走 `_grant_to_hand` 的「满则进弃牌 / 消失」分支，等于把消耗品丢进垃圾桶。
	if state.hand_full():
		_log("工具「%s」：手牌已满（%d 张），先打出一张再用" % [t.trap_name, FieldState.HAND_LIMIT])
		return false
	match t.pick_kind:
		"deck_copy":''',
    '''	# 「加入手牌」的两种形态都会撞上限 —— 手牌满时直接不让用，
	# 否则会走 `_grant_to_hand` 的「满则进弃牌 / 消失」分支，等于把消耗品丢进垃圾桶。
	# R841：**hand_down（润滑油）不改手牌张数**，手牌满着也该能用 —— 闸门只挡「加卡」那两种。
	if t.pick_kind != "hand_down" and state.hand_full():
		_log("工具「%s」：手牌已满（%d 张），先打出一张再用" % [t.trap_name, FieldState.HAND_LIMIT])
		return false
	match t.pick_kind:
		"hand_down":
			# R841 润滑油 7019：候选 = **此刻的手牌**，当场缓存（面板开着时手牌不会变，
			# 但缓存让「面板下标」与「确认时的卡」永远是同一张）。
			# 与 deck_copy 的区别：那个从抽牌库**复制一张进来**，这个**原地改**已有的卡。
			if state.hand.is_empty():
				_log("工具「%s」：手牌是空的，没有可以上油的卡" % t.trap_name)
				return false
			_tool_pick_cards.clear()
			for hc: CardData in state.hand:
				_tool_pick_cards.append(hc)
			_tool_pick_deck.clear()
		"deck_copy":''',
    "engine: begin_tool_pick hand_down")

# ---------- ⑤ tool_pick_cards ----------
rep('''	if tool_pick_kind == "random3":
		return _tool_pick_cards.duplicate()
	return []''',
    '''	if tool_pick_kind == "random3" or tool_pick_kind == "hand_down":
		return _tool_pick_cards.duplicate()
	return []''',
    "engine: tool_pick_cards hand_down")

# ---------- ⑥ tool_pick_confirm ----------
rep('''		"random3":
			if index >= 0 and index < _tool_pick_cards.size():
				var c: CardData = _tool_pick_cards[index]''',
    '''		"hand_down":
			# R841 润滑油 7019：给选中的**那张手卡**挂减费。
			# 走 `state.hand_cost_delta`（手卡内减费唯一口径）：
			# 卡离手（打出 / 弃掉）自动恢复原价，抓回手里又生效 —— 与谟涅摩叙涅 8072 同一条路。
			# 句柄比对用 `state.hand.has(hc)`：面板开着时那张卡若已不在手里（极端情况），
			# 就不能白给一个减费。
			if index >= 0 and index < _tool_pick_cards.size():
				var hc: CardData = _tool_pick_cards[index]
				var down := 1
				var td: TrapData = TrapRepo.load_json().get_trap(tool_pick_id)
				if td != null:
					down = maxi(1, td.cost_down)
				if state.hand.has(hc):
					state.hand_cost_delta[hc] = int(state.hand_cost_delta.get(hc, 0)) + down
					_log("润滑油：%s 的费用本场 -%d（现 %d 费）"
						% [hc.card_name, down, cost_of(hc)])
					action.emit("tool_pick_done", {"tool": tool_pick_id,
							"how": "hand_down", "card": hc.card_name})
					ok = true
		"random3":
			if index >= 0 and index < _tool_pick_cards.size():
				var c: CardData = _tool_pick_cards[index]''',
    "engine: tool_pick_confirm hand_down")

print("engine 全部应用")
