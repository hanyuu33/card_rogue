class_name RunState
extends RefCounted
## 肉鸽单次闯关（run）的玩家状态 —— 跨战斗保留。
## 玩家拥有「最大生命」和「当前生命」：战斗中受伤结算在局内，
## 战斗胜利后把剩余生命写回这里，下一场接着用。
## 事件（如「休息」）也作用在这份状态上。
##
## 肉鸽流程：start_run 生成地图与初始卡组 → 战斗/休息/事件节点推进 →
## 胜利领取卡牌奖励（加入卡组）→ 打败 Boss 通关；失败回标题。
## 每场战斗写入战斗记录（卡组内容 / 是否失败 / 最终血量），
## 持久化在 user://battle_records.json，跨 run 保留。

const RECORDS_PATH := "user://battle_records.json"
const RECORDS_KEEP := 200          # 最多保留的记录条数

static var max_hp: int = 50      # 玩家最大生命
static var hp: int = 50          # 玩家当前生命（跨战斗保留）

# ---- run 进度 ----
static var run_active := false               # 是否在肉鸽 run 中（false = 单关/演示模式）
static var deck_ids: Array[int] = []         # 当前卡组（卡 id，可重复）
## ⚠️ 卡组的「实际费用」**不存表**（R110 鸭鸭工匠）：
## 铁栅栏 9072 只要进了卡组就一定是工匠锻造出来的（没有任何别的途径把它放进卡组），
## 所以它的费用可以**现算** —— 见 `deck_cost_at_index()`。
## 为什么不用平行数组：那玩意儿要跟着删卡 / 换卡 / 鸭血复制一起搬，
## 漏一处就整表错位；现算则天然不可能错位。
static var map_columns: Array = []           # RogueMap.generate 的结果（起点 + 12 层 + Boss）
static var current_layer := GameLayers.LAYER_DEFAULT  # 本局地图所属的层（第一层）
static var current_node_id := -1             # 玩家所在节点（-1 = 还没出发）
static var cleared_ids: Array = []           # 已完成的节点 id
static var pending_level: Dictionary = {}    # 即将进入的战斗关卡（地图 → 战斗）
static var pending_node: Dictionary = {}     # 即将进入的地图节点（地图 → 休息/事件）
static var reward_context := ""              # 奖励来源："battle" / "event" / ""（演示）
static var reward_type := "normal"           # 奖励类型："normal" / "boss"（概率构成不同）
static var pending_event := ""               # 即将进入的事件子类型："treasure" / "whisper"
static var pending_deck_edit := ""           # 事件「遗忘之泉」的待办卡组操作："" / "delete"（删一张卡）
static var reward_kinds: Array[String] = []  # 本次卡牌奖励的卡类限制（空 = 不限制；如 ["效果","技能"]）
static var battle_log: Array = []            # 本局战斗记录（与持久化文件同步追加）
static var player_class: String = "森林精魄"   # 本局所选角色（PlayerClass.ids() 之一）
static var battle_wins := 0                   # 本局已胜利的普通战斗数（前 2 场简单）
static var elite_wins := 0                   # 本局已胜利的精英战斗数（前 2 场简单）
static var used_levels: Array = []           # 本局已进入的关卡名（尽量不重复）
static var boss_pick: Dictionary = {}       # 本局摇定的本层 Boss 关卡（R63：同层可能有多个 Boss；
									# 开局摇一次，地图名牌与实际进入读同一份）
# 彩蛋 Boss（R73）：第一层摇到「恶魔鸭」时按 REVENGE_TRIGGER_CHANCE 置位，
# 下一层（第二层）摇 Boss 时被顶替成「恶魔鸭（复仇）」并复位。
# **一次性**：消费后立刻置回false —— 免得第三层（若以后有）继续顶替。
static var revenge_pending := false
const REVENGE_TRIGGER_CHANCE := 0.5         # 50%
const DEMON_DUCK_BOSS_NAME := "恶魔鸭"       # 第一层触发条件：摇中的 boss 名必须是它

# ---- 难度档位（R47）：标题界面选择，默认 0（宽松） ----
# 0 = 宽松：每场战斗**胜利**回复 3 点生命；休息回复 40% 最大生命。
# 1 = 标准：战斗结束不回血；休息回复 40% 最大生命。
# 2 = 困难：战斗结束不回血；休息回复 25% 最大生命（= 加入难度档位之前的实机行为）。
# 档位只在标题界面改，不属于 run 状态（end_run / start_run 都不动它）。
static var difficulty: int = 0
const DIFFICULTY_COUNT := 3
const DIFFICULTY_NAMES: Array[String] = ["宽松", "标准", "困难"]
const DIFFICULTY_NOTES: Array[String] = [
	"每场战斗胜利回复 3 生命；休息回复 40% 最大生命。",
	"战斗结束不回血；休息回复 40% 最大生命。",
	"战斗结束不回血；休息回复 25% 最大生命（与加入难度档位前完全一致）。",
]
const DIFFICULTY_BATTLE_HEAL: Array[int] = [3, 0, 0]      # 战斗胜利回复量
const DIFFICULTY_REST_PCT: Array[float] = [0.40, 0.40, 0.25]  # 休息回复百分比

