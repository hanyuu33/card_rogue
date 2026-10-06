class_name CardReward
extends RefCounted
## 肉鸽模式 · 卡牌奖励抽取规则。
##
## 两档奖励类型，稀有度概率构成不同（0=普通 1=稀有 2=史诗）：
##   normal（普通过关奖励）：普通 70% / 稀有 27% / 史诗 3%
##   boss  （Boss过关奖励）：普通 35% / 稀有 45% / 史诗 20%
## 一次奖励给 3 张候选（互不重名），玩家选 1 张或跳过。

const TYPES: Array[String] = ["normal", "boss"]
const TYPE_LABELS := {"normal": "普通过关奖励", "boss": "Boss过关奖励"}
## 每种奖励类型 → [普通, 稀有, 史诗] 概率权重（总和不必为 1，内部归一化）
const TYPE_WEIGHTS := {
	"normal": [0.70, 0.27, 0.03],
	"boss": [0.35, 0.45, 0.20],
}
const CHOICES := 3


static func type_label(reward_type: String) -> String:
	return TYPE_LABELS.get(reward_type, reward_type)


## 从候选池按稀有度权重抽 count 张互不重名的卡。
## kinds = ["效果", "技能"] 这类**卡类白名单**（空 = 不限卡类），用于事件里限定范围内的三选一
## （如「奥秘之泉 · 喝下泉水」只在 效果 / 技能 里抽，稀有度概率仍按奖励类型走）。
## rng 可注入（测试用）；缺省用全局随机。
## cid = 角色过滤（R47）：排除**其他角色专属卡**（暗影刺客不会摇到森林精魄的身份卡，反之亦然）。
## 留空 = 用当前 run 的角色（RunState.player_class）—— 游戏内调用一律走这条。
static func roll(repo: CardRepo, reward_type: String, count: int = CHOICES,
		rng: RandomNumberGenerator = null, kinds: Array[String] = [],
		cid: String = "") -> Array[CardData]:
	var pool := repo.reward_pool_for(cid if cid != "" else RunState.player_class)
	if not kinds.is_empty():
		var filtered: Array[CardData] = []
		for c: CardData in pool:
			if c.kind in kinds:
				filtered.append(c)
		pool = filtered
	var out: Array[CardData] = []
	if pool.is_empty() or count <= 0:
		return out
	var weights: Array = TYPE_WEIGHTS.get(reward_type, TYPE_WEIGHTS["normal"])
	var used_names := {}
	for i in count:
		var card := _pick_one(pool, weights, used_names, rng)
		if card == null:
			break
		used_names[card.card_name] = true
		out.append(card)
	return out


static func _pick_one(pool: Array[CardData], weights: Array,
		used_names: Dictionary, rng: RandomNumberGenerator) -> CardData:
	## 标准权重抽样：只在「仍有未选名称候选」的稀有度里，
	## 按各自权重归一化后抽一个稀有度，再从该稀有度候选里随机取一张。
	var live := {}   # rarity -> candidates（仍有候选的稀有度）
	var total := 0.0
	for r in 3:
		var w := _weight_at(weights, r)
		if w <= 0.0:
			continue
		var candidates: Array[CardData] = []
		for c: CardData in pool:
			if c.rarity == r and not used_names.has(c.card_name):
				candidates.append(c)
		if not candidates.is_empty():
			live[r] = candidates
			total += w
	if live.is_empty():
		return null
	var roll := rng.randf() * total if rng != null else randf() * total
	var acc := 0.0
	var chosen_r := -1
	for r in [0, 1, 2]:
		if not live.has(r):
			continue
		acc += _weight_at(weights, r)
		if roll < acc:
			chosen_r = r
			break
	if chosen_r < 0:  # 浮点兜底：取最后一个仍有候选的稀有度
		var keys := live.keys()
		chosen_r = keys[keys.size() - 1]
	var candidates: Array[CardData] = live[chosen_r]
	var idx := (rng.randi_range(0, candidates.size() - 1)
			if rng != null else randi() % candidates.size())
	return candidates[idx]


static func _weight_at(weights: Array, r: int) -> float:
	return float(weights[r]) if r < weights.size() else 0.0
