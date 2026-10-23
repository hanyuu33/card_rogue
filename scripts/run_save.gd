class_name RunSave
extends RefCounted
## 肉鸽 run 的本地存档 / 续档（"继续游戏"）—— 关掉 app 也能从本地数据接着当前局。
##
## 存档内容 = RunState 的全部**持久字段**（血量 / 卡组 / 地图 / 位置 / 道具 / 种子 / 随机源状态 /
## 待领奖励队列……）。地图格子里没有小数、关卡字典里有 Vector2i（敌人站位），所以用
## **var_to_str / str_to_var** 序列化（int / bool / Vector2i / 嵌套字典数组原样 round-trip），
## 不走 JSON（JSON 存不了 Vector2i，且数字会被统一成 float）。
##
## 随机源：只存 `run_rng.seed + run_rng.state` 两个整数即可**精确续上**随机链条 ——
## 地图/关卡/掉落早已从这条链上摇过，续档后下一次摇点和关掉 app 前完全一致（不影响已生成的局面）。
##
## 存档时机 / 生命周期：
##   * **存**：map_scene 每次稳定停留在地图时（每个节点结算完的检查点）自动存一份；
##   * **清**：① 标题点「开始」开新局（弃旧档）；② RunState.end_run()（通关/失败/放弃）；
##   * **读**：标题「继续游戏」→ load_run() → 进地图。
##
## ⚠️ 续档只恢复到**地图层**：战斗中关掉 app，下次从"这场之前"的地图检查点接着来
##   （那场重打）—— 与杀戮尖塔等同类肉鸽一致，避免存半场战斗导致"已走过的战斗房卡死"。

const SAVE_PATH := "user://run_save.sav"
const FORMAT := 1


# ------------------------------------------------------------ 查询

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# ------------------------------------------------------------ 写入

static func snapshot() -> Dictionary:
	## 当前 run 的**全部持久字段**（存档 = 它直接落盘）。
	## R241 抽出来单独一个函数，是为了让「确定性」能被**测试**验证：
	## 测试可以 snapshot() → 改乱内存 → apply(snapshot) → 再摇随机，完全不用碰磁盘。
	## ⚠️ 随机源只存 `seed + state` 两个整数：地图 / 掉落 / 摇卡 / 商店库存 / 战斗种子
	## 全部从这条链派生，续上这两个数 = 续上整条链。
	var rng: RandomNumberGenerator = RunState.run_rng
	return {
		"max_hp": RunState.max_hp,
		"hp": RunState.hp,
		"deck_ids": RunState.deck_ids,
		"deck_mods": RunState.deck_mods,
		"gold": RunState.gold,
		"map_cells": RunState.map_cells,
		"current_layer": RunState.current_layer,
		"current_node_id": RunState.current_node_id,
		"cleared_ids": RunState.cleared_ids,
		"seen_ids": RunState.seen_ids,       # R207：迷雾记忆（揭开过的房间不再还原）
		"chocolate": RunState.chocolate,
		"boss_pending": RunState.boss_pending,
		"player_class": RunState.player_class,
		"battle_wins": RunState.battle_wins,
		"elite_wins": RunState.elite_wins,
		"used_levels": RunState.used_levels,
		"boss_pick": RunState.boss_pick,
		"revenge_pending": RunState.revenge_pending,
		"relics": RunState.relics,
		"skipped_relics": RunState.skipped_relics,
		"duck_revive_chance": RunState.duck_revive_chance,
		"run_seed": RunState.run_seed,
		"rng_seed": rng.seed if rng != null else 0,
		"rng_state": rng.state if rng != null else 0,
		"pending_rewards": RunState.pending_rewards,
		"relic_choice": RunState.relic_choice,
		"pending_relic": RunState.pending_relic,
		"pending_relic_drop": RunState.pending_relic_drop,
		"pending_deck_edit": RunState.pending_deck_edit,
		"statue_charge": RunState.statue_charge,
		"basin_charge": RunState.basin_charge,   # R311 不锈钢盆：剩余点数（跨战斗累计）
		"lucky7_turns": RunState.lucky7_turns,   # R314 lucky 7：跨战斗回合计数
		"match_charge": RunState.match_charge,   # R342 火柴：剩余刷新次数（3 → 0）
		"bandage_pending": RunState.bandage_pending,  # R339：止血绷带的本层累计（原先漏存 → 续档归零）
		"boss_beaten": RunState.boss_beaten,          # R339：本层 Boss 已打（一层只开一次）
		"run_finished": RunState.run_finished,        # R339：本局已收尾（地图不再兜底开新局）
		"delivery_done": RunState.delivery_done,        # R339：委托完成（一次性，原先漏存）
		"map_strokes": RunState.map_strokes,            # R339：玩家在地图上画的线（原先漏存）
		"map_flags": RunState.map_flags,                # R339：玩家在地图上插的旗
		"pending_event": RunState.pending_event,
		"reward_type": RunState.reward_type,
		"reward_context": RunState.reward_context,
		"difficulty": RunState.difficulty,
		# R323：正停在一场没打完的战斗里时记下来（继续游戏据此直接回那一场）
		"resume_battle": RunState.resume_battle,
	}