# ---- 录像（R46）：run 层唯一随机源 ----
static var run_seed: int = 0                 # 本局种子（录像回放的根：run 层全部随机由它派生）
static var run_rng := RandomNumberGenerator.new()   # 本局随机源（地图/道具/关卡/掉落/五换一）

# ---- 道具 ----
static var relics: Array[int] = []           # 已拥有的道具 id（跨战斗保留）
static var skipped_relics: Array[int] = []   # 奖励掉落里被「跳过」的道具 id：本局后续不再随机出来
static var relic_choice: Array[int] = []     # 起点三选一的候选（选定后清空）
static var pending_relic := -1               # 等待卡组选择的即时道具 id（-1 = 无）
static var pending_relic_drop := -1          # 精英/Boss 掉落的道具 id（-1 = 无，领取后清空）
static var duck_revive_chance := 100         # 叠加态的鸭（6013）：当前复活概率（每次复活 -25）

# 事件道具 id
const WHISPER_RELIC_ID := 6010   # 鸭之低语（事件节点获得）
const BARBECUE_RELIC_ID := 6011  # 烤肉（休息处获得，进入 Boss 战时消耗）
const RICE_RELIC_ID := 6012      # 一袋米抗几楼（鸭之凝视事件获得）
const STACK_DUCK_RELIC_ID := 6013  # 叠加态的鸭（复活道具，奖励池）
const PEAR_RELIC_ID := 6019      # 鸭梨（鸭梨山大事件获得；战斗内每次 HP 受伤 → 最大生命 +1）
const ARCANE_CHARM_RELIC_ID := 6020  # 奥秘护符（奥秘之泉事件 / 奖励池；每回合第一张效果牌费用 -1）
const WILD_FORM_RELIC_ID := 6022      # 荒野形态（森林精魄角色赠品；不入任何随机池）
const DUCK_REVIVE_STEP := 25     # 每次复活后降低的百分点

# 鸭血（6024，奖励道具）：获得时从卡组里**最多选 2 张卡各复制一份**加入卡组。
# 「最多 2 张」的上限只有这一处，界面按它显示按钮与提示，别在界面里另写死数字。
const DUCK_BLOOD_RELIC_ID := 6024
const DUCK_BLOOD_MAX := 2

# 二层事件「绝赞五换一」的奖励卡（cards.json）：5 费 5/25 程1 速1，须弃 4 张手牌才能使用
const HERO_CARD_ID := 9023

# 事件「鸭鸭工匠」（R110）：把卡组里选中的那张卡变成一张「铁栅栏」（FENCE_CARD_ID）。
# 产物费用**统一改成 2 费**（卡面铁栅栏本身是 0 费，但工匠产物按 2 费计）。
const FENCE_CARD_ID := 9072
const SMITH_COST := 2                 # 产物铁栅栏的费用（覆盖卡面的 0 费）

# 即时道具
const SOURCE_POWER_ID := 6002     # 源数之力（改造卡组中的一张卡）
const SOURCE_POWER_HP_COST := 5   # 源数之力的代价：失去 5 点最大生命


static func reset(new_max := 50) -> void:
	## 重置生命（保留 run 进度——单测与旧流程兼容）。
	max_hp = new_max
	hp = new_max


static func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


static func heal(amount: int) -> int:
	## 回复指定生命，上限为最大生命。返回实际回复量。
	var gained: int = mini(max_hp - hp, maxi(0, amount))
	hp += gained
	return gained


# ---- 难度档位（R47）----

static func _diff() -> int:
	## 当前档位（越界兜底）。
	return clampi(difficulty, 0, DIFFICULTY_COUNT - 1)


static func set_difficulty(d: int) -> void:
	## 标题界面选择难度档位（0 / 1 / 2）。
	difficulty = clampi(d, 0, DIFFICULTY_COUNT - 1)


static func difficulty_name() -> String:
	return DIFFICULTY_NAMES[_diff()]


static func difficulty_note() -> String:
	## 该档位的完整效果说明（标题界面展示用）。
	return DIFFICULTY_NOTES[_diff()]


static func battle_win_heal() -> int:
	## 战斗**胜利**后的自动回复量（难度 0 = 3 点，其余档位 = 0）。
	return DIFFICULTY_BATTLE_HEAL[_diff()]


static func rest_pct() -> float:
	## 本档位的休息回复百分比（0 / 1 档 = 0.40，2 档 = 0.25）。
	return DIFFICULTY_REST_PCT[_diff()]


