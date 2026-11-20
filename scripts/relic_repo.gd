class_name RelicRepo
extends RefCounted
## 道具库：从 relics.json 加载全部道具（与 CardRepo 同风格）。

var _relics := {}  # id -> RelicData

## R746：静态数据的**唯一共享实例**。`relics.json` 运行期不变，而地图每 90ms 重绘一次，
## 每次重绘都拿这份数据 —— 每次 `load_json()` 都是一次读盘 + JSON 解析 + 61 个 RelicData
## 构造（模拟器上实测占单帧绘制耗时的 25%）。绘制路径一律走这里。
static var _shared = null          # 无类型注解：写成自身 class_name 会触发解析器自引用错误


static func shared() -> RelicRepo:
	if _shared == null:
		_shared = load_json()
	return _shared


static func load_json(path: String = "res://relics.json") -> RelicRepo:
	var repo := RelicRepo.new()
	## R789：`content/` 覆盖优先（热更），缺失或损坏时回落 pck 基线。
	var data: Variant = DataPaths.read_json(path, "relics")
	if data == null:
		push_error("relics.json 缺失或解析失败")
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
		# R817：试玩版只列基线内的道具（图鉴 / 商店陈列 / 事件取货都读这里）
		if GameBuild.is_demo() and not DemoScope.allows_relic(id):
			continue
		out.append(_relics[id])
	out.sort_custom(func(a: RelicData, b: RelicData): return a.id < b.id)
	return out


func initial_ids() -> Array[int]:
	## 初始道具池（起点三选一；新道具加进 relics.json 后在此登记）。
	## R244：**鸡煲 6003 移出初始池**；R652：**该道具已整体删除**（数据/逻辑/测试/图标一并清掉）；
	##       新增「行囊」6030（+100 金币 + 一张木栅栏进卡组）。
	## R245：新增「勇气徽章」6031（精英首回合 / Boss 前两回合 +1 费）与
	##       「陶罐」6032（随机 2 件奖励道具 + 一张「罐子」诅咒进卡组）。
	## R341：新增「惊奇盒子」6047（获得即塞一张同名工事卡）与「洞窟绳」6048
	##       （Boss 以外的战斗可以逃跑，逃跑即失去）。两件都只在第一层起点三选一。
	# R745：新增「工具箱」6068（立即给一个随机工具、每进新层再给一个）。
	# R830：新增「首饰盒」6088（获得即随机一张史诗卡加入卡组）。
	# R835：新增「空故事书」6089（战斗开始时对全体敌人造成「页数」点伤害；
	#       每经过一个事件房 / 打赢一个首领 +1 页，页数进存档、跨战斗累计）→ 11 → 12 件。
	var out: Array[int] = [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068, 6088, 6089]
	return _demo_ids(out)


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
	## R813：**水晶骰子 6040 降回「一般」档**（店长口径）—— 它仍在奖励池内，
	##       只是不再受 legendary_chance 那道闸限制，改为跟普通道具一起摇。
	## R813：**水晶骰子 6040 降回「一般」档**（店长口径）—— 它仍在奖励池内，
	##       只是不再受 legendary_chance 那道闸限制，改为跟普通道具一起摇。
	## R315：新增「爆米花」6046（本回合没用技能指向敌人 → 下回合多抽 1 张），「一般」档。
	## R342：新增传奇「采集刀」6050（战斗胜利后多给一组卡牌奖励）与「火柴」6051
	##       （卡牌奖励界面 3 次刷新，一般档）。
	## R346：**剧情锁定**的道具（`RelicData.locked`）在解锁前不进奖励池 ——
	##       过闸的唯一口就是这里；初始池 / 二层池 / 事件池 / 角色赠品是显式 id 列表，不受影响。
	## R352：加「竖琴」6052（**一般档**，故事 1 解锁后发放；未解锁时被 `_drop_locked` 挡住）。
	## R383：加「骑士剑」6053（**一般档**，故事 2 解锁；同样被 `_drop_locked` 挡住）。
	## R534：加「三个机器人」6060（**一般档**，追加故事 profile5「通缉令」解锁；
	##       未解锁时同样被 `_drop_locked` 挡住）。
	## R440：加「暗动力」6054（**传奇档**，只进奖励池 —— 不进初始 / 二层 / 事件 / 角色池）。
	##       它是「拿副作用换强度」的那一类：每回合多抽一张，代价是不能跳过卡牌奖励、
	##       也不能在商店删卡；不锁剧情（谁都能摇到）。
	## R586：加「正义背刺」6064（**一般档**，故事 5「新的委托」解锁；未解锁同样被挡）。
	## R593：加「机械臂」6065（**一般档**，故事 6「轰鸣之后」解锁；未解锁同样被挡）。
	# R792：**猴爪 6066 与板甲 6070 / 兵 6071 / 墙砖 6072** 补进奖励池 ——
	#   猴爪原先在 relics.json 里标「奖励」、引擎也有机制，但不在本列表里，
	#   于是 `roll_reward_relic()` 永远摇不到它（孤儿道具）。这里一并收进来。
	#   三件新道具都是一般档、不锁剧情（进池即可摇到）。
	# R793：加「刺墙」6073（己方工事被攻击 → 攻击者受 5 伤）与「应急装甲」6074
	#   （玩家 HP 每回合最多受 20 伤）。同样一般档、不锁剧情。
	# R796：加「兔脚」6076（战后金币 +10、工具掉率 +10% 加算）与「钻头」6077
	#   （X 费卡 X ≥ 6 时翻倍）。都是「战后 / 出牌时」被动，一般档、不锁剧情。
	# R797：加「龟壳」6078（上回合没攻击过的己方单位受伤 -2，至少 1）。同样一般档。
	# R805：加「蜂蜜」6079（所有己方盟友移动速度 +1）。一般档、不锁剧情。
	# R806：加「法术卷轴」6080（每场战斗第一次用技能卡 → 那张卡带「次元」的复制进手牌）。
	#   与蜂蜜同为战斗类被动、一般档、不锁剧情。
	# ⚠️ 这份 id 列表是**硬编码**的 —— 新增道具除了 relics.json 之外，
	#    必须在这里补登，否则 `reward_ids()` 抽不到它（R805 就是在这挂了一次）。
	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065, 6066,
			6070, 6071, 6072, 6073, 6074, 6076, 6077, 6078, 6079, 6080,
		6081, 6082, 6083, 6084]
	return _demo_ids(_filter_by_tier(_drop_locked(ids), tier))


