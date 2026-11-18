# -*- coding: utf-8 -*-
"""R797 引擎侧：龟壳 6078（受伤 -2）+ 河豚 7015（回弹一格）。"""
ROOT = "E:/tmp/wt794/"
NL = "\r\n"
fails = []


def patch(path, pairs):
    raw = open(ROOT + path, "rb").read().decode("utf-8")
    for old, new in pairs:
        o = old.replace("\n", NL)
        n = new.replace("\n", NL)
        c = raw.count(o)
        if c != 1:
            fails.append("%s: %d 次 → %r" % (path, c, old[:50]))
            continue
        raw = raw.replace(o, n)
    open(ROOT + path, "wb").write(raw.encode("utf-8"))
    print("patched %-24s CRLF %d / LF %d" % (path, raw.count("\r\n"), raw.count("\n")))


# ---------- 常量 ----------
patch("scripts/game_engine.gd", [
    ("""const SPIKE_WALL_RELIC_ID:= 6073""",
     """# R797 龟壳（6078，一般档）：**上回合没有攻击过的己方单位**受到的伤害 -SHELL_REDUCE
# （至少仍受 1 点，与犀牛 / 加厚装甲同一条下限口径）。
#   判据读 `Placement.attacked_prev_turn`（attack / attack_hp 置位、reset_units 复位）
# —— 「上回合」= 敌方回合里看到的「我方上一个回合打没打过」。
const SHELL_RELIC_ID:= 6078
const SHELL_REDUCE:= 2
const SPIKE_WALL_RELIC_ID:= 6073"""),

    # ---------- 减伤段 ①g ----------
    ("""	# ①e 空号：原「土元素（9218）光环 -1 伤」随该卡在 R536 删除，编号不复用 ——""",
     """	# ①g R797 龟壳（6078）：**上回合没有攻击过的己方单位**受到的伤害 -SHELL_REDUCE。
	#    只认己方（`p.owner == SIDE_SELF`）—— 敌人挨打不减，否则等于给对面一件免费道具；
	#    与上面几条同为 flat 减伤、同一条「至少仍受 1 点」下限。
	if p != null and dmg > 0 and p.owner == SIDE_SELF and not p.attacked_prev_turn \\
			and RunState.has_relic(SHELL_RELIC_ID):
		var sh_before:= dmg
		dmg = maxi(1, dmg - SHELL_REDUCE)
		if dmg != sh_before:
			_log("龟壳：%s（上回合未攻击）受到的伤害 %d → %d" % [
					p.card.card_name, sh_before, dmg])
	# ①e 空号：原「土元素（9218）光环 -1 伤」随该卡在 R536 删除，编号不复用 ——"""),

    # ---------- attack()：记「攻击过」----------
    ("""	var def_dmg:= _hit_unit(defender, atk_power, "战斗", true, true)""",
     """	# R797 龟壳：普攻落地的**置位口**之一（另一处是 `attack_hp()`）。
	# 挂在这里而不是函数开头：射程 / 嘲讽 / 组装任何一步提前 return 都不算「攻击过」。
	attacker.attacked_prev_turn = true
	var def_dmg:= _hit_unit(defender, atk_power, "战斗", true, true)"""),

    # ---------- attack_hp()：记「攻击过」----------
    ("""	var power:= attacker.effective_power() + _turn_dmg_bonus(side)\\
	+ _ally_dmg_bonus(attacker.card, side)
	# R145：`dealt` = 真正落到 HP 上的伤害""",
     """	# R797 龟壳：直击 HP 也算「攻击过」（置位口之二，与 `attack()` 同一句话术）。
	attacker.attacked_prev_turn = true
	var power:= attacker.effective_power() + _turn_dmg_bonus(side)\\
	+ _ally_dmg_bonus(attacker.card, side)
	# R145：`dealt` = 真正落到 HP 上的伤害"""),

    # ---------- _trap_path_check：把「来时的格子」传下去 ----------
    ("""	var hit_cells: Array[Vector2i] = []
	for i in range(1, path.size()):
		var c: Vector2i = path[i]
		if state.trap_fields.has(c):
			hit_cells.append(c)
	for hc in hit_cells:
		if p.health <= 0:
			break
		_trigger_trap(hc, p)""",
     """	var hit_cells: Array[Vector2i] = []
	for i in range(1, path.size()):
		var c: Vector2i = path[i]
		if state.trap_fields.has(c):
			hit_cells.append(c)
	for hc in hit_cells:
		if p.health <= 0:
			break
		# R797 河豚：把「来这一格之前站在哪」（`path[i-1]`）一并传下去 ——
		# 回弹方向就是它。⚠️ 别在 `_trigger_trap` 里自己反推：那时 `move_unit` 已经
		# 落位，`_cell_of(p)` 只剩当前格，来路信息只在 path 里。
		var prev_cell := Vector2i(-1, -1)
		var pi := path.find(hc)
		if pi > 0:
			prev_cell = path[pi - 1]
		_trigger_trap(hc, p, prev_cell)"""),

    # ---------- _trigger_trap：签名 + 回弹 ----------
    ("""func _trigger_trap(cell: Vector2i, p: Placement) -> void:""",
     """func _trigger_trap(cell: Vector2i, p: Placement, prev_cell:= Vector2i(-1, -1)) -> void:"""),

    ("""		_apply_poison(p, t.damage, t.poison_turns - 1)""",
     """		_apply_poison(p, t.damage, t.poison_turns - 1)
	# R797 河豚（7015）：伤害与附带效果都结算完、人还活着 → 回弹。
	# 放最后而不是最前：它要改 `board`（搬格子），先搬再结算附带效果就得拿新格子重新定位，
	# 白白多一处「搬完忘了改 cell」的坑。
	if t.bounce > 0 and p.health > 0:
		_bounce_unit(p, prev_cell, t)"""),

    # ---------- 新增 _bounce_unit ----------
    ("""func _sleep_tick(side: String) -> void :""",
     """func _bounce_unit(p: Placement, prev_cell: Vector2i, t: TrapData) -> void :
	## R797 河豚 7015 的**回弹唯一口**。店长口径：
	##   「回到来到这一格前的上一格（仅限正常移动到这里的，用效果直接到这一格的
	##     则往这张卡所属方的方向弹一格）」。
	##   * 正常移动 → `prev_cell` 就是来路，原样弹回去；
	##   * 没有来路 / 来路已被占 / 越界 / 落在禁行行 → 改朝**河豚所属方**弹一格。
	##     河豚是玩家放的 → 己方方向 = 行号 +1（`back_row(SIDE_SELF)` 在 x=5 那一侧）。
	## ⚠️ 落点必须过 `unit_slot_allowed()`：对方后排（我方 HP 行）不许站人，
	##    「弹」和「推」一样要守这条，别指望调用方记得。
	var src:= _cell_of(p)
	if src == Vector2i(-1, -1):
		return
	var dst:= prev_cell
	var why:= "弹回来时的 %s" % str(dst)
	if dst == Vector2i(-1, -1) or dst == src or state.board.has(dst) \\
			or not unit_slot_allowed(dst, p.owner):
		dst = src + Vector2i(1, 0)
		why = "朝我方方向弹到 %s" % str(dst)
		if dst.x < 0 or dst.x >= FieldState.BOARD_ROWS or state.board.has(dst) \\
				or not unit_slot_allowed(dst, p.owner):
			_log("河豚：%s 无处可弹，留在原地" % p.card.card_name)
			action.emit("trap_bounce", {"from": src, "to": src, "card": p.card,
					"id": t.id, "blocked": true})
			return
	state.move_unit(src, dst)
	_log("河豚：%s 被%s（%s → %s）" % [p.card.card_name, why, src, dst])
	action.emit("trap_bounce", {"from": src, "to": dst, "card": p.card,
			"id": t.id, "blocked": false})


func _sleep_tick(side: String) -> void :"""),
])

if fails:
    print("!! 失败：")
    for f in fails:
        print("   " + f)
else:
    print("OK 全部命中")
