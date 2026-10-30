class_name FieldState
extends RefCounted
## 一局对局的场地状态（肉鸽版）。
## 战场 6 行 x 3 列：第 0~2 行对手、第 3~5 行自己；格子键 = Vector2i(行, 列)。
##
## 肉鸽费用规则：没有费用区卡牌，改为费用计数 —— 每回合固定 ENERGY_PER_TURN 点，
## 出牌时扣除；**回合结束时剩余费用作废、重置回 ENERGY_PER_TURN**（不跨回合累积）。
## 牌库循环：抽牌时牌库空了 → 把弃牌区整堆洗入牌库继续抽。

const BOARD_ROWS := 6
const BOARD_COLS := 3
const OPPONENT_ROWS := 3
const ENERGY_PER_TURN := 5
const HAND_DRAW_PER_TURN := 5
const HAND_LIMIT := 10           # 手牌上限：达到后**抽到的牌直接进弃牌区**（R299，不再留在牌库）
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
## 沉睡（恶魔鸭 9116）：Placement.sleep_left = 还要睡几点（回合/受伤各 -1）。
## 引擎在 end_turn 里对该方单位 -1；>0 时不能移动 / 攻击 / 直击 HP。
const SLEEP_TRAIT := "沉睡"
const SLEEP_TURNS := 2
# 「按张记账」的卡：减费记在这个实例身上 → 抽到时必须换成独立副本，
# 否则同名卡共享库内实例，一张的减费会串到卡组里其它同名卡上。
const PER_INSTANCE_TRAITS: Array[String] = ["留手", "魔像"]

## R299：手牌满时 `draw()` 抽出来的那张 —— 它**没进手牌、直接进了弃牌区**。
## 返回 null（语义仍是「没进手牌」），界面靠这个字段播「牌堆 → 弃牌堆」的动画，
## 引擎靠它区分「因为手牌满而进弃牌」与「牌库弃牌都空、真的抽不到」。
var last_burn_card: CardData = null
var deck: Array[CardData] = []
var discard: Array[CardData] = []
var hand: Array[CardData] = []
var effects: Array[CardData] = []   # 我方效果区：使用后的效果卡，正面朝上持续生效
var enemy_effects: Array[CardData] = []  # 敌方效果区：开局即启用，正面朝上持续生效
var energy := ENERGY_PER_TURN  # 我方费用计数（开局即有一回合的量；回合结束重置回它）
var opp_energy := ENERGY_PER_TURN  # 对方费用计数（同上：回合结束重置）
var self_cost_reduction := 0    # 赤狐：本回合我方出牌费用 -N（回合开始清零，只影响我方）
var self_ally_cost_reduction := 0  # 快速出击：本回合我方手牌中「盟友」费用 -N（回合开始清零）
var self_next_ally_reduction := 0  # 斑鸠：本回合「下一个盟友」费用 -N（用掉 / 回合开始即清零）
var self_next_effect_reduction := 0  # 小精灵：本回合「下一张效果卡」费用 -N（用掉 / 回合开始即清零）
var self_effect_plays := 0      # 本回合我方已使用的「效果牌」张数（反应型效果卡判定「本回合第一次」）
var opp_effect_plays := 0       # 同上，敌方（敌方 AI 不出效果牌，保留以对称）
var self_skill_plays := 0       # 本回合我方已使用的「技能卡」张数（魔力核心 9076：每回合第一张技能）
var self_card_plays := 0        # 本回合我方已使用的**卡牌总张数**（终结 9086 的 X、幻影斗篷 6023 每 2 张触发；回合开始清零）
var opp_card_plays := 0         # 同上，敌方（对称保留：敌方若拿到终结，X 算法一致）
var wild_form_used := false     # 荒野形态 6022（R60）：本场战斗中是否已触发过「第一次受击减伤+反伤」
var void_dmg_spells := 0       # 风元素 9082：本次对战中「用技能牌对敌方造成伤害」的次数
#                              （每发生一次，手卡里的风元素费用 -2；只在本场战斗内累计）
## R140：本局「消失」的卡数（消耗区计数）—— 离场消失 / 用后消失 / 从抽牌库抹除，
## 共同点 = **不进弃牌区、也不回手牌**，等于从本场牌组里抹掉。累加口见各处
## `void_count += 1`（FieldState.discard_hand / GameEngine 的 use_spell·_destroy·
## focus_pick·foresight_pick_card·_melt_ice_walls），战斗结束即作废。
var void_count := 0
## R155：消失的卡本体（与 void_count 平行，每处 `void_count += 1` 都同步 append）——
## 消耗区从「只报一个数」升级成可点开的浏览面板，玩家能回看本局到底消失了哪些卡。
var void_cards: Array = []
var self_next_energy := 0      # 活力转移 9110（R55）：剩余费用换来的「下个回合开始时」额外费用（发放后清零）
var self_next_draw := 0        # 负重减轻 8066（R201）：选卡消失换来的「下个回合开始时」额外抽牌张数（发放后清零）
var opp_next_energy := 0       # 同上，敌方（对称保留）
var self_energy_spent := 0     # 本回合**已花掉**的费用（暗影之刃 9111 的 X；回合开始清零）
var opp_energy_spent := 0      # 同上，敌方（对称保留）
var board := {}  # Vector2i -> Placement
# 场地效果（R74）：Vector2i -> CardData。**与board 完全分开**——场地不是单位，
# 不能被攻击、不挡路、也不参与碰撞；它只是「这个格子上挂着一个一次性效果」。
# **每个格子最多 1 个**（这正是「每个格子只能存在一个效果」的数据保证：
# 写入唯一口FieldState.set_field，第二块场地直接顶掉第一块，不做叠加）。
var field_effects := {}
# 每个场地是**谁放的**（SIDE_SELF / SIDE_OPPONENT）。归属判据（场地精通加成按主人的
# 效果区算、界面按主人配色）都读它，不能按「谁踩上去」取 —— 否则敌方踩我方场地会替我结算。
var field_owner := {}
	## R451：空袭（9209，敌方效果卡）——**玩家回合开始**随机标记的格子。
	## 只记坐标、不记卡：标记只是「这些格子下回合要挨炸」的临时指令，与 `field_effects`
	## （那格真的挂着一张场地卡）是两回事，别混成一张表。
