class_name SteamAchievements
extends RefCounted
## Steam 专有成就体系（R576；R577 补 AppID 接入）。
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

# ------------------------------------------------------------ AppID（留空 = 发行形态）

## Steamworks 后台的 AppID。**留空（0）就是发行形态的正确值**，不是待补的半成品：
##   * 从 Steam 客户端启动时，客户端会注入 `SteamAppId` 环境变量，`steamInitEx(0)`
##     自己会去读它 —— 发行包不需要带任何 AppID 文件，也**不该**带
##     （带了会覆盖客户端注入的值；Valve 明确要求发行包不含 steam_appid.txt）。
##   * 只有**本地离线调试**（没开 Steam 客户端、或跑测试 build）才需要补一个值：
##     填这里，或改用项目根的 `steam_appid.txt`（模板见 steam_appid.txt.template）。
##   * 自有 App 在 Steamworks 后台正式上线前，可用 Valve 公开的 Spacewar 测试 ID `480`。
const APP_ID := 0

## `init()` 的自定义状态：没装 GodotSteam。取负数，与 Steamworks 的 status 码（0/1/2/3/79…）不冲突。
const INIT_NOT_INSTALLED := -2

## 达到该难度（含）的真通关算「高难度通关」。
const HARD_DIFF := 5

## 职业 → 通关成就 API 名。
const CLEAR_API_BY_CLASS := {
	PlayerClass.DRUID: API_CLEAR_FOREST,
	PlayerClass.ROGUE: API_CLEAR_ROGUE,
	PlayerClass.MECH: API_CLEAR_MECH,
}


# ------------------------------------------------------------ 运行期状态

static var _init_done := false   ## init() 是否已跑过（幂等保护）
static var _init_ok := false     ## Steamworks 是否真的可用（决定 unlock 走不走）
static var _init_status := -1    ## 0=OK；2/20=客户端没开；79=AppID 无效；-2=没装插件
static var _init_verbal := ""    ## Steamworks 回传的失败原因（原样保留，便于排查）


# ------------------------------------------------------------ 桥接（唯一入口）

static func _steam() -> Object:
	## 拿 GodotSteam 的 Steam singleton（未装 → null）。不直接引用 `Steam` 标识符。
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


static func _read_local_appid() -> int:
	## 读项目根 `steam_appid.txt`（本地调试用，**不入库**，见 steam_appid.txt.template）。
	## 不存在 / 内容不是整数 → 0（= 交给环境变量，发行形态就是这个值）。
	const P := "res://steam_appid.txt"
	if not FileAccess.file_exists(P):
		return 0
	var f := FileAccess.open(P, FileAccess.READ)
	if f == null:
		return 0
	var t := f.get_as_text().strip_edges()
	f.close()
	if not t.is_valid_int():
		return 0
	return int(t)


static func effective_app_id() -> int:
	## 本次初始化实际用的 AppID：常量优先 → 本地 steam_appid.txt → 0（交给环境变量）。
	## 三者都没有时返回 0 —— 这正是发行形态（Steam 客户端注入 SteamAppId）。
	if APP_ID > 0:
		return APP_ID
	return _read_local_appid()


static func init() -> void:
	## 初始化 Steamworks（GodotSteam）。幂等；**未装插件 / 初始化失败都不中断游戏**，
	## 只把原因记进 `status_text()`。在 title_scene._ready 调一次 —— Steam 没起来时
	## `setAchievement` 不生效（成就静默丢弃，不影响游玩）。
	if _init_done:
		return
	_init_done = true
	var steam := _steam()
	if steam == null:
		_init_status = INIT_NOT_INSTALLED
		_init_verbal = "GodotSteam not installed"
		return
	var app_id := effective_app_id()
	if steam.has_method("steamInitEx"):
		# steamInitEx 回 {status:int, verbal:String}，比只回 bool 的 steamInit 多一层
		# 失败原因（2=客户端没开 / 79=AppID 无效），正好写进 status_text()。
		var r: Variant = steam.call("steamInitEx", app_id)
		if r is Dictionary:
			_init_status = int((r as Dictionary).get("status", -1))
			_init_verbal = str((r as Dictionary).get("verbal", ""))
			_init_ok = _init_status == 0
	elif steam.has_method("steamInit"):
		_init_ok = bool(steam.call("steamInit", app_id))
		_init_status = 0 if _init_ok else 1
	if _init_ok:
		print("[Steam] 初始化成功（AppID %d）" % app_id)
	else:
		push_warning("[Steam] 初始化失败（AppID %d / status %d）：%s —— 成就跳过，游戏照常"
				% [app_id, _init_status, _init_verbal])


static func is_ready() -> bool:
	## Steamworks 是否真的可用（装了插件 + 初始化成功）。UI 想挂成就入口时用它判断。
	return _init_ok


static func status_text() -> String:
	## 人类可读的运行状态 —— 给设置页 / 调试面板 / 反馈日志用。
	if _steam() == null:
		return "未安装 GodotSteam（成就功能关闭）"
	if not _init_done:
		return "尚未初始化"
	if _init_ok:
		# APP_ID 留空时实际用的是客户端注入的 AppID，不能显示成「AppID 0」误导排查。
		var aid := effective_app_id()
		if aid > 0:
			return "已连接 Steam（AppID %d）" % aid
		return "已连接 Steam（AppID 由 Steam 客户端注入）"
	if _init_status == 2 or _init_status == 20:
		return "Steam 客户端未运行"
	if _init_status == 79:
		return "AppID 无效或未配置（填 SteamAchievements.APP_ID，或放 steam_appid.txt）"
	return "初始化失败（status %d）：%s" % [_init_status, _init_verbal]


static func reset_for_test() -> void:
	## **仅供测试**：复位静态状态让 init() 能重跑。别在游戏逻辑里调。
	_init_done = false
	_init_ok = false
	_init_status = -1
	_init_verbal = ""


static func unlock(api: String) -> void:
	## 解锁一个 Steam 成就。幂等（Steam 端重复解锁无害）。
	## 未装 GodotSteam / 未初始化成功 → 静默跳过，绝不影响测试版 / 本地开发。
	if not _init_ok:
		return
	var steam := _steam()
	if steam == null or not steam.has_method("setAchievement"):
		return
	if not bool(steam.call("setAchievement", api)):
		return
	# 立刻落盘：否则要等 Steam 正常退出才提交，崩溃 / 强杀会丢成就。
	if steam.has_method("storeStats"):
		steam.call("storeStats")


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
