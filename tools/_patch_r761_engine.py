# -*- coding: utf-8 -*-
"""R761 补丁 5/9：占位字段 + 引擎 —— 诗（6069）与 招募（9264）。

game_engine.gd / placement.gd 都是 **CRLF**，本脚本按字节改，模式串统一 \n → \r\n。
"""
import io

GE = r"E:\work\card_rogue\scripts\game_engine.gd"
PL = r"E:\work\card_rogue\scripts\placement.gd"


def load(p):
    with io.open(p, "rb") as f:
        return f.read()


def save(p, b):
    with io.open(p, "wb") as f:
        f.write(b)


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n")


def rep(b, old, new, n=1):
    o = crlf(old).encode("utf-8")
    c = b.count(o)
    assert c == n, "命中 %d 次（期望 %d）：%r" % (c, n, old[:70])
    return b.replace(o, crlf(new).encode("utf-8"))


# ============================================================ placement.gd
b = load(PL)

b = rep(b, '''var totem_atk: int = 0
''', '''var totem_atk: int = 0
## R761 诗（6069，吟游诗人初始道具）：「**其他职业**的盟友 +2 力量」——
## 与竖琴 / 野性图腾**逐字同构**的持续 buff（赋值不累加、绝不写回 `card.power`）。
## 与竖琴唯一的差别是判据：只看「这张盟友不是吟游诗人自己的」（杜鹃不算）。
var poem_atk: int = 0
''')

b = rep(b, '''			+ end_atk + upgrade_atk + dark_lord_atk + hecaton_atk + harp_atk + sword_atk
			+ totem_atk
''', '''			+ end_atk + upgrade_atk + dark_lord_atk + hecaton_atk + harp_atk + sword_atk
			+ totem_atk + poem_atk
''')

b = rep(b, '''	if totem_atk > 0:
		out.append({"label": "野性图腾：力量 +%d（本场，不叠加）" % totem_atk,
				"col": COL_B, "kind": "buff"})
''', '''	if totem_atk > 0:
		out.append({"label": "野性图腾：力量 +%d（本场，不叠加）" % totem_atk,
				"col": COL_B, "kind": "buff"})
	if poem_atk > 0:
		out.append({"label": "诗：力量 +%d（本场，不叠加）" % poem_atk,
				"col": COL_B, "kind": "buff"})
''')

b = rep(b, '''	"mass_mnemo_turn", "sleep_left", "stun_left", "harp_atk", "sword_atk",
''', '''	"mass_mnemo_turn", "sleep_left", "stun_left", "harp_atk", "sword_atk", "poem_atk",
''')

save(PL, b)
print("placement.gd OK")

# ============================================================ game_engine.gd
b = load(GE)

# ---- 常量 ----
b = rep(b, '''const HARP_RELIC_ID:= 6052
const HARP_ATK:= 2
''', '''const HARP_RELIC_ID:= 6052
const HARP_ATK:= 2
# R761 诗（6069，吟游诗人初始道具），两段效果都只住在本组常量里：
#   ① **每回合第一次**使用「其他职业的盟友」→ 回复 `POEM_REBATE` 点费用（`_poem_tick`）；
#   ② **其他职业的盟友** +`POEM_ATK` 力量 —— 与竖琴 6052 同一套持续 buff 写法
#      （`Placement.poem_atk` + `effective_power()`，赋值不累加，绝不写回 `card.power`）。
# ⚠️ 「其他职业」的判据是**不是吟游诗人自己**（`_poem_ally()`）—— 杜鹃 9263 不吃。
const POEM_RELIC_ID:= 6069
const POEM_ATK:= 2
const POEM_REBATE:= 1
# R761 招募（9264，吟游诗人 0 费技能）：从三个其他职业的盟友里选一张加入手卡。
# 候选在**开面板那一刻**就摇定并缓存（与神秘牌 7011 同一口径），否则同一份存档读两次
# 会出现两组不同的候选。随机源走引擎 rng → 同种子同结果、回放可复现。
const RECRUIT_ID:= 9264
''')

# ---- 待选字段 ----
b = rep(b, '''var wish_pending:= false    # 许愿（9168）：等玩家从**卡组**选一张卡加入手卡
''', '''var wish_pending:= false    # 许愿（9168）：等玩家从**卡组**选一张卡加入手卡
## R761 招募（9264）：等玩家从**三个其他职业的盟友**里选一张加入手卡。
## 候选是**独立副本**（`_new_own_card`），且只在这里存一份 —— 面板只是把它画出来。
var recruit_pending:= false
var _recruit_cards: Array = []
''')

