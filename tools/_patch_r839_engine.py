## R839：大蒜 7017 —— 引擎层（放置 / 倒计时 / 五处落点闸门）
## 用法：python tools/_patch_r839_engine.py
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
P = "scripts/game_engine.gd"


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep(path, old, new, tag):
    d = read(path)
    crlf = "\r\n" in d
    norm = d.replace("\r\n", "\n")
    o, n = old.replace("\r\n", "\n"), new.replace("\r\n", "\n")
    cnt = norm.count(o)
    if cnt == 0 and n in norm:
        print("skip %-36s（已应用）" % tag)
        return
    assert cnt == 1, "%s 锚点命中 %d 次（要求 1）" % (tag, cnt)
    out = norm.replace(o, n)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    print("ok  %-38s (%s)" % (tag, "CRLF" if crlf else "LF"))


# ---------- ① 回合推进 + 转发口 + 放置分支 ----------
rep(P, '''func place_trap(id: int, cell: Vector2i) -> bool:''', '''func cell_sealed(cell: Vector2i) -> bool:
	## R839 大蒜：界面唯一的读取口（拖放高亮 / 手牌落点 / 地图提示都读它）——
	## 别在界面里直接摸 `state.sealed_cells`，否则「引擎说封了、界面说没封」迟早出现。
	return state != null and state.is_cell_sealed(cell)


func _seal_tick() -> void:
	## R839 大蒜 7017：**每个我方回合开始**推进封锁倒计时。
	## 「3 个我方回合」= 3 个完整轮次（放下那回合的敌方行动 + 之后两轮），
	## 与 `traps.json` 里 7017 的 desc 是同一句话 —— 改口径两处一起改。
	## 到期解开的格子发纯视觉事件（界面据它提示），不影响任何判定。
	var gone := state.tick_seals()
	for cell: Vector2i in gone:
		_log("大蒜：%s 的封锁到期，这一格恢复可用" % cell)
	if not gone.is_empty():
		action.emit("seal_expired", {"cells": gone})


func place_trap(id: int, cell: Vector2i) -> bool:''', "engine: cell_sealed + _seal_tick")

rep(P, '''	if not trap_legal_cells().has(cell):
		return false
	state.trap_fields[cell] = id''', '''	if not trap_legal_cells().has(cell):
		return false
	# R839 大蒜 7017：**封锁型** —— 不写 `trap_fields`（那张表是「踩上去触发」，
	# 而封锁格根本踩不进去），改把这一格封进 `sealed_cells`：任何单位进不来也过不去。
	if t.block_turns > 0:
		state.seal_cell(cell, t.block_turns)
		_log("工具布置：「%s」封住 %s（%d 个我方回合不可使用）"
				% [t.trap_name, cell, t.block_turns])
		action.emit("seal_place", {"cell": cell, "id": id, "turns": t.block_turns})
		return true
	state.trap_fields[cell] = id''', "engine: place_trap 封锁分支")

# ---------- ② 合法格：封锁格不再可放 ----------
rep(P, '''			if state.board.has(c) or state.field_effects.has(c) or state.trap_fields.has(c):
				continue''', '''			# R839：被大蒜封着的格子不可使用 —— 陷阱 / 场地 / 工具都不许再往上堆。
			if state.board.has(c) or state.field_effects.has(c) or state.trap_fields.has(c) \\
					or state.is_cell_sealed(c):
				continue''', "engine: trap_legal_cells")

# ---------- ③ 移动 BFS：封锁格不能停留、不能穿过 ----------
rep(P, '''			if phasing == 1:
				# 穿行：被占格可**路过**（照样记 dist/parent 让 BFS 继续），落点合法性另判''',
    '''			# R839 大蒜：封锁格「不可使用」—— 不能停留、也**不能穿过**。
			# 排在穿行分支之前：穿行只让「被占格」可路过，封锁格是硬墙。
			if state.is_cell_sealed(nxt):
				continue
			if phasing == 1:
				# 穿行：被占格可**路过**（照样记 dist/parent 让 BFS 继续），落点合法性另判''',
    "engine: _move_bfs")

# ---------- ④ 跳跃落点 ----------
rep(P, '''			if t == cell:
				continue
			if state.board.has(t):
				continue
			if not unit_slot_allowed(t, side):
				continue
			out.append(t)''', '''			if t == cell:
				continue
			if state.board.has(t):
				continue
			if state.is_cell_sealed(t):
				continue      # R839 大蒜：跳跃也进不去封锁格
			if not unit_slot_allowed(t, side):
				continue
			out.append(t)''', "engine: leap_cells")

# ---------- ⑤ 河豚回弹落点 ----------
rep(P, '''	if state == null or state.board.has(dst):
		return false
	return unit_slot_allowed(dst, p.owner)''', '''	if state == null or state.board.has(dst):
		return false
	if state.is_cell_sealed(dst):
		return false      # R839 大蒜：别把人「弹进」封锁格
	return unit_slot_allowed(dst, p.owner)''', "engine: _bounce_cell_ok")