static func save_run() -> bool:
	## 把当前 run 写入本地存档。非 run 中 / 写盘失败返回 false。
	if not RunState.run_active:
		return false
	return save_snapshot(snapshot())


static func save_snapshot(d: Dictionary) -> bool:
	## 把**指定的一份快照**写盘（R339）。
	## 战斗检查点必须写「进战斗之前」的那一份：`battle_scene` 在 `_load_entry_level()`
	## **之前**抓 `snapshot()`，否则开局第 1 个我方回合已经推过 lucky 7 计数（+1），
	## 续档重打这一场又从「已 +1」的计数起步 → 每续一次多算一格（用户报的计数错乱）。
	var root := {"__runsave__": FORMAT, "d": d}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunSave：无法写入存档 " + SAVE_PATH)
		return false
	f.store_string(var_to_str(root))
	f.close()
	return true


# ------------------------------------------------------------ 读取

static func load_run() -> bool:
	## 从本地存档恢复 run（写入 RunState 静态字段）。成功返回 true。
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var root: Variant = str_to_var(txt)
	if not (root is Dictionary) or int((root as Dictionary).get("__runsave__", 0)) != FORMAT:
		push_warning("RunSave：存档格式不兼容或已损坏")
		return false
	var d: Dictionary = (root as Dictionary).get("d", {})
	if not (d is Dictionary):
		return false
	return apply(d)


