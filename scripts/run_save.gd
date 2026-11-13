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

## ⚠️ R378：`SAVE_PATH` 从 const 改成 **static var** —— 测试模式要换成另一条路径。
## 玩家那份永远是 `run_save.sav`；回归套件走 `run_save_test.sav`。
const REAL_SAVE_PATH := "user://run_save.sav"
const TEST_SAVE_PATH := "user://run_save_test.sav"
static var SAVE_PATH := REAL_SAVE_PATH
const FORMAT := 1
## R377：存档事故取证日志（谁 SAVE / LOAD / CLEAR / QUARANTINE 了，一行一条）。
const TRACE_PATH := "user://save_trace.log"
## R392：测试 / 探针那份单独放。`SAVE_PATH` 早就分了，日志却没分 ——
## 跑一次窗口烟测（二十几条 `CLEAR by end_run`）就把玩家真正的现场冲干净了。
const TEST_TRACE_PATH := "user://save_trace_test.log"
static var TRACE_FILE := TRACE_PATH
const TRACE_KEEP := 200

## R486：**存档内容版本**（与上面的 `FORMAT` 分工不同，别混）：
##   * `FORMAT` = 外层包装能不能解开（root 里的 `__runsave__`）。不匹配 → `_readable()` 直接否。
##   * `CONTENT_VERSION` = 包装里**内容口径**的版本：字段结构 / 卡池 / 摆位规则变了就 +1。
##     包装能解开、但内容可能已经没法继续 —— 这就得靠版本号 + 体检来判断。
## ⚠️ 这个数字**必须真的写进存档**（`snapshot()` 的 `data_ver`）。没有它，两台机器之间
##    同步来的档就永远分不清「旧档」还是「新档」，只能靠猜；而猜错的代价是玩家的进度。
## R488：v2 —— 新增 `lake_victim`（湖中仙女「谎言」摇定的卡组下标）。缺这个键的旧档照样读
## （默认 -1 = 进房重摇），所以 `MIN_CONTENT_VERSION` 保持在 0。
const CONTENT_VERSION := 2
## 低于它的档一律不能读（改结构时把它抬到「还认的老结构」那一档）。
## 0 = 目前还认所有 R486 之前（没有 data_ver 字段）的档。
const MIN_CONTENT_VERSION := 0

## R486：最近一次读档失败的原因 —— **给界面看的整句话**，空 = 上一次没失败。
## 为什么要有它：`load_run()` 只返回 bool，标题页 / 地图兜底 / AI 桥接就只能各自编文案，
## 于是「为什么不能继续」永远说不清（玩家看到的是「读取失败」四个字）。
## 现在三个入口读同一份 `last_error`，提示天然同步。
static var last_error := ""
## 失败类别（界面据此决定要不要说「已备份」）：
##   "missing"      盘上没档
##   "corrupt"      解不开 / 半截档
##   "finished"     这一局已经收尾
##   "version_new"  存档比本作新（**不隔离、不删**，换回新版游戏还能接着打）
##   "version_old"  存档太旧 / 里面有已下架的卡或道具
##   "content"      结构不合理（没卡组 / 没地图 / 层数越界 / 停在图上不存在的格子）
static var last_error_kind := ""
## 「来自更新版本」那份档的指纹（长度:修改时间）。`has_save()` 靠它把按钮藏起来，
## 但**文件一个字节都不动** —— 档被同步 / 重写（指纹变了）就自动解封，不用重启游戏。
static var _blocked_stamp := ""

## R640：**「这局已经通关过」的墓碑**（按 `run_seed` 记账，最多留 `CLEARED_KEEP` 条）。
## 为什么需要它（用户报「通关后依旧可以继续游戏，又回到已经打过的母舰空袭」）：
## 通关那一刻 `mark_run_won()` 确实 `clear_save()` 删了档，但**删掉不等于再也写不回来** ——
## 只要还有一个实例 / 一次迟到的检查点拿着通关前那份快照往 `user://run_save.sav` 写一次
## （双开、转场窗口期、`.prev` 回滚……），盘上就又出现一份「第三层打到一半」的合法档，
## 标题页照旧亮「继续游戏」，玩家点进去就回到那局已经打通的进度上重打。
## 判据放在**读档口**（而不是只在写档口堵）：只要种子在这张名单里，任何来源的档一律作废 ——
## 这才是「通关就该结束」这件事的唯一权威。
## ⚠️ 只按 seed 认，不按层数 / 时间猜：同一个 seed = 同一局，没有例外。
## ⚠️ 和 `SAVE_PATH` 一样**必须分测试路径**（R640）：回归套件里会真的通关几十次，
##    共用一个文件就把玩家自己的通关名单冲掉 / 塞满。
const REAL_CLEARED_PATH := "user://run_cleared.sav"
const TEST_CLEARED_PATH := "user://run_cleared_test.sav"
static var CLEARED_PATH := REAL_CLEARED_PATH
const CLEARED_KEEP := 20

## `has_save()` 的缓存：标题页 `_process` **每帧**都会问一次，而判断「已收尾 / 已通关种子」
## 必须把 8KB 存档解包一遍 —— 每帧解包是纯浪费。按文件指纹（长度:修改时间）缓存结果，
## 档被写 / 被删（指纹变了）就自动重算，不会读到过期结论。
static var _resume_stamp := ""
static var _resume_ok := false


static func set_test_mode() -> void:
	## R378（用户二次上报「你测试的时候可能没有问题，可是我玩的时候就是会有」的真正原因）：
	## 回归套件里几十处 `clear_save()` / `save_run()`，**全打在同一个 `user://run_save.sav` 上**。
	## 开发机和玩家是同一台机器 → 跑一次 test_engine 就把正在打的那一局删掉了；
	## 跑 test_smoke 又会造一份假档，让标题页冒出「继续游戏」并进一个假局。
	## 测试进程一律改走 `run_save_test.sav`，**永远别碰玩家那份**。
	## ⚠️ 三个测试脚本入口（test_engine / test_smoke / test_reward）第一行就得调它。
	SAVE_PATH = TEST_SAVE_PATH
	TRACE_FILE = TEST_TRACE_PATH
	CLEARED_PATH = TEST_CLEARED_PATH     # R640：通关墓碑同样不许写玩家那份


# ------------------------------------------------------------ 查询