var air_raid_cells: Array[Vector2i] = []
	## R451：空袭已经结算过几轮 → 落地值 = 卡面 value + 本值 × GameEngine.AIR_RAID_STEP。
var air_raid_turns := 0

var hp_self := 20
var hp_opponent := 20
## R234 止血绷带（6029）：本场战斗中我方 HP **实际**受到的伤害合计（每场 FieldState 新建即清零）。
var self_hp_damage_taken := 0
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
## R271：**手卡内减费**（CardData -> int，正数 = 减 N 费）。
## 与 `hand_free` 同一条判据（`cost_of` 里验 `hand.has(card)`）→ 打出 / 弃掉自动恢复原价。
## 用途：谟涅摩叙涅 8072「以随机变化方式入手 → 费用 -2」。
var hand_cost_delta := {}
## R276：**本回合**的手卡内减费（CardData -> int，正数 = 减 N 费）。
## 与 `hand_cost_delta` 是**两张表**：上面那张是「永久」（谟涅摩叙涅 8072 的 -2），
## 这张只活到 `end_turn` —— 用途是随心组装 9144「变化出的盟友卡本回合费用 -1」。
## 同样靠 `hand.has(card)` 判据 → 离手自动恢复原价，不必逐处清标记。
var hand_cost_turn := {}
## R271：代达罗斯 8060「本回合，你手卡里的「聚能炮击」费用为 0」—— **回合结束清空**。
var turn_cannon_free := false
## R271：**本次对战中我方使用过几张「聚能炮击」9145**（聚能机兵 / 代达罗斯 / 量产型的 X）。
## 记账口唯一 = `GameEngine._note_card_played()`。
var self_cannon_plays := 0
## R404：**本次对战中我方变化过几张牌**（失控要塞 9161 的 X）。
## 记账口唯一 = `GameEngine._note_card_changed()`：手牌变化走 `_transform_hand_card()`，
## 卡组变化走惊喜运单 8079 / 库存整理 9184。与 `self_cannon_plays` 并列、**回合不清零**。
var self_card_changes := 0
var turn_card_discount := {}    # CardData -> int：本回合这张**手卡**费用 -N（魔像术 9079；回合结束清空）
var turn_card_raise := 0         # 本回合**手卡全体**费用 +N（契约签订者 8024；回合结束清空）
var turn_keep: Array[CardData] = []  # 回转 9089 抽到的牌：本回合结束不弃（discard_hand 跳过；回合结束清空）
## 夜行（9155，R232）：本回合**我方所有卡费用为 0**（cost_of 最前判定；回合结束清空）。
var turn_all_free := false
## 夜行（9155，R232）：本回合**我方出牌上限**（含夜行本卡；0 = 不限；回合结束清空）。
var card_play_cap := 0
var turn_limit: int = -1        # -1 = 不限回合
var clear_win := false          # 消灭所有敌方场上单位 → 直接胜利（关卡有敌方单位时启用）
var level_name := ""
var rng: RandomNumberGenerator = null   # 洗牌随机源（测试/固定种子注入；null = 引擎全局随机）


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
	## 洗牌：注入了 rng（固定种子 / 回归测试）就走可复现的 Fisher-Yates，否则用引擎全局随机。
	if rng == null:
		# ⚠️ R312（种子审计）：rng 为 null 这条兜底**不可复现** —— 全局随机源既不受本局
		# 种子控制，也不进录像 / 存档。真实战斗（battle_scene.load_level 传 brng）与联机
		# （R312 起按卡组哈希播种）都走不到这里；只有测试 / 演示故意不传 rng 时会用到。
		# 新增调用方请一律传 rng，不要依赖这条兜底。
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
	## 抽一张。
	## R299（用户规则）：**手牌满 → 照样从牌库抽出来，但直接进弃牌区** —— 不再「不抽、不丢牌」。
	##   抽出来的那张记在 `last_burn_card` 上（界面据此播「牌堆 → 弃牌堆」动画），
	##   返回值仍是 null（语义 = 没进手牌），调用方不必改判据。
	## 牌库空了先把弃牌区整堆洗入牌库（用户规则），**两者都空**才返回 null（此时 last_burn_card 也为 null）。
	last_burn_card = null
	if deck.is_empty() and not discard.is_empty():
		deck = discard.duplicate()
		_shuffle_deck()
		discard.clear()
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_back()
	# 「按张记账」的卡（陨石术「留手」/ 魔像术「魔像」）：**第一次**抽到换成独立副本，
	# 否则同名卡共享库内实例 → 一张的减费会串到卡组里其它同名卡上（见 GameEngine 的实例级减费）。
	# R123：副本离开手卡再抽回来**不再换新副本**（own_copy 已标记）——
	# 否则实例级永久减费（陨石术「每用一张技能 -1」）会在每次循环后静默归零。
	# R281：**手牌里永远是独立副本**。实例级记账（card_discount / turn_card_discount /
	# hand_free / turn_free）都以 CardData 对象为 key，而牌库/弃牌区里的同名卡**共享卡库实例**
	# —— 只要一张共享实例进了手牌，给「它」减费就等于给**所有同名卡**减费
	# （实测：8075 量产型谟涅摩叙涅的炮击减费串到了牌库另一张同名卡）。
	# 所以判据从白名单 trait 放宽成「**还没复制过就复制**」；R123 的顾虑
	# （副本离手再抽回会被重复复制 → 永久减费归零）由 `own_copy` 标记覆盖。
	if not card.own_copy:
		card = CardData.from_dict(card.to_dict())
		card.own_copy = true
	# R299：手牌满 → 这张照样**离开牌库**，但直接进弃牌区（不再原地留在牌库）。
	# ⚠️ 顺序：先 pop 再判满 —— 用户口径是「手牌满之后一切抽卡都改为进弃牌」，
	#    不是「手牌满就不抽」。
	if hand_full():
		discard.append(card)
		last_burn_card = card
		return null
	hand.append(card)
	return card


