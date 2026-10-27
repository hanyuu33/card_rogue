class_name GameLevels
extends RefCounted
## 内置关卡（肉鸽版）：「鸭子骑士来袭」——
## 我方用初始卡组（12 张），敌方前排左右各一只鸭子骑士（AI 控制推进）。
##
## 教程系统与多关卡暂时移除；教程引导条相关常量保留，
## battle_scene 的 dormant 代码仍引用它们（tutorial 数组为空即不触发）。
## 未来肉鸽波次模式将替换 builtin_levels。
##
## 标识（key）：每个关卡都带 `"key"` —— **稳定的 ASCII 标识**，与关卡名解耦
## （关卡改名不影响它）。用途：按关卡替换的素材槽位名，例如战斗背景
## `assets/ui/battle_bg_<key>.png`（见 GameLevels.bg_key / UiAssets.battle_bg_name）。
##
## 分层（layer）：每个关卡都带 `"layer"` 字段，标明它属于哪一层。
## 地图只会从「本层内容池」里抽关（见 levels_of_tier / normal_pool 等），
## 内容池由 GameLayers.content_layers 决定：第一层 = [1]（只用第一层关卡），
## 第二层 = [2]（只用第二层关卡，不再混用第一层）。

const CUE_OWN_HALF := "own_half"    # 闪烁我方半场
const CUE_HAND := "hand"            # 闪烁手牌区
const CUE_COST := "cost_zone"       # （旧费用区提示，保留常量兼容）
const CUE_PLAY := "play"            # 闪烁手牌（挑一张可出的）+ 目标空格
const CUE_UNIT := "unit"            # 闪烁某个战场单位
const CUE_TAPPED := "tapped"        # 闪烁横置的我方单位
const CUE_FORT := "own_fort"        # 闪烁我方工事
const CUE_SPELL := "spell"          # 闪烁手牌里的法术
const CUE_NEXT := "btn_next"        # 闪烁引导条「下一步」按钮
const CUE_END := "btn_end"          # 闪烁「回合结束」按钮

const _DUMMY_ID := 9101
const _DUMMY_HEALTH := 4

# ---- 关卡分级 ----
const TIER_NORMAL_EASY := 0    # 普通敌人-简单
const TIER_NORMAL_HARD := 1    # 普通敌人-困难
const TIER_ELITE_EASY := 2     # 精英敌人-简单
const TIER_ELITE_HARD := 3     # 精英敌人-困难
const TIER_BOSS := 4           # Boss
const TIER_NAMES: Array[String] = [
	"普通敌人-简单", "普通敌人-困难", "精英敌人-简单", "精英敌人-困难", "Boss",
]


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]


# ---- 敌方 HP：关卡基准值 + 精英 +10 / Boss +20，最后整体 ×2 ----
const ENEMY_HP_ELITE_BONUS := 10
const ENEMY_HP_BOSS_BONUS := 20
const ENEMY_HP_MULTIPLIER := 2


static func enemy_hp_of(lvl: Dictionary) -> int:
	## 关卡实际敌方 HP：基准值（关卡里写的 enemy_hp）+ 精英 +10 / Boss +20，再 ×2。
	## 30 → 普通 60 / 精英 80 / Boss 100。
	var base := int(lvl.get("enemy_hp", 30))
	var bonus := 0
	match int(lvl.get("tier", -1)):
		TIER_ELITE_EASY, TIER_ELITE_HARD:
			bonus = ENEMY_HP_ELITE_BONUS
		TIER_BOSS:
			bonus = ENEMY_HP_BOSS_BONUS
	return (base + bonus) * ENEMY_HP_MULTIPLIER


static func level_names() -> Array[String]:
	## 选关菜单显示名：【分级】关卡名（按分级顺序排列）。
	var out: Array[String] = []
	var lvls := builtin_levels()
	for lvl in lvls:
		out.append("【%s】%s" % [tier_name(int(lvl["tier"])), str(lvl["name"])])
	return out


static func builtin_levels() -> Array:
	## 按分级从低到高：普通简单×8（第一层 4 + 第二层 4）→ 普通困难×8（第一层 4 + 第二层 4）→
	## 精英简单×5（第一层 2 + 第二层 3）→ 精英困难×5（第一层 2 + 第二层 3）→
	## Boss×6（第一层 3 + 第二层 2 + 第三层 1）。合计 33 关（R174 百眼动员进第二层普通简单；
	## R340 永夜鸭群进第一层精英困难；**R356 启示者进第三层**）。
	## 地图节点从「本层内容池」的对应分级池随机抽关（见 normal_pool / elite_pool / boss_level）。
	return [_encounter(), _familiars(), _archer_knight(), _blaze_pack(),
			_frost_line(), _assembly_line(), _mass_anvil(), _argos_mobilize(),
		_knight_charge(), _wizard(), _white_mage_guard(), _night_ducks(),
			_sun_forge(), _hecaton(), _undead_legion(), _twin_cannon(),
		_captain(), _duck_kiln(), _breath_charge(), _hermes(), _dragon_nest(),
		_captain_wizard(), _legion(), _mech_giant(), _steel_fortress(), _asclepius(),
		_boss_dragon(), _boss_demon_duck(), _boss_duck_darkside(),
			_mech_duck_boss(), _hephaestus(), _scrapyard(), _eternal_night(),
			_boss_revelator()]


static func layer_of(level: Dictionary) -> int:
	## 关卡所属层（未标 layer 的关卡按第一层处理）。
	return int(level.get("layer", GameLayers.LAYER_DEFAULT))


static func bg_key(level: Dictionary) -> String:
	## 该关卡专属战斗背景的槽位名（`assets/ui/battle_bg_<key>.png` 里的那段 key）。
	## 没标 key 的关卡返回空串 → 取图会直接退到「当层背景」。
	return str(level.get("key", ""))


static func all_keys() -> Array[String]:
	## 所有关卡的 key（测试用：查空、查重、查字符集）。
	var out: Array[String] = []
	for lvl in builtin_levels():
		out.append(bg_key(lvl))
	return out


static func levels_of_layer(layer: int) -> Array[Dictionary]:
	## 取属于该层的所有关卡（保持 builtin_levels 顺序）。
	var out: Array[Dictionary] = []
	for lvl in builtin_levels():
		if layer_of(lvl) == layer:
			out.append(lvl)
	return out