static func has_save() -> bool:
	# R377：先自愈。上次写盘若在「旧档已挪走、新档还没换上」那一刻被打断
	# （关窗口 / 切后台 / 被杀 / 文件被杀软短暂占用），盘上只剩一份完整的 .tmp ——
	# 它内容就是新档，直接提升回来。不然按钮白白消失，玩家以为「档没了」。
	_recover_tmp()
	if not FileAccess.file_exists(SAVE_PATH):
		_resume_stamp = ""
		return false
	# R486：判过「来自更新版本」的那份档**留着但不给按** —— 它多半是从另一台机器
	# 同步过来的新进度，删掉等于把玩家的未来进度抹了。指纹变了（档被重写 / 换回来）
	# 自动解封，所以切回新版游戏、或同步覆盖之后都不用重启。
	if protects_save():
		return false
	# R640：**「继续游戏」按钮亮不亮，等于「这份档能不能真的接着打」**。
	# 以前这里只问「文件在不在」—— 于是通关后又被写回来的那份档、以及已经收尾的档
	# 都会让按钮亮起来，玩家点下去才被拒绝（甚至被放回去重打）。判据往下沉一层：
	# 收尾过的 / 通关过的种子，同样算「没有档」。按指纹缓存，别每帧解包 8KB。
	var st := _light_stamp(SAVE_PATH)
	if st == _resume_stamp and _resume_stamp != "":
		return _resume_ok
	_resume_stamp = st
	_resume_ok = _resumable()
	return _resume_ok


static func _light_stamp(path: String) -> String:
	## R640：`has_save()` 每帧都要问一次，所以指纹必须**便宜**。
	## `_stamp_of()` 是读整个文件取长度（8KB，每帧一次纯浪费）；这里只开句柄取长度 + 修改时间。
	## 判据仍然是「档被重写 / 被删」→ 指纹变 → 缓存失效，足够。
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var n := f.get_length()
	f.close()
	return "%d:%d" % [n, FileAccess.get_modified_time(path)]


static func _resumable() -> bool:
	## R640：`has_save()` 的轻量体检 —— 只回答「点『继续游戏』会不会被立刻踢回来」。
	## **不做完整 `validate()`**（那是 `load_run()` 的活，它还要说清失败原因）：
	## 这里只认两条「按了也白按」的死条件：
	##   ① 档里 `run_finished` 已真（这一局已经收尾）；
	##   ② 档里的 `run_seed` 在通关墓碑名单里（这一局已经打通）。
	## 解不开的档**仍然算有档**（返回 true）—— 保持老行为：让玩家点进去，
	## 由 `load_run()` 告诉他「存档已损坏 / 版本太旧」，比按钮凭空消失清楚得多。
	if not _readable(SAVE_PATH):
		return true
	var root: Variant = str_to_var(FileAccess.get_file_as_string(SAVE_PATH))
	if not (root is Dictionary):
		return true
	var d: Variant = (root as Dictionary).get("d", null)
	if not (d is Dictionary):
		return true
	if bool((d as Dictionary).get("run_finished", false)):
		return false
	if is_cleared(int((d as Dictionary).get("run_seed", 0))):
		return false
	return true


static func protects_save() -> bool:
	## R486：盘上那份档我们**读不懂、但故意不删**（判过「来自更新版本」）—— 真值表示
	## 「继续游戏」不该亮、写新档前必须先把它留成 `.bad`。指纹变了（档被同步 / 重写）
	## 就自动为假，不用重启游戏。
	return _blocked_stamp != "" and _stamp_of(SAVE_PATH) == _blocked_stamp


# ------------------------------------------------------------ R640 通关墓碑

