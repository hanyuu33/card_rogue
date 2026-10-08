class_name GameLevels
extends RefCounted
## 内置关卡（肉鸽版）：「鸭子骑士来袭」——
## 我方用初始卡组（12 张），敌方前排左右各一只鸭子骑士（AI 控制推进）。
##
## 教程系统与多关卡暂时移除；教程引导条相关常量保留，
## battle_scene 的 dormant 代码仍引用它们（tutorial 数组为空即不触发）。
## 未来肉鸽波次模式将替换 builtin_levels。
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
	## 按分级从低到高：普通简单×6（含第二层 2 关）→ 普通困难×2 →
	## 精英简单×2（含第二层「哈气骑士团」）→ 精英困难×2 → Boss。
	## 地图节点从「本层内容池」的对应分级池随机抽关（见 normal_pool / elite_pool / boss_level）。
	return [_encounter(), _familiars(), _archer_knight(), _blaze_pack(),
			_white_mage_guard(), _night_ducks(),
			_knight_charge(), _wizard(), _duck_kiln(),
		_captain(), _captain_wizard(), _legion(), _breath_charge(), _frost_line(), _undead_legion(), _dragon_nest(),
		_mech_giant(), _boss_dragon(), _boss_demon_duck(), _mech_duck_boss(), _boss_duck_darkside()]


static func layer_of(level: Dictionary) -> int:
	## 关卡所属层（未标 layer 的关卡按第一层处理）。
	return int(level.get("layer", GameLayers.LAYER_DEFAULT))


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


