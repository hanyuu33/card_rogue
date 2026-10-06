class_name FieldState
extends RefCounted
## 一局对局的场地状态（肉鸽版）。
## 战场 6 行 x 3 列：第 0~2 行对手、第 3~5 行自己；格子键 = Vector2i(行, 列)。
##
## 肉鸽费用规则：没有费用区卡牌，改为能量计数 —— 每回合固定 ENERGY_PER_TURN 点，
## 出牌时扣除；**回合结束时剩余能量作废、重置回 ENERGY_PER_TURN**（不跨回合累积）。
## 牌库循环：抽牌时牌库空了 → 把弃牌区整堆洗入牌库继续抽。

const BOARD_ROWS := 6
const BOARD_COLS := 3
const OPPONENT_ROWS := 3
const ENERGY_PER_TURN := 5
const HAND_DRAW_PER_TURN := 5
const HAND_LIMIT := 10           # 手牌上限：达到后不再抽牌（超出部分留在牌库）
const HASTE_TRAIT := "哈气"      # 效果卡「哈气」（9024）：所属阵营单位每回合行动 value 次
const HASTE_START_TURN := 3     # 哈气前置：该方第 3 个回合起才生效（前两回合仍是每回合行动 1 次）
const VANISH_TRAIT := "离场消失"  # 鸭蛋 9022 / 魔像 9080：离场即消失，不进弃牌区、不再洗回牌库
const KEEP_HAND_TRAIT := "留手"   # 陨石术 9077：回合结束时留在手卡里，不弃
# 「自我复制」（R82：野兔 9032）：这张卡是**场上/手牌里的临时衍生物**，
# 不是从牌库抽来的实体 —— 手牌里回合结束消失、场上离场消失，两段都不进弃牌区。
# 与 VANISH_TRAIT 的区别：VANISH 只管「离场」；本 trait 连「手牌回合结束」也一起管。
const CLONE_TRAIT := "自我复制"
# 上面这个 trait 只回答「**这张卡会不会自己复制**」；
# 「是不是衍生物（离场就消失）」看 `CardData.is_ephemeral` —— 卡库原卡也带 CLONE_TRAIT，
# 两者必须分开判，否则原卡被打死/被弃时也会被当成衍生物抹掉。
## 沉睡（恶魔鸭 9116，R63）：Placement.sleep_left = 还要睡几个己方回合。
## 引擎在 end_turn 里对该方单位 -1；>0 时不能移动 / 攻击 / 直击 HP。
const SLEEP_TRAIT := "沉睡"
const SLEEP_TURNS := 2
# 「按张记账」的卡：减费记在这个实例身上 → 抽到时必须换成独立副本，
# 否则同名卡共享库内实例，一张的减费会串到卡组里其它同名卡上。
const PER_INSTANCE_TRAITS: Array[String] = ["留手", "魔像"]