# ---------- ⑥ 随机空格（召唤 / 锻造 / 紧急呼叫定位）----------
rep(P, '''		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			if not state.board.has(c):
				free.append(c)
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[rng.randi_range(0, free.size() - 1)]


func _zone_label(side: String) -> String:''', '''		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			# R839 大蒜：封锁格不是「空格」—— 召唤物落上去会被 `place` 拒绝，白丢一次。
			if not state.board.has(c) and not state.is_cell_sealed(c):
				free.append(c)
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[rng.randi_range(0, free.size() - 1)]


func _zone_label(side: String) -> String:''', "engine: _random_free_board_cell")

rep(P, '''	var free: Array[Vector2i] = []
	for r: int in rows:
		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			if not state.board.has(c):
				free.append(c)''', '''	var free: Array[Vector2i] = []
	for r: int in rows:
		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			# R839 大蒜：封锁格不算空格（与 `_random_free_board_cell` 同一口径）。
			if not state.board.has(c) and not state.is_cell_sealed(c):
				free.append(c)''', "engine: _random_free_half_cell")

rep(P, '''			if not state.board.has(c):
				near.append(c)''', '''			if not state.board.has(c) and not state.is_cell_sealed(c):
				near.append(c)      # R839 大蒜：封锁格不能当召唤落点''',
    "engine: _revelator_free_cell")

# ---------- ⑥b 闪现落点（R111 不看阻挡，但封锁格仍然进不去）----------
rep(P, '''		if state.board.has(dst):
			_log("闪现落点 %s 已有单位" % dst)
			return''', '''		if state.board.has(dst):
			_log("闪现落点 %s 已有单位" % dst)
			return
		if state.is_cell_sealed(dst):
			_log("闪现落点 %s 被大蒜封着（不可使用）" % dst)
			return''', "engine: blink 落点")

# ---------- ⑦ 场地卡落点（界面 static 口判不了 state，引擎侧补一刀）----------
rep(P, '''		if not field_place_allowed(cell, f_aim):
			_pay_refund(paid)
			_log("场地放不了：%s 是「%s」生效，目标方永远进不去 %s"
				% [card.card_name, f_aim, cell])
			return null''', '''		if not field_place_allowed(cell, f_aim):
			_pay_refund(paid)
			_log("场地放不了：%s 是「%s」生效，目标方永远进不去 %s"
				% [card.card_name, f_aim, cell])
			return null
		# R839 大蒜：被封锁的格「不可使用」—— 场地也铺不上去。
		# `field_place_allowed()` 是 static（界面高亮也读它，拿不到 state），
		# 所以这一刀只补在引擎侧；界面高亮另外读 `engine.cell_sealed()` 过滤。
		if state.is_cell_sealed(cell):
			_pay_refund(paid)
			_log("场地放不了：%s 被大蒜封着（剩 %d 个我方回合不可使用）"
				% [card.card_name, int(state.sealed_cells.get(cell, 0))])
			return null''', "engine: 场地落点")

# ---------- ⑧ 我方回合开始调用 ----------
rep(P, '''		_action_growth_tick(SIDE_SELF)   # R161：先推进成长计数，再刷新 acts_left''',
    '''		_seal_tick()                     # R839 大蒜：封锁格倒计时（我方回合开始 -1）
		_action_growth_tick(SIDE_SELF)   # R161：先推进成长计数，再刷新 acts_left''',
    "engine: _begin_turn 调用")


# ---------- ③b AI 距离估算（_walk_search / _wall_depth / _unit_distance / _hp_pos_distance）
CR = chr(13)
LF = chr(10)
d = read(P)
norm = d.replace(CR + LF, LF)
o = "\t\t\tif nxt.x == forbidden_row_for(SIDE_OPPONENT)"
n = ("\t\t\t# R839 大蒜：封锁格当墙 —— AI 的距离估算必须与真实走位同一口径，"
     + LF + "\t\t\t# 否则它会算出「一步就到」然后卡在原地白掉一个行动。"
     + LF + "\t\t\tif state.is_cell_sealed(nxt):"
     + LF + "\t\t\t\tcontinue"
     + LF + "\t\t\tif nxt.x == forbidden_row_for(SIDE_OPPONENT)")
cnt = norm.count(o)
if cnt == 0 and n in norm:
    print("skip engine: AI 距离估算（已应用）")
else:
    assert cnt == 4, "AI 距离估算锚点命中 %d 次（要求 4）" % cnt
    out = norm.replace(o, n)
    if CR + LF in d:
        out = out.replace(LF, CR + LF)
    write(P, out)
    print("ok  engine: AI 距离估算（4 处）")