static func levels_of_tier(tiers: Array, layer := GameLayers.LAYER_DEFAULT) -> Array[Dictionary]:
	## 取「属于本层内容池」且分级在 tiers 内的所有关卡（保持 builtin_levels 顺序）。
	## 内容池由 GameLayers.content_layers 决定：第二层是 [2]（只用第二层的关卡），
	## 所以第二层的地图只会抽到第二层的专属关卡，不会串到第一层。
	var content := GameLayers.content_layers(layer)
	var out: Array[Dictionary] = []
	for lvl in builtin_levels():
		if content.has(layer_of(lvl)) and int(lvl["tier"]) in tiers:
			out.append(lvl)
	return out


static func normal_pool(layer := GameLayers.LAYER_DEFAULT) -> Array[Dictionary]:
	## 该层普通战斗节点的关卡池（普通敌人-简单/困难）。
	return levels_of_tier([TIER_NORMAL_EASY, TIER_NORMAL_HARD], layer)


static func elite_pool(layer := GameLayers.LAYER_DEFAULT) -> Array[Dictionary]:
	## 该层精英战斗节点的关卡池（精英敌人-简单/困难）。
	return levels_of_tier([TIER_ELITE_EASY, TIER_ELITE_HARD], layer)


static func boss_level(layer := GameLayers.LAYER_DEFAULT) -> Dictionary:
	## 该层 Boss 关：**优先本层专属 Boss**（layer 与关卡自身 layer 匹配），
	## 没有才用内容池里的 Boss（内容池已按层隔离，正常不会抽到别的层的 Boss），
	## 再没有就退回任意 Boss 关。
	##注意：同一层有**多个** Boss 时本函数只返回第一个（确定性的「兜底/默认」）——
	##   真正的随机由 RunState 在开局时从 boss_pool 里摇一次并存在 boss_pick，
	##   地图名牌与实际进入都读那一份，保证「地图上写的就是真会遇到的那只」。
	var pool := levels_of_tier([TIER_BOSS], layer)
	for lvl in pool:
		if layer_of(lvl) == layer:
			return lvl
	if not pool.is_empty():
		return pool[0]
	pool = levels_of_tier([TIER_BOSS])
	return pool[0] if not pool.is_empty() else builtin_levels().back()


static func boss_pool(layer := GameLayers.LAYER_DEFAULT) -> Array[Dictionary]:
	## 该层**所有**可选的 Boss 关卡（按 builtin_levels 顺序）。给RunState 摇 Boss 用。
	##层内专属优先；本层没有专属 Boss 时才用内容池里的。
	var pool := levels_of_tier([TIER_BOSS], layer)
	var own: Array[Dictionary] = []
	for lvl in pool:
		if layer_of(lvl) == layer:
			own.append(lvl)
	if not own.is_empty():
		return own
	return pool


static func deck_for(deck_key: String, repo: CardRepo) -> Array[CardData]:
	## 目前所有关卡都用初始卡组（deck_key == "starter"）。
	return repo.starter_deck()


static func extra_cards(_repo: CardRepo) -> Array[CardData]:
	## 肉鸽版没有教程专属卡。
	return []


static func unit_range_bonus(e: Array) -> int:
	## R366：编成元组**第 8 项**（可选字典）= 这一关单独给该单位的加成。
	## 当前只认 `{"range_bonus": N}` —— 百臂工场把两座量产型赫利俄斯的程 1 提到 2。
	## ⚠️ 元组前六项只是「文档 + 卡库缺卡时的兜底」：卡库里有定义时 `load_level` 一律读
	##    卡库那份（`repo.get_card()` 命中就直接用）。所以**想只加强某一关的某一只，
	##    只能走这里** —— 改 cards.json 会让三关（百臂工场 / 量产流水线 / 百眼动员）一起变。
	if e.size() < 8 or not (e[7] is Dictionary):
		return 0
	return int((e[7] as Dictionary).get("range_bonus", 0))


static func with_unit_override(card: CardData, e: Array) -> CardData:
	## R366：把编成加成套到**副本**上。`card` 本身绝不被修改（返回新实例或原样返回）。
	## ⚠️ 必须复制：卡库命中时传进来的就是 `repo.get_card()` 的**原卡**，`place()` 也直接
	##    引用它 —— 就地 `attack_range += 1` 会把加强烙进卡库（图鉴 / 另外两关跟着变，
	##    而且当局结束也不会还原）。与 R325 `RunState.scaled_enemy_card` 同一条纪律。
	var bonus := unit_range_bonus(e)
	if card == null or bonus == 0:
		return card
	var c := CardData.from_dict(card.to_dict())
	c.attack_range += bonus
	return c


static func _encounter() -> Dictionary:
	## 普通敌人-简单：中排左右各一只鸭子骑士（3/30，速 2，击杀成长），AI 推进。
	## enemy_units: [id, 名称, 力, 生, 程, 速, 格子]（第 8 项可选 = 本关专属加成，
	##   现在只认 `{"range_bonus": N}`；见 `unit_range_bonus()` / `with_unit_override()`）
	return {
		"name": "鸭子骑士来袭",
		"key": "duck_knight",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 2)],
		],
		"tutorial": [],
	}


static func _wizard() -> Dictionary:
	## 普通敌人-困难：后排中间鸭子巫师（8/50，程 2，回合开始召唤使魔），
	## 前排中间一只使魔鸭子，AI 推进。
	## 敌方效果卡「使魔之力 9115」：每回合开始使魔鸭子力量 +1（永久）——
	## 巫师本来就会源源补使魔，加上这个成长后越拖越难打。
	return {
		"name": "巫师的召唤",
		"key": "wizard",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9008, "鸭子巫师", 8, 50, 2, 1, Vector2i(1, 1)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 1)],
		],
		"enemy_effects": [9115],
		"tutorial": [],
	}


## 第二层关卡的成长曲线（R123 改口径）：**不再有「开局削减攻击力」的 debuff** ——
## 起始攻击力直接写在卡牌数据里（cards.json 的 power 就是玩家看到的真实值），
## 开局从 0 层起步，之后每 2 个回合 +1，最多 +4，让后期压力一点点涨回来。
const LAYER2_GROWTH := {
	"start_turn": 2,    # 从第 2 回合开始成长
	"period": 2,        # 每 2 个回合
	"inc": 1,           # +1 攻击力
	"cap": 4,           # 累计最多 +4
}