func discard_hand(keep_all := false) -> int:
	## 回合结束：弃掉全部手牌 → 弃牌区。返回**离开手牌**的张数。
	## R314 储物箱（6044）：`keep_all = true` → **一张都不弃**（直接返回 0）。
	## ⚠️ 只跳过「进水弃牌区」这一步：带「离场消失」的卡与衍生物**照旧消失** ——
	##    那是「消失」不是「丢弃」，若也保留，野兔复制出来的衍生物会无限堆在手里。
	## 例外一：带「离场消失」的卡（鸭蛋 9022）离场即消失，不进弃牌区、不会再被洗回卡组。
	## 例外二：带「留手」的卡（陨石术 9077 / 素体 8025）留在手卡里，下个回合继续用。
	## 例外三（R82）：**衍生物**（`CardData.is_ephemeral`，野兔 9032 复制出来的那些）
	##   回合结束就消失 —— 它是本场战斗内的产物，不该被洗回牌库再抽出来（否则能无限刷）。
	##   ⚠️ 判据是 `is_ephemeral` **而不是** trait「自我复制」：卡库里的原卡也带那个 trait，
	##   它是牌库实体，被弃时应该照常进弃牌区。
	var n := 0
	var kept: Array[CardData] = []
	for c: CardData in hand:
		if keep_all and not c.traits.has(VANISH_TRAIT) and not c.is_ephemeral:
			kept.append(c)
			continue
		if c.traits.has(VANISH_TRAIT):
			n += 1
			void_count += 1   # R140：离场消失 → 计入消耗区
			void_cards.append(c)
			continue
		if c.is_ephemeral:
			n += 1
			void_count += 1   # R140：衍生物回合结束消失 → 计入消耗区
			void_cards.append(c)
			continue
		if c.traits.has(KEEP_HAND_TRAIT):
			kept.append(c)
			continue
		if c.has_affix("保存"):          # R181：商店附魔「保存」——回合结束手牌保留（做成字段）
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
	## 返回被顶掉的那张旧场地（没有则 null）。
	## 存**副本**而不是库内实例：场地会挂可叠加的临时加攻，直接挂共享实例会污染卡库。
	var old: CardData = field_effects.get(cell)
	field_effects[cell] = CardData.from_dict(card.to_dict())
	field_owner[cell] = owner_side
	return old


