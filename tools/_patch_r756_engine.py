# -*- coding: utf-8 -*-
"""R756 game_engine：计量工坊三机制（常数测量员 / 精密计算者 / 负载增量员）。"""
import io

ROOT = "e:/work/card_rogue/"
P = ROOT + "scripts/game_engine.gd"


def L(s):
    return s.replace("\n", "\r\n")


raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in raw, "game_engine.gd 应为 CRLF"


def rep(old, new, why):
    global raw
    o = L(old)
    n = L(new)
    c = raw.count(o)
    assert c == 1, "%s：锚点命中 %d 次\n%r" % (why, c, o[:120])
    raw = raw.replace(o, n)
    print("ok:", why)


# ---------------- ① 常量块 ----------------
rep(
    'const MASS_HELIOS_ID:= 9137\n',
    '''const MASS_HELIOS_ID:= 9137

# ── 第二层·普通困难「计量工坊」（R756）──
# 三个单位一套：后排常数测量员 9253 / 中排精密计算者 9254 / 前排负载增量员 9255。
# 三套机制一律按 **trait** 判、不认 id —— 以后想把机制复用到别的单位身上，挂个同名
# trait 就行，引擎不用再改（这也是本作「字段 / 特性」体系的既有做法）。
#
# 常数测量员：**作为行动的代替**分配固定 16 点伤害（不是「回合开始触发」—— 店长口径：
#   发动要能行动、发动后算行动过，所以整条行动在 `_ai_act` 里就被换成这一招，
#   走的是与枭熊 / 激光巨炮同一条「专属 AI」通道，见 `_surveyor_act`）。
const SURVEYOR_ID := 9253
const SURVEYOR_TRAIT := "测量"
const SURVEYOR_NAME := "常数测量员"
const SURVEYOR_POOL := 16
# 精密计算者：对方盟友 / 工事入场后把生命压到 15（入场增益结算完之后）。
const CALCULATOR_ID := 9254
const CALCULATOR_TRAIT := "计算"
const CALCULATOR_NAME := "精密计算者"
const CALCULATOR_HP_CAP := 15
# 负载增量员：回合开始往对方抽牌库塞一张「攻击」+ 一张「木栅栏」。
const LOADER_ID := 9255
const LOADER_TRAIT := "增量"
const LOADER_NAME := "负载增量员"
const LOADER_GIFT_ATTACK := 8002      # 「攻击」（1 费技能）
const LOADER_GIFT_FENCE := 8001       # 「木栅栏」（2 费工事 0/6）
''',
    "常量块",
)

# ---------------- ② _ai_act 特判 ----------------
rep(
    '''	if p.card.traits.has(LASER_TRAIT):
		_laser_cannon_act(cell, p)
		return
''',
    '''	if p.card.traits.has(LASER_TRAIT):
		_laser_cannon_act(cell, p)
		return
	# R756 常数测量员：力 0 / 程 1，通用流程只会「往前挪一步、然后空手横置」——
	# 它的整个行动就是那一发分配。必须排在 `_ai_target_choice` **之前**：
	# 它压根不该有普通攻击（卡面写的是「作为行动的代替」）。
	if p.card.traits.has(SURVEYOR_TRAIT):
		_surveyor_act(cell, p)
		return
''',
    "_ai_act 特判",
)