static func _frost_line() -> Dictionary:
	## 第二层·普通敌人-简单「寒冰防线」：后排中央一名冰冻术士（4/24 程3，
	## 首个回合开始时冻结我方一个单位），前排中央铁壁卫兵（3/40 嘲讽）带队，
	## 两翼各一个骷髅兵。嘲讽会逼停在它面前的敌方单位。
	return {
		"name": "寒冰防线",
		"key": "frost_line",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"enemy_growth": LAYER2_GROWTH,
		"starting_hand": 0,
		"enemy_units": [
			[1031, "冰冻术士", 4, 24, 3, 1, Vector2i(0, 1)],
			[1011, "铁壁卫兵", 3, 40, 1, 1, Vector2i(2, 1)],
			[1053, "骷髅兵", 2, 10, 1, 1, Vector2i(2, 0)],
			[1054, "骷髅兵", 3, 14, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _undead_legion() -> Dictionary:
	## 第二层·普通敌人-困难「亡灵军团」：后排中央亡灵领主（5/55 速2，亡语召唤两个骷髅，一回合行动两次），
	## 前排骷髅兵（嘲讽）+ 腐化尸鬼（4/18 速2，亡语打我方 HP）+ 骷髅兵（亡语召唤一只骷髅）。
	return {
		"name": "亡灵军团",
		"key": "undead_legion",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"enemy_growth": LAYER2_GROWTH,
		"starting_hand": 0,
		"enemy_units": [
			[1051, "亡灵领主", 4, 55, 1, 2, Vector2i(0, 1)],
			[1055, "骷髅兵", 2, 28, 1, 1, Vector2i(2, 0)],
			[1050, "腐化尸鬼", 4, 18, 1, 2, Vector2i(2, 1)],
			[1054, "骷髅兵", 3, 14, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _dragon_nest() -> Dictionary:
	## 第二层·精英敌人-简单「龙族巢穴」：后排中央灰烬龙（6/45 速2，战吼对我方全场 4 伤，一回合行动两次），
	## 中排两翼幼龙（5/25 程2，亡语召唤龙裔 4/12），前排中央铁壁卫兵（嘲讽）挡路。
	return {
		"name": "龙族巢穴",
		"key": "dragon_nest",
		"tier": TIER_ELITE_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"enemy_growth": LAYER2_GROWTH,
		"starting_hand": 0,
		"enemy_units": [
			[1013, "灰烬龙", 5, 45, 1, 2, Vector2i(0, 1)],
			[1014, "幼龙", 5, 25, 2, 1, Vector2i(1, 0)],
			[1014, "幼龙", 5, 25, 2, 1, Vector2i(1, 2)],
			[1011, "铁壁卫兵", 3, 40, 1, 1, Vector2i(2, 1)],
		],
		"tutorial": [],
	}


static func _mech_giant() -> Dictionary:
	## 第二层·精英敌人-困难「机甲巨兵」：后排中央熔岩巨人（9/70 速2，法术免疫，一回合行动两次），
	## 中排两翼爆裂机甲（4/30 程2，亡语对全场单位 8 伤），前排中央铁壁卫兵（嘲讽）。
	return {
		"name": "机甲巨兵",
		"key": "mech_giant",
		"tier": TIER_ELITE_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"enemy_growth": LAYER2_GROWTH,
		"starting_hand": 0,
		"enemy_units": [
			[1071, "熔岩巨人", 8, 60, 1, 2, Vector2i(0, 1)],
			[1061, "爆裂机甲", 4, 30, 2, 1, Vector2i(1, 0)],
			[1061, "爆裂机甲", 4, 30, 2, 1, Vector2i(1, 2)],
			[1011, "铁壁卫兵", 3, 40, 1, 1, Vector2i(2, 1)],
		],
		"tutorial": [],
	}


static func _boss_dragon() -> Dictionary:
	## Boss：后排中间远古虚骨龙（12/100，程 2 速 2，回合开始吐息），
	## 敌方效果卡「鸭子号角」——每 3 个回合召唤一只鸭子骑士。
	return {
		"name": "远古虚骨龙",
		"key": "boss_dragon",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9014, "远古虚骨龙", 12, 100, 2, 2, Vector2i(0, 1)],
		],
		"enemy_effects": [9015],
		"tutorial": [],
	}


static func _boss_demon_duck() -> Dictionary:
	## Boss：后排中间恶魔鸭（9116，5/100，程2 速1，**沉睡 2 回合**——前 2 个回合
	## 完全不行动；受伤会提前 1 回合醒来，醒着再受伤就永久 +1 力量，越打越疼）。
	## 敌方效果卡「恶魔使魔 9117」——每回合开始：
	##   ① 所有使魔鸭子力量 +1（永久，trait「使魔成长」，与 9115 同一通路）；
	##   ② **每 2 回合**在一个**随机空格**召唤一只使魔鸭子（**玩家后排除外**，
	##      敌方也能直接压到我方半场）。R70 起召唤从「每回合」改为「每 2 回合」，
	##      强度增长（使魔成长）仍是每回合，只是不再每回合都补一只新鸭子。
	## 于是打这场是一场「抢节奏」：要么速攻在它醒来前打死，要么先清使魔鸭群别让它们滚起来。
	return {
		"name": "恶魔鸭",
		"key": "boss_demon_duck",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"intro": "zzZ……（它好像还没睡醒）",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9116, "恶魔鸭", 5, 100, 2, 1, Vector2i(0, 1)],
		],
		"enemy_effects": [9117],
		"tutorial": [],
	}


static func _boss_demon_duck_revenge() -> Dictionary:
	## 彩蛋 Boss「恶魔鸭（复仇）」（R73）：**不进 boss_pool** —— 它不是随机池的一员，
	## 而是「第一层摇到恶魔鸭 → 50% 触发」后**顶替第二层 boss** 的那一只。
	##   与第一层「恶魔鸭」关的差异（其余照旧：同一张恶魔使魔 9117、同样后排中央、
	##   同样 5/145 程2 速1 —— R77 把血量从 100 提到 145，因为它同时吃两条挨打变强）：
	##   ① 换成 9118「恶魔鸭（复仇）」—— **没有「沉睡」trait**，所以它**开局就直接行动**，
	##      不再给你「前 2 回合白给」的窗口；
	##   ② 每次受到伤害 → **本回合**力量 +1（可叠加，回合结束清零），**并且力量永久 +1**
	##      （R77：把恶魔鸭 9116 原本那条「越打越强」还回来了）。
	## 于是难度来源完全变了：第一层那只逼你「抢节奏在它睡醒前打死」，
	## 这只逼你「**一回合内**解决战斗」——因为多打一下它就多疼一下，
	## 而它的 5 攻正好够把你的前排敲开。
	return {
		"name": "恶魔鸭（复仇）",
		"key": "boss_demon_duck_revenge",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"intro": "「……你还欠我一场。」",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9118, "恶魔鸭（复仇）", 5, 145, 2, 1, Vector2i(0, 1)],
		],
		"enemy_effects": [9117],
		"tutorial": [],
	}