func clear_field(cell: Vector2i) -> CardData:
	## 撤掉格子上的场地（触发后 / 被顶替时）。返回被撤掉的那张。
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


func has_mass_helios(side: String) -> bool:
	## 「量产型赫利俄斯」（9137，R152）是否在**该方场上**。
	## 它是「除自己以外的己方单位受到的技能伤害减半（向上取整）」这条光环的**唯一开关**，
	## 与 `has_sun_forge` 同范式：实时扫场面、只收成一个函数、绝不烤进 CardData ——
	## 「塔被打掉 → 光环立刻断」是免费的。
	## ⚠️ 光环**不含光源自己**（「量产型赫利俄斯以外的己方单位」），那条判据在引擎侧
	##    `_unit_damage_taken` 里用 `p.card.id != MASS_HELIOS_ID` 补。
	for p: Placement in board.values():
		if p.owner == side and p.card.id == GameEngine.MASS_HELIOS_ID:
			return true
	return false


func has_sun_forge(side: String) -> bool:
	## 「太阳熔炉」的太阳装置（赫利俄斯 9130）是否在**该方场上**。
	## 它是「量产型俄倪厄双动」与「俄倪厄每回合回血」两条光环的**唯一开关**，
	## 所以两条都调这里判 —— 两处各写一遍扫描迟早会漏一处（改了一处忘另一处）。
	for p: Placement in board.values():
		if p.owner == side and p.card.id == GameEngine.SUN_FORGE_HELIOS_ID:
			return true
	return false