static func rest_heal_amount() -> int:
	## 休息事件的回复量 = 最大生命 × 本档位百分比（向上取整），再受上限封顶。
	return ceili(max_hp * rest_pct())


static func rest() -> int:
	## 「休息」事件：按本局难度档位恢复最大生命的 40%（0 / 1 档）或 25%（2 档），不超过上限。
	return heal(rest_heal_amount())


static func lose_max_hp(amount: int) -> int:
	## 失去指定点数的最大生命（「源数之力」的代价）：
	## 当前生命同步下降相同的点数，且不超过新的上限、不低于 0；
	## 至少保留 1 点最大生命（否则玩家会直接暴毙）。返回实际失去的点数。
	var lost: int = mini(maxi(0, amount), maxi(0, max_hp - 1))
	if lost <= 0:
		return 0
	max_hp -= lost
	hp = clampi(hp - lost, 0, max_hp)
	return lost


# ------------------------------------------------------------ run 生命周期

static func start_run(map: Array, layer := GameLayers.LAYER_DEFAULT,
		cid: String = "") -> void:
	## 新 run：满血、初始卡组、载入地图、定位起点（第 0 列唯一节点）。
	## layer = 本局地图所属的层（地图上所有战斗/事件都从这一层的内容池里取）。
	## map 传空数组时用本局种子现生成（真实流程 = 角色选择场景这样进来）。
	reset()
	# run 种子：回放时由 ReplayLog 预先写好（不重摇）；正常开局时新摇一个
	if not (ReplayLog.playing and run_seed != 0):
		run_seed = randi()
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	run_active = true
	player_class = cid if cid != "" else PlayerClass.default_id()
	map_columns = map if not map.is_empty() else RogueMap.generate(run_rng, layer)
	current_layer = layer
	cleared_ids = []
	battle_log = []
	pending_level = {}
	pending_node = {}
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	# 开局卡组 = 公共部分 + 2 张角色基础盟友（森林精魄 → 树人；暗影刺客 → 幽影）
	# + 角色专属卡（森林精魄 → 熊 8004；暗影刺客 → 突袭 9086）。见 PlayerClass.start_deck_ids。
	deck_ids = PlayerClass.start_deck_ids(player_class)
	battle_wins = 0
	elite_wins = 0
	used_levels = []
	# 本层 Boss 开局摇定（同层多个 Boss 时随机；走 run_rng → 录像可复现）
	# 彩蛋 Boss（R73）：开新 run 先清pending，再摇 —— _roll_boss 内部会按
	# 「第一层是否摇中恶魔鸭」置位。顺序不能反，否则会用到上一局残留的 pending。
	revenge_pending = false
	boss_pick = _roll_boss(current_layer)
	relics = []
	skipped_relics = []
	pending_relic = -1
	pending_relic_drop = -1
	duck_revive_chance = 100
	pending_event = ""
	# 角色赠品道具（森林精魄 → 荒野形态 6022）：不入随机池，也不占起点三选一的名额
	var cls_relic := PlayerClass.relic_of(player_class)
	if cls_relic > 0:
		gain_relic(cls_relic)
	# 起点三选一：从初始道具池随机抽 3 个不重复的
	relic_choice = _roll_relic_choice()
	if not map.is_empty() and not map[0].is_empty():
		current_node_id = int(map[0][0]["id"])
	else:
		current_node_id = -1


static func end_run() -> void:
	## run 结束（通关或失败回标题）：清掉 run 标记（记录与持久化文件保留）。
	run_active = false
	player_class = PlayerClass.default_id()
	deck_ids = []
	map_columns = []
	current_layer = GameLayers.LAYER_DEFAULT
	current_node_id = -1
	cleared_ids = []
	pending_level = {}
	pending_node = {}
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	# 彩蛋 Boss（R73）：run 结束必须复位，否则上一局触发的 pending 会漏进下一局，
	# 让新玩家莫名其妙在第二层撞见恶魔鸭（复仇）。
	revenge_pending = false
	boss_pick = {}
	reward_type = "normal"
	battle_wins = 0
	elite_wins = 0
	used_levels = []
	relics = []
	relic_choice = []
	skipped_relics = []
	pending_relic = -1
	pending_relic_drop = -1
	duck_revive_chance = 100
	pending_event = ""