# ---------------- ③ _surveyor_act ----------------
rep(
    '# ================= R467：枭熊专属 AI =================\n',
    '''# ================= R756：常数测量员专属 AI（「作为行动的代替」）=================

func _surveyor_act(cell: Vector2i, p: Placement) -> void :
	## 「常数测量员」9253（二层普通困难「计量工坊」后排）：
	##   **作为行动的代替**，对**敌方单位**（这里 = 玩家场上单位）分配 `SURVEYOR_POOL`
	##   （= 16）点伤害：由近及远，一个目标吃满它**当前的生命**后把剩下的分给下一个；
	##   分不完的由**对方 HP** 承受。这一次若没有对**对方 HP** 造成伤害 → 自己眩晕一回合。
	##
	## 与土元素 9235 的三处差别（全部是店长口径，别照着土元素改回来）：
	##   ① 池子**固定 16**，不随「本场用过几张盟友」增长；
	##   ② 剩下的伤害**会溢出到玩家 HP**（土元素只打场上单位，`_earth_primal_enter`
	##      明确不直击 HP）；
	##   ③ 溢不出来就把自己晕掉 —— 这条才是这关的正解：「拿够厚的单位堵枪口」。
	##
	## ⚠️ 每段的分配量一律 `mini(left, q.health)`：对超负荷单位就是「刚好归零」
	##   （它负血存活、伤害不溢出，多分出去的点数等于白烧），对普通单位同样是「刚好打倒」。
	##   与土元素那行逐字同源，别改成「有多少分多少」。
	## ⚠️ 池子按**分配量**扣、不按实际落地量扣（同土元素）：目标有减伤时只是它自己更耐打，
	##   漏出来的点数不会再分给下一个 —— 否则同一笔伤害会被减伤「复制」一份，总量凭空变多。
	## ⚠️ 参与队列（`primal_queue`）时目标**此刻**就已经定死（`random = false`）：
	##   和土元素一样可以连射，不必等前一段落地（见 `can_launch_primal_next`）。
	var victims := SIDE_SELF if p.owner == SIDE_OPPONENT else SIDE_OPPONENT
	var rest: Array[Vector2i] = []
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q != null and q.owner == victims and q.health > 0:
			rest.append(c)
	# 由近及远；距离相同按格序 —— 回放 / 同种子必须逐帧一致（与土元素 / 激光同一条纪律）。
	var ordered: Array[Vector2i] = []
	while not rest.is_empty():
		var best := 0
		for i in range(1, rest.size()):
			var d_new: int = manhattan(rest[i], cell)
			var d_old: int = manhattan(rest[best], cell)
			if d_new < d_old or (d_new == d_old and rest[i] < rest[best]):
				best = i
		ordered.append(rest[best])
		rest.remove_at(best)
	var plan: Array = []
	var left: int = SURVEYOR_POOL
	for c2: Vector2i in ordered:
		if left <= 0:
			break
		var q2: Placement = state.board.get(c2, null)
		if q2 == null or q2.health <= 0:
			continue
		var chunk: int = mini(left, q2.health)
		plan.append({"target": q2, "amount": chunk, "source": SURVEYOR_NAME,
				"src": cell, "random": false})
		left -= chunk
	for hit: Dictionary in plan:
		hit["count"] = plan.size()
		if defer_primal_effects:
			primal_queue.append(hit)
		else:
			_hit_unit(hit.target, int(hit.amount), SURVEYOR_NAME, true, false)
	if not defer_primal_effects:
		_destroy_dead()
	# 溢出：走 `_damage_player` 唯一口 —— 减伤 / 不锈钢盆 / lucky 7 / 森林守护照常生效。
	# 「有没有对对方 HP 造成伤害」按**实际掉血**判（前后差值），不按纸面点数判：
	# 被完全挡下 / 免疫时一样算「没造成伤害」，于是它照样眩晕。
	var spilled := 0
	if left > 0:
		var before_hp: int = state.hp_self if victims == SIDE_SELF else state.hp_opponent
		_damage_player(victims, left, SURVEYOR_NAME)
		var after_hp: int = state.hp_self if victims == SIDE_SELF else state.hp_opponent
		spilled = maxi(0, before_hp - after_hp)
	_log("%s：分配 %d 点伤害（%d 个目标），溢出 %d（对方 HP -%d）" % [
			SURVEYOR_NAME, SURVEYOR_POOL, plan.size(), left, spilled])
	action.emit("survey_beam", {"cell": cell, "total": SURVEYOR_POOL,
			"hits": plan.size(), "left": left, "spilled": spilled,
			"stun": spilled <= 0, "side": p.owner})
	if spilled <= 0:
		_apply_stun(p, SURVEYOR_NAME + "：没打到 HP")
	_tap(p, "%s：计量完毕" % SURVEYOR_NAME)
	_check_game_over()


# ================= R467：枭熊专属 AI =================
''',
    "_surveyor_act",
)