func unit_actions(p: Placement, side: String) -> int:
	## 单位本回合的**行动轮数**（唯一口）。四个来源取最大：
	##   ① 卡面自带 `actions`（疾行，如鸭子队长）；
	##   ② 效果区「哈气」9024 给的 `extra_actions`（整方生效）；
	##   ③ 太阳熔炉：本方场上有赫利俄斯 → 量产型俄倪厄（9131）额外行动一次；
	##   ④ 行动力成长（R161 赫尔墨斯 9140）：每过 3 回合额外 +1 行动轮数。
	## ⚠️ 所有写 `acts_left` 的地方（place / reset_units / apply_extra_actions）
	##   都必须走这个口 —— 漏一处就会出现「上场那回合不动、下回合才双动」的错位。
	var n := maxi(p.card.actions, extra_actions(side))
	n = maxi(n, p.action_growth_extra)
	# R371：启示者阶段 2 起「每回合可行动两次」—— 与卡面 `actions` / 哈气 同一条
	# 「取最大」通道，于是 place / reset_units / apply_extra_actions 三处自动一致。
	if p.boss_phase >= 2:
		n = maxi(n, GameEngine.REVELATOR_ACTIONS)
	if p.card.id == GameEngine.SUN_FORGE_FURY_ID and has_sun_forge(side):
		n = maxi(n, GameEngine.SUN_FORGE_ACTIONS)
	return n


func apply_extra_actions(side: String) -> void:
	## 场上有新单位落地 / 效果区发生变动后，给该阵营**已经在场**的单位补上额外行动轮数。
	## 原本只有「哈气」一个来源（关卡开局是先摆单位、再启用效果卡，所以必须补这一次）；
	## R135 起来源多了「场上的赫利俄斯」—— 它的上场顺序**不由效果区决定**，
	## 所以判据统一收敛到 `unit_actions`，不再只看效果区（那条 `extra <= 0 → return`
	## 的短路也必须去掉，否则「没有哈气」的关卡整段被跳过）。
	for p: Placement in board.values():
		if p.owner == side:
			p.acts_left = maxi(p.acts_left, unit_actions(p, side))