static func revenge_boss() -> Dictionary:
	## 彩蛋 Boss 关（恶魔鸭（复仇））的**唯一取用口**。
	## 刻意**不**进 builtin_levels：那样它会同时出现在 ①调试用关卡选择菜单、
	## ②`boss_pool`（第二层就会随机抽到它，50% 触发就形同虚设）。
	## 只由 RunState 在「第一层摇到恶魔鸭且 50% 命中」时显式顶替第二层 boss。
	return _boss_demon_duck_revenge()


static func _mech_duck_boss() -> Dictionary:
	## 第二层 Boss「机械巨鸭」：后排中央一只机械巨鸭（9047，10/150，程 3 速 1），
	## 每个回合开始把场上的发条鸭（9048，4/5 程1 速1）补齐到 2 只。
	## 敌方效果卡「齿轮升腾」——每回合开始时所有敌方单位**永久 +2 力量（无上限）**。
	return {
		"name": "机械巨鸭",
		"key": "mech_duck_boss",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"intro": "咔哒…咔哒…",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9047, "机械巨鸭", 10, 150, 3, 1, Vector2i(0, 1)],
		],
		"enemy_effects": [9049],
		"tutorial": [],
	}


static func _boss_duck_darkside() -> Dictionary:
	## 第一层 Boss「鸭之暗面」（R111 / R158：血量 150 → 100，并从第二层下调到第一层）：
	## 后排中央一只鸭之暗面（9124，9/100，程1 速1），
	## 敌方效果卡「暗影召唤 9125」——**开局**以及**每 3 个回合**召唤一只鸭子暗杀者（9123，6/30）。
	##   * 鸭之暗面「穿行」= 移动**无视单位阻挡**（可穿过任何单位，不能停在上面）；
	##   * 鸭之暗面「暗影领主」= **每个存活暗杀者** +3 力 +1 速（死了立刻掉）；
	##   * 暗杀者被动：只要场上还有非暗杀单位（= 鸭之暗面还在），它就不能打我方 HP，
	##     但可以**闪现**到任意空格 —— 于是它专门绕后咬你的后排，而不是傻推脸。
	## 打法：暗杀者会自己滚起来，要么尽快点掉暗杀者压住鸭之暗面的成长，
	##   要么直接顶着脸硬拆 150 血（但每多一只暗杀者它就多疼一下）。
	return {
		"name": "鸭之暗面",
		"key": "boss_duck_darkside",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"intro": "……别回头看。",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9124, "鸭之暗面", 9, 100, 1, 1, Vector2i(0, 1)],
		],
		"enemy_effects": [9125],
		"tutorial": [],
	}


static func _hephaestus() -> Dictionary:
	## 第二层 Boss「赫菲斯托斯工坊」（R150；R225 上调）：后排中央一只赫菲斯托斯
	## （9135，5/120 程1 速1）。它带 trait「锻造」「践踏」，效果都由引擎在**唯一口**结算：
	##   * **亲手击杀**我方单位 → 在**己方半场随机空格**锻造一只量产型俄倪厄（9131，5/45）
	##     （挂 `_credit_kill`），并**清零**空转计数 —— 它一直在杀就一直不变强；
	##   * **每 1 个我方回合**没能亲手击杀 → 力量 +1、攻击距离 +1（挂 `_forge_tick`，
	##     永久累计、无上限）。R225：周期 3 → 1（用户口径「每三回合改为每回合」）；
	##   * **践踏**（R225）：攻击击杀我方单位时，溢出的伤害沿**同一列**继续打下一个我方
	##     单位，整列打穿后直击我方 HP（挂 `attack()` 的溢出链 `_trample_chain`）。
	## 打法：一味往前顶着送头 = 它一直在生小兵 + 践踏一路穿到脸；缩着完全不接触
	##   = 每回合自己长 1 力 1 程、射程越来越难躲。中间路线是**压住血线但别让它拿到
	##   最后一刀** —— 击杀那一下由别的来源打出（法术 / 陷阱）就不会触发锻造，
	##   但注意践踏只看「它这一下打死人」的溢出，挡在它面前的单位越薄，漏到后方越狠。
	return {
		"name": "赫菲斯托斯工坊",
		"key": "hephaestus_forge",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"intro": "……铁砧还热着。",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9135, "赫菲斯托斯", 5, 120, 1, 1, Vector2i(0, 1)],
			# R397（用户口径「给赫菲斯托斯那关也加上两个量产型赫菲斯托斯在后排」）：
			# 后排左右各一只（9138，4/50 程1 速1，带「量产锻造」+「践踏」）。
			# ⚠️ 它们也吃「践踏」——三只都站在 row 0 时，前方同一列的溢出会一路传下去。
			[9138, "量产型赫菲斯托斯", 4, 50, 1, 1, Vector2i(0, 0)],
			[9138, "量产型赫菲斯托斯", 4, 50, 1, 1, Vector2i(0, 2)],
		],
		"tutorial": [],
	}


static func _boss_revelator() -> Dictionary:
	## 第三层 Boss「启示者」（R356）：攻 15 / 血 300 / 程 2 / 速 2，后排中央 (0, 1)。
	## 第三层是一条 5 格直道（起点 → 精英 → 商店 → 篝火 → Boss，见 RogueMap.line_cells），
	## 本关是那条道的终点。
	##   * **敌方 HP 为 ∞**（`enemy_hp_infinite`）：直击打不空，唯一的胜利条件是击破启示者
	##     本体（`win_on_boss`）—— 否则玩家绕开本体、一路糊脸就能跳过整场三阶段；
	##   * **三阶段**（血线 = 最大生命的 2/3、1/3，唯一口 `GameEngine.revelator_gate_hp()`）：
	##     剩余生命降到 2/3、1/3 时各进一阶 → 退回后排中间 (0, 1)（原格有东西就**消灭它**）、
	##     换掉场上效果卡、界面播阶段横幅并重新弹一次敌方效果；
	##   * 阶段效果全部在 GameEngine 一处结算（`_revelator_*` 系列），卡面只是同一口径的文案。
	## ⚠️ `enemy_effects` 只写第一阶段的「舰炮 9201」—— 二、三阶段的 9202 / 9203 由引擎
	##    在阶段转移时换上，不进关卡表（否则开局就会同时启用三张）。
	return {
		"name": "启示者",
		"key": "boss_revelator",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_THREE,
		"deck_key": "starter",
		"intro": "……抬头看。",
		"player_hp": 20,
		"enemy_hp": 30,
		"enemy_hp_infinite": true,
		"win_on_boss": 9200,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9200, "启示者", 15, 300, 2, 2, Vector2i(0, 1)],
		],
		"enemy_effects": [9201],
		"tutorial": [],
	}