static func advance_layer(layer: int) -> int:
	## 进入下一层（打败上一层 Boss 后由 battle_scene 调用）：
	##   * **恢复所有生命**（第二层起始节点：满血重新出发）；
	##   * 生成本层地图（RogueMap.generate(rng, layer)）；
	##   * 掷本层起始道具三选一（第一层 = 初始池，第二层 = 二层起始池）；
	##   * 重置层内进度（战斗计数 / 选关记录 / 已清节点），**卡组与道具跨层保留**。
	## 返回本层起点节点 id（-1 = 地图为空）。
	max_hp = maxi(1, max_hp)
	hp = max_hp                      # 二层起始：恢复所有生命
	current_layer = layer
	battle_wins = 0
	elite_wins = 0
	used_levels = []
	# 本层 Boss 开局摇定（换层要重摇：第二层只有机械巨鸭）
	boss_pick = _roll_boss(layer)
	cleared_ids = []
	pending_level = {}
	pending_node = {}
	pending_event = ""
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	reward_type = "normal"
	# 本层地图用本局种子续摇（同一 run 的随机链条：start_run → 各次 advance_layer）
	map_columns = RogueMap.generate(run_rng, layer)
	relic_choice = _roll_relic_choice()
	if not map_columns.is_empty() and not (map_columns[0] as Array).is_empty():
		current_node_id = int(map_columns[0][0]["id"])
	else:
		current_node_id = -1
	return current_node_id


# ---- 道具 ----


static func _roll_boss(layer: int) -> Dictionary:
	## 从「本层 Boss 池」摇一个。走 run_rng → 录像回放可复现。
	## 池里只有一个（第二层）时直接返回它，不消耗随机源。
	##
	## **彩蛋 Boss（R73）**：摇第一层的Boss 时，若摇中「恶魔鸭」→ 50% 概率
	## 置 `revenge_pending`；之后**第二层的 boss 被顶替成「恶魔鸭（复仇）」**。
	## 判定写在这一处（而不是 boss 分支的调用点），是为了让
	## ① `boss_pick`（地图 Boss 名牌的数据源）② `next_level("boss")` 实际进入的关卡
	## 读的是同一份结果 —— 否则地图上写机械巨鸭、进去却是恶魔鸭（复仇）。
	## 走 run_rng → 录像回放可复现。
	if layer == GameLayers.LAYER_DEFAULT:
		var first := _pick_from_boss_pool(layer)
		if str(first.get("name", "")) == DEMON_DUCK_BOSS_NAME \
				and run_rng.randf() < REVENGE_TRIGGER_CHANCE:
			revenge_pending = true
		return first
	# 第二层：彩蛋顶替优先（顶替后不再消耗随机源 —— 池里本来也只有机械巨鸭一只）。
	if revenge_pending:
		revenge_pending = false
		return GameLevels.revenge_boss()
	return _pick_from_boss_pool(layer)


static func _pick_from_boss_pool(layer: int) -> Dictionary:
	## 纯「从本层 Boss 池随机抽一只」，不含彩蛋逻辑（供 _roll_boss 分派）。
	var pool := GameLevels.boss_pool(layer)
	if pool.is_empty():
		return GameLevels.boss_level(layer)
	if pool.size() == 1:
		return pool[0]
	return pool[run_rng.randi() % pool.size()]


static func _roll_relic_choice() -> Array[int]:
	## 从「本层起始道具池」随机抽 3 个不重复的（池小于 3 时全给）：
	## 第一层 = 初始道具池（6001~6004）；第二层 = 二层专属起始道具池（6014~6018）。
	var pool := RelicRepo.load_json().start_ids_for_layer(current_layer)
	var out: Array[int] = []
	var bag: Array[int] = pool.duplicate()
	while out.size() < 3 and not bag.is_empty():
		out.append(bag.pop_at(run_rng.randi() % bag.size()))
	return out


static func choose_start_relic(id: int) -> void:
	## 起点三选一：收下所选道具（relic_pick 场景调用）。
	gain_relic(id)
	relic_choice = []


static func gain_relic(id: int) -> void:
	## 获得道具：登记进列表；即时类当场结算。
	if relics.has(id):
		return
	relics.append(id)
	var relic := RelicRepo.load_json().get_relic(id)
	if relic == null:
		return
	match relic.id:
		6001:   # 类固醇：最大生命 +6（当前生命同 +6）
			max_hp += 6
			hp += 6
		6002:   # 源数之力（SOURCE_POWER_ID）：先失去 5 点最大生命，再进入卡组选择
			lose_max_hp(SOURCE_POWER_HP_COST)
			pending_relic = relic.id
		6004:   # 失忆药水：需要玩家再选一张卡
			pending_relic = relic.id
		DUCK_BLOOD_RELIC_ID:   # 鸭血：从卡组里最多选 2 张各复制一份（进卡组编辑场景）
			pending_relic = relic.id
		6017:   # 重鸭（二层起始）：拾起时最大生命 +6（当前生命同 +6）
			max_hp += 6
			hp += 6


static func has_relic(id: int) -> bool:
	return relics.has(id)