# ---- start_game 重置 ----
b = rep(b, '''	wish_pending = false
	_steel_stamp_used = false   # R307：思想钢印每场战斗一次
''', '''	wish_pending = false
	recruit_pending = false
	_recruit_cards.clear()
	_poem_used = false          # R761 诗：每场战斗从「这回合还没回费」开始
	_steel_stamp_used = false   # R307：思想钢印每场战斗一次
''')

# ---- 每回合开关 ----
b = rep(b, '''		_unit_played_this_turn = false
''', '''		_unit_played_this_turn = false
		_poem_used = false   # R761 诗：每个我方回合重新给一次「第一次」额度
''')

# ---- 回合开始的道具对齐 ----
b = rep(b, '''		_sync_harp()   # R352 竖琴：战斗中拿到的道具 / 读档续战，此处补齐在场上盟友的 +2
''', '''		_sync_harp()   # R352 竖琴：战斗中拿到的道具 / 读档续战，此处补齐在场上盟友的 +2
		_sync_poem()   # R761 诗：同一处对齐「其他职业的盟友 +2 力量」
''')

# ---- _sync_poem（插在 _sync_totem 之前）----
b = rep(b, '''func _sync_totem() -> void:
''', '''func _sync_poem() -> void:
	## R761 诗（6069）：把场上每个**其他职业的**己方盟友的 `poem_atk` 与「是否持有道具」对齐
	## （**赋值**，不累加 —— 与竖琴 R372 / 野性图腾 R745 完全同一套写法）。
	## 需要它是因为道具可能在战斗中途拿到 / 读档续战，那批盟友上场时还没有「诗」。
	## 幂等，随便多调。
	var has_poem := RunState.has_relic(POEM_RELIC_ID)
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != SIDE_SELF or p.health <= 0 or p.card == null:
			continue
		if not _poem_ally(p.card):
			continue
		var want := POEM_ATK if has_poem else 0
		if p.poem_atk == want:
			continue
		p.poem_atk = want
		if want > 0:
			_log("诗：%s 补吃 +%d 力量（%d）"
					% [p.card.card_name, POEM_ATK, p.effective_power()])


func _poem_ally(card: CardData) -> bool:
	## R761：「其他职业的盟友」唯一判据 —— 盟友卡且**不是吟游诗人自己的**。
	## 公用卡（class 留空，如雪豹 8081）与三个职业的盟友都算「其他职业」，
	## 因为「诗」吃的不是某个具体职业，而是「借来的、不是我自己谱的曲」。
	return card != null and card.kind == "盟友" \\
			and card.card_class != PlayerClass.BARD


func _poem_tick(side: String, played: CardData) -> void:
	## R761 诗（6069）①：**每回合第一次**使用其他职业的盟友 → 回复 1 点费用。
	## 判据三件套：我方 / 本回合还没触发过 / 打出的确实是别职业的盟友。
	## 记账口就这一处（`_note_card_played` 是唯一出牌收尾口）—— 远程、回放、随机打出
	## 全都会走到，不会出现「玩家出牌回费、AI 出牌不回费」两套口径。
	if side != SIDE_SELF or _poem_used:
		return
	if not RunState.has_relic(POEM_RELIC_ID) or not _poem_ally(played):
		return
	_poem_used = true
	state.energy += POEM_REBATE
	_log("诗：本回合第一次使用别职业盟友「%s」→ 回复 %d 点费用（%d）"
			% [played.card_name, POEM_REBATE, state.energy])


func _sync_totem() -> void:
''')

# ---- 落地加成 ----
b = rep(b, '''	var beast_hp:= _beast_hp_bonus(card)
''', '''	# R761 诗（6069）：「其他职业的盟友」+2 力量 —— 与竖琴逐字同构（只写 Placement 字段）。
	if RunState.has_relic(POEM_RELIC_ID) and p.owner == SIDE_SELF and _poem_ally(card):
		p.poem_atk = POEM_ATK
		_log("诗：%s 获得 +%d 力量（%d）"
				% [card.card_name, POEM_ATK, p.effective_power()])
	var beast_hp:= _beast_hp_bonus(card)
''')

# ---- 出牌收尾口 ----
b = rep(b, '''	_phantom_cloak_tick(side)
''', '''	_poem_tick(side, played)
	_phantom_cloak_tick(side)
''')

# ---- use_spell 守卫 ----
b = rep(b, '''	if paint_pending:
		return "涂装机器人：请先在场上选一个友方单位"
''', '''	if paint_pending:
		return "涂装机器人：请先在场上选一个友方单位"
	if recruit_pending:
		return "招募：请先从这三个其他职业的盟友里选一张"
''')

