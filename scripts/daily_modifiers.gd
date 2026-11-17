class_name DailyModifiers
extends RefCounted
## R767：每日挑战的**修饰池**与**随机卡组**。
##
## 为什么单独一个模块：R762 的每日挑战只是「固定角色 + 固定难度 + 固定种子」，
## 每天都长一个样，第三天就没人打了。这里给两样东西：
##   ① 修饰池 —— 10 条增益 / 10 条减益，每天各摇 2 条（同日同局，跨端一致）；
##   ② 随机卡组 —— 同一天所有人的 15 张牌一样，但每天都不同。
##
## 三条纪律：
##   * **纯函数**：只吃 (root_seed, cid)，不碰 RunState / 全局随机源 —— 这样同一天
##     在任何机器、任何顺序下摇出来的结果都相同，Steam 榜才有意义。
##   * **效果字段只写「取值口的名字」**，合并方式按后缀区分：`_mul` 相乘，其余相加。
##     实际落地全在 `RunState` 那几个唯一取数口里，本模块不直接改任何数值。
##   * **池子顺序即抽取顺序**（用 Fisher-Yates 打乱后取前 N）—— 往池子里加条目会改变
##     历史日期的结果；真要加，同时把 `RULES_VERSION` 加一，让旧榜留在旧规则下。

const RULES_VERSION := 3
const BUFF_COUNT := 2
const DEBUFF_COUNT := 2

## 每日随机卡组的固定张数：10 张基础（木栅栏 + 攻击）+ 5 张从本职业可达池里摇。
const DECK_TOTAL := 15
const DECK_EXTRAS := 5

const FENCE_ID := 8001
const ATTACK_ID := 8002

## 修饰池。`fx` 的键就是 `RunState` 取数口的字段名：
##   gold / choco / tools / deck_extra / deck_curse / enemy_hp / enemy_power / energy / draw / rest_pick
##   （相加）· hp_mul / rare_mul / elite_mul（相乘）· rest_to_battle / fatigue（布尔「或」）
## ⚠️ `rest`（休息回复百分比）这个键**仍然被 `RunState.rest_pct()` 读**，但 R781 起没有任何
##    修饰产出它 —— 留着是给「将来要再加一条回血修饰」的地方，别顺手删掉取数口。
const POOL: Array = [
	# ---- 增益 ----
	{"key": "RICH", "kind": "buff", "zh": "富裕", "desc_zh": "初始金币 +80",
		"fx": {"gold": 80}},
	{"key": "STURDY", "kind": "buff", "zh": "强健", "desc_zh": "最大生命 +15%",
		"fx": {"hp_mul": 1.15}},
	{"key": "RATIONS", "kind": "buff", "zh": "旅粮", "desc_zh": "每层巧克力 +2",
		"fx": {"choco": 2}},
	{"key": "LUCKY", "kind": "buff", "zh": "幸运", "desc_zh": "稀有卡获取概率 ×1.6",
		"fx": {"rare_mul": 1.6}},
	{"key": "WARM", "kind": "buff", "zh": "温暖", "desc_zh": "火堆可以选两个选项",
		"fx": {"rest_pick": 1}},
	{"key": "GIFTED", "kind": "buff", "zh": "工具箱", "desc_zh": "开局多一件工具",
		"fx": {"tools": 1}},
	{"key": "MIXED", "kind": "buff", "zh": "杂牌", "desc_zh": "卡组多 3 张随机卡",
		"fx": {"deck_extra": 3}},
	{"key": "FRAIL_FOE", "kind": "buff", "zh": "敌之孱弱", "desc_zh": "敌人生命 −15%",
		"fx": {"enemy_hp": -0.15}},
	{"key": "QUIET", "kind": "buff", "zh": "冷清", "desc_zh": "精英出现概率 ×0.75",
		"fx": {"elite_mul": 0.75}},
	{"key": "SURGE", "kind": "buff", "zh": "灵光", "desc_zh": "每回合费用 +1",
		"fx": {"energy": 1}},

	# ---- 减益 ----
	{"key": "POOR", "kind": "debuff", "zh": "贫瘠", "desc_zh": "初始金币 −50",
		"fx": {"gold": -50}},
	{"key": "ANEMIC", "kind": "debuff", "zh": "贫血", "desc_zh": "最大生命 −12%",
		"fx": {"hp_mul": 0.88}},
	{"key": "HUNGRY", "kind": "debuff", "zh": "饥饿", "desc_zh": "每层巧克力 −2",
		"fx": {"choco": -2}},
	{"key": "UNLUCKY", "kind": "debuff", "zh": "倒霉", "desc_zh": "稀有卡获取概率 ×0.5",
		"fx": {"rare_mul": 0.5}},
	{"key": "COLD", "kind": "debuff", "zh": "阴冷", "desc_zh": "火堆全部变为战斗",
		"fx": {"rest_to_battle": true}},
	{"key": "CURSED", "kind": "debuff", "zh": "诅咒", "desc_zh": "卡组塞 2 张木栅栏",
		"fx": {"deck_curse": 2}},
	{"key": "TOUGH_FOE", "kind": "debuff", "zh": "敌之顽强", "desc_zh": "敌人生命 +20%",
		"fx": {"enemy_hp": 0.20}},
	{"key": "FIERCE", "kind": "debuff", "zh": "凶猛", "desc_zh": "敌人攻击 +1",
		"fx": {"enemy_power": 1}},
	{"key": "CROWDED", "kind": "debuff", "zh": "拥挤", "desc_zh": "精英出现概率 ×1.5",
		"fx": {"elite_mul": 1.5}},
	{"key": "DRAINED", "kind": "debuff", "zh": "滞涩", "desc_zh": "每回合抽卡 −1",
		"fx": {"draw": -1}},
]