static func offer_relic_drop(node_type: String) -> int:
	## 精英 / Boss 战斗胜利：从奖励池随机掉落一个道具（不与已拥有的、
	## 以及本局曾被「跳过」的重复 —— 跳过表示不想要，后续不再随机出来）。
	## 掉落登记到 pending_relic_drop，由奖励界面领取；没有可掉落的返回 -1。
	if node_type != "elite" and node_type != "boss":
		return -1
	var pool: Array[int] = []
	for id in RelicRepo.load_json().reward_ids():
		if not relics.has(id) and not skipped_relics.has(id):
			pool.append(id)
	if pool.is_empty():
		return -1
	pending_relic_drop = pool[run_rng.randi() % pool.size()]
	return pending_relic_drop


static func claim_relic_drop() -> int:
	## 领取掉落的道具（奖励界面调用）。返回道具 id（无掉落返回 -1）。
	if pending_relic_drop < 0:
		return -1
	var id := pending_relic_drop
	pending_relic_drop = -1
	gain_relic(id)
	return id


static func skip_relic_drop() -> int:
	## 跳过掉落的道具（奖励界面调用）：放弃本次掉落并登记 ——
	## 本局后续的随机掉落 / 开箱都不会再摇出它。返回道具 id（无掉落返回 -1）。
	if pending_relic_drop < 0:
		return -1
	var id := pending_relic_drop
	pending_relic_drop = -1
	if not skipped_relics.has(id):
		skipped_relics.append(id)
	return id


static func roll_reward_relic() -> int:
	## 宝箱层开箱：随机一个「尚未拥有、也未被跳过」的奖励道具 id（没有时返回 -1）。
	var pool: Array[int] = []
	for id in RelicRepo.load_json().reward_ids():
		if not relics.has(id) and not skipped_relics.has(id):
			pool.append(id)
	if pool.is_empty():
		return -1
	return pool[run_rng.randi() % pool.size()]


static func relic_state_note(id: int) -> String:
	## 道具的动态状态说明（叠加态的鸭：当前复活概率）；无动态状态时返回 ""。
	if id == STACK_DUCK_RELIC_ID and relics.has(STACK_DUCK_RELIC_ID):
		return "当前复活概率 %d%%。" % duck_revive_chance
	return ""


static func consume_barbecue() -> int:
	## 道具「烤肉」（6011）：进入 Boss 战时自动消耗 → 回复 25% 最大生命
	## （向上取整，不超过上限）。返回实际回复量；未持有返回 -1。
	## 消耗后道具离开道具栏，因此休息处可以再次烤制。
	if not relics.has(BARBECUE_RELIC_ID):
		return -1
	relics.erase(BARBECUE_RELIC_ID)
	return heal(ceili(max_hp * 0.25))


static func delete_deck_card(index: int) -> bool:
	## 失忆药水：删除卡组中第 index 张卡。成功返回 true。
	if index < 0 or index >= deck_ids.size():
		return false
	deck_ids.remove_at(index)
	pending_relic = -1
	return true


static func transform_deck_card(repo: CardRepo, index: int) -> Dictionary:
	## 源数之力：把卡组中第 index 张卡变成一张随机奖励卡。
	## 返回 {ok, old_id, new_id}（供界面/日志展示）。
	if index < 0 or index >= deck_ids.size():
		return {"ok": false, "old_id": 0, "new_id": 0}
	var old_id: int = deck_ids[index]
	# 修复（实机体验）：必须用本局 run_rng —— 否则走全局随机，破坏 R46 录像回放的确定性
	var rolled := CardReward.roll(repo, "normal", 1, run_rng)
	var new_id: int = rolled[0].id if not rolled.is_empty() else old_id
	deck_ids[index] = new_id
	pending_relic = -1
	return {"ok": true, "old_id": old_id, "new_id": new_id}

static func smith_deck_card(index: int) -> Dictionary:
	## 事件「鸭鸭工匠」：把卡组中第 index 张卡**变成一张铁栅栏**。
	##
	## 费用口径（用户确认）：产物是「**2 费**铁栅栏」—— 卡面铁栅栏是 0 费，但这里
	## 统一按 SMITH_COST(=2) 记。原卡的费用不再影响结果（反正已经被替换掉了）。
	##
	## ⚠️ 为什么不直接改卡库：卡库是**共享实例**，改它会连本局之外都污染。
	## 所以这里只换 id；「2 费」由 `deck_cost_at_index()` **现算**出来
	## （卡组里的铁栅栏 = 工匠锻造的 = SMITH_COST 费），不存平行数组、不会错位。
	## 纯确定性操作，不走随机源 → 录像回放天然一致。
	if index < 0 or index >= deck_ids.size():
		return {"ok": false, "old_id": 0, "new_id": 0}
	var old_id: int = deck_ids[index]
	deck_ids[index] = FENCE_CARD_ID
	pending_deck_edit = ""
	# 「2 费」不用在这里记 —— `deck_cost_at_index()` 会把卡组里的铁栅栏一律算成 SMITH_COST。
	return {"ok": true, "old_id": old_id, "new_id": FENCE_CARD_ID, "cost": SMITH_COST}