func place(card: CardData, cell: Vector2i, owner := "self",
		summon := false) -> Placement:
	var p := Placement.new()
	p.card = card
	p.owner = owner
	p.health = card.health
	# R209：把**随身携带**的改造层数接到场上。手牌 / 牌库里的改造（系统升级 / 批量改造 /
	# 批量传输 / 自主升级 / 生产订单 / 回收 / 返修）烤进的就是这张卡，层数记在
	# `card.upgrade_stacks` —— 漏了这一步，侦察塔光环（每层 +1 易伤）与卡面
	# 「改造 ×N」徽标上场后全是 0（用户实测报的缺陷）。
	# ⚠️ 只读不写回：上场后的改造仍只加 `p.upgrade_stacks`，离场不还原到卡上。
	p.upgrade_stacks = card.upgrade_stacks
	# R274：「改造生命层」（堡垒 8034）—— **层数不论在哪里获得**，
	# 上场时一并折算成生命（以前只有「升级」「加厚装甲」两个场上入口给，
	# 手牌里攒的层数上场后白吃）。走同一套差量记账：
	# `stack_hp_applied` 记「已结算多少」，`upgrade_hp` 记「离场要还多少」。
	# ⚠️ 先换独立副本：`card` 可能是卡库共享实例，直接改会跨 run 泄漏。
	if card.traits.has(GameEngine.STACK_HP_TRAIT):
		var stack_bonus: int = p.upgrade_stacks * GameEngine.STACK_HP_PER
		if stack_bonus > 0:
			p.card = CardData.from_dict(card.to_dict())
			p.card.traits = (p.card.traits as Array).duplicate()
			p.stack_hp_applied = stack_bonus
			p.upgrade_hp += stack_bonus
			p.card.health += stack_bonus
			p.health += stack_bonus
	# R279：「改造攻程 / 改造移速」—— 与「改造生命层」同一条路：**层数不论在哪里获得**，
	# 上场时一并折算。手牌里被改造过的榴弹击手（系统升级 / 批量改造 / 创意 等）上场后，
	# 射程必须跟着层数走 —— 以前只在场上改造才 +1，手牌攒的层数上场就白吃（用户报的缺陷）。
	# 记账仍走 Placement 字段（`upgrade_range` / `upgrade_speed`），离场由
	# `_card_leaving_field` 一并减回去；卡面数值同时抬在这个**副本**上（与场上改造同口径）。
	# ⚠️ 先换独立副本：`card` 可能是卡库共享实例，直接改会跨 run 泄漏。
	if p.upgrade_stacks > 0:
		var rng_bonus: int = p.upgrade_stacks if card.traits.has(GameEngine.UPGRADE_RANGE_TRAIT) else 0
		var spd_bonus: int = p.upgrade_stacks if card.traits.has(GameEngine.UPGRADE_SPEED_TRAIT) else 0
		if rng_bonus > 0 or spd_bonus > 0:
			if p.card == card:
				p.card = CardData.from_dict(card.to_dict())
				p.card.traits = (card.traits as Array).duplicate()
			p.upgrade_range += rng_bonus
			p.upgrade_speed += spd_bonus
			p.card.attack_range += rng_bonus
			p.card.move_speed += spd_bonus
	# 哈气：已到生效回合且效果区有哈气时，上场即可行动 extra 次（与卡自带的 actions 取大者）。
	# ⚠️ R122：`summon = true`（**被召唤**出来的，不是玩家从手牌打出来的）固定 **1 轮** ——
	#    召唤物当回合**恰好行动一次**，不继承哈气 / 双动字段。
	#    用户口径：「当回合仍然可以行动，只是回合计数要正确，召唤的回合行动 2 格肯定是有问题的」。
	#    玩家主动出牌（play_from_hand）照旧吃哈气 —— 那是「他自己花费用打出来的」。
	p.acts_left = 1 if summon else unit_actions(p, owner)
	# 沉睡（恶魔鸭 9116）：带「沉睡」trait 的单位一上场就开始睡（SLEEP_TURNS 点）。
	# 放在 place 里 = 唯一初始化口，关卡摆位 / 效果卡召唤出来的都算。
	if card.traits.has(SLEEP_TRAIT):
		p.sleep_left = SLEEP_TURNS
	# 铸造倒计时（量产型赫卡同克瑞斯 9133，R149）：带「铸造」trait 的单位一上场就挂表。
	# 同样放在 place 里 = **唯一初始化口**（与沉睡 / 护盾同一套路）；回合数取引擎常量
	# FUSE_TURNS，与卡面 effect_text 写的是同一句话 —— 改一处必须一起改。
	if card.traits.has(GameEngine.FUSE_TRAIT):
		p.fuse_left = GameEngine.FUSE_TURNS
	# 锻造（赫菲斯托斯 9135，R150）：带「锻造」trait 的单位一上场就挂上空转计数。
	# 同样放在 place 里 = **唯一初始化口**（与沉睡 / 铸造同一套路）；周期取引擎常量
	# FORGE_PERIOD，与卡面 effect_text 写的是同一句话 —— 改一处必须一起改。
	if card.traits.has(GameEngine.FORGE_TRAIT):
		p.forge_period = GameEngine.FORGE_PERIOD
	# 行动力成长（R161，赫尔墨斯 9140）：上场时挂上空转计数器。
	# 同样放在 place 里 = **唯一初始化口**；周期取引擎常量 ACTION_GROWTH_PERIOD。
	if card.traits.has(GameEngine.ACTION_GROWTH_TRAIT):
		p.action_growth_turns = 0
		p.action_growth_extra = p.card.actions   # 总行动数目标，成长时 +1
	# 启示者（9200，R356，第三层 Boss）：一上场就是**第 1 阶段**。
	# 同样放在 place 里 = 唯一初始化口（关卡摆位 / 将来任何召唤路径都一致）；
	# 之后的 2、3 阶段由引擎按血量在 `_revelator_check_phase()` 里推进。
	if card.id == GameEngine.REVELATOR_ID:
		p.boss_phase = 1
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
			elif p.stun_left > 0:
				# 眩晕（R341，惊奇盒子 9179）：与冰封同一条通道 —— 本回合横置保持、不吃行动权，
				# 眩晕本身解除（只挡一个自己回合）。
				p.tapped = true
				p.stun_left -= 1
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
			# 陷阱加强（R238）：「本回合挪过没有」的**唯一复位口** —— 回合开始清零，
			# 与上面的 moved 分开记（moved 会被禁足置 true，不能拿来判「原地不动」）。
			p.did_move = false
			# 哈气 / 太阳熔炉：回合开始时刷新成「行动两次」
			# （未到生效回合 / 原本就双动 → 不叠加，取最大）
			p.acts_left = unit_actions(p, side)


