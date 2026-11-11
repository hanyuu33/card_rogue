class_name UnlockSystem
extends RefCounted
## 发布版解锁体系唯一口（R550）。
##
## 发布版（`GameBuild.is_release()`）才生效的渐进解锁：
##   * **职业**：初始只有森林精魄。累计「见到一层 Boss」1 次 → 暗影刺客；2 次 → 机械之心。
##     判据 = 进入第一层 Boss 战（打赢与否不算），见 `note_boss_seen()`。
##   * **难度**：每个职业独立。用某职业在难度 X「打通 2 层」（击败第二层 Boss）→ 该职业
##     难度上限抬到 X+1。初始各职业难度上限 = 0，见 `note_layer_two_cleared()`。
##   * **随机选择**：随机摇人时难度取「尽可能高」= `global_max_difficulty()`（已解锁职业的
##     最高难度），但**不突破**随到职业自己的上限（`min(global, cap(picked))` —— 因随到的
##     职业必已解锁，`cap ≤ global`，所以实际 = 该职业自己的最高难度）。
##
## 测试版：`is_class_unlocked` 恒 true、`difficulty_cap` 恒 = 最高档，记录照写但不生效。
## 数据实体在 `ProfileData`（unlocked_classes / class_diff / stats.boss_seen），这里只做判定。

## 职业解锁顺序：第 N 个 = 累计「见到一层 Boss」N 次后解锁。
const CLASS_ORDER: Array[String] = [PlayerClass.ROGUE, PlayerClass.MECH]


# ------------------------------------------------------------ 查询（唯一闸门口）

static func is_class_unlocked(cid: String) -> bool:
	## 该职业当前是否可选。
	if not GameBuild.is_release():
		return true
	if cid == PlayerClass.DRUID:
		return true                 # 森林精魄是起始职业，恒解锁
	return ProfileData.is_class_unlocked(cid)


static func difficulty_cap(cid: String) -> int:
	## 该职业当前**可选到的最高难度**（含）。
	if not GameBuild.is_release():
		return RunState.DIFFICULTY_COUNT - 1
	return clampi(ProfileData.class_difficulty(cid), 0, RunState.DIFFICULTY_COUNT - 1)


static func global_max_difficulty() -> int:
	## 已解锁职业中的最高难度上限（随机选择的「尽可能高」目标）。
	if not GameBuild.is_release():
		return RunState.DIFFICULTY_COUNT - 1
	var m := 0
	for cid: String in PlayerClass.ids():
		if is_class_unlocked(cid):
			m = maxi(m, difficulty_cap(cid))
	return m


static func unlocked_count() -> int:
	## 当前已解锁的职业数（发布版有意义；测试版恒 = 全职业数）。
	var n := 0
	for cid: String in PlayerClass.ids():
		if is_class_unlocked(cid):
			n += 1
	return n


# ------------------------------------------------------------ 事件钩子

static func note_boss_seen(layer: int) -> void:
	## 「见到一层 Boss」→ 累计 + 按顺序解锁职业。幂等（同一局只触发一次由调用方保证）。
	## 测试版直接 return，不写脏玩家档案。
	# R576 Steam 成就：直面恐惧（见到第一层 Boss）。独立于版本闸门 —— 幂等，
	# 未装 GodotSteam 时 SteamAchievements.unlock 内部静默跳过。
	if layer == GameLayers.LAYER_DEFAULT:
		SteamAchievements.note_first_boss()
	if not GameBuild.is_release():
		return
	if layer != GameLayers.LAYER_DEFAULT:
		return
	ProfileData.bump(ProfileData.K_BOSS_SEEN)
	var seen := ProfileData.stat(ProfileData.K_BOSS_SEEN)
	for i in CLASS_ORDER.size():
		if seen >= i + 1:
			ProfileData.unlock_class(CLASS_ORDER[i])
	ProfileData.flush()


static func note_layer_two_cleared() -> void:
	## 「打通 2 层」（击败第二层 Boss）→ 当前职业难度上限 +1（封顶最高档）。
	## 测试版直接 return。幂等：`set_class_difficulty` 只升不降，重复调也只会抬一次。
	# R576 Steam 成就：深入腹地（打通第二层）。独立于版本闸门（幂等）。
	SteamAchievements.note_layer2_clear()
	if not GameBuild.is_release():
		return
	if not RunState.run_active:
		return
	var cid := RunState.player_class
	var cur := RunState.difficulty
	if cur >= RunState.DIFFICULTY_COUNT - 1:
		return
	var nxt := maxi(ProfileData.class_difficulty(cid), cur + 1)
	if ProfileData.set_class_difficulty(cid, nxt):
		ProfileData.flush()