static func buff_keys() -> Array[String]:
	return _keys_of("buff")


static func debuff_keys() -> Array[String]:
	return _keys_of("debuff")


static func _keys_of(kind: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in POOL:
		if str(e.get("kind", "")) == kind:
			out.append(str(e["key"]))
	return out


static func entry(key: String) -> Dictionary:
	## 按 key 取条目；未知 key 返回空字典（调用方自行兜底，别崩）。
	for e: Dictionary in POOL:
		if str(e.get("key", "")) == key:
			return e
	return {}


static func name_of(key: String) -> String:
	## 修饰名（界面显示）。i18n 走 `daily` 域；没翻译时回退中文原词。
	var e := entry(key)
	if e.is_empty():
		return key
	return GameI18n.ui("daily", "MOD_" + key, str(e.get("zh", key)))


static func desc_of(key: String) -> String:
	## 一句话效果说明。**只描述数值**，不写「幸运/倒霉」这种评价词。
	var e := entry(key)
	if e.is_empty():
		return ""
	return GameI18n.ui("daily", "MODDESC_" + key, str(e.get("desc_zh", "")))


static func line_of(key: String) -> String:
	## 面板上的一整行：`名称 · 效果`。中间用间隔号，视觉上比冒号轻。
	return "%s · %s" % [name_of(key), desc_of(key)]


static func roll(root_seed: int) -> Array[String]:
	## 每天摇 2 增益 + 2 减益。用**独立派生流**（不碰 RunState.run_rng）：
	## 玩家在标准模式里玩过多少局，都不该影响今天每日的配置。
	var rng := RandomNumberGenerator.new()
	rng.seed = (root_seed ^ 0x5A5A1A1A) & 0x7FFFFFFF
	var buffs := buff_keys()
	var debuffs := debuff_keys()
	_shuffle(buffs, rng)
	_shuffle(debuffs, rng)
	var out: Array[String] = []
	for i in mini(BUFF_COUNT, buffs.size()):
		out.append(buffs[i])
	for i in mini(DEBUFF_COUNT, debuffs.size()):
		out.append(debuffs[i])
	return out


static func _shuffle(arr: Array[String], rng: RandomNumberGenerator) -> void:
	## Fisher-Yates。不用 `Array.shuffle()`：那个吃全局随机源，同日不同机器会摇出不同结果。
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := arr[i]
		arr[i] = arr[j]
		arr[j] = t


static func fx_of(keys: Array) -> Dictionary:
	## 把若干修饰条目合并成一份「效果汇总」。`_mul` 后缀相乘，布尔取「或」，其余相加。
	## R781：布尔分支做成通用判断（原先只认 `fatigue` 一个特例）—— 「阴冷」的
	## `rest_to_battle` 也是开关型，再写一个 key 特例只会让第三条布尔修饰继续漏。
	var out: Dictionary = {}
	for k: Variant in keys:
		var e := entry(str(k))
		if e.is_empty():
			continue
		var fx: Dictionary = e.get("fx", {})
		for fk: Variant in fx.keys():
			var name := str(fk)
			var raw: Variant = fx[fk]
			if raw is bool:
				out[name] = bool(out.get(name, false)) or bool(raw)
				continue
			if name.ends_with("_mul"):
				out[name] = float(out.get(name, 1.0)) * float(raw)
			else:
				out[name] = float(out.get(name, 0.0)) + float(raw)
	return out


static func roll_deck(root_seed: int, cid: String, fx: Dictionary = {}) -> Array[int]:
	## 每日随机卡组：**15 张** —— 10 张基础（木栅栏 4~6 + 攻击补足）+ 5 张本职业可达卡，
	## 其中至少 1 张盟友（全是技能的话开场就站不住人）。
	##
	## 为什么不整组随机：木栅栏与攻击是「这个游戏的下限」—— 抽不到这两样，
	## 前两回合就会出现「手里 5 张全下不去」的死局，那不叫随机叫坏局。
	## 也不动 `PlayerClass.BASE_COMMON`：标准模式的初始卡组必须一个字都不变。
	var rng := RandomNumberGenerator.new()
	rng.seed = (root_seed ^ 0x2D2D2D2D) & 0x7FFFFFFF
	var fence := rng.randi_range(4, 6)
	var atk := 10 - fence
	var out: Array[int] = []
	for i: int in fence:
		out.append(FENCE_ID)
	for i: int in atk:
		out.append(ATTACK_ID)
	var repo := CardRepo.load_json()
	var pool := _daily_pool(repo, cid)
	if pool.is_empty():
		# 池空（理论上不会）→ 退回职业标准卡组，别给玩家一个 10 张的空壳。
		return PlayerClass.start_deck_ids(cid)
	var allies: Array[CardData] = []
	for c: CardData in pool:
		if c.kind == "盟友":
			allies.append(c)
	if not allies.is_empty():
		out.append(int(allies[rng.randi() % allies.size()].id))
	for i: int in DECK_EXTRAS - (1 if not allies.is_empty() else 0):
		out.append(int(pool[rng.randi() % pool.size()].id))
	if out.size() < DECK_TOTAL:
		# 保险：盟友池抽过之后若数量不足（池子极小时会发生），用攻击补齐。
		while out.size() < DECK_TOTAL:
			out.append(ATTACK_ID)
	# 修饰追加：`deck_extra`（杂牌）加随机好卡、`deck_curse`（诅咒）塞木栅栏。
	# 放在这里而不是 `start_run()` 里 —— 配置必须是纯函数，同一天任何机器算出来一样。
	for i: int in int(fx.get("deck_extra", 0)):
		out.append(int(pool[rng.randi() % pool.size()].id))
	for i: int in int(fx.get("deck_curse", 0)):
		out.append(FENCE_ID)
	return out


static func _daily_pool(repo: CardRepo, cid: String) -> Array[CardData]:
	## 每日卡组专用池：**刻意不看账号进度** —— 剧情锁（`locked`）与个人禁卡都不看。
	##
	## 理由：每日挑战的承诺是「同一天所有人同一局」，而 `CardRepo.reward_pool_for()`
	## 会按 `ProfileData` 的解锁状态过滤。拿它当池子，同一天两台机器（解锁进度不同）
	## 就会摇出不同卡组，Steam 榜立刻失去意义。
	##
	## 与奖励池的差别**仅此两条**，别在这里顺手加别的过滤 —— 加一条就可能重新引入账号差异。
	var out: Array[CardData] = []
	for c: CardData in repo.all_cards():
		if c.rarity > 2 or c.traits.has("测试"):
			continue
		if c.event_only:
			continue
		if PlayerClass.is_hidden_class(c.card_class):
			continue
		if not repo.is_own_class_card(c, cid):
			continue
		out.append(c)
	# 顺序必须稳定：抽取结果是「按下标摇」的，池子顺序一变，同一天就不再是同一套牌。
	out.sort_custom(func(a: CardData, b: CardData): return a.id < b.id)
	return out


static func deck_label() -> String:
	return GameI18n.ui("daily", "MOD_DECK_RANDOM", "随机构筑")