static func _encounter() -> Dictionary:
	## 普通敌人-简单：中排左右各一只鸭子骑士（3/30，速 2，击杀成长），AI 推进。
	## enemy_units: [id, 名称, 力, 生, 程, 速, 格子]
	return {
		"name": "鸭子骑士来袭",
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


## 第二层关卡的成长曲线（「低开高走」）：开局先把敌人的攻击力压下去，
## 之后每 2 个回合 +1，最多 +4，让后期压力一点点涨回来。
const LAYER2_GROWTH := {
	"mod_strong": -3,   # 强力怪（基础攻击力 >= strong_atk）开局攻击力 -3
	"mod_weak": -1,     # 杂兵开局攻击力 -1
	"strong_atk": 7,    # 基础攻击力 >= 7 算「强力怪」
	"start_turn": 2,    # 从第 2 回合开始成长
	"period": 2,        # 每 2 个回合
	"inc": 1,           # +1 攻击力
	"cap": 4,           # 累计最多 +4
}

static func _frost_line() -> Dictionary:
	## 第二层·普通敌人-简单「寒冰防线」：后排中央一名冰冻术士（5/24 程3，
	## 首个回合开始时冻结我方一个单位），前排中央铁壁卫兵（4/45 嘲讽）带队，
	## 两翼各一个骷髅兵。嘲讽会逼停在它面前的敌方单位。
	return {
		"name": "寒冰防线",
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
			[1031, "冰冻术士", 5, 24, 3, 1, Vector2i(0, 1)],
			[1011, "铁壁卫兵", 4, 40, 1, 1, Vector2i(2, 1)],
			[1053, "骷髅兵", 3, 10, 1, 1, Vector2i(2, 0)],
			[1054, "骷髅兵", 4, 14, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _undead_legion() -> Dictionary:
	## 第二层·普通敌人-困难「亡灵军团」：后排中央亡灵领主（8/55 速2，亡语召唤两个骷髅，一回合行动两次），
	## 前排骷髅兵（嘲讽）+ 腐化尸鬼（5/18 速2，亡语打我方 HP）+ 骷髅兵（亡语召唤一只骷髅）。
	return {
		"name": "亡灵军团",
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
			[1051, "亡灵领主", 8, 55, 1, 2, Vector2i(0, 1)],
			[1055, "骷髅兵", 3, 28, 1, 1, Vector2i(2, 0)],
			[1050, "腐化尸鬼", 5, 18, 1, 2, Vector2i(2, 1)],
			[1054, "骷髅兵", 4, 14, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _dragon_nest() -> Dictionary:
	## 第二层·精英敌人-简单「龙族巢穴」：后排中央灰烬龙（9/40 速2，战吼对我方全场 4 伤，一回合行动两次），
	## 中排两翼幼龙（6/25 程2，亡语召唤龙裔 4/12），前排中央铁壁卫兵（嘲讽）挡路。
	return {
		"name": "龙族巢穴",
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
			[1013, "灰烬龙", 9, 45, 1, 2, Vector2i(0, 1)],
			[1014, "幼龙", 6, 25, 2, 1, Vector2i(1, 0)],
			[1014, "幼龙", 6, 25, 2, 1, Vector2i(1, 2)],
			[1011, "铁壁卫兵", 4, 40, 1, 1, Vector2i(2, 1)],
		],
		"tutorial": [],
	}


static func _mech_giant() -> Dictionary:
	## 第二层·精英敌人-困难「机甲巨兵」：后排中央熔岩巨人（12/70 速2，法术免疫，一回合行动两次），
	## 中排两翼爆裂机甲（7/30 程2，亡语对全场单位 8 伤），前排中央铁壁卫兵（嘲讽）。
	return {
		"name": "机甲巨兵",
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
			[1071, "熔岩巨人", 12, 70, 1, 2, Vector2i(0, 1)],
			[1061, "爆裂机甲", 7, 30, 2, 1, Vector2i(1, 0)],
			[1061, "爆裂机甲", 7, 30, 2, 1, Vector2i(1, 2)],
			[1011, "铁壁卫兵", 4, 40, 1, 1, Vector2i(2, 1)],
		],
		"tutorial": [],
	}


static func _boss_dragon() -> Dictionary:
	## Boss：后排中间远古虚骨龙（12/100，程 2 速 2，回合开始吐息），
	## 敌方效果卡「鸭子号角」——每 3 个回合召唤一只鸭子骑士。
	return {
		"name": "远古虚骨龙",
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
	## 第二层 Boss「鸭之暗面」（R111）：后排中央一只鸭之暗面（9124，9/150，程1 速1），
	## 敌方效果卡「暗影召唤 9125」——**开局**以及**每 3 个回合**召唤一只鸭子暗杀者（9123，6/30）。
	##   * 鸭之暗面「穿行」= 移动**无视单位阻挡**（可穿过任何单位，不能停在上面）；
	##   * 鸭之暗面「暗影领主」= **每个存活暗杀者** +3 力 +1 速（死了立刻掉）；
	##   * 暗杀者被动：只要场上还有非暗杀单位（= 鸭之暗面还在），它就不能打我方 HP，
	##     但可以**闪现**到任意空格 —— 于是它专门绕后咬你的后排，而不是傻推脸。
	## 打法：暗杀者会自己滚起来，要么尽快点掉暗杀者压住鸭之暗面的成长，
	##   要么直接顶着脸硬拆 150 血（但每多一只暗杀者它就多疼一下）。
	return {
		"name": "鸭之暗面",
		"tier": TIER_BOSS,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"intro": "……别回头看。",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[9124, "鸭之暗面", 9, 150, 1, 1, Vector2i(0, 1)],
		],
		"enemy_effects": [9125],
		"tutorial": [],
	}


static func _legion() -> Dictionary:
	## 精英敌人-困难：鸭子骑士×6（后排 3 + 前排 3），敌方开局启用效果卡
	## 「鸭子之力」——所有友方每回合力量 +1，最多累计 +5。
	return {
		"name": "骑士军团",
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
			[9012, "鸭子队长", 8, 50, 1, 1, Vector2i(0, 1)],
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
	## 第二层·普通敌人-简单：后排中央一名白魔法师（9021，2/100，回合开始治疗
	## 生命值百分比最低的己方单位 10 点；精进——每回合开始力量 +1，无前置条件），
	## 前排三名鸭子骑士护阵。
	return {
		"name": "白魔法师护阵",
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
			[9021, "白魔法师", 2, 100, 1, 1, Vector2i(0, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _night_ducks() -> Dictionary:
	## 第二层·普通敌人-简单：中排左右各一只夜鸭（6/35，程 2 速 2，回合开始 +1 攻），
	## 前排左右各一只使魔鸭子（4/15，程 1 速 1）护阵，AI 推进。
	return {
		"name": "夜鸭阵",
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
			[9027, "夜鸭", 6, 35, 2, 2, Vector2i(1, 0)],
			[9027, "夜鸭", 6, 35, 2, 2, Vector2i(1, 2)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 0)],
			[9009, "使魔鸭子", 4, 15, 1, 1, Vector2i(2, 2)],
		],
		"tutorial": [],
	}


static func _breath_charge() -> Dictionary:
	## 第二层·精英敌人-简单：前排三名鸭子骑士一字排开，后排两翼各一名鸭子弓手
	## （程 2 远程压制），敌方开局启用效果卡「哈气」——**敌方**单位从第 3 个回合起一回合可以行动两次
	## （移动 + 攻击重来一遍；骑士速 2 → 一回合最多推进 4 格；前 2 回合仍是单动）。
	return {
		"name": "哈气骑士团",
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


static func _duck_kiln() -> Dictionary:
	## 第二层·普通敌人-困难：敌方后排中央一座鸭子窑（9025，工事 0 力 100 血），
	## 自己回合开始时（含首回合）在四周曼哈顿距离为 1 的空格各烧出一只陶瓷鸭
	## （8 力，生命 = 当前己方回合数，程1 速2）。越界/被占用的邻格跳过。
	return {
		"name": "鸭子窑",
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
			[9025, "鸭子窑", 0, 100, 0, 0, Vector2i(0, 1)],
		],
		"tutorial": [],
	}


static func _captain() -> Dictionary:
	## 精英敌人-简单：后排中间鸭子队长（8/50，一回合行动两次），
	## 中排左右各一只鸭子骑士护航，AI 推进。
	return {
		"name": "鸭子队长登场",
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
			[9012, "鸭子队长", 8, 50, 1, 1, Vector2i(0, 1)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 0)],
			[9001, "鸭子骑士", 3, 30, 1, 2, Vector2i(1, 2)],
		],
		"tutorial": [],
	}