static func deck_cost_at_index(i: int) -> int:
	## 卡组里第 i 张卡的**实际费用**。
	## 规则：**铁栅栏（FENCE_CARD_ID）进了卡组 = 工匠锻造的 → 一律按 SMITH_COST(2) 计**
	## （卡面是 0 费）；其余卡一律用卡库原价。
	## ⚠️ **现算、不存表**：现算不可能与 deck_ids 错位（删卡 / 换卡 / 鸭血复制都天然正确）。
	## 代价是「铁栅栏进卡组就按 2 费算」成了硬规则 —— 9072 目前**只有**鸭鸭工匠能放进
	## 卡组（栅栏修复术只把它放到**场上**），所以规则成立；将来若新增别的渠道把铁栅栏
	## 塞进卡组，要回来改这里。
	if i < 0 or i >= deck_ids.size():
		return 0
	var id: int = deck_ids[i]
	if id == FENCE_CARD_ID:
		return SMITH_COST
	var c := CardRepo.load_json().get_card(id)
	return c.cost if c != null else 0


static func duplicate_deck_cards(repo: CardRepo, indices: Array) -> Dictionary:
	## 鸭血（DUCK_BLOOD_RELIC_ID）：把选中的每张卡**各复制一份**加入卡组（原卡保留）。
	## 最多 DUCK_BLOOD_MAX 张 —— 上限在这里强制，界面只是照它显示，超出的 silently 丢弃。
	## 返回 {ok, copied: [{id, name}, ...]}：ok = 至少复制了一张（一张都不选也算正常完成）。
	##
	## ⚠️ **下标必须在复制前全部校验完**：复制是 append，不改已有下标，所以边校验边 append
	## 是安全的；但仍先做一遍去重 + 越界过滤，避免同一个下标被选中两次而复制出两张同样的。
	## 用 `run_rng` ？不需要 —— 纯确定性操作，录像回放天然一致。
	var picked: Array[int] = []
	for v: Variant in indices:
		var i := int(v)
		if i >= 0 and i < deck_ids.size() and not picked.has(i):
			picked.append(i)
	var copied: Array = []
	for i2: int in picked:
		if copied.size() >= DUCK_BLOOD_MAX:
			break
		var id: int = deck_ids[i2]
		var c := repo.get_card(id)
		copied.append({"id": id, "name": c.card_name if c != null else str(id)})
		deck_ids.append(id)     # 副本追加到卡组末尾（原卡位置不动）
	pending_relic = -1
	return {"ok": not copied.is_empty(), "copied": copied}


static func deck_distinct_names(repo: CardRepo) -> int:
	## 卡组中**不同卡名**的数量（同名不同 id 只算一种，如骷髅兵 1053/1054/1055）。
	var names := {}
	for id in deck_ids:
		var c := repo.get_card(id)
		names[c.card_name if c != null else str(id)] = true
	return names.size()


static func can_trade_five(repo: CardRepo) -> bool:
	## 二层事件「绝赞五换一」的前提：卡组里至少有 5 种不同名的卡。
	return deck_distinct_names(repo) >= 5