# ---- use_spell 分支（接在森林的朋友们之后）----
b = rep(b, '''			return "「%s」加入手卡，其本回合费用 -%d" % [ff_copy.card_name,
					FOREST_FRIENDS_DISCOUNT]
''', '''			return "「%s」加入手卡，其本回合费用 -%d" % [ff_copy.card_name,
					FOREST_FRIENDS_DISCOUNT]
		RECRUIT_ID:
			# 招募（9264，R761，吟游诗人 0 费初始技能）：
			#   从**三个其他职业的盟友**里各摇一张当候选，玩家选一张加入手卡。
			# * 候选在**这一刻**定下来（`_recruit_cards`），面板只负责画；
			# * 随机源走引擎 rng → 同种子同结果、回放可复现；
			# * 摇不出来（池子被剧情锁 / 禁卡清空）→ 当回合落空，别开一个空面板。
			var rc_list := _roll_recruit_cards()
			if rc_list.is_empty():
				_log("招募：卡池里摇不出其他职业的盟友")
				return "卡池里没有可招募的盟友，效果落空"
			_recruit_cards = rc_list
			recruit_pending = true
			_log("招募：候选 %d 张（%s）" % [rc_list.size(), "、".join(
					rc_list.map(func(c: CardData) -> String: return c.card_name))])
			action.emit("recruit", {"pending": true, "count": rc_list.size()})
			return "从这 %d 张里选一张加入手卡" % rc_list.size()
''')

# ---- 招募候选/结算（插在 _random_reward_card 之前）----
b = rep(b, '''func _random_reward_card(side: String) -> CardData:
''', '''func _roll_recruit_cards() -> Array:
	## R761 招募（9264）：**每个可见职业各摇一张盟友**当候选（店长口径「每种职业各一张」）。
	## 池子走 `reward_pool_for(职业)` —— 剧情锁与本局禁卡一并生效；空了再退回该职业全部
	## 盟友卡（与森林的朋友们 9183 同一条退路）。
	## 返回的是**独立副本**（`_new_own_card`）：面板要显示是哪张，而 `turn_free` 之类
	## 以卡对象为键的机制绝不能拿卡库共享实例（R281 的教训）。
	var repo := CardRepo.load_json()
	var out: Array = []
	for cls: String in PlayerClass.ids():
		var pool: Array[CardData] = []
		for c: CardData in repo.reward_pool_for(cls):
			if c.kind == "盟友":
				pool.append(c)
		if pool.is_empty():
			for c2: CardData in repo.player_cards():
				if c2.kind == "盟友" and c2.card_class == cls:
					pool.append(c2)
		if pool.is_empty():
			continue
		var pick: CardData = pool[rng.randi() % pool.size()]
		out.append(_new_own_card(pick))
	return out


func recruit_cards() -> Array:
	## 面板要画的候选（顺序 = 职业顺序：森林精魄 / 暗影刺客 / 机械之心）。
	if not recruit_pending:
		return []
	return _recruit_cards.duplicate()


func recruit_pick(index: int) -> bool:
	## 招募的**结算唯一口**。`index` = `recruit_cards()` 的下标。
	## 手牌满 → 走 `_grant_to_hand` 的通用口径（进弃牌区，不蒸发）。
	if not recruit_pending:
		return false
	if index < 0 or index >= _recruit_cards.size():
		return false
	var c: CardData = _recruit_cards[index]
	var landed := _grant_to_hand(c, "招募")
	_log("招募：%s「%s」" % ["加入手卡" if landed else "手牌已满 → 进弃牌区", c.card_name])
	action.emit("recruit_pick", {"card": c, "landed": landed})
	recruit_pending = false
	_recruit_cards.clear()
	return landed


func recruit_cancel() -> void:
	## 放弃（面板的「不招募」/ 空候选自愈）：什么都不发生，技能已经付过费。
	recruit_pending = false
	_recruit_cards.clear()


func _random_reward_card(side: String) -> CardData:
''')

# ---- 本能面板守卫 ----
b = rep(b, '''		or merge_pending or crow_pending or whale_pending or endless_pending \\
		or rebirth_pending or eliminate_pending
''', '''		or merge_pending or crow_pending or whale_pending or endless_pending \\
		or rebirth_pending or eliminate_pending or recruit_pending
''')

# ---- 成员变量 ----
b = rep(b, '''var earring_pending := false      # 是否处于「自动出牌中」
''', '''var earring_pending := false      # 是否处于「自动出牌中」
## R761 诗（6069）：**本回合是否已经用掉「第一次使用别职业盟友回费」**。
## 每个我方回合开始归零（`_begin_turn`），每场战斗开始也归零（`start_game`）。
var _poem_used := false
''')

save(GE, b)
print("game_engine.gd OK")