static func _scrapyard() -> Dictionary:
	## 第二层·普通敌人-困难（R228「废料场」）：后排两只拾荒者（9151，4/50 程1 速1）
	## + 前排三只废弃机器人（9152，5/40 程1 速1）。
	##   * 拾荒者：**己方回合开始时**，各给一个「拾荒者以外」的己方单位一次改造
	##     （+3 攻 / +5 血，挂 `_scavenger_tick`）；
	##   * 废弃机器人：**每次被改造** → 对所有敌方单位（= 玩家单位）各 1 点伤害
	##     （挂 `_on_unit_upgraded`，所以拾荒者改它一次就响一次）。
	## 题面：拾荒者越改越肥，且多半改到机器人 → 每回合额外 1~2 次全体 1 伤；
	##   先点拾荒者断掉成长链，还是先拆机器人止住群伤，是这关的核心取舍。
	##   （机器人 5/40 顶在前排，拾荒者 4/50 躲在后排 —— 想拆拾荒者得先撬开前排。）
	## ⚠️ 站位按 `Vector2i(行, 列)`（board key 语义，敌方占 row 0~2，row 0 = 最后排）。
	## ⚠️ 数组顺序：拾荒者写在**最前**（成长源先上场，回合开始扫描时一定在场）。
	return {
		"name": "废料场",
		"key": "scrapyard",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"intro": "……铁锈味比血还重。",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9151, "拾荒者", 4, 50, 1, 1, Vector2i(0, 0)],
			[9151, "拾荒者", 4, 50, 1, 1, Vector2i(0, 2)],
			[9152, "废弃机器人", 5, 40, 1, 1, Vector2i(2, 0)],
			[9152, "废弃机器人", 5, 40, 1, 1, Vector2i(2, 1)],
			[9152, "废弃机器人", 5, 40, 1, 1, Vector2i(2, 2)],
		],
		"enemy_effects": [],
		"tutorial": [],
	}


static func _legion() -> Dictionary:
	## 精英敌人-困难：鸭子骑士×6（后排 3 + 前排 3），敌方开局启用效果卡
	## 「鸭子之力」——所有友方每回合力量 +1，最多累计 +5。
	return {
		"name": "骑士军团",
		"key": "legion",
		"tier": TIER_ELITE_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(0, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(0, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(0, 2)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 2)],
		],
		"enemy_effects": [9013],
		"tutorial": [],
	}


static func _familiars() -> Dictionary:
	## 普通敌人-简单：使魔鸭群——前排 3 只 + 中排左右各 1 只使魔鸭子。
	return {
		"name": "使魔鸭群",
		"key": "familiars",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 0)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 1)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 2)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(1, 0)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(1, 2)],
		],
		"tutorial": [],
	}


static func _knight_charge() -> Dictionary:
	## 普通敌人-困难：中排三只鸭子骑士一字排开正面冲锋（3/30，速 2，击杀成长）。
	return {
		"name": "骑士冲锋",
		"key": "knight_charge",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 2)],
		],
		"tutorial": [],
	}


static func _captain_wizard() -> Dictionary:
	## 精英敌人-困难：后排中间队长坐镇，中排巫师源源召唤使魔，前排使魔护卫。
	## 敌方效果卡「使魔之力 9115」：使魔鸭子每回合开始力量 +1（永久）。
	return {
		"name": "队长与巫师",
		"key": "captain_wizard",
		"tier": TIER_ELITE_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9012, "鸭子队长", 7, 50, 1, 1, Vector2i(0, 1)],
			[9008, "鸭子巫师", 8, 50, 2, 1, Vector2i(1, 1)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 1)],
		],
		"enemy_effects": [9115],
		"tutorial": [],
	}


static func _archer_knight() -> Dictionary:
	## 普通敌人-简单：后排左右各一名鸭子弓手（程 2 远程），后排中间一名鸭子骑士护卫。
	return {
		"name": "弓手与骑士",
		"key": "archer_knight",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9017, "鸭子弓手", 3, 18, 2, 1, Vector2i(0, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(0, 1)],
			[9017, "鸭子弓手", 3, 18, 2, 1, Vector2i(0, 2)],
		],
		"tutorial": [],
	}


static func _blaze_pack() -> Dictionary:
	## 普通敌人-简单：前排中间一只鸭子骑士顶线，前排左右各一只爆炎鸭
	## （5/3，亡语：死亡时对曼哈顿距离 1 的 4 格各造成 10 点伤害，不分敌我），
	## 后排中间一只使魔鸭子压阵。
	## 注意：两只爆炎鸭都与骑士相邻 —— 打死爆炎鸭会把骑士也炸伤。
	return {
		"name": "爆炎鸭阵",
		"key": "blaze_pack",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(0, 1)],
			[9020, "爆炎鸭", 5, 3, 1, 1, Vector2i(2, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 1)],
			[9020, "爆炎鸭", 5, 3, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _white_mage_guard() -> Dictionary:
	## 第一层·普通敌人-困难（R158 从「第二层·普通敌人-简单」上调；**R164 降难度**）：
	## 后排中央一名白魔法鸭（9021，R164 由「白魔法师」改名并下调为 0/30，回合开始治疗
	## 生命值百分比最低的己方单位 5 点；精进——每回合开始力量 +1，无前置条件），
	## **中排**左右各一名鸭子骑士护阵。
	## R164 的两处降难度：① 删掉原来站在前排正中（2,1）的第三只鸭子骑士；
	##   ② 留下的两只鸭子骑士从**前排**（2 行）退到**中排**（1 行）—— 冲进我方半场更慢，
	##   开场有一次从容布置的机会。
	return {
		"name": "白魔法鸭护阵",
		"key": "white_mage_guard",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9021, "白魔法鸭", 0, 30, 1, 1, Vector2i(0, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 2)],
		],
		"tutorial": [],
	}