static func apply(d: Dictionary) -> bool:
	## 把一份 snapshot（存档里的 d）**写回 RunState**。R241 从 load_run 里抽出来，
	## 于是「读档」与「测试里验证确定性」走的是**同一段代码**，不会两条路各写一遍。
	RunState.max_hp = maxi(1, int(d.get("max_hp", 50)))
	RunState.hp = clampi(int(d.get("hp", RunState.max_hp)), 0, RunState.max_hp)
	RunState.run_active = true
	RunState.deck_ids = _int_array(d.get("deck_ids", []))
	RunState.deck_mods = d.get("deck_mods", []) if d.get("deck_mods", []) is Array else []
	RunState.ensure_deck_mods()   # R204：老存档没有 deck_mods → 补齐成与 deck_ids 等长
	RunState.gold = int(d.get("gold", 100))
	RunState.map_cells = d.get("map_cells", []) if d.get("map_cells", []) is Array else []
	RunState.current_layer = int(d.get("current_layer", GameLayers.LAYER_DEFAULT))
	RunState.current_node_id = int(d.get("current_node_id", -1))
	RunState.cleared_ids = _int_array(d.get("cleared_ids", []))
	# R207：读档后先还原「揭开过就不还原」的记忆，再按当前视野补一批
	#（老存档没有这个字段 → 空数组，补完等于「读档那一刻看见的都记住」）。
	RunState.seen_ids = _int_array(d.get("seen_ids", []))
	RunState.reveal_known()
	RunState.chocolate = int(d.get("chocolate", 0))
	RunState.boss_pending = bool(d.get("boss_pending", false))
	RunState.player_class = str(d.get("player_class", PlayerClass.default_id()))
	RunState.battle_wins = int(d.get("battle_wins", 0))
	RunState.elite_wins = int(d.get("elite_wins", 0))
	RunState.used_levels = _str_array(d.get("used_levels", []))
	RunState.boss_pick = d.get("boss_pick", {}) if d.get("boss_pick", {}) is Dictionary else {}
	RunState.revenge_pending = bool(d.get("revenge_pending", false))
	RunState.relics = _int_array(d.get("relics", []))
	RunState.skipped_relics = _int_array(d.get("skipped_relics", []))
	RunState.duck_revive_chance = int(d.get("duck_revive_chance", 100))
	RunState.run_seed = int(d.get("run_seed", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("rng_seed", 0))
	rng.state = int(d.get("rng_state", 0))
	RunState.run_rng = rng
	RunState.pending_rewards = d.get("pending_rewards", []) if d.get("pending_rewards", []) is Array else []
	RunState.relic_choice = _int_array(d.get("relic_choice", []))
	RunState.pending_relic = int(d.get("pending_relic", -1))
	RunState.pending_relic_drop = int(d.get("pending_relic_drop", -1))
	RunState.pending_deck_edit = str(d.get("pending_deck_edit", ""))
	RunState.statue_charge = int(d.get("statue_charge", 0))
	# R311 不锈钢盆：老存档没有这个字段 → 按 0；有盆却没点数时补满（旧档兼容）
	RunState.basin_charge = int(d.get("basin_charge", 0))
	if RunState.has_relic(RunState.BASIN_RELIC_ID) and RunState.basin_charge <= 0:
		RunState.basin_charge = RunState.BASIN_MAX
	# R314 lucky 7：老存档没有这个字段 → 按 0（下次开始我方回合起重新累计）
	RunState.lucky7_turns = int(d.get("lucky7_turns", 0))
	# R342 火柴：存档里没有这个字段（旧档）→ 若身上有火柴就按满 3 次补齐，别让旧档带着 0 次。
	var saved_match := int(d.get("match_charge", -1))
	RunState.match_charge = (RunState.MATCH_CHARGES if saved_match < 0
			else maxi(0, saved_match))
	if not RunState.has_relic(RunState.MATCH_RELIC_ID):
		RunState.match_charge = 0
	# R339：止血绷带的本层累计 —— 老存档没有这个字段 → 按 0
	RunState.bandage_pending = maxi(0, int(d.get("bandage_pending", 0)))
	# R339：本层 Boss 是否已打（老存档 → false，等于「这一层还没打过」）
	RunState.boss_beaten = bool(d.get("boss_beaten", false))
	RunState.run_finished = bool(d.get("run_finished", false))
	# R339：委托完成 / 地图标记 —— 老存档没有这些字段 → 按空处理
	RunState.delivery_done = bool(d.get("delivery_done", false))
	RunState.map_strokes = d.get("map_strokes", []) if d.get("map_strokes", []) is Array else []
	RunState.map_flags = d.get("map_flags", []) if d.get("map_flags", []) is Array else []
	RunState.pending_event = str(d.get("pending_event", ""))
	RunState.reward_type = str(d.get("reward_type", "normal"))
	RunState.reward_context = str(d.get("reward_context", ""))
	RunState.difficulty = clampi(int(d.get("difficulty", 0)), 0, RunState.DIFFICULTY_COUNT - 1)
	# R223 难度 5：读档后按存档里的巧克力纠正「疲惫」在不在卡组
	# （老存档没有它、难度也是旧的，直接按当前口径推导最稳）
	RunState.sync_fatigue()
	# R323：续档停在一场战斗里 → 把那一场的「关卡 / 房间」一起还原，
	# 战斗场景的 `_load_entry_level()` 就是读 `pending_level` 开局的。
	var rb: Variant = d.get("resume_battle", {})
	RunState.resume_battle = rb if rb is Dictionary else {}
	if not RunState.resume_battle.is_empty():
		RunState.pending_level = RunState.resume_battle.get("level", {})
		RunState.pending_node = RunState.resume_battle.get("node", {})
	# 瞬时转换字段不存档（安全检查点上它们本就为空）：读档后复位，走地图重新触发
	if RunState.resume_battle.is_empty():
		RunState.pending_level = {}
		RunState.pending_node = {}
	RunState.reward_kinds = []
	RunState.battle_log = []
	return true


# ------------------------------------------------------------ 删除

static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ------------------------------------------------------------ 工具

static func _int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v: Variant in a:
			out.append(int(v))
	return out


static func _str_array(a: Variant) -> Array:
	var out: Array = []
	if a is Array:
		for v: Variant in a:
			out.append(str(v))
	return out