func _demo_ids(ids: Array[int]) -> Array[int]:
	## R817：试玩版的内容基线过滤（道具侧的**唯一口**，与卡池的
	## `CardRepo.demo_allows()` 同一张表）。口径 =「修复跟着走、新增不跟着走」：
	## 老道具改效果 / 修 bug 用的是同一个 id，自动同步到试玩；新道具 id 不在
	## `demo_scope.json` 里，默认不进试玩。非试玩版原样返回（零行为变化）。
	if not GameBuild.is_demo():
		return ids
	var out: Array[int] = []
	for id: int in ids:
		if DemoScope.allows_relic(id):
			out.append(id)
	return out


func _drop_locked(ids: Array[int]) -> Array[int]:
	## R346：去掉「剧情还没解锁」的道具（未标记 locked 的照旧全留）。
	ProfileData.ensure_loaded()
	var out: Array[int] = []
	for id: int in ids:
		var r: RelicData = get_relic(id)
		if r != null and r.locked and not ProfileData.is_relic_unlocked(id):
			continue
		out.append(id)
	return out


func normal_reward_ids() -> Array[int]:
	## 奖励池里的「一般道具」（R383 起 18 件；竖琴 6052 / 骑士剑 6053 未解锁时各少 1 件）。
	return reward_ids(RelicData.TIER_NORMAL)


func legendary_reward_ids() -> Array[int]:
	## 奖励池里的「传奇道具」（R342 起 4 件：6040 水晶骰子 / 6044 储物箱 / 6045 lucky 7 /
	## 6050 采集刀；R391 起 5 件：**鸭嘴 6006 由一般升为传奇**。
	## R440 起 6 件：**暗动力 6054**（多抽一张的代价型道具）。
	## R810 起 7 件：**缺陷时钟 6084**（第 12 张牌结束回合、跳过敌方回合）。
	## R813 起 6 件：**水晶骰子 6040 降为一般档**（移出本池）。
	## R352 的竖琴 6052 是**一般档**，不在这里）。
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
	## 事件道具池（事件节点给予，如鸭鸭低语、一袋米抗几楼、鸭梨；
	## 不进初始/奖励池）。R244：苹果 6027 从奖励池挪进来（「苹果与医生」专属）。
	## R743：烤肉 6011 已从道具改成**工具**（7007，见 traps.json / RunState.BARBECUE_TOOL_ID）——
	## 它不再属于道具池的任何一类，这里必须拿掉，否则火焰熔炉 / 投入道具这类
	## 「按道具池取货」的地方会拿一个 relics.json 里根本不存在的 id。
	var out: Array[int] = [6010, 6012, 6019, 6027]
	return _demo_ids(out)