var deck: Array[CardData] = []
var discard: Array[CardData] = []
var hand: Array[CardData] = []
var effects: Array[CardData] = []   # 我方效果区：使用后的效果卡，正面朝上持续生效
var enemy_effects: Array[CardData] = []  # 敌方效果区：开局即启用，正面朝上持续生效
var energy := ENERGY_PER_TURN  # 我方能量计数（开局即有一回合的量；回合结束重置回它）
var opp_energy := ENERGY_PER_TURN  # 对方能量计数（同上：回合结束重置）
var self_cost_reduction := 0    # 赤狐：本回合我方出牌费用 -N（回合开始清零，只影响我方）
var self_ally_cost_reduction := 0  # 快速出击：本回合我方手牌中「盟友」费用 -N（回合开始清零）
var self_next_ally_reduction := 0  # 斑鸠：本回合「下一个盟友」费用 -N（用掉 / 回合开始即清零）
var self_next_effect_reduction := 0  # 小精灵：本回合「下一张效果卡」费用 -N（用掉 / 回合开始即清零）
var fort_discount_self := 0    # 紧急埋伏 9106：你使用的下一张工事卡费用 -N（打出一张工事时消费一层，不随回合清零）
var fort_discount_opp := 0     # 同上，敌方（对称保留）
var self_effect_plays := 0      # 本回合我方已使用的「效果牌」张数（反应型效果卡判定「本回合第一次」）
var opp_effect_plays := 0       # 同上，敌方（敌方 AI 不出效果牌，保留以对称）
var self_skill_plays := 0       # 本回合我方已使用的「技能卡」张数（魔力核心 9076：每回合第一张技能）
var self_card_plays := 0        # 本回合我方已使用的**卡牌总张数**（终结 9086 的 X、幻影斗篷 6023 每 2 张触发；回合开始清零）
var opp_card_plays := 0         # 同上，敌方（对称保留：敌方若拿到终结，X 算法一致）
var wild_form_used := false     # 荒野形态 6022（R60）：本场战斗中是否已触发过「第一次受击减伤+反伤」
var void_dmg_spells := 0       # 虚空主宰 9082：本次对战中「用技能牌对敌方造成伤害」的次数
#                              （每发生一次，手卡里的虚空主宰费用 -2；只在本场战斗内累计）
var self_next_energy := 0      # 活力转移 9110（R55）：剩余费用换来的「下个回合开始时」额外费用（发放后清零）
var opp_next_energy := 0       # 同上，敌方（对称保留）
var self_energy_spent := 0     # 本回合**已花掉**的费用（暗影之刃 9111 的 X；回合开始清零）
var opp_energy_spent := 0      # 同上，敌方（对称保留）
var board := {}  # Vector2i -> Placement
# 场地效果（R74）：Vector2i -> CardData。**与board 完全分开**——场地不是单位，
# 不能被攻击、不挡路、也不参与碰撞；它只是「这个格子上挂着一个一次性效果」。
# **每个格子最多 1 个**（这正是「每个格子只能存在一个效果」的数据保证：
# 写入唯一口FieldState.set_field，第二块场地直接顶掉第一块，不做叠加）。
var field_effects := {}
# 双重场地（9108，R74）的待触发标记：Vector2i -> 次数。挂在**格子**上（场地不是单位）。
# 触发口唯一 = GameEngine._twin_field_chain（场地效果结算完、场地已被摘掉之后才调）。
var field_chains := {}
# 每个场地是**谁放的**（SIDE_SELF / SIDE_OPPONENT）。双重场地连锁补场地时按原主人取候选，
# 不能按「谁踩上去」取 —— 否则敌方踩我方场地会替我方抽卡。
var field_owner := {}
var hp_self := 20
var hp_opponent := 20
var max_hp_self := 20
var max_hp_opponent := 20
var opp_hand_count := 5
var opp_deck_count := 0
var self_turn_no := 0          # 我方已开始的回合数（哈气前置判定；引擎在回合开始时同步）
var opp_turn_no := 0           # 对方已开始的回合数（同上）
var card_discount := {}         # CardData -> int：实例级减费（智慧喷涌抽到的那一张效果卡费用 -N）
var turn_free := {}             # CardData -> true：本回合费用为 0（使魔之夜的乌鸦；回合结束清空）
## CardData -> true：**在手牌里期间**费用为 0（无限装甲 8038 供能的改造牌）。
## ⚠️ 与 `turn_free` 的关键区别 = **重置时机**：
##   * `turn_free` 在**回合结束**清空；
##   * 本表**回合结束不清** —— 判据是「这张卡此刻还在不在手牌里」，
##     所以玩家把它**打出 / 弃掉**时自动恢复原价（`cost_of` 里验 `hand.has(card)`）。
##   这也是为什么**不需要在 10 处离手口逐个挂钩**（离手口分散在 play / use / discard / …），
##   靠「判据 = 此刻在手牌里」一次解决，漏一处也不会出 bug。
var hand_free := {}
var turn_card_discount := {}    # CardData -> int：本回合这张**手卡**费用 -N（魔像术 9079；回合结束清空）
var turn_card_raise := 0         # 本回合**手卡全体**费用 +N（契约签订者 8024；回合结束清空）
var turn_keep: Array[CardData] = []  # 回转 9089 抽到的牌：本回合结束不弃（discard_hand 跳过；回合结束清空）
var turn_limit: int = -1        # -1 = 不限回合
var clear_win := false          # 消灭所有敌方场上单位 → 直接胜利（关卡有敌方单位时启用）
var level_name := ""
var rng: RandomNumberGenerator = null   # 洗牌随机源（录像回放注入；null = 引擎全局随机）


func _init(deck_cards: Array[CardData] = [], hp_me := 20, hp_foe := 20,
		limit := -1, lvl_name := "", do_shuffle := true,
		shuffle_rng: RandomNumberGenerator = null) -> void:
	deck = deck_cards.duplicate()
	hp_self = hp_me
	hp_opponent = hp_foe
	max_hp_self = hp_self
	max_hp_opponent = hp_opponent
	turn_limit = limit
	level_name = lvl_name
	rng = shuffle_rng
	if do_shuffle:
		_shuffle_deck()


func _shuffle_deck() -> void:
	## 洗牌：注入了 rng（录像回放）就走可复现的 Fisher-Yates，否则用引擎全局随机。
	if rng == null:
		deck.shuffle()
		return
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: CardData = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp


func _needs_own_instance(card: CardData) -> bool:
	## 这张卡是否需要「一抽到就复制一份」——它把减费记在实例身上，不能和牌库共享实例。
	for t: String in PER_INSTANCE_TRAITS:
		if card.traits.has(t):
			return true
	return false


