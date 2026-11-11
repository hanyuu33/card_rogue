class_name SteamAchievements
extends RefCounted
## Steam 专有成就体系（R576）。
##
## 与 game 内 story 成就（`stories.json` → 解锁剧情段）**完全独立**：
##   * story 成就 = 游戏内「剧情解锁条件」，数据在 stories.json / ProfileData，解锁剧情用。
##   * Steam 成就 = Steamworks 后台定义的**进度徽章**，通过 Steam API 解锁，展示在商店页。
##
## 桥接层设计 —— GodotSteam（GDExtension）是**可选外部依赖**：
##   * 未装插件 / 本地开发 / 测试版 → `Engine.has_singleton("Steam")` 为 false，
##     全部方法静默跳过，游戏照常运行。
##   * ⚠️ 本文件**从不直接引用 `Steam` 标识符**（走 `Engine.get_singleton` + `call` 反射）——
##     否则没装 GodotSteam 时会在编译期 Parse Error，把整个工程打崩。
##   * 安装 GodotSteam 并导出发行后 → 成就自动解锁，所有调用点一行不用改。
##
## Steamworks 后台需按下面 `API_*` 常量名创建**同名**成就（配置清单见
## release/steam_achievements.md）。

# ------------------------------------------------------------ 成就 API 名（Steamworks 后台照此建）
const API_FIRST_STEP := "FIRST_STEP"       # 初次启程：开始第一局
const API_FIRST_BOSS := "FIRST_BOSS"       # 直面恐惧：见到第一层 Boss
const API_LAYER2_CLEAR := "LAYER2_CLEAR"   # 深入腹地：打通第二层
const API_FULL_CLEAR := "FULL_CLEAR"       # 完整通关：打通第三层（真胜利）
const API_CLEAR_FOREST := "CLEAR_FOREST"   # 森林精魄通关
const API_CLEAR_ROGUE := "CLEAR_ROGUE"     # 暗影刺客通关
const API_CLEAR_MECH := "CLEAR_MECH"       # 机械之心通关
const API_CLEAR_HARD := "CLEAR_HARD"       # 高难度通关：难度 ≥ HARD_DIFF

## 达到该难度（含）的真通关算「高难度通关」。
const HARD_DIFF := 5

## 职业 → 通关成就 API 名。
const CLEAR_API_BY_CLASS := {
	PlayerClass.DRUID: API_CLEAR_FOREST,
	PlayerClass.ROGUE: API_CLEAR_ROGUE,
	PlayerClass.MECH: API_CLEAR_MECH,
}


# ------------------------------------------------------------ 桥接（唯一入口）

static func _steam() -> Object:
	## 拿 GodotSteam 的 Steam singleton（未装 → null）。不直接引用 `Steam` 标识符。
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


static func init() -> void:
	## 初始化 Steamworks（GodotSteam）。未装插件时静默跳过。
	## 建议在游戏启动早期（title_scene._ready）调一次 —— Steam 未初始化时
	## `setAchievement` 会被 `isSteamRunning` 挡住，成就解不出来。
	var steam := _steam()
	if steam == null:
		return
	if steam.has_method("steamInit"):
		steam.call("steamInit")


static func unlock(api: String) -> void:
	## 解锁一个 Steam 成就。幂等（Steam 端重复解锁无害）。
	## 未装 GodotSteam / 未初始化 → 静默跳过，绝不影响测试版 / 本地开发。
	var steam := _steam()
	if steam == null:
		return
	if steam.has_method("isSteamRunning") and not bool(steam.call("isSteamRunning")):
		return
	if steam.has_method("setAchievement"):
		steam.call("setAchievement", api)


# ------------------------------------------------------------ 事件钩子（物理事件点，独立于 GameBuild 版本闸门）

static func note_first_step() -> void:
	## 开始第一局（run_state.start_run）。Steam 成就幂等，重复开局无害。
	unlock(API_FIRST_STEP)


static func note_first_boss() -> void:
	## 见到第一层 Boss（与 UnlockSystem.note_boss_seen 同源，但独立触发）。
	unlock(API_FIRST_BOSS)


static func note_layer2_clear() -> void:
	## 打通第二层（击败第二层 Boss）。
	unlock(API_LAYER2_CLEAR)


static func note_game_clear(cid: String, difficulty: int) -> void:
	## 真通关一次（打通第三层）—— 完整通关 + 对应职业通关 + 高难度通关三合一。
	unlock(API_FULL_CLEAR)
	var api: String = CLEAR_API_BY_CLASS.get(cid, "")
	if api != "":
		unlock(api)
	if difficulty >= HARD_DIFF:
		unlock(API_CLEAR_HARD)