func layer2_ids() -> Array[int]:
	## 第二层起始道具池（只在第二层的起始节点三选一；
	## 不进第一层初始池 / 奖励池 / 事件池）。
	## R246：新增「兼修」6033（每回合 +1 费 + 奖励/商店放开职业）与
	##       「附魔大师」6034（每次休息随机附一个合规的随机附魔）。
	## R341：新增「鹿首标本」6049（每个我方回合开始：技能与场地伤害 +1，本场累计）。
	##       ⚠️ R503：原描述写「技能和陷阱类场地」，陷阱一档随卡删除，文案已改为「技能和场地」。
	## R375（用户口径）：**移除「附魔大师」6034** —— 不再出现在第二层的起始三选一里。
	##       道具定义仍留在 relics.json（旧存档读得动、图鉴照列、机制也还在），
	##       只是**不进任何池** → 新开一局拿不到它。
	## R514（用户口径）：**「鸭之低语」6010 进二层起始池** —— 它不再作为独立事件房出现
	##       （`game_layers.LAYERS[1].events` 已删 whisper），改由第二层起点的
	##       「卷卷三选一」给出。池子 9 件、`RunState._roll_relic_choice()` 仍随机抽 3 件，
	##       所以它每局约 3/9 的概率出现在选项里，而不是必出。
	## R509（用户口径）：**「记忆药水」6067 进二层起始池** —— 第二层起点的「卷卷三选一」给出，
	##       每次战斗开始自动打出一张效果卡。池子 8→9 件。
	## R822（店长口径）：这 9 件里 **4 件带鸭的（6010 / 6015 / 6017 / 6018）归属移到鸭绅士**。
	##       本函数仍返回**全量**（它是二层的权威名单）；实际发放走进
	##       `layer2_ids_for(host)` —— 遇到卷卷只出剩下的，遇到鸭绅士只出带鸭的。
	## R824（店长口径）：新增「鸭子闹钟」6085（第 2 回合 +1 费 + 抽 1 张；第 5 回合起技能 +1），
	##       归鸭绅士 → 全量 9→10 件，鸭绅士 4→5 件，卷卷仍是 5 件。
	## R826（店长口径）：新增「音乐盒」6086（每场战斗开始把 2 张随机音符加入卡组），
	##       归**卷卷**（不带鸭）→ 全量 10→11 件，卷卷 5→6 件，鸭绅士仍 5 件。
	## R829（店长口径）：音乐盒 6086 改为 3 种音符；新增「这是礼帽」6087（己方盟友/工事死亡
	##       → 洗回抽牌库 + 本局 -2 费 + 次元），归**鸭绅士** → 全量 11→12 件，鸭绅士 5→6 件。
	var out: Array[int] = [6014, 6015, 6016, 6017, 6018, 6033, 6049, 6010, 6067, 6085, 6086, 6087]
	return _demo_ids(out)


func duck_host_ids() -> Array[int]:
	## R822（店长口径）：**鸭绅士**的起始道具池 —— 「带鸭」的道具
	## （6010 鸭之低语 / 6015 鸭语耳环 / 6017 重鸭 / 6018 生蛋鸭 / 6085 鸭子闹钟）。
	## 归属整体移到鸭绅士这边：卷卷在场时这几件不再出现；
	## 鸭绅士的三选一从这份名单里抽 3 件（不重复）。
	## R824：加「鸭子闹钟」6085 → 4 件变 5 件（仍是抽 3，不是必出）。
	## R829：加「这是礼帽」6087 → 5 件变 6 件（仍是抽 3，不是必出）。
	## 判据只有「在不在这份名单里」一条 —— 场景 / 存档 / 测试都不许另写一遍。
	var out: Array[int] = [6010, 6015, 6017, 6018, 6085, 6087]
	return _demo_ids(out)


func layer2_ids_for(host: int) -> Array[int]:
	## R822：按「这一局第二层起点遇到谁」取起始池。
	##   host = 1（鸭绅士）→ 带鸭的那几件（R829 起 6 件：多一件礼帽 6087）；
	##   host = 0（卷卷）  → 全量减去带鸭的（R826 起 6 件：多一件音乐盒 6086）。
	## R824（店长口径：「试玩版改为给鸭绅士」）：**删掉 R822 的试玩版例外** ——
	##   鸭绅士进试玩之后，那 4 件有人发放了，卷卷池不该再兜全量（否则同两件道具
	##   在两位主持人那里都能抽到，归属就白分了）。试玩版与正式版走同一条分流。
	##   ⚠️ 试玩版池子由 `_demo_ids()` 按 demo_scope.json 裁：6085 / 6086 都已进基线
	##      （道具档口径是「全部登陆」），所以试玩版两位主持人各 6 / 6 件，与正式版一致。
	if host != 0:
		return duck_host_ids()
	var all_ids := layer2_ids()
	var duck := duck_host_ids()
	var out: Array[int] = []
	for id: int in all_ids:
		if not duck.has(id):
			out.append(id)
	return out


func start_ids_for_layer(layer: int, host := 0) -> Array[int]:
	## 该层「起始节点三选一」的道具池：第一层 = 初始池；第二层 = 二层起始池（按 host 分流）。
	## `host` 省略时按卷卷算 —— 老调用点（出图 / 测试）行为不变。
	match layer:
		2:
			return layer2_ids_for(host)
	return initial_ids()


func class_ids() -> Array[int]:
	## 角色赠品道具（选定角色时由 RunState.start_run 发放，如森林精魄的「荒野形态」6022）。
	## 这一池**不参与任何随机抽取**：起点三选一 / 奖励掉落 / 事件 / 二层起始都不含它。
	var out: Array[int] = [6022, 6023, 6025]
	return _demo_ids(out)


func roll_reward(rng: RandomNumberGenerator, tier: String = "") -> int:
	## 从奖励池随机抽一个道具 id（奖励界面上架/掉落用）。
	## R289：`tier` 传 "一般" / "传奇" 可只在该档里抽；空串 = 全池（旧行为）。
	var pool := reward_ids(tier)
	if pool.is_empty():
		return -1
	return pool[rng.randi() % pool.size()]