static func trade_five_for_one(repo: CardRepo) -> Dictionary:
	## 二层事件「绝赞五换一」：删除卡组中 **5 张不同名**的卡（每种名各删 1 张），
	## 再把一张「英雄」（9023）加入卡组。
	## ⚠️ 抽样是**按同名张数加权**的：某个名字在卡组里有 k 张，它被选中的概率就是 k 倍
	##（R110；原为等概率）。理由：卡组里堆同名的废牌本就是最大的负担，该让它有机会被换掉。
	## 返回 {ok, removed: [{id, name}, ...], new_id}；不同名的卡不足 5 种 → ok=false 且卡组不变。
	var by_name := {}     # 卡名 -> 该名在 deck_ids 里的所有下标
	for i in deck_ids.size():
		var c := repo.get_card(deck_ids[i])
		var nm: String = c.card_name if c != null else str(deck_ids[i])
		if not by_name.has(nm):
			by_name[nm] = []
		var arr: Array = by_name[nm]
		arr.append(i)
		by_name[nm] = arr
	if by_name.size() < 5:
		return {"ok": false, "removed": [], "new_id": 0}
	# 2026-10-08（R110）：**同名张数越多越容易被选中** ——
	# 原实现是 `run_rng.randi() % bag.size()` 的等概率抽样；改成按「该名在卡组里的张数」加权。
	# 为什么这么设计：卡组里堆了 5 张同名的废牌，本来就是这局最大的负担，
	# 让人家有机会把它换掉才合理；等概率等于让「最该被处理的那张」和「只抽到一张的」一样难被选中。
	# 权重 = **该名张数的平方根**（isqrt(k*1000)），不是线性 k。
	# 为什么不直接用 k：这里抽的是「6 种里选 5 种」，线性权重下只要某名权重够大就**必被选中**
	# （实测权重 4/11 时命中率 0.97）—— 概率弹性消失，玩家感受到的是"锁定"而不是"概率变高"。
	# 平方根把 4 张压成 2 倍于 1 张：重复卡确实更容易被换掉，但不会被抽 5/6 的结构锁死。
	# 用自写的整数平方根 _isqrt(k*1000)（GDScript 没有内置 isqrt，也不是为了跨平台确定性）。
	# ⚠️ 必须走 run_rng（不能全局随机），否则破坏 R46 录像回放的确定性。
	var pool_names: Array = by_name.keys()
	var weights: Array[int] = []
	for nm_w in pool_names:
		weights.append(_isqrt(int((by_name[nm_w] as Array).size()) * 1000))
	var picked: Array = []
	for _k in 5:
		var total_w := 0
		for w in weights:
			total_w += w
		# 加权抽一个：落在 weights 的累积区间里 → 命中对应名字 → 从候选池删掉它并同步权重
		var roll := run_rng.randi_range(0, total_w - 1)
		var acc := 0
		var chosen := 0
		for wi in weights.size():
			acc += int(weights[wi])
			if roll < acc:
				chosen = wi
				break
		picked.append(pool_names[chosen])
		pool_names.remove_at(chosen)
		weights.remove_at(chosen)
	var drop_idx: Array[int] = []
	for nm2 in picked:
		var arr2: Array = by_name[nm2]
		drop_idx.append(int(arr2[0]))     # 同名多张时只删其中一张
	drop_idx.sort()
	drop_idx.reverse()                    # 从大到小删，避免下标位移
	var removed: Array = []
	for i2: int in drop_idx:
		var c2 := repo.get_card(deck_ids[i2])
		removed.append({"id": deck_ids[i2],
				"name": c2.card_name if c2 != null else str(deck_ids[i2])})
		deck_ids.remove_at(i2)
	deck_ids.append(HERO_CARD_ID)
	return {"ok": true, "removed": removed, "new_id": HERO_CARD_ID}


## 整数平方根（floor(sqrt(n)))——GDScript **没有**内置 isqrt()，这里自己实现。
## 纯整数运算（不用 sqrtf），保证同一输入永远得同一结果 —— 回放录像依赖这个确定性。
## 算法：从 0 开始每次加 1 直到 x*x > n；n 很小（权重 = 张数×1000 ≤ 几十千），够快。
static func _isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := 0
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x


static func _find_node(node_id: int) -> Dictionary:
	for col_nodes in map_columns:
		for node in col_nodes:
			if int(node["id"]) == node_id:
				return node
	return {}


static func current_node() -> Dictionary:
	## 玩家当前所在节点。
	for col_nodes in map_columns:
		for node in col_nodes:
			if int(node["id"]) == current_node_id:
				return node
	return {}


static func available_nodes() -> Array:
	## 从当前节点可以走到的下一列节点（起点前 = 第 0 列节点）。
	if current_node_id < 0:
		return (map_columns[0] if not map_columns.is_empty() else [])
	for col_nodes in map_columns:
		for node in col_nodes:
			if int(node["id"]) == current_node_id:
				var out: Array = []
				for nid in node["next"]:
					var n := _find_node(int(nid))
					if not n.is_empty():
						out.append(n)
				return out
	return []


static func advance(node_id: int) -> void:
	## 走到一个节点（完成当前节点并移动）。
	if current_node_id >= 0 and not cleared_ids.has(current_node_id):
		cleared_ids.append(current_node_id)
	current_node_id = node_id


static func complete_current() -> void:
	## 当前节点内容完成（战斗胜利 / 休息 / 事件）。
	if current_node_id >= 0 and not cleared_ids.has(current_node_id):
		cleared_ids.append(current_node_id)


# ---- 动态难度（战斗节点不预写关卡，进入时按进度决定） ----

static func on_battle_won(node_type: String) -> void:
	## 战斗胜利后累计同类胜场：决定后续难度（前 2 场简单、之后困难）。
	## 「事件节点遭遇怪物」（node_type = "event"）**同样按普通战斗计数**（R47 修复）：
	## 否则这类战斗永远停在「简单」档，也不消耗「前 2 场简单」的额度 →
	## 玩家可以靠怪物事件反复刷简单战斗。
	if node_type == "battle" or node_type == "event":
		battle_wins += 1
	elif node_type == "elite":
		elite_wins += 1


static func node_layer(node: Dictionary) -> int:
	## 节点所属的层（节点自带 layer；缺省时按本局地图的层处理）。
	return int(node.get("layer", current_layer))