static func _night_ducks() -> Dictionary:
	## 第一层·普通敌人-困难（R158 从「第二层·普通敌人-简单」上调；R340 改为**一只**夜鸭）：
	## 中排一只夜鸭（5/35，程 2 速 2，回合开始 +1 攻），前排左右各一只使魔鸭子（4/15，程 1 速 1）护阵，
	## AI 推进。
	return {
		"name": "夜鸭阵",
		"key": "night_ducks",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9027, "夜鸭", 5, 35, 2, 2, Vector2i(1, 0)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 0)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _eternal_night() -> Dictionary:
	## 第一层·精英敌人-困难（R340）：中排左右各一只夜鸭（5/35，程 2 速 2，回合开始 +1 攻），
	## 敌方开局启用效果卡「永夜」（9178）—— **夜鸭不再虚弱**：奇数回合也不吃「惧光」
	## （既不降攻击距离 / 移动速度，也不减半力量）。
	## 定位：比「夜鸭阵」更硬的双鸭阵 —— 玩家原本可以靠「奇数回合夜鸭够不着 / 打不痛」
	## 拖节奏，带上永夜之后这条窗口彻底关掉，只能硬碰 2 只每回合 +1 攻的夜鸭。
	return {
		"name": "永夜鸭群",
		"key": "eternal_night",
		"tier": TIER_ELITE_HARD,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9027, "夜鸭", 5, 35, 2, 2, Vector2i(1, 0)],
			[9027, "夜鸭", 5, 35, 2, 2, Vector2i(1, 2)],
		],
		"enemy_effects": [9178],
		"tutorial": [],
	}


static func _breath_charge() -> Dictionary:
	## 第二层·精英敌人-简单：前排三名鸭子骑士一字排开，后排两翼各一名鸭子弓手
	## （程 2 远程压制），敌方开局启用效果卡「哈气」——**敌方**单位从第 3 个回合起一回合可以行动两次
	## （移动 + 攻击重来一遍；骑士速 2 → 一回合最多推进 4 格；前 2 回合仍是单动）。
	return {
		"name": "哈气骑士团",
		"key": "breath_charge",
		"tier": TIER_ELITE_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"intro": "我要闹了",   # 关卡开场台词（大字横幅，比回合横幅停留更久）
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9017, "鸭子弓手", 3, 18, 2, 1, Vector2i(0, 0)],
			[9017, "鸭子弓手", 3, 18, 2, 1, Vector2i(0, 2)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 2)],
		],
		"enemy_effects": [9024],
		"tutorial": [],
	}


static func _hermes() -> Dictionary:
	## 第二层·精英敌人-简单（R161；R397 后排加两只量产型赫尔墨斯）：1 只赫尔墨斯
	## （9/80，程 1 速 1）站在**前排中央** (2,1)。
	## 自带「行动力成长」——每过 3 个敌方回合，行动次数 +1，越拖越强。
	## R397（用户口径「后排左方右方新增一个量产型赫尔墨斯」）：(0,0) / (0,2) 各一只
	## **量产型赫尔墨斯**（9188，装甲运输车 5/55 程1 速1）—— 没有「行动力成长」、
	## 不疾行，纯粹是后排的两块厚肉：想直接够到中央那只 9 攻的，得先穿透它们这一列。
	return {
		"name": "赫尔墨斯的试炼",
		"key": "hermes",
		"tier": TIER_ELITE_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9140, "赫尔墨斯", 9, 80, 1, 1, Vector2i(2, 1)],
			[9188, "量产型赫尔墨斯", 5, 55, 1, 1, Vector2i(0, 0)],
			[9188, "量产型赫尔墨斯", 5, 55, 1, 1, Vector2i(0, 2)],
		],
		"tutorial": [],
	}

static func _asclepius() -> Dictionary:
	## 第二层·精英敌人-困难（R162）：后排中央一只阿斯克勒庇厄斯
	## （9141，12/80 程1 速1，带「护甲积攒」）。
	## 每回合开始时获得 16 护甲；若获得前已有护甲，则清零护甲并对随机敌方单位
	## 造成等量伤害，之后力量 +1。越拖攻击力越高，且护甲会不断「存爆」。
	return {
		"name": "阿斯克勒庇厄斯的试炼",
		"key": "asclepius",
		"tier": TIER_ELITE_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"enemy_growth": LAYER2_GROWTH,
		"starting_hand": 0,
		"enemy_units": [
			[9141, "阿斯克勒庇厄斯", 12, 80, 1, 1, Vector2i(0, 1)],
		],
		"tutorial": [],
	}

static func _duck_kiln() -> Dictionary:
	## 第一层·精英敌人-简单（R158 从「第二层·普通敌人-困难」上调）：敌方后排中央一座
	## 鸭子窑（9025，工事 0 力 100 血），自己回合开始时（含首回合）在四周曼哈顿距离为 1
	## 的空格各烧出一只陶瓷鸭（6 力，生命每过 2 回合 +1，程1 速1）。越界/被占用的邻格跳过。
	## 上调理由：第一层精英简单池原本只有「鸭子队长登场」一关（R134 测算的 P0 缺口）。
	return {
		"name": "鸭子窑",
		"key": "duck_kiln",
		"tier": TIER_ELITE_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9025, "鸭子窑", 0, 100, 0, 0, Vector2i(0, 1)],
		],
		"tutorial": [],
	}