func iter_board() -> Array:
	## -> Array[ [Vector2i, Placement], ... ]，按格子排序保证绘制稳定。
	var pairs: Array = []
	for cell: Vector2i in board:
		pairs.append([cell, board[cell]])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	return pairs


# ============================================================ R439 战斗存档
## 把整场局面写成可落盘的字典。**只在「我方回合开始」这一刻调用** ——
## 此刻回合级临时表（turn_free / hand_cost_turn / turn_keep / 各种 pending）
## 都已被开局流程清空，所以它们**故意不存**：存了反而会在续档时复活一批过期状态。
## 要存的是「跨回合仍然成立」的东西：牌堆、场面、双方血量、费用、消耗区计数。
func save_dict() -> Dictionary:
	var d: Dictionary = {
		"energy": energy,
		"opp_energy": opp_energy,
		"hp_self": hp_self,
		"hp_opponent": hp_opponent,
		"max_hp_self": max_hp_self,
		"max_hp_opponent": max_hp_opponent,
		"self_turn_no": self_turn_no,
		"opp_turn_no": opp_turn_no,
		"void_count": void_count,
		"self_cannon_plays": self_cannon_plays,
		"self_card_changes": self_card_changes,
		"self_hp_damage_taken": self_hp_damage_taken,
		"wild_form_used": wild_form_used,
		"void_dmg_spells": void_dmg_spells,
		"opp_hand_count": opp_hand_count,
		"turn_limit": turn_limit,
		"clear_win": clear_win,
		"level_name": level_name,
		"self_next_energy": self_next_energy,
		"self_next_draw": self_next_draw,
		"opp_next_energy": opp_next_energy,
		"void_cards": _cards_save(void_cards),
		"deck": _cards_save(deck),
		"discard": _cards_save(discard),
		"hand": _cards_save(hand),
		"effects": _cards_save(effects),
		"enemy_effects": _cards_save(enemy_effects),
		"board": _board_save(),
		"fields": _fields_save(),
		"air_raid_cells": _air_raid_save(),
		"air_raid_turns": air_raid_turns,
	}
	if rng != null:
		d["rng_seed"] = rng.seed
		d["rng_state"] = rng.state
	return d