static func next_level(node: Dictionary) -> Dictionary:
	## 进入战斗节点时决定具体关卡 —— 只从「该节点所属层」的关卡池里抽
	## （第一层的关卡不会跑到别的层，别的层的关卡也不会出现在第一层）：
	## 前 2 场普通战斗 = 普通敌人-简单，之后 = 普通敌人-困难；
	## 前 2 场精英 = 精英敌人-简单，之后 = 精英敌人-困难；Boss 固定。
	## 同一分级池内尽量不重复（本局用完一轮后允许循环复用）。
	var layer := node_layer(node)
	match str(node["type"]):
		"battle", "event":
			# event 只在地图事件节点遭遇怪物（event_kind=monster）时走到这里，
			# 按普通战斗处理。
			var tier: int = GameLevels.TIER_NORMAL_EASY if battle_wins < 2 \
					else GameLevels.TIER_NORMAL_HARD
			return _pick_level(_layer_tier_pool([tier], layer))
		"elite":
			var tier2: int = GameLevels.TIER_ELITE_EASY if elite_wins < 2 \
					else GameLevels.TIER_ELITE_HARD
			return _pick_level(_layer_tier_pool([tier2], layer))
		"boss":
			# Boss 可能同层有多个（如第一层：远古虚骨龙 / 恶魔鸭）。
			# 开局（start_run / advance_layer）已用run_rng 摇好并存在 boss_pick，
			# 这里直接用它 —— 地图名牌读的是同一份，**地图上写的就是真会遇到的那只**。
			if not boss_pick.is_empty():
				return boss_pick
			return GameLevels.boss_level(layer)
	return {}


static func _layer_tier_pool(tiers: Array, layer: int) -> Array[Dictionary]:
	## 取该层该分级的关卡池；该层暂时没有这类关卡时退回默认层，
	## 避免地图走进死路（新增层尚未补齐关卡时的兜底）。
	var pool := GameLevels.levels_of_tier(tiers, layer)
	if pool.is_empty() and layer != GameLayers.LAYER_DEFAULT:
		pool = GameLevels.levels_of_tier(tiers)
	return pool


static func _pick_level(pool: Array[Dictionary]) -> Dictionary:
	if pool.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for lvl in pool:
		if not used_levels.has(str(lvl["name"])):
			candidates.append(lvl)
	if candidates.is_empty():
		candidates = pool          # 本局全用过：允许循环复用
	var pick: Dictionary = candidates[run_rng.randi() % candidates.size()]
	used_levels.append(str(pick["name"]))
	return pick


# ---- 卡组 ----

static func add_card(id: int) -> void:
	## 卡牌奖励收下的卡加入卡组。
	deck_ids.append(id)


static func build_deck(repo: CardRepo) -> Array[CardData]:
	## 按 deck_ids 构建实际牌库（缺定义的 id 跳过）。
	## ⚠️ 费用以 **deck_cost_at_index** 为准（工匠锻造的铁栅栏是 2 费、卡面却是 0 费）：
	## 只有「与卡面费用不同」的那些才取**副本**改写费用，其余照旧用卡库**共享实例** ——
	## 没锻造过铁栅栏时，行为与以前**完全一致**（不会到处多出复制品）。
	var cards: Array[CardData] = []
	for i in deck_ids.size():
		var c := repo.get_card(deck_ids[i])
		if c == null:
			continue
		var want := deck_cost_at_index(i)
		if want != c.cost:
			var cp := CardData.from_dict(c.to_dict())
			cp.cost = want
			cards.append(cp)
		else:
			cards.append(c)
	return cards


static func deck_summary(repo: CardRepo) -> Array:
	## 卡组内容摘要：[{id, name, count}, ...]（按首次出现顺序）。
	var order: Array = []
	var counts := {}
	for id in deck_ids:
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	var out: Array = []
	for id in order:
		var c := repo.get_card(id)
		out.append({"id": id, "name": c.card_name if c != null else str(id),
				"count": counts[id]})
	return out


# ------------------------------------------------------------ 战斗记录

static func record_battle(repo: CardRepo, level_name: String, tier: int,
		win: bool, final_hp: int) -> void:
	## 每场战斗结束调用：记录卡组内容 / 是否失败 / 最终血量，并持久化。
	var entry := {
		"time": Time.get_datetime_string_from_system().replace("T", " "),
		"level": level_name,
		"tier": tier,
		"win": win,
		"final_hp": final_hp,
		"max_hp": max_hp,
		"deck": deck_summary(repo),
	}
	battle_log.append(entry)
	_append_persisted(entry)


static func load_records() -> Array:
	## 读取持久化的全部战斗记录（新在前）。
	if not FileAccess.file_exists(RECORDS_PATH):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	return data if data is Array else []


static func _append_persisted(entry: Dictionary) -> void:
	var all := load_records()
	all.append(entry)
	while all.size() > RECORDS_KEEP:
		all.pop_front()
	var f := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all, "  "))