static func _sun_forge() -> Dictionary:
	## 第二层·普通敌人-困难（R135）：后排中央一座太阳装置「赫利俄斯」
	## （9130，**工事** 0 力 50 血 / 程 0 / 速 0 —— 不会打人也不会移动）。
	## 它在场时，本方的「量产型俄倪厄」（9131，5/45 程1 速1）获得两条光环：
	##   ① 一回合行动两次；② 每回合结束回复 2 点生命。
	## ⚠️ 两条都**以「赫利俄斯还在场」为前提** —— 先拆掉太阳装置，两只俄倪厄
	##    立刻回到「每回合 1 次行动、不回血」。这是这关的核心取舍：
	##    打兵（45×2 血）还是拆塔（50 血，但它自己回不了血）。
	## ⚠️ 摆放顺序：赫利俄斯写**在数组最前**。`place()` 是算完 `acts_left` 才落子，
	##    光环源先上场 → 后面两只俄倪厄上场时就吃到了双动；battle_scene 摆完还会
	##    统一 `apply_extra_actions` 补一次，两条保险都留着（顺序反过来也不会漏）。
	return {
		"name": "太阳熔炉",
		"key": "sun_forge",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9130, "赫利俄斯", 0, 50, 0, 0, Vector2i(0, 1)],
			[9131, "量产型俄倪厄", 5, 45, 1, 1, Vector2i(2, 0)],
			[9131, "量产型俄倪厄", 5, 45, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _hecaton() -> Dictionary:
	## 第二层·普通敌人-困难（R152「百臂工场」；R397 赫卡同克瑞斯 50→80 血、程 1→2）：
	## 一只赫卡同克瑞斯（9136，8/**80** 程**2** 速1）
	## + 两座量产型赫利俄斯（9137，**工事** 6/30 **程2** 速0 —— 打得到人但不会移动）。
	##
	## 赫卡同克瑞斯（R152）：**回合开始时**若场上没有其他己方单位，获得力量 +2 与
	## 「受到的攻击伤害减半」—— 实时扫场面（`_refresh_hecaton`），塔一倒就生效、
	## 己方再来新单位就失效。两座塔在场时它只是普攻 8 的普通大哥。
	## 量产型赫利俄斯（R152）：在场时**除自己以外**的己方单位「受到的技能伤害减半
	## （向上取整）」—— 实时扫描（`FieldState.has_mass_helios`），塔被打掉立刻失效。
	##
	## 取舍：两座塔各 30 血、打人 6，还压着全场的技能流；拆掉它们大哥就会狂暴
	## （10 攻 + 攻击减半）。先拆塔还是先磨 50 血的大哥，就是这关的核心决策。
	## ⚠️ 站位按 `Vector2i(行, 列)`（board key 语义，敌方占 row 0~2，row 0 = 最后排）：
	##    大哥 (0,1) 坐镇后排中央，两座塔 **(2,0)/(2,2) 顶到前排**。
	## R366（用户口径「百臂工厂需要加强，让那个敌方工事攻击距离+1且移动到敌方前排
	## (2,0) 和 (2,2)」）：塔从中排挪到前排，程 1 → 2；程的加强写在元组第 8 项
	## `{"range_bonus": 1}`（**只加强这一关**，卡库 9137 仍是程 1）。
	##    距离是**曼哈顿**：塔窝在中排 row 1 程 1 时够得着的只有自家半场，等于纯肉盾；
	##    顶到前排 row 2 程 2 才真能打到我方 (3,0)/(3,1)/(4,0) 一带 —— 这才是「加强」，
	##    同时也把「前排被塔占住、中路 (2,1) 留一个口」的取舍摆到玩家面前。
	## ⚠️ 摆放顺序：赫卡同克瑞斯写在**数组最前**（与 _sun_forge 的赫利俄斯同理 ——
	##    光环源先上场，随后 `_refresh_hecaton` 才能立刻把它算进「唯一单位」判定）。
	return {
		"name": "百臂工场",
		"key": "hecaton",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9136, "赫卡同克瑞斯", 8, 80, 2, 1, Vector2i(0, 1)],
			[9137, "量产型赫利俄斯", 6, 30, 2, 0, Vector2i(2, 0), {"range_bonus": 1}],
			[9137, "量产型赫利俄斯", 6, 30, 2, 0, Vector2i(2, 2), {"range_bonus": 1}],
		],
		"tutorial": [],
	}


static func _assembly_line() -> Dictionary:
	## 第二层·普通敌人-简单（R158「量产流水线」）：前排左右各一只量产型俄倪厄
	## （9131，5/45 程1 速1），后排中央一座量产型赫利俄斯（9137，**工事** 6/30 程1 速0）。
	## 塔在场 → 塔以外的己方单位「受到的技能伤害减半（向上取整）」—— 实时扫描
	## （`FieldState.has_mass_helios`），塔一倒减半**立刻失效**。
	## 取舍：先拆 30 血的塔（好拆，但它一直压着法术流），还是硬吃减半把两只 45 血
	##   的俄倪厄磨掉。塔在后排够不到人，所以「拆塔」几乎不挨打 —— 这关的教学点
	##   就是让你认出「减半是从哪来的」。
	## R219 效果卡「流水线装配」（9147）：**每过 3 回合**，随机从量产型俄倪厄（9131）
	##   与量产型赫利俄斯（9137）中召唤一个到己方半场空格 —— 这关从此是「拆不完的产线」：
	##   拖得越久，塔（技能减半）与兵（5 攻 45 血）都会越滚越多，逼玩家别再磨、尽快拆塔。
	## ⚠️ 站位按 `Vector2i(行, 列)`：俄倪厄 (2,0)/(2,2) 顶前排，塔 (0,1) 坐后排中央。
	return {
		"name": "量产流水线",
		"key": "assembly_line",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9137, "量产型赫利俄斯", 6, 30, 1, 0, Vector2i(0, 1)],
			[9131, "量产型俄倪厄", 5, 45, 1, 1, Vector2i(2, 0)],
			[9131, "量产型俄倪厄", 5, 45, 1, 1, Vector2i(2, 2)],
		],
		"enemy_effects": [9147],
		"tutorial": [],
	}


static func _mass_anvil() -> Dictionary:
	## 第二层·普通敌人-简单（R158「量产铁砧」；R397 一只 → **三只**并加践踏）：
	## 后排**一字排开三只**量产型赫菲斯托斯（9138，4/50 程1 速1）。
	##   * 「量产锻造」——**亲自击杀**我方单位时，在**己方半场随机空格**锻造一只
	##     量产型俄倪厄（9131，5/45 程1 速1）（挂 `_credit_kill` + `_mass_heph_kill_forge`，
	##     走引擎 rng → 回放可复现）；
	##   * 「践踏」（R397，与 Boss 版 9135 同一条 `_trample_chain`）——击杀时溢出的伤害
	##     沿**同一列**继续打下一个我方单位，整列打穿后直击我方 HP。
	## 与 Boss 版赫菲斯托斯（9135）的差别：**没有「空转成长」那半边** ——
	##   它不会自己越长越疼，纯粹是「你送一个头它就多一只兵」+ 溢出穿列。
	## 三只同款：题面从「别让它拿到最后一刀」变成「**三条列上都得防溢出**」——
	##   每只只有 4 攻，正面硬顶并不疼，疼的是滚起来的兵和被穿到后排的溢出。
	## ⚠️ 站位按 `Vector2i(行, 列)`（敌方占 row 0~2，row 0 = 最后排）：
	##    三只全放 (0,0)/(0,1)/(0,2) 后排一字 —— 速 1 要走两步才够得着我方，
	##    给玩家留出「先手点掉列头 / 摆薄前排」的决策时间。
	return {
		"name": "量产铁砧",
		"key": "mass_anvil",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9138, "量产型赫菲斯托斯", 4, 50, 1, 1, Vector2i(0, 0)],
			[9138, "量产型赫菲斯托斯", 4, 50, 1, 1, Vector2i(0, 1)],
			[9138, "量产型赫菲斯托斯", 4, 50, 1, 1, Vector2i(0, 2)],
		],
		"tutorial": [],
	}