# ---------------- ④ _on_ally_entered 两处接入 ----------------
rep(
    '''	_wanted_mark(p, side)   # R525 通缉令：敌方场上所有单位获得「次元」
	_hidden_energy_tick(p, side)   # R331：友方**单位**（含工事）入场 → 改造 +「死亡」
	if p.card.kind != "盟友":
		return
	if p.card.id == DUCKLING_ID:
		_duckling_discount(p)   # R692：小鸭入场 → 手卡随机一张效果卡 -1
	_wind_force_tick(side, "%s 入场" % p.card.card_name)
''',
    '''	_wanted_mark(p, side)   # R525 通缉令：敌方场上所有单位获得「次元」
	_hidden_energy_tick(p, side)   # R331：友方**单位**（含工事）入场 → 改造 +「死亡」
	if p.card.kind != "盟友":
		# R756：**工事**也要吃「精密计算者」的血压制（卡面写的是「盟友或工事」），
		# 而工事在下一行就被 kind 判早退了 —— 所以这里必须先补一次。
		_compute_cap_tick(p, side)
		return
	if p.card.id == DUCKLING_ID:
		_duckling_discount(p)   # R692：小鸭入场 → 手卡随机一张效果卡 -1
	_wind_force_tick(side, "%s 入场" % p.card.card_name)
	# R756：**所有入场增益的最后一步**（店长口径）。放在这里 = 本函数内所有战吼 /
	# 光环 / 加血都跑完之后，才轮到「精密计算者」压血。
	_compute_cap_tick(p, side)
''',
    "_on_ally_entered 接入",
)

# ---------------- ⑤ _compute_cap_tick ----------------
rep(
    '''func _hidden_energy_tick(p: Placement, side: String) -> void :
''',
    '''func _calculator_on_field(side: String) -> Vector2i:
	## 该方场上**还活着的**「精密计算者」里 `entry_seq` 最小的那个格子；
	## 没有则 `Vector2i(-1, -1)`。
	## ⚠️ 取 `entry_seq` 最小而不是「先遍历到的」：棋盘是 Dictionary，迭代顺序不可依赖，
	##   同一局面两次跑出不同结果就不是回放了（与冰冻术士「本场第一个入场」同一条纪律）。
	var best := Vector2i(-1, -1)
	var best_seq := 1 << 30
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p == null or p.owner != side or p.health <= 0 or p.card == null:
			continue
		if not p.card.traits.has(CALCULATOR_TRAIT):
			continue
		if p.entry_seq < best_seq:
			best = cell
			best_seq = p.entry_seq
	return best


func _compute_cap_tick(p: Placement, side: String) -> void :
	## 「精密计算者」9254（二层普通困难「计量工坊」中排）：
	##   对方（= 我方）的**盟友或工事**入场后，若其生命大于 `CALCULATOR_HP_CAP`（15），
	##   则变为 15。店长口径：**在所有入场增益结算之后**结算。
	##
	## 挂在 `_on_ally_entered()` 的末尾（工事那一路在 kind 判早退前单独补一次）——
	## 那个函数就是「入场增益」的唯一入口：战吼 / 隐藏能源 / 通缉令 / 风之力全在里面。
	##
	## ⚠️ 只压**当前生命**，绝不写 `CardData.health`（生命上限）：
	##   ① 「入场后若生命 > 15 则变为 15」是一次性事件，不是「上限被永久锁死」；
	##   ② 改上限要牵动离场还原（`_card_leaving_field`）、满血判据（`p.health >= card.health`）、
	##      血条分母一整串，而这个效果的全部语义只是「这一下把你压到 15 血」；
	##   ③ 敌方关卡单位用的是**卡库共享实例**，写 `p.card.health` 会跨局泄漏到图鉴。
	## ⚠️ 只对**对方**生效：精密计算者自己不压自己人（卡面写的是「对方」）。
	if p == null or p.card == null or p.health <= CALCULATOR_HP_CAP:
		return
	if side != SIDE_SELF or p.owner != SIDE_SELF:
		return
	if p.card.kind != "盟友" and p.card.kind != "工事":
		return
	var src := _calculator_on_field(SIDE_OPPONENT)
	if src == Vector2i(-1, -1):
		return
	var before: int = p.health
	p.health = CALCULATOR_HP_CAP
	_log("%s：%s 入场生命 %d → %d" % [CALCULATOR_NAME, p.card.card_name, before, p.health])
	action.emit("compute_cap", {"cell": _cell_of(p), "card": p.card, "src": src,
			"from": before, "to": CALCULATOR_HP_CAP})


func _hidden_energy_tick(p: Placement, side: String) -> void :
''',
    "_compute_cap_tick",
)