static func mark_cleared(seed_id: int) -> void:
	## 这一局打通了 → 把 seed 记进名单（幂等，同一 seed 只留一条，只留最近 `CLEARED_KEEP` 条）。
	## 调用点唯一：`RunState.mark_run_won()`（通关那一瞬，比删档晚不了几毫秒）。
	## 为什么按 seed 认而不是按「层数 / 时间」猜：seed 是这一局的唯一身份，
	## 同一 seed = 同一局，没有例外 —— 猜层数会把「第二层刚进第三层」的合法档误杀。
	## ⚠️ 写失败不影响通关：最坏退化成老行为（只靠删档），不会有额外的错误路径。
	if seed_id == 0:
		return
	var seeds := cleared_seeds()
	var at := seeds.find(seed_id)
	if at >= 0:
		seeds.remove_at(at)
	seeds.append(seed_id)
	while seeds.size() > CLEARED_KEEP:
		seeds.remove_at(0)
	var f := FileAccess.open(CLEARED_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunSave：通关墓碑写不进去 " + CLEARED_PATH)
		return
	for s: int in seeds:
		f.store_line(str(s))
	f.close()
	_resume_stamp = ""       # 通关之后一律不该再有「继续游戏」，缓存立刻作废
	_trace("CLEARED seed=%d（名单 %d 局）" % [seed_id, seeds.size()])


static func cleared_seeds() -> Array[int]:
	## 通关墓碑名单（新 → 旧）。文件不存在 = 一局都没通过（老玩家 / 首次启动）。
	var out: Array[int] = []
	if not FileAccess.file_exists(CLEARED_PATH):
		return out
	for line: String in FileAccess.get_file_as_string(CLEARED_PATH).split("\n", false):
		var t := line.strip_edges()
		if t.is_valid_int():
			out.append(int(t))
	return out


static func is_cleared(seed_id: int) -> bool:
	## 这一局的 seed 是不是已经打通过。`load_run()` / `has_save()` 都靠它把复活档按死。
	if seed_id == 0:
		return false
	return cleared_seeds().has(seed_id)


static func probe_newer_save() -> void:
	## R486：**开机先问一句**，不等玩家点「继续游戏」。
	## 场景（正是双机同步的日常）：另一台机器存的那份档 `data_ver` 比这台高 →
	## `has_save()` 会返回假、「继续游戏」按钮直接消失；可玩家一次都没点过按钮，
	## 屏幕上也没有任何说明 —— 表现就是「我的进度凭空没了，游戏还让我重开」。
	## 这里只在**标题页加载时**跑一次：读盘 → 体检 → 若判成 `version_new` 就记下
	## 原因与指纹（`protects_save()` 随之为真，标题页据此画常驻说明）。
	## ⚠️ 只读：**不改文件、不写 RunState**；隔离 / 清洗仍然只发生在 `load_run()` 里。
	if protects_save():
		return          # 同一进程里已经判过（点过继续游戏 / 已探过）
	if not FileAccess.file_exists(SAVE_PATH):
		return
	if not _readable(SAVE_PATH):
		return          # 损坏档留给 `load_run()` 说；这里只认「版本比本作新」
	var root: Variant = str_to_var(FileAccess.get_file_as_string(SAVE_PATH))
	var d: Variant = (root as Dictionary).get("d", {})
	var v: Dictionary = validate(d if d is Dictionary else {})
	if str(v.get("kind", "")) != "version_new":
		return
	last_error_kind = "version_new"
	last_error = str(v.get("msg", GameI18n.ui("shared", "RUN_SAVE_NEWER_FALLBACK", "存档来自更新的版本，本版本不能使用")))
	_blocked_stamp = _stamp_of(SAVE_PATH)
	_trace("PROBE-BLOCK(version_new) 标题页先发现：%s" % last_error)


# ------------------------------------------------------------ 写入

static func snapshot() -> Dictionary:
	## 当前 run 的**全部持久字段**（存档 = 它直接落盘）。
	## R241 抽出来单独一个函数，是为了让「确定性」能被**测试**验证：
	## 测试可以 snapshot() → 改乱内存 → apply(snapshot) → 再摇随机，完全不用碰磁盘。
	## ⚠️ 随机源只存 `seed + state` 两个整数：地图 / 掉落 / 摇卡 / 商店库存 / 战斗种子
	## 全部从这条链派生，续上这两个数 = 续上整条链。
	var rng: RandomNumberGenerator = RunState.run_rng
	return {
		# R486：这份档是**哪个内容口径**写的。缺了它（R486 之前的档）= 0，照样读，
		# 但一旦哪天结构变了，`validate()` 就没有依据把「旧档」挡在门外。
		"data_ver": CONTENT_VERSION,
		"max_hp": RunState.max_hp,
		"hp": RunState.hp,
		"deck_ids": RunState.deck_ids,
		"deck_mods": RunState.deck_mods,
		# R488：湖中仙女「谎言」摇定的那一张（卡组下标）—— 不存的话
		# 「回标题 → 继续 → 重进本房」会换一张，按钮上写的卡名与实际删掉的不是同一张。
		"lake_victim": RunState.lake_victim,
		"card_growth": RunState.card_growth,   # R393：本局永久击杀成长
		"gold": RunState.gold,
		"map_cells": RunState.map_cells,
		"current_layer": RunState.current_layer,
		"current_node_id": RunState.current_node_id,
		"cleared_ids": RunState.cleared_ids,
		"seen_ids": RunState.seen_ids,       # R207：迷雾记忆（揭开过的房间不再还原）
		"event_kinds_used": RunState.event_kinds_used,   # R374：本局已出过的事件（一局只出一次）
		"chocolate": RunState.chocolate,
		"fatigue_granted_layer": RunState.fatigue_granted_layer,   # R358：疲惫每层只发一次
		"boss_pending": RunState.boss_pending,
		"player_class": RunState.player_class,
		"battle_wins": RunState.battle_wins,
		"elite_wins": RunState.elite_wins,
		# R630：**整局累计**三项（结算页 / 记录页读的就是它们）。原先只存了「本层」两个数 →
		# 关掉游戏再「继续游戏」之后，战斗 / 精英 / 伤害从 0 重新起算，通关结算只剩
		# 「读档之后」那一段（用户口径「3 层只统计了 3 层」的第二个来源）。
		"total_battle_wins": RunState.total_battle_wins,
		"total_elite_wins": RunState.total_elite_wins,
		"total_damage": RunState.total_damage,
		"used_levels": RunState.used_levels,
		"boss_pick": RunState.boss_pick,
		"revenge_pending": RunState.revenge_pending,
		"relics": RunState.relics,
		"key_relics": RunState.key_relics,   # R543：信物（解锁第三层，与道具分开记账）
		# R367：已耗尽的道具（灰显的那些）与每层 Boss 战果 —— 续档要接着画灰 / 接着记。
		"spent_relics": RunState.spent_relics,
		"boss_kills": RunState.boss_kills,
		"run_bans": RunState.run_bans,   # R352：本局禁卡快照（续档要接着用同一份）
		"skipped_relics": RunState.skipped_relics,
		"duck_revive_chance": RunState.duck_revive_chance,
		"run_seed": RunState.run_seed,
		"rng_seed": rng.seed if rng != null else 0,
		"rng_state": rng.state if rng != null else 0,
		"pending_rewards": RunState.pending_rewards,
		# R390：商店会话（离开后下次移动前能重进，货架必须原样）
		"shop_states": RunState.shop_states,
		"shop_revisit_id": RunState.shop_revisit_id,
		"relic_choice": RunState.relic_choice,
		"pending_relic": RunState.pending_relic,
		"pending_relic_drop": RunState.pending_relic_drop,
		"pending_deck_edit": RunState.pending_deck_edit,
		"statue_charge": RunState.statue_charge,
		"basin_charge": RunState.basin_charge,   # R311 不锈钢盆：剩余点数（跨战斗累计）
		"lucky7_turns": RunState.lucky7_turns,   # R314 lucky 7：跨战斗回合计数
		"pipe_ready": RunState.pipe_ready,   # R446 烟斗：还亮着没有
		"core_lost": RunState.core_lost,      # R458 核心：累计失去的生命值
		"core_armed": RunState.core_armed,     # R458 核心：够 15 点没有
		"match_charge": RunState.match_charge,   # R342 火柴：剩余刷新次数（3 → 0）
		"bandage_pending": RunState.bandage_pending,  # R339：止血绷带的本层累计（原先漏存 → 续档归零）
		"boss_beaten": RunState.boss_beaten,          # R339：本层 Boss 已打（一层只开一次）
		"run_finished": RunState.run_finished,        # R339：本局已收尾（地图不再兜底开新局）
		"delivery_done": RunState.delivery_done,        # R339：委托完成（一次性，原先漏存）
		"map_strokes": RunState.map_strokes,            # R339：玩家在地图上画的线（原先漏存）
		"map_flags": RunState.map_flags,                # R339：玩家在地图上插的旗
		"pending_event": RunState.pending_event,
		# R473：延迟发卡的挂单（武术大师「2 场后给」）—— 跨战斗存活，必须存
		"delayed_cards": RunState.delayed_cards,
		# R473：圣餐结算过的那一间休息处（漏存 → 续档重进同一间还能再回一次 50%）
		"sacrament_node": RunState.sacrament_node,
		"reward_type": RunState.reward_type,
		"reward_context": RunState.reward_context,
		"difficulty": RunState.difficulty,
		# R323：正停在一场没打完的战斗里时记下来（继续游戏据此直接回那一场）
		"resume_battle": RunState.resume_battle,
	}


static func save_run() -> bool:
	## 把当前 run 写入本地存档。非 run 中 / 写盘失败返回 false。
	## R640：**已收尾的一局不许再写档**。`mark_run_won()` 已经把续档删了，可那时
	## `run_active` 还是真的（R471 要等玩家离开才 `end_run()`）—— 这段窗口里任何一次
	## 迟到的检查点（`_clear_battle_checkpoint` / 地图落盘 / 奖励面板回来）都会把
	## 「通关那局」原样写回盘上，标题页于是又冒出「继续游戏」。
	## 判据只有 `run_finished`：它一真，这一局就不该再有续档。
	if not RunState.run_active:
		return false
	if RunState.run_finished:
		return false
	return save_snapshot(snapshot())


static func save_snapshot(d: Dictionary) -> bool:
	## 把**指定的一份快照**写盘（R339）。
	## 战斗检查点必须写「进战斗之前」的那一份：`battle_scene` 在 `_load_entry_level()`
	## **之前**抓 `snapshot()`，否则开局第 1 个我方回合已经推过 lucky 7 计数（+1），
	## 续档重打这一场又从「已 +1」的计数起步 → 每续一次多算一格（用户报的计数错乱）。
	##
	## ⚠️ R377（用户报「回标题后不能继续游戏」的根因）：**任何一刻盘上都必须有一份能读的档**。
	## R359 的写法是「删掉旧档 → rename 新档」，两步之间被打断（关窗口 / 切后台 / 被
	## 杀软短暂占用 / 双开抢同一个 user://）就**两份都没有** —— 而且不会留下半截档
	## （.tmp 是完整的），`has_save()` 直接变假、「继续游戏」按钮凭空消失。
	## 现在改成三档，任何一步失败上一份好档都还在：
	##   ① 先整份写 .tmp，写完**自检**（读回来必须能解析、关键字段在）；
	##   ② 旧档 rename 成 .prev（**不删**）；
	##   ③ .tmp 换上正式名；失败就把 .prev 回滚回来。
	var root := {"__runsave__": FORMAT, "d": d}
	var tmp_path := SAVE_PATH + ".tmp"
	var prev_path := SAVE_PATH + ".prev"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("RunSave：无法写入存档 " + tmp_path)
		_trace("SAVE-FAIL 打不开 .tmp")
		return false
	f.store_string(var_to_str(root))
	f.close()
	# 自检：写出去的必须是「读得回来」的档（防某天某个字段序列化成怪东西）
	if not _readable(tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		push_warning("RunSave：新档自检不通过，本次不覆盖旧档")
		_trace("SAVE-FAIL .tmp 自检不通过（旧档未动）")
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("RunSave：打不开 user://，存档没替换成功")
		_trace("SAVE-FAIL 打不开 user://")
		return false
	# R486：盘上那份我们**读不懂**（更新版本的档 / 损坏档）→ 先留一份 `.bad` 再写新的。
	# 不能只靠下面的 `.prev` 流程：`.prev` 在最后会被删掉，等于把玩家的旧进度抹了；
	# 而「读不懂」的档恰恰是最需要留着的那种（换回新版游戏 / 事后人工捞回来）。
	if FileAccess.file_exists(SAVE_PATH) and _looks_unreadable(SAVE_PATH):
		var bad_path := SAVE_PATH + ".bad"
		if FileAccess.file_exists(bad_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH),
				ProjectSettings.globalize_path(bad_path))
		_trace("SAVE-PRESERVE 盘上旧档读不懂，先存成 .bad 再写新档")
	if FileAccess.file_exists(prev_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(prev_path))
	if FileAccess.file_exists(SAVE_PATH):
		if dir.rename(SAVE_PATH, prev_path) != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
			push_warning("RunSave：旧档挪不动（被占用？），本次不覆盖")
			_trace("SAVE-FAIL 旧档挪不动（旧档完好）")
			return false
	var err := dir.rename(tmp_path, SAVE_PATH)
	if err != OK:
		# 回滚：旧档还回正式名 —— 别让玩家连旧档都没有
		if FileAccess.file_exists(prev_path):
			dir.rename(prev_path, SAVE_PATH)
		push_warning("RunSave：存档替换失败 err=%d（旧档已回滚）" % err)
		_trace("SAVE-FAIL 换档失败 err=%d（旧档已回滚）" % err)
		return false
	if FileAccess.file_exists(prev_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(prev_path))
	_trace("SAVE ok deck=%d map=%d layer=%d node=%d finished=%s" % [
			(d.get("deck_ids", []) as Array).size(),
			(d.get("map_cells", []) as Array).size(),
			int(d.get("current_layer", -1)), int(d.get("current_node_id", -9)),
			str(d.get("run_finished", "?"))])
	return true


# ------------------------------------------------------------ 读取

static func load_run() -> bool:
	## 从本地存档恢复 run（写入 RunState 静态字段）。成功返回 true。
	## R486：失败时**一定**留下 `last_error` / `last_error_kind`（给界面说清原因），
	## 并且按类别决定「隔离」还是「原样留着」—— 见 `validate()` 的注释。
	last_error = ""
	last_error_kind = ""
	_blocked_stamp = ""
	_recover_tmp()
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("missing", GameI18n.ui("shared", "RUN_SAVE_MISSING", "没有可继续的存档"), false)
		_trace("LOAD-FAIL 盘上没有档")
		return false
	if not _readable(SAVE_PATH):
		push_warning("RunSave：存档格式不兼容或已损坏")
		_fail("corrupt", GameI18n.ui("shared", "RUN_SAVE_CORRUPT", "存档已损坏，不能使用"), true, "格式损坏")
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var root: Variant = str_to_var(txt)
	var d: Dictionary = (root as Dictionary).get("d", {})
	# R359：**已收尾的一局不算「可继续」**。`end_run(false)`（回标题）以前也把
	# `run_finished` 置真并保档 —— 那份档读进来后 `map_scene._ready` 立刻按
	# 「本局已收尾」把人踢回标题，表现是「点了继续游戏又回到标题」的循环。
	# 现在 `end_run(false)` 不再置真（见 run_state），这里再加一道：老档 / 异常档
	# 里带着 `run_finished: true` 就直接当废档清掉，别留一个死按钮。
	# R377：**这里不再删档**，只隔离成 `run_save.sav.bad` —— 以前 `clear_save()` 一删，
	# 玩家那份档就真的没了，连事后人工捞回来的机会都没有。
	if bool(d.get("run_finished", false)):
		push_warning("RunSave：存档是已收尾的一局，隔离不继续")
		_fail("finished", GameI18n.ui("shared", "RUN_SAVE_FINISHED", "这一局已经结束，不能继续"), true, "已收尾")
		return false
	# R640：**通关过的种子一律作废**（用户报「通关后继续游戏又回到打过的母舰空袭」）。
	# 上面那条只管「档里自己写着收尾」，而复活的那份档写的是 `run_finished: false`
	# —— 它看起来完全合法。真正的权威是**这一局的 seed 有没有打通过**：
	# 通关那一刻 `mark_cleared()` 已经把 seed 记进墓碑，于是哪怕档被别的实例 /
	# 迟到的检查点 / `.prev` 回滚写回来，也读不进去。
	# ⚠️ 这里**直接删**（不隔离成 .bad）：这份档没有任何取证价值，它就是一局已经打完的进度；
	# 留着只会在目录里越积越多，还让 `_recover_tmp()` 有东西可捡。
	var _cleared_seed := int(d.get("run_seed", 0))
	if _cleared_seed != 0 and is_cleared(_cleared_seed):
		push_warning("RunSave：存档属于已通关的一局（seed=%d），作废" % _cleared_seed)
		_trace("LOAD-DROP(cleared) seed=%d 已通关，续档作废" % _cleared_seed)
		clear_save()
		_fail("finished", GameI18n.ui("shared", "RUN_SAVE_CLEARED", "这一局已经通关，不能继续"), false, "已通关种子")
		return false
	# R486：**体检**。`_readable()` 只证明「包能解开」，解出来的东西可以荒谬到根本没法继续
	# （卡组全是已下架的卡 / 地图是空的 / 停在第九层）。以前这种档会被 `apply()` 硬读进来，
	# 然后在战斗里炸，或者表现成「卡组凭空少牌」—— 玩家完全不知道是档的问题。
	var v := validate(d)
	if not bool(v.get("ok", false)):
		var kind := str(v.get("kind", "content"))
		var msg := str(v.get("msg", GameI18n.ui("shared", "RUN_SAVE_INVALID_FALLBACK", "存档内容不合理，不能使用")))
		push_warning("RunSave：存档体检不通过（%s）—— %s" % [kind, msg])
		# 来自更新版本的档**不隔离**：它可能是另一台机器同步过来的新进度，
		# 删掉 / 改名等于替玩家做了「这份进度不要了」的决定。
		var keep_file := kind == "version_new"
		_fail(kind, msg, not keep_file,
				"体检不通过：%s" % kind)
		if keep_file:
			_blocked_stamp = _stamp_of(SAVE_PATH)
			_trace("LOAD-BLOCK(%s) 存档留着但不给继续：%s" % [kind, msg])
		return false
	var ok := apply(d)
	_trace("LOAD %s deck=%d map=%d layer=%d" % ["ok" if ok else "FAIL",
			RunState.deck_ids.size(), RunState.map_cells.size(), RunState.current_layer])
	return ok


static func apply(d: Dictionary) -> bool:
	## 把一份 snapshot（存档里的 d）**写回 RunState**。R241 从 load_run 里抽出来，
	## 于是「读档」与「测试里验证确定性」走的是**同一段代码**，不会两条路各写一遍。
	RunState.max_hp = maxi(1, int(d.get("max_hp", 50)))
	RunState.hp = clampi(int(d.get("hp", RunState.max_hp)), 0, RunState.max_hp)
	RunState.run_active = true
	RunState.deck_ids = _int_array(d.get("deck_ids", []))
	RunState.deck_mods = d.get("deck_mods", []) if d.get("deck_mods", []) is Array else []
	RunState.ensure_deck_mods()   # R204：老存档没有 deck_mods → 补齐成与 deck_ids 等长
	# R488：湖中仙女「谎言」摇定的那一张（卡组下标）。老存档没这个键 → -1（进房时重摇）；
	# 下标越界也回 -1（卡组被改短过的话，旧下标已经没有意义，不能拿去删卡）。
	var lv := int(d.get("lake_victim", -1))
	RunState.lake_victim = lv if lv >= 0 and lv < RunState.deck_ids.size() else -1
	# R393：本局永久击杀成长。老存档没有这个键 → 空账（卡面回到基础数值）。
	RunState.card_growth = {}
	var cg_raw: Variant = d.get("card_growth", {})
	if cg_raw is Dictionary:
		for cg_k: Variant in (cg_raw as Dictionary).keys():
			var cg_v: Variant = (cg_raw as Dictionary)[cg_k]
			if not (cg_v is Dictionary):
				continue
			var cg_d: Dictionary = cg_v
			var cg_out := {}
			for cg_stat in ["power", "health", "damage"]:
				var cg_n := maxi(0, int(cg_d.get(cg_stat, 0)))
				if cg_n != 0:
					cg_out[cg_stat] = cg_n
			if not cg_out.is_empty():
				RunState.card_growth[str(cg_k)] = cg_out
	RunState.gold = int(d.get("gold", 100))
	RunState.map_cells = d.get("map_cells", []) if d.get("map_cells", []) is Array else []
	RunState.current_layer = int(d.get("current_layer", GameLayers.LAYER_DEFAULT))
	RunState.current_node_id = int(d.get("current_node_id", -1))
	RunState.cleared_ids = _int_array(d.get("cleared_ids", []))
	# R207：读档后先还原「揭开过就不还原」的记忆，再按当前视野补一批
	#（老存档没有这个字段 → 空数组，补完等于「读档那一刻看见的都记住」）。
	RunState.seen_ids = _int_array(d.get("seen_ids", []))
	RunState.reveal_known()
	# R374：事件账本（老存档没有 → 空表；最坏结果只是这一局后半段又抽到一个旧事件）
	var eku_raw: Variant = d.get("event_kinds_used", {})
	RunState.event_kinds_used = {}
	if eku_raw is Dictionary:
		for eku_k: Variant in (eku_raw as Dictionary).keys():
			RunState.event_kinds_used[str(eku_k)] = true
	# R445（用户口径「这一局不会再出现占卜室」）：字段是 R374 才加的 —— **老存档没有**，
	# 光靠上面那行会得到一个空账本，换层重生成地图时就会把第一层出过的占卜室再抽一遍
	# （「读档后又撞见同一个事件」的真实成因）。这里按当前地图把已出现的事件补登记，
	# 与 `start_run()` 预生成地图那条分支同一套口径。
	# ⚠️ 只在账本为空时补：账本非空说明存档本身是 R374 之后的，别拿地图去覆盖它
	#    （地图上可能还有 `?` 房没揭晓，覆盖会把「已出过但图上没有的」记录抹掉）。
	# R544b（边界澄清）：老档在**第二层**读档时，第一层出过的事件已无法从存档恢复
	#    （那层地图早被换层替掉了）—— 但第二层地图早已定型、不会重新生成，故不会再撞出
	#    新的重复；R374 之后的新存档账本完整持久化（`snapshot`/`apply` 双向），跨层不重复已根治。
	if RunState.event_kinds_used.is_empty() and RunState.map_cells.size() > 0:
		for mc: Dictionary in RunState.map_cells:
			if str(mc.get("type", "")) == "event":
				var mck := str(mc.get("event_kind", ""))
				if mck != "":
					RunState.event_kinds_used[mck] = true
	RunState.chocolate = int(d.get("chocolate", 0))
	# R358：老存档没有这个字段 → -1（等同「本层还没发过」），下面 sync 按旧口径补一次
	RunState.fatigue_granted_layer = int(d.get("fatigue_granted_layer", -1))
	RunState.boss_pending = bool(d.get("boss_pending", false))
	RunState.player_class = str(d.get("player_class", PlayerClass.default_id()))
	RunState.battle_wins = int(d.get("battle_wins", 0))
	RunState.elite_wins = int(d.get("elite_wins", 0))
	# R630：整局累计跟着一起回填。**老档没有这三个键**（R630 之前的档）→ 用「本层」两个数
	# 兜底：那至少是同一局打出来的真实场次；直接兜 0 等于把老档的统计抹平，比少算更糟。
	RunState.total_battle_wins = int(d.get("total_battle_wins", d.get("battle_wins", 0)))
	RunState.total_elite_wins = int(d.get("total_elite_wins", d.get("elite_wins", 0)))
	RunState.total_damage = int(d.get("total_damage", 0))
	RunState.used_levels = _str_array(d.get("used_levels", []))
	RunState.boss_pick = d.get("boss_pick", {}) if d.get("boss_pick", {}) is Dictionary else {}
	RunState.revenge_pending = bool(d.get("revenge_pending", false))
	RunState.relics = _drop_unknown_relics(_int_array(d.get("relics", [])))
	RunState.key_relics = _int_array(d.get("key_relics", []))   # R543：信物（老存档无此字段 → 空）
	# R367：灰显道具 / Boss 战果。**必须在 `relics` 之后、下面盆与火柴的复查之前**赋值 ——
	# 那两处用 `has_relic()`（已排除 spent）决定要不要补满点数。
	RunState.spent_relics = _drop_unknown_relics(_int_array(d.get("spent_relics", [])))
	var bk_raw: Variant = d.get("boss_kills", [])
	RunState.boss_kills = []
	if bk_raw is Array:
		for b: Variant in bk_raw:
			if b is Dictionary and (b as Dictionary).has("layer"):
				RunState.boss_kills.append(b)
	# R352：老存档没有这个字段 → 空数组 = 这一局不禁卡（保守，不误伤奖励池）
	RunState.run_bans = _int_array(d.get("run_bans", []))
	RunState.skipped_relics = _int_array(d.get("skipped_relics", []))
	RunState.duck_revive_chance = int(d.get("duck_revive_chance", 100))
	RunState.run_seed = int(d.get("run_seed", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("rng_seed", 0))
	rng.state = int(d.get("rng_state", 0))
	RunState.run_rng = rng
	RunState.pending_rewards = d.get("pending_rewards", []) if d.get("pending_rewards", []) is Array else []
	# R390：商店会话。JSON 读回来的键是字符串，数值是 float —— 一律按原口径收拢。
	var ss: Variant = d.get("shop_states", {})
	RunState.shop_states = ss if ss is Dictionary else {}
	RunState.shop_revisit_id = int(d.get("shop_revisit_id", -1))
	RunState.relic_choice = _int_array(d.get("relic_choice", []))
	# R473：延迟发卡挂单。JSON 读回来的数值是 float，这里逐个收成 int；
	# 结构不对的条目直接丢（宁可少挂一张，也不要留一条永远减不到 0 的幽灵单）。
	var dc_raw: Variant = d.get("delayed_cards", [])
	RunState.delayed_cards = []
	RunState.sacrament_node = int(d.get("sacrament_node", -1))
	if dc_raw is Array:
		for e: Variant in dc_raw:
			if e is Dictionary and (e as Dictionary).has("id"):
				RunState.delayed_cards.append({
					"id": int(e["id"]),
					"need": int(e.get("need", 0)),
					"elite": bool(e.get("elite", false))})
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
	RunState.pipe_ready = bool(d.get("pipe_ready", false))   # R446
	# R458 核心：老档没有这两个字段 → 默认 0 / false（等于「还没受过伤」）
	RunState.core_lost = int(d.get("core_lost", 0))
	RunState.core_armed = bool(d.get("core_armed", false))
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
	# R477（用户口径）：继续游戏**一律回到这一场战斗开打之前**。老档里可能还挂着
	# `battle`（当年「恢复到第 N 回合」的快照）—— 读进来的第一件事就是把它摘掉，
	# 只留 node / level，让战斗场景从第 1 回合重新开局。
	if RunState.resume_battle.has("battle"):
		RunState.resume_battle.erase("battle")
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


# ------------------------------------------------------------ R486 存档体检

static func validate(d: Dictionary) -> Dictionary:
	## R486：读档前的**合理性体检（唯一口）**。返回 `{ok, kind, msg}`。
	## 只判「这份档还能不能安全继续」，**不修数据、不写 RunState** —— 通过之后才 `apply()`
	## （apply 里那些「老档缺字段就补默认值」的兼容逻辑照旧，两者分工不重叠）。
	##
	## 判据分三档，越前面的越硬：
	##   ① **版本**：`data_ver` 比本作新 → 读不懂（`version_new`，档留着）；
	##      比 `MIN_CONTENT_VERSION` 旧 → 太老读不了（`version_old`）。
	##   ② **已下架内容**：卡组 / 待领奖励 / 延迟发卡里引用了**当前卡库没有的卡**，
	##      或道具栏里引用了当前道具库没有的道具 → 这就是「旧版本的档」（`version_old`）。
	##      ⚠️ 这条最容易漏：卡被删 / 改了 id 之后，老档读进来会得到一个 `null` 卡，
	##      战斗里第一张牌就炸；而它看起来只是「我的卡组少了一张」。
	##   ③ **结构**：没有卡组 / 没有地图 / 格子缺字段 / 层数越界 / 停在图上不存在的格子。
	if d.is_empty():
		return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_EMPTY", "存档内容是空的，不能使用"))
	var ver := int(d.get("data_ver", 0))
	if ver > CONTENT_VERSION:
		return _verdict(false, "version_new",
				GameI18n.ui("shared", "RUN_SAVE_NEWER_VERSION", "存档来自更新的版本（存档 v%d / 本作 v%d），本版本不能使用该存档") % [ver, CONTENT_VERSION])
	if ver < MIN_CONTENT_VERSION:
		return _verdict(false, "version_old",
				GameI18n.ui("shared", "RUN_SAVE_OLDER_VERSION", "存档版本过旧（存档 v%d / 本作 v%d），不能使用") % [ver, CONTENT_VERSION])
	# ② 卡组
	var deck: Variant = d.get("deck_ids", [])
	if not (deck is Array) or (deck as Array).is_empty():
		return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_NO_DECK", "存档里没有卡组，不能使用"))
	var gone := _missing_card_ids(deck as Array)
	if not gone.is_empty():
		return _verdict(false, "version_old",
				GameI18n.ui("shared", "RUN_SAVE_REMOVED_CARDS", "存档里有 %d 张已下架的卡（%s），属于旧版本，不能使用") % [
						gone.size(), _ids_text(gone)])
	# ② 待领奖励 / 延迟发卡的候选（这里引用了不存在的卡 → 奖励页一点就炸）
	var pend: Array = []
	var pr: Variant = d.get("pending_rewards", [])
	if pr is Array:
		for e: Variant in pr:
			if e is Dictionary and (e as Dictionary).get("candidates", null) is Array:
				pend.append_array((e as Dictionary)["candidates"])
	var dc: Variant = d.get("delayed_cards", [])
	if dc is Array:
		for e2: Variant in dc:
			if e2 is Dictionary and (e2 as Dictionary).has("id"):
				pend.append((e2 as Dictionary)["id"])
	var gone_p := _missing_card_ids(pend)
	if not gone_p.is_empty():
		return _verdict(false, "version_old",
				GameI18n.ui("shared", "RUN_SAVE_PENDING_REMOVED_CARDS", "存档的待领奖励里有 %d 张已下架的卡（%s），属于旧版本，不能使用") % [
						gone_p.size(), _ids_text(gone_p)])
	# ② 道具
	var rel: Variant = d.get("relics", [])
	var gone_r := _missing_relic_ids(rel if rel is Array else [])
	if not gone_r.is_empty():
		return _verdict(false, "version_old",
				GameI18n.ui("shared", "RUN_SAVE_REMOVED_RELICS", "存档里有 %d 件已下架的道具（%s），属于旧版本，不能使用") % [
						gone_r.size(), _ids_text(gone_r)])
	# ③ 结构
	if int(d.get("max_hp", 0)) <= 0:
		return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_INVALID_MAX_HP", "存档的血量上限异常（%d），不能使用") % int(d.get("max_hp", 0)))
	var cells: Variant = d.get("map_cells", [])
	if not (cells is Array) or (cells as Array).is_empty():
		return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_NO_MAP", "存档里没有地图，不能使用"))
	var ids := {}
	for mc: Variant in cells:
		if not (mc is Dictionary) or not (mc as Dictionary).has("id") \
				or not (mc as Dictionary).has("type"):
			return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_INVALID_MAP_CELL", "存档的地图格子结构损坏，不能使用"))
		ids[int((mc as Dictionary)["id"])] = true
	var layer := int(d.get("current_layer", 0))
	if not GameLayers.exists(layer):
		return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_INVALID_LAYER", "存档停在不存在的第 %d 层，不能使用") % layer)
	# current_node_id = -1 是合法的「还没落在地图格上」（开局那一刻就是这样）
	var node := int(d.get("current_node_id", -1))
	if node >= 0 and not ids.has(node):
		return _verdict(false, "content", GameI18n.ui("shared", "RUN_SAVE_INVALID_NODE", "存档停在地图上不存在的格子（%d），不能使用") % node)
	return _verdict(true, "", "")


static func _verdict(ok: bool, kind: String, msg: String) -> Dictionary:
	return {"ok": ok, "kind": kind, "msg": msg}


static func _missing_card_ids(ids: Array) -> Array[int]:
	## 这些 id 里，**当前卡库没有**的有哪些（去重、保序）。空数组 = 全都在。
	var out: Array[int] = []
	if ids.is_empty():
		return out
	var repo := CardRepo.load_json()
	var seen := {}
	for v: Variant in ids:
		var cid := int(v)
		if cid <= 0 or seen.has(cid):
			continue
		seen[cid] = true
		if repo.get_card(cid) == null:
			out.append(cid)
	return out


static func _missing_relic_ids(ids: Array) -> Array[int]:
	var out: Array[int] = []
	if ids.is_empty():
		return out
	var repo := RelicRepo.load_json()
	var seen := {}
	for v: Variant in ids:
		var rid := int(v)
		if rid <= 0 or seen.has(rid):
			continue
		seen[rid] = true
		if repo.get_relic(rid) == null:
			out.append(rid)
	return out


static func _ids_text(ids: Array[int]) -> String:
	## 提示里最多列 5 个 id（别让一句话长到把界面顶出去）。
	var parts: PackedStringArray = PackedStringArray()
	for i in mini(ids.size(), 5):
		parts.append(str(ids[i]))
	if ids.size() > 5:
		parts.append("…")
	return "、".join(parts)


static func _fail(kind: String, msg: String, quarantine := false, reason := "") -> void:
	## R486：一次失败的统一出口 —— 记原因（给界面）+ 按需隔离（留证据）。
	last_error_kind = kind
	last_error = msg
	if quarantine:
		_quarantine(reason if reason != "" else kind)


static func _looks_unreadable(path: String) -> bool:
	## 「这份档我们自己读不懂」—— 要么包都解不开，要么是判过「来自更新版本」的那一份。
	## ⚠️ 只用于**写档前**决定要不要先留 `.bad`，不要拿它当读档判据（读档走 `validate()`）。
	if not _readable(path):
		return true
	return protects_save()


static func _stamp_of(path: String) -> String:
	## 文件指纹（长度 + 修改时间）。用来认「还是不是刚才那份档」——
	## 存档被同步 / 重写之后指纹就变了，`has_save()` 自动解封。
	if not FileAccess.file_exists(path):
		return ""
	return "%d:%d" % [FileAccess.get_file_as_string(path).length(),
			FileAccess.get_modified_time(path)]


# ------------------------------------------------------------ 删除

static func clear_save(src := "") -> void:
	## 删档。R377：带上 `src` 才会写进 `save_trace.log` ——
	## 「谁把玩家的档删了」这个问题光靠读代码猜不出来，必须留证据。
	##
	## R640：**删没删掉必须当真**。旧写法无条件 `remove_absolute()` 然后照写
	## `CLEAR by xxx` —— 文件被占用（双开 / 杀软 / 同步盘）时删除会失败，
	## 日志里却写着「已清」，于是通关后盘上那份档还在、标题页照旧亮「继续游戏」，
	## 而现场日志完全对不上（查了两轮才想到要看文件本身）。
	## 现在：删一次 → 复查 → 还在就重试一次并留 `DELETE-FAIL`，让下次排查有据可查。
	var err := _remove(SAVE_PATH)
	if err != OK and FileAccess.file_exists(SAVE_PATH):
		err = _remove(SAVE_PATH)
		if err != OK:
			push_warning("RunSave：存档删不掉（err=%d）—— 下次启动可能还会亮「继续游戏」" % err)
			_trace("DELETE-FAIL %s err=%d" % [SAVE_PATH, err])
	_blocked_stamp = ""
	last_error = ""
	last_error_kind = ""
	_resume_stamp = ""          # R640：档没了 → 「有没有档」的缓存立刻作废
	if src != "":
		_trace("CLEAR by %s" % src)
	# 顺手把伴侣文件也收干净，别留下让 `_recover_tmp()` 误判的孤儿
	# ⚠️ **不删 `.bad`** —— 那是「档坏了 / 来自新版本」时留给玩家和我们的现场（R377），
	#    清档顺手把它删掉等于把唯一能事后查证的东西抹了。
	for suf: String in [".tmp", ".prev"]:
		var p2 := SAVE_PATH + suf
		if FileAccess.file_exists(p2):
			_remove(p2)


static func _remove(path: String) -> int:
	## R640：删一个文件并**把结果交回去**（`DirAccess.remove_absolute` 的返回值以前没人看）。
	## 文件本来就不存在 = 已经达成目标，直接 OK。
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ------------------------------------------------------------ R377 取证 / 自愈

static func _readable(path: String) -> bool:
	## 只判「这份文件能不能当成一份存档读出来」，**不写 RunState**。
	if not FileAccess.file_exists(path):
		return false
	var root: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if not (root is Dictionary):
		return false
	if int((root as Dictionary).get("__runsave__", 0)) != FORMAT:
		return false
	var d: Variant = (root as Dictionary).get("d", null)
	return d is Dictionary and not (d as Dictionary).is_empty()


static func _recover_tmp() -> void:
	## R377：把「上次没换上的新档」提回来。.tmp 是**完整写完并自检过**才会 rename 的，
	## 所以只要正式档不在、.tmp 能读，它就是玩家那一局的最新状态。
	var tmp := SAVE_PATH + ".tmp"
	if not FileAccess.file_exists(tmp):
		return
	if FileAccess.file_exists(SAVE_PATH):
		# 正式档还在（上次其实成功了，.tmp 是残留）→ 丢掉残留
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return
	if not _readable(tmp):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.rename(tmp, SAVE_PATH) == OK:
		_trace("RECOVER-TMP 把上次没换上的存档提升为正式档")


static func _quarantine(reason: String) -> void:
	## R377：出问题的档**不删**，改名成 `run_save.sav.bad` 留着。
	## 一是取证（「不能继续」到底档里长什么样，看这个文件就知道），
	## 二是万一判定过严，玩家还有机会捞回来。
	var bad := SAVE_PATH + ".bad"
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(bad))
	_trace("QUARANTINE(%s) → run_save.sav.bad" % reason)


static func _trace(msg: String) -> void:
	## R377：存档事故的**唯一取证口**（`user://save_trace.log`，留最近 200 行）。
	## **只在真实游玩时写** —— headless / 出图 / 回归套件一律不写，
	## 免得把测试噪声混进玩家现场。
	if DisplayServer.get_name() == "headless":
		return
	var args := OS.get_cmdline_user_args()
	if "--screenshot" in args or "--demo" in args:
		return
	var line := "%s %s" % [Time.get_datetime_string_from_system(), msg]
	var lines: PackedStringArray = PackedStringArray()
	if FileAccess.file_exists(TRACE_FILE):
		lines = FileAccess.get_file_as_string(TRACE_FILE).split("\n", false)
	lines.append(line)
	while lines.size() > TRACE_KEEP:
		lines.remove_at(0)
	var f := FileAccess.open(TRACE_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()


# ------------------------------------------------------------ 工具

static func _drop_unknown_relics(ids: Array[int]) -> Array[int]:
	## R652：剔除 relics.json 里已不存在的道具 id（旧存档可能残留已删除的 6003 鸡煲）。
	## 下游有四十余处 `get_relic()` 直接取属性，读档时先清一遍，免得 null 一路传下去。
	var repo := RelicRepo.load_json()
	var out: Array[int] = []
	for id: int in ids:
		if repo.get_relic(id) != null:
			out.append(id)
	return out


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
