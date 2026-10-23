class_name RelicRepo
extends RefCounted
## 道具库：从 relics.json 加载全部道具（与 CardRepo 同风格）。

var _relics := {}  # id -> RelicData


static func load_json(path: String = "res://relics.json") -> RelicRepo:
	var repo := RelicRepo.new()
	if not FileAccess.file_exists(path):
		push_error("relics.json 不存在")
		return repo
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("relics.json 解析失败")
		return repo
	var list: Array = data if data is Array else data.get("relics", [])
	for d: Dictionary in list:
		var relic := RelicData.from_dict(d)
		repo._relics[relic.id] = relic
	return repo


func get_relic(id: int) -> RelicData:
	return _relics.get(id)


func all_relics() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for id: int in _relics.keys():
		out.append(_relics[id])
	out.sort_custom(func(a: RelicData, b: RelicData): return a.id < b.id)
	return out


func initial_ids() -> Array[int]:
	## 初始道具池（起点三选一；新道具加进 relics.json 后在此登记）。
	## R244：**鸡煲 6003 移出初始池**（仍留在道具库里，供旧存档/演示使用）；
	##       新增「行囊」6030（+100 金币 + 一张木栅栏进卡组）。
	## R245：新增「勇气徽章」6031（精英首回合 / Boss 前两回合 +1 费）与
	##       「陶罐」6032（随机 2 件奖励道具 + 一张「罐子」诅咒进卡组）。
	## R341：新增「惊奇盒子」6047（获得即塞一张同名工事卡）与「洞窟绳」6048
	##       （Boss 以外的战斗可以逃跑，逃跑即失去）。两件都只在第一层起点三选一。
	return [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048]


func reward_ids(tier: String = "") -> Array[int]:
	## 奖励道具池（精英 / Boss 掉落、大宝箱开箱等途径；不进起点三选一）。
	## R224：新增苹果 6027（+14 最大生命并回满）/ 牛奶 6028（随机两种附魔）。
	## R244：**苹果 6027 移出奖励池** → 改为第二层事件「苹果与医生」专属的道具。
	## R289：加 `tier` 形参做二级分档 —— "" = 全池（旧行为不变）；
	##       "一般" / "传奇" = 只返回该档的 id。
	## R311：新增「水晶骰子」6040（除固定房间与休息处外全变「?」房 + ? 房战斗掷骰加费）
	##       与「不锈钢盆」6041（10 点计数代替承伤 / 商店优先抵账）。两件都在「一般」档。
	## R313：新增「风妖精」6042（一回合第 5 张牌 → 全体 4 伤）与「快速符文」6043
	##       （每出牌技能伤害 +10% 加算去尾、对不能行动的敌人加倍）。
	## R314：**水晶骰子 6040 升为「传奇」档**；新增传奇「储物箱」6044（回合结束不弃手牌）
	##       与「lucky 7」6045（每 7 个回合免伤 + 技能 +7）。传奇档不再空置。
	## R315：新增「爆米花」6046（本回合没用技能指向敌人 → 下回合多抽 1 张），「一般」档。
	## R342：新增传奇「采集刀」6050（战斗胜利后多给一组卡牌奖励）与「火柴」6051
	##       （卡牌奖励界面 3 次刷新，一般档）。
	return _filter_by_tier([6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051], tier)


func normal_reward_ids() -> Array[int]:
	## 奖励池里的「一般道具」（R342 起 16 件）。
	return reward_ids(RelicData.TIER_NORMAL)


func legendary_reward_ids() -> Array[int]:
	## 奖励池里的「传奇道具」（R342 起 4 件：6040 水晶骰子 / 6044 储物箱 / 6045 lucky 7 /
	## 6050 采集刀）。
	## ⚠️ 调用方仍须能忍住空池（拿满 / 全跳过时的正常边界）。
	return reward_ids(RelicData.TIER_LEGENDARY)


func _filter_by_tier(ids: Array[int], tier: String) -> Array[int]:
	## 按分档筛 id：空串 = 原样返回；未知档位 = 空池 + 警告（不猜、不回落）。
	if tier == "":
		return ids
	if not RelicData.RELIC_TIERS.has(tier):
		push_warning("RelicRepo：未知道具分档「%s」，按空池处理" % tier)
		return []
	var out: Array[int] = []
	for id: int in ids:
		var r: RelicData = get_relic(id)
		if r != null and r.tier == tier:
			out.append(id)
	return out


func event_ids() -> Array[int]:
	## 事件道具池（事件节点给予，如鸭鸭低语、一袋米抗几楼、休息处烤肉、鸭梨；
	## 不进初始/奖励池）。R244：苹果 6027 从奖励池挪进来（「苹果与医生」专属）。
	return [6010, 6011, 6012, 6019, 6027]


func layer2_ids() -> Array[int]:
	## 第二层起始道具池（只在第二层的起始节点三选一；
	## 不进第一层初始池 / 奖励池 / 事件池）。
	## R246：新增「兼修」6033（每回合 +1 费 + 奖励/商店放开职业）与
	##       「附魔大师」6034（每次休息随机附一个合规的随机附魔）。
	## R341：新增「鹿首标本」6049（每个我方回合开始：技能与陷阱类场地伤害 +1，本场累计）。
	return [6014, 6015, 6016, 6017, 6018, 6033, 6034, 6049]


func start_ids_for_layer(layer: int) -> Array[int]:
	## 该层「起始节点三选一」的道具池：第一层 = 初始池，第二层 = 二层起始池。
	match layer:
		2:
			return layer2_ids()
	return initial_ids()


func class_ids() -> Array[int]:
	## 角色赠品道具（选定角色时由 RunState.start_run 发放，如森林精魄的「荒野形态」6022）。
	## 这一池**不参与任何随机抽取**：起点三选一 / 奖励掉落 / 事件 / 二层起始都不含它。
	return [6022, 6023, 6025]


func roll_reward(rng: RandomNumberGenerator, tier: String = "") -> int:
	## 从奖励池随机抽一个道具 id（奖励界面上架/掉落用）。
	## R289：`tier` 传 "一般" / "传奇" 可只在该档里抽；空串 = 全池（旧行为）。
	var pool := reward_ids(tier)
	if pool.is_empty():
		return -1
	return pool[rng.randi() % pool.size()]