func apply_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	energy = int(d.get("energy", energy))
	opp_energy = int(d.get("opp_energy", opp_energy))
	hp_self = int(d.get("hp_self", hp_self))
	hp_opponent = int(d.get("hp_opponent", hp_opponent))
	max_hp_self = int(d.get("max_hp_self", max_hp_self))
	max_hp_opponent = int(d.get("max_hp_opponent", max_hp_opponent))
	self_turn_no = int(d.get("self_turn_no", self_turn_no))
	opp_turn_no = int(d.get("opp_turn_no", opp_turn_no))
	void_count = int(d.get("void_count", void_count))
	self_cannon_plays = int(d.get("self_cannon_plays", self_cannon_plays))
	self_card_changes = int(d.get("self_card_changes", self_card_changes))
	self_hp_damage_taken = int(d.get("self_hp_damage_taken", self_hp_damage_taken))
	wild_form_used = bool(d.get("wild_form_used", wild_form_used))
	void_dmg_spells = int(d.get("void_dmg_spells", void_dmg_spells))
	opp_hand_count = int(d.get("opp_hand_count", opp_hand_count))
	turn_limit = int(d.get("turn_limit", turn_limit))
	clear_win = bool(d.get("clear_win", clear_win))
	level_name = str(d.get("level_name", level_name))
	self_next_energy = int(d.get("self_next_energy", self_next_energy))
	self_next_draw = int(d.get("self_next_draw", self_next_draw))
	opp_next_energy = int(d.get("opp_next_energy", opp_next_energy))
	void_cards = _cards_load(d.get("void_cards", []))
	deck = _cards_load(d.get("deck", []))
	discard = _cards_load(d.get("discard", []))
	hand = _cards_load(d.get("hand", []))
	effects = _cards_load(d.get("effects", []))
	enemy_effects = _cards_load(d.get("enemy_effects", []))
	board.clear()
	var bl: Variant = d.get("board", [])
	if bl is Array:
		for item: Variant in bl:
			if not (item is Dictionary):
				continue
			var cell := Vector2i(int(item["r"]), int(item["c"]))
			var p := Placement.new()
			p.apply_save(item["p"])
			board[cell] = p
	field_effects.clear()
	field_owner.clear()
	var fl: Variant = d.get("fields", [])
	if fl is Array:
		for item2: Variant in fl:
			if not (item2 is Dictionary):
				continue
			var cell2 := Vector2i(int(item2["r"]), int(item2["c"]))
			field_effects[cell2] = CardData.from_dict(item2["card"])
			field_owner[cell2] = str(item2.get("owner", "self"))
	air_raid_cells.clear()
	var ar: Variant = d.get("air_raid_cells", [])
	if ar is Array:
		for item3: Variant in ar:
			if item3 is Dictionary:
				air_raid_cells.append(Vector2i(int(item3["r"]), int(item3["c"])))
	air_raid_turns = int(d.get("air_raid_turns", air_raid_turns))
	# 洗牌随机源：续档后继续抽牌 / 触发的随机必须接着同一条链（否则续档 = 换牌序）
	if d.has("rng_seed") and rng != null:
		rng.seed = int(d["rng_seed"])
		rng.state = int(d["rng_state"])


static func _cards_save(arr: Array) -> Array:
	var out: Array = []
	for c: Variant in arr:
		if c is CardData:
			out.append((c as CardData).to_dict())
	return out


static func _cards_load(arr: Variant) -> Array[CardData]:
	var out: Array[CardData] = []
	if arr is Array:
		for x: Variant in arr:
			if x is Dictionary:
				out.append(CardData.from_dict(x))
	return out


func _board_save() -> Array:
	var out: Array = []
	for cell: Vector2i in board:
		var p: Placement = board[cell]
		if p == null:
			continue
		out.append({"r": cell.x, "c": cell.y, "p": p.to_save()})
	return out


func _air_raid_save() -> Array:
	## R451：空袭标记格的存档形态（与 `_board_save` 同款 {"r","c"}）。
	var out: Array = []
	for cell: Vector2i in air_raid_cells:
		out.append({"r": cell.x, "c": cell.y})
	return out


func _fields_save() -> Array:
	var out: Array = []
	for cell: Vector2i in field_effects:
		var c: CardData = field_effects[cell]
		if c == null:
			continue
		out.append({"r": cell.x, "c": cell.y, "card": c.to_dict(),
				"owner": str(field_owner.get(cell, "self"))})
	return out