func hand_full() -> bool:
	## 手牌是否已达上限（达上限后 draw() 不再给牌）。
	return hand.size() >= HAND_LIMIT


func draw() -> CardData:
	## 抽一张；手牌已满（>= HAND_LIMIT）→ 不抽并返回 null（**不洗牌、不丢牌**）；
	## 牌库空了先把弃牌区整堆洗入牌库（用户规则），两者都空才返回 null。
	if hand_full():
		return null
	if deck.is_empty() and not discard.is_empty():
		deck = discard.duplicate()
		_shuffle_deck()
		discard.clear()
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_back()
	# 「按张记账」的卡（陨石术「留手」/ 魔像术「魔像」）：抽到的这一张换成独立副本，
	# 否则同名卡共享库内实例 → 一张的减费会串到卡组里其它同名卡上（见 GameEngine 的实例级减费）。
	if _needs_own_instance(card):
		card = CardData.from_dict(card.to_dict())
	hand.append(card)
	return card


func discard_hand() -> int:
	## 回合结束：弃掉全部手牌 → 弃牌区。返回**离开手牌**的张数。
	## 例外一：带「离场消失」的卡（鸭蛋 9022）离场即消失，不进弃牌区、不会再被洗回卡组。
	## 例外二：带「留手」的卡（陨石术 9077 / 素体 8025）留在手卡里，下个回合继续用。
	## 例外三（R82）：**衍生物**（`CardData.is_ephemeral`，野兔 9032 复制出来的那些）
	##   回合结束就消失 —— 它是本场战斗内的产物，不该被洗回牌库再抽出来（否则能无限刷）。
	##   ⚠️ 判据是 `is_ephemeral` **而不是** trait「自我复制」：卡库里的原卡也带那个 trait，
	##   它是牌库实体，被弃时应该照常进弃牌区。
	var n := 0
	var kept: Array[CardData] = []
	for c: CardData in hand:
		if c.traits.has(VANISH_TRAIT):
			n += 1
			continue
		if c.is_ephemeral:
			n += 1
			continue
		if c.traits.has(KEEP_HAND_TRAIT):
			kept.append(c)
			continue
		if turn_keep.has(c):          # 回转：本回合抽到的牌留在手里
			kept.append(c)
			continue
		discard.append(c)
		n += 1
	hand.clear()
	for c: CardData in kept:
		hand.append(c)
	return n


func energy_of(side := "self") -> int:
	return energy if side == "self" else opp_energy


func pay_energy(cost: int, side := "self") -> void:
	## 扣费唯一入口。顺带记账「本回合已花掉多少」（暗影之刃 9111 的 X = 已花掉的费用数）：
	## 记**实际扣掉**的量（费用不足时不会扣成负数，就只记真实减少的那部分）。
	if side == "self":
		var before := energy
		energy = maxi(0, energy - cost)
		self_energy_spent += before - energy
	else:
		var before2 := opp_energy
		opp_energy = maxi(0, opp_energy - cost)
		opp_energy_spent += before2 - opp_energy


func energy_spent_of(side := "self") -> int:
	## 本回合已花掉的费用（暗影之刃 9111 的 X）。
	return self_energy_spent if side == "self" else opp_energy_spent


func starting_hand(count := 5) -> void:
	for i in count:
		draw()


func opp_draw(count := 1) -> void:
	opp_hand_count += count


static func cell_owner(row: int) -> String:
	return "opponent" if row < OPPONENT_ROWS else "self"


func unit_at(cell: Vector2i) -> Placement:
	return board.get(cell)


func field_at(cell: Vector2i) -> CardData:
	## 该格子上的场地效果（没有则 null）。唯一读取口。
	return field_effects.get(cell)


func set_field(card: CardData, cell: Vector2i, owner_side := "self") -> CardData:
	## 在格子上挂一个场地效果。**唯一写入口**（"每个格子只能存在一个效果" 的执行点）。
	## 返回被顶掉的那张旧场地（没有则 null）—— 双重场地要靠它接连锁。
	## 存**副本**而不是库内实例：场地会挂可叠加的临时加攻，直接挂共享实例会污染卡库。
	var old: CardData = field_effects.get(cell)
	field_effects[cell] = CardData.from_dict(card.to_dict())
	field_owner[cell] = owner_side
	return old


func clear_field(cell: Vector2i) -> CardData:
	## 撤掉格子上的场地（触发后 / 被顶替时）。返回被撤掉的那张。
	## **保留** field_chains：连锁标记属于「这个格子」而不是「这张场地」——
	## 触发后场地已消失，但格子若被双重场地标记过，随机补上的新场地同样该吃连锁。
	var old: CardData = field_effects.get(cell)
	field_effects.erase(cell)
	field_owner.erase(cell)
	return old


