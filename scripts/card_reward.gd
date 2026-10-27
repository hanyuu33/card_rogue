class_name CardReward
extends RefCounted
## 肉鸽模式 · 卡牌奖励抽取规则。
##
## 两档奖励类型，稀有度概率构成不同（0=普通 1=稀有 2=史诗）：
##   normal（普通过关奖励）：普通 68% / 稀有 27% / 史诗 5%（R392）
##   boss  （Boss过关奖励）：普通 35% / 稀有 45% / 史诗 20%
##   epic  （R390 Boss 额外那组）：100% 史诗（三张候选全史诗）
## 一次奖励给 3 张候选（互不重名），玩家选 1 张或跳过。

const TYPES: Array[String] = ["normal", "boss", "epic"]
const TYPE_LABELS := {"normal": "普通过关奖励", "boss": "Boss过关奖励",
		"epic": "史诗卡牌奖励"}
## 每种奖励类型 → [普通, 稀有, 史诗] 概率权重（总和不必为 1，内部归一化）
const TYPE_WEIGHTS := {
	"normal": [0.68, 0.27, 0.05],
	"boss": [0.35, 0.45, 0.20],
	# R390（用户口径）：Boss 额外那一组「必定史诗」—— 权重只留史诗档，
	# 于是三张候选必然都是史诗。史诗池空了 `_pick_one` 会返回 null，
	# 那一组就不入队（宁可少给一组，也不拿稀有冒充史诗）。
	"epic": [0.0, 0.0, 1.0],
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
## exclude_ids（R342，火柴 6051）：**先把这些 id 从池子里摘掉**再抽 —— 「刷新」不该刷出
## 玩家刚刚见过的那三张。摘完不够 count 张时**不自作聪明**：放弃排除、按原池抽
## （宁可重复，也不能给出半组奖励）。确定性不变：同一操作序列消耗同样多个随机数。
static func roll(repo: CardRepo, reward_type: String, count: int = CHOICES,
		rng: RandomNumberGenerator = null, kinds: Array[String] = [],
		cid: String = "", exclude_ids: Array[int] = []) -> Array[CardData]:
	# R246 兼修（6033）：持有它 → 奖励（连带商店那一行）不再按职业过滤。
	# ⚠️ 只影响「默认 cid」这一支：显式传 cid 的调用（事件 / 测试）语义不变。
	var want_cid := cid
	if want_cid == "":
		want_cid = "" if RunState.all_class_rewards() else RunState.player_class
	var pool := repo.reward_pool_for(want_cid)
	if not kinds.is_empty():
		var filtered: Array[CardData] = []
		for c: CardData in pool:
			if c.kind in kinds:
				filtered.append(c)
		pool = filtered
	if not exclude_ids.is_empty():
		var kept: Array[CardData] = []
		for c: CardData in pool:
			if not exclude_ids.has(c.id):
				kept.append(c)
		if kept.size() >= count:
			pool = kept
	var out: Array[CardData] = []
	if pool.is_empty() or count <= 0:
		return out
	# R223 难度 4「稀有卡牌获取概率降低」：稀有权重 ×0.5（史诗不动；内部按总和归一化）。
	# ⚠️ TYPE_WEIGHTS 是 const 字典、取出来的是**共享引用** —— 必须 `.duplicate()`
	# 新建数组再改，否则会把全局表永久改掉（后续每局都吃这个乘数）。
	var weights: Array = (TYPE_WEIGHTS.get(reward_type, TYPE_WEIGHTS["normal"]) as Array).duplicate()
	var rare_mul: float = RunState.rare_weight_mul()
	if rare_mul != 1.0:
		weights[1] = float(weights[1]) * rare_mul
	var used_names := {}
	for i in count:
		var card := _pick_one(pool, weights, used_names, rng)
		if card == null:
			break
		used_names[card.card_name] = true
		out.append(card)
	return out


static func roll_rarity(repo: CardRepo, rarity: int, count := 1,
		rng: RandomNumberGenerator = null, cid := "") -> Array[CardData]:
	## 按**稀有度**抽卡（R305：湖中仙女 · 诚实 → 随机一张史诗）。
	## 池子 = 本职业奖励池里 rarity 命中的卡（`repo.reward_pool_for(cid)`；cid 空 → 本局职业）。
	## ⚠️ 不走 `TYPE_WEIGHTS`：那是「按稀有权重抽」，这里稀有度已经定死，再套权重就没意义。
	## ⚠️ 随机源由调用方给（本局 `run_rng`）—— 同一种子必然一致。
	var want := cid
	if want == "":
		want = "" if RunState.all_class_rewards() else RunState.player_class
	var pool: Array[CardData] = []
	for c: CardData in repo.reward_pool_for(want):
		if c.rarity == rarity:
			pool.append(c)
	var out: Array[CardData] = []
	if pool.is_empty() or count <= 0:
		return out
	var used := {}
	for i in count:
		var cands: Array[CardData] = []
		for c: CardData in pool:
			if not used.has(c.card_name):
				cands.append(c)
		if cands.is_empty():
			break
		var pick := (rng.randi_range(0, cands.size() - 1) if rng != null
				else randi() % cands.size())
		out.append(cands[pick])
		used[cands[pick].card_name] = true
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