static func _argos_mobilize() -> Dictionary:
	## 第二层·普通敌人-简单（R174「百眼动员」）：中排左右各一只量产型阿尔戈斯
	## （9142，**7/35** 程2 **速2**），带「百眼」trait —— **在场时每单位只发动一次**
	## （`Placement.ability_used`，离场再上场算新单位）：**攻击命中单位**时，在
	## **己方后排**（row 0）召唤一只量产型俄倪厄（9131，5/45 程1 速1），并使其
	## **移动速度 +1**（`Placement.summon_haste`，随单位离场消失，不烤进 CardData）；
	## 后排满则退到己方半场随机空格（引擎 rng → 回放可复现）。
	## 取舍：速 2 的中排阿尔戈斯一两步就压到脸上，每只只有一次「攻击换一只 2 速俄倪厄」
	##   —— 是让它们尽早把这一拍打出来（早点召唤、早点多一只咬人的），还是卡射程 /
	##   先点掉一只让它连发动机会都没有，就是这关的决策点。两只**各自独立**计数。
	## ⚠️ 与量产铁砧（9138）的区别：那个要**亲手击杀**才锻造；这个只要**攻击命中**。
	## R219：后排中央 **(0,1)** 再加一座**量产型赫利俄斯**（9137，工事 6/30）——
	##   塔在场 → 塔以外的己方单位「受到的技能伤害减半（向上取整）」，于是两只阿尔戈斯
	##   和被它们召唤出来的俄倪厄全都变硬；拆塔又得先越过中排那两只 7 攻的阿尔戈斯。
	## ⚠️ 站位按 `Vector2i(行, 列)`（board key 语义，敌方占 row 0~2，row 0 = 最后排）：
	##    塔 (0,1) 坐后排中央，两只阿尔戈斯 (1,0)/(1,2) 扎中排左右，给玩家留出一拍反应时间。
	return {
		"name": "百眼动员",
		"key": "argos_mobilize",
		"tier": TIER_NORMAL_EASY,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
		[9142, "量产型阿尔戈斯", 7, 35, 2, 2, Vector2i(1, 0)],
		[9142, "量产型阿尔戈斯", 7, 35, 2, 2, Vector2i(1, 2)],
			[9137, "量产型赫利俄斯", 6, 30, 1, 0, Vector2i(0, 1)],
		],
		"tutorial": [],
	}


static func _twin_cannon() -> Dictionary:
	## 第二层·普通敌人-困难（R158「双机炮阵」）：前排左右各一只量产型俄倪厄
	## （9131，5/45 程1 速1），敌方效果卡「充能巨炮 9139」——
	## **己方每个回合开始时**，随机破坏**一个敌方单位**（= 我方单位，走引擎 rng）。
	## 于是这关的题面是「站不住场」：每回合固定少一个单位，前线迟早被两只俄倪厄压穿。
	## 取舍：铺得越多，炮的期望损失被摊得越薄（但每只都扛不住 5 攻）；
	##   只留少量高质量单位，则每一下都掉肉。玩家要在「数量」和「质量」之间选一边。
	## ⚠️ 破坏走唯一口 `_destroy`（离场记账 / 亡语 / 击杀记功与别处完全一致），
	##   不是另起一套删除；没有可破坏的目标时静默跳过（只打日志）。
	return {
		"name": "双机炮阵",
		"key": "twin_cannon",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9131, "量产型俄倪厄", 5, 45, 1, 1, Vector2i(2, 0)],
			[9131, "量产型俄倪厄", 5, 45, 1, 1, Vector2i(2, 2)],
		],
		"enemy_effects": [9139],
		"tutorial": [],
	}


static func _steel_fortress() -> Dictionary:
	## 第二层·精英敌人-困难（R149）：后排右边一只俄倪厄（9132，10/50 程1 速1，
	## **自带双动**），后排左边一只量产型赫卡同克瑞斯（9133，3/35 程1 速1）。
	##
	## 赫卡同克瑞斯身上带**铸造倒计时**：**我方回合结束** -1，减到 0 时破坏自身、
	## 在**原地**立起一座钢铁要塞（9134，工事 5/100 程2，嘲讽）。
	## ⚠️ 这不是亡语 —— 被玩家提前打掉就什么都不会留下（卡面已写明）。
	## 于是这关的取舍是：**5 个回合内**是先把 35 血的赫卡同克瑞斯拆掉（要塞就永远
	## 不会出现），还是先应付那只每回合打两轮的 10 攻俄倪厄（50 血）。
	## 真让要塞立起来，玩家要面对 100 血 + 嘲讽 + 攻程 2 的工事，再往后才轮得到俄倪厄。
	return {
		"name": "钢铁要塞",
		"key": "steel_fortress",
		"tier": TIER_ELITE_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9133, "量产型赫卡同克瑞斯", 3, 35, 1, 1, Vector2i(0, 0)],
			[9132, "俄倪厄", 10, 50, 1, 1, Vector2i(0, 2)],
		],
		"tutorial": [],
	}


static func _captain() -> Dictionary:
	## 精英敌人-简单：后排中间鸭子队长（8/50，一回合行动两次），
	## 中排左右各一只鸭子骑士护航，AI 推进。
	return {
		"name": "鸭子队长登场",
		"key": "captain",
		"tier": TIER_ELITE_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9012, "鸭子队长", 7, 50, 1, 1, Vector2i(0, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 2)],
		],
		"tutorial": [],
	}