# ---------------- ⑥ _loader_tick ----------------
rep(
    '''func _field_upgrade_grant(p: Placement, atk: int, hp: int, source: String,
''',
    '''func _loader_tick(side: String) -> void :
	## 「负载增量员」9255（二层普通困难「计量工坊」前排）：
	##   **回合开始时**，把一张「攻击」8002 和一张「木栅栏」8001 加入**对方抽牌库**。
	##
	## 与破绽 9154（`_breach_tick`）同一条口径，只是塞的是真卡、不是诅咒：
	##   * 敌方持有 → 真的插进玩家牌库（`state.deck`），位置随机（引擎 rng → 回放一致）；
	##   * 我方持有 → 敌方牌库只是抽象计数（`opp_deck_count`），各 +1。
	## ⚠️ 卡必须走 `_new_own_card()`：牌库里的共享实例一旦被后来的减费 / 改造碰到，
	##   改动会泄漏回卡库（R737 的老坑）。
	## ⚠️ 快照格子后排序再结算：同一回合多只单位时 rng 消耗顺序必须稳定。
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p == null or p.owner != side or p.health <= 0 or p.card == null:
			continue
		if not p.card.traits.has(LOADER_TRAIT):
			continue
		cells.append(cell)
	if cells.is_empty():
		return
	cells.sort()
	var repo := CardRepo.load_json()
	if repo == null:
		return
	for c: Vector2i in cells:
		var caster: Placement = state.unit_at(c)
		if caster == null:
			continue
		for cid in [LOADER_GIFT_ATTACK, LOADER_GIFT_FENCE]:
			var base: CardData = repo.get_card(int(cid))
			if base == null:
				_log("%s：卡库缺少赠卡定义（%d）" % [LOADER_NAME, int(cid)])
				continue
			var gift := _new_own_card(base)
			if side == SIDE_OPPONENT:
				var idx: int = state.deck.size()
				if idx > 0:
					idx = rng.randi_range(0, idx)
				state.deck.insert(idx, gift)
				_log("%s：回合开始 → 一张「%s」塞进你的抽牌库（牌库 %d 张）" % [
						caster.card.card_name, gift.card_name, state.deck.size()])
				action.emit("deck_gift", {"card": gift, "from": caster.card,
						"cell": c, "deck": state.deck.size(), "side": side})
			else:
				state.opp_deck_count += 1
				_log("%s（我方）：回合开始 → 对方抽牌库 +1 张「%s」" % [
						caster.card.card_name, gift.card_name])
				action.emit("deck_gift", {"card": gift, "from": caster.card,
						"cell": c, "deck": -1, "side": side})


func _field_upgrade_grant(p: Placement, atk: int, hp: int, source: String,
''',
    "_loader_tick",
)

# ---------------- ⑦ _begin_turn 接入 ----------------
rep(
    '''		_breach_tick(SIDE_OPPONENT)        # R231 破绽：俄倪厄 9132 / 量产型 9131 往我方卡组塞诅咒
''',
    '''		_breach_tick(SIDE_OPPONENT)        # R231 破绽：俄倪厄 9132 / 量产型 9131 往我方卡组塞诅咒
		_loader_tick(SIDE_OPPONENT)        # R756 负载增量员 9255：往我方牌库塞「攻击」+「木栅栏」
''',
    "_begin_turn 接入",
)

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("written, len =", len(raw))