func extra_actions(side: String) -> int:
	## 该阵营效果区里「哈气」提供的**每回合行动次数**（多张取最大，不叠加）。
	## 0 = 没有哈气 / 还没到生效回合（正常每回合行动一次）。传 "self" / "opponent"。
	## 哈气有前置：该方第 HASTE_START_TURN 个回合起才生效（前两回合照常单动）。
	## 判定点只有这一处 —— place / reset_units / apply_extra_actions 全部经它。
	var zone: Array[CardData] = effects if side == "self" else enemy_effects
	var best := 0
	for c: CardData in zone:
		if c.traits.has(HASTE_TRAIT):
			best = maxi(best, c.value)
	if best <= 0:
		return 0
	var turn_no := self_turn_no if side == "self" else opp_turn_no
	if turn_no < HASTE_START_TURN:
		return 0
	return best


func apply_extra_actions(side: String) -> void:
	## 效果区发生变动后，给该阵营**已经在场**的单位补上额外的行动轮数
	## （关卡开局是先摆单位、再启用效果卡，所以必须补这一次）。
	var extra := extra_actions(side)
	if extra <= 0:
		return
	for p: Placement in board.values():
		if p.owner == side:
			p.acts_left = maxi(p.acts_left, extra)


func place(card: CardData, cell: Vector2i, owner := "self") -> Placement:
	var p := Placement.new()
	p.card = card
	p.owner = owner
	p.health = card.health
	# 哈气：已到生效回合且效果区有哈气时，上场即可行动 extra 次（与卡自带的 actions 取大者）
	p.acts_left = maxi(card.actions, extra_actions(owner))
	# 沉睡（恶魔鸭 9116）：带「沉睡」trait 的单位一上场就开始睡（SLEEP_TURNS 个己方回合）。
	# 放在 place 里 = 唯一初始化口，关卡摆位 / 效果卡召唤出来的都算。
	if card.traits.has(SLEEP_TRAIT):
		p.sleep_left = SLEEP_TURNS
	# 能量屏障（8033，R87）：带该 trait 的单位一上场就获得「首次受伤免掉」的一次性护盾。
	# 放在 place 里 = **唯一初始化口**，于是无论它是手牌打出来的、关卡摆位的、
	# 还是效果卡召唤出来的，都一致（漏了某条路径 = 那条路径出来的没有护盾）。
	p.first_hit_shield = card.traits.has(GameEngine.BARRIER_TRAIT)
	# 次元（R93）：**衍生物**上场那一刻挂上字段 —— 它们在场上离场即消失、不进弃牌区。
	# 放在 place 里 = 唯一初始化口，与「沉睡 / 护盾」同一套路。
	# ⚠️ 只在这里加，**手牌里那份复制品不加** —— 手牌那份是「幻影」
	#   （回合结束消失），两种消失刻意由两个字段分别表示，玩家一眼能分清。
	# ⚠️ `is_ephemeral` 只打在 `_spawn_self_clone` 产出的副本上，**卡库原卡没有**，
	#   所以不会误伤正常单位。副本是 `from_dict` 出来的独立实例 → 改它不污染卡库。
	if card.is_ephemeral:
		card.add_affix(GameEngine.AFFIX_DIMENSION)
	board[cell] = p
	return p


func move_unit(src: Vector2i, dst: Vector2i) -> void:
	board[dst] = board[src]
	board.erase(src)


func reset_units(side: String) -> void:
	for p: Placement in board.values():
		if p.owner == side:
			if p.frozen:
				# 寒冰箭：本回合开始不重置——横置保持（不能再行动），冰封解除
				p.tapped = true
				p.frozen = false
			elif p.sleep_left > 0:
				# 沉睡（恶魔鸭 9116，R63）：还在睡 → 本回合**不行动**（复用横置通道，
				# 于是 move / attack / attack_hp / AI 队列全部自然被拦住，不用各写一遍）。
				p.tapped = true
			else:
				p.tapped = false
			# 禁足（冰霜陷阱，R51）：挂上的下回合生效 —— 本回合视为已移动（不能移动，仍可攻击）
			if p.rooted == 1:
				p.rooted = 2
			p.moved = p.rooted > 0
			# 哈气：回合开始时被刷新成「行动两次」（未到生效回合 / 原本就双动 → 不叠加）
			p.acts_left = maxi(p.card.actions, extra_actions(side))


func iter_board() -> Array:
	## -> Array[ [Vector2i, Placement], ... ]，按格子排序保证绘制稳定。
	var pairs: Array = []
	for cell: Vector2i in board:
		pairs.append([cell, board[cell]])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	return pairs
