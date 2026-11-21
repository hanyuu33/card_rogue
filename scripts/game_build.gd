class_name GameBuild
extends RefCounted
## 发布版 / 测试版 判定唯一口（R550）。
##
## 两版共用同一套代码与素材，只有「发布版」额外开启职业 / 难度的渐进解锁体系：
##   * 发布版：初始只有森林精魄、难度 0，按「见到一层 Boss / 打通 2 层」逐步解锁；
##   * 测试版（默认）：全部职业、全部难度直接可用 —— 开发自测走这条。
##
## 判定顺序（只要任一条成立即视为发布版）：
##   1. 测试强制位（`set_test_release()`，仅供 test_engine / test_smoke 注入）；
##   2. 导出预设注入的 feature tag `cardrogue_release`（`OS.has_feature`，
##      发布包由 `export_presets.cfg` 的 `custom_features` 写入）；
##   3. 命令行参数 `--release`（编辑器里跑发布版、出图核验用：`godot -- --release`）。
##
## 默认（编辑器 / 普通导出）三者皆不成立 → 测试版。⚠️ 新增内容要「覆盖两个版本」时，
## 数据与机制照常进测试版；只有这里的 `is_release()` 闸门之后的差异才属发布版独有。

const RELEASE_FEATURE := "cardrogue_release"

## R814 试玩版（Steam 试玩 / 展会切片）—— **与发布版正交的第三档**。
##
## 与发布版的区别不是「少一点内容」，而是**切片**：只开森林精魄 + 暗影刺客、难度上限 1、
## 每职业 60 张卡、剧情一律不可解锁、打完第二层 Boss 直接进「胜利？」结算。
## 内容仍在同一套数据里（事件 / 道具全量可用），只有 `is_demo()` 之后的差异才属试玩版独有。
##
## 判定顺序同发布版：强制位 → feature tag → 命令行 `-- --demo`。
## ⚠️ `is_release()` 在试玩版恒为 false（试玩包就算被误挂上 release tag，也不该跑
##    渐进解锁 / 图鉴「见过才收录」那一套 —— 见 `is_release()` 首行的短路）。
const DEMO_FEATURE := "cardrogue_demo"

static var _test_release := -1   # -1 = 自动；0 = 强制测试版；1 = 强制发布版（仅测试用）
static var _test_demo := -1      # -1 = 自动；0 = 强制非试玩；1 = 强制试玩（仅测试用）


static func is_demo() -> bool:
	if _test_demo >= 0:
		return _test_demo == 1
	if OS.has_feature(DEMO_FEATURE):
		return true
	return "--demo" in OS.get_cmdline_user_args()


static func is_published() -> bool:
	## R848（店长口径）：「**面向玩家的成品包**」= 发布版 或 试玩版。
	##
	## 只在「这件事是不是玩家自己的档案 / 进度」时用它 —— 图鉴「见过才收录」、
	## 收集进度分母这类口径，试玩版必须和发布版**同一套**（试玩玩家看到的图鉴行为
	## 就是正式版的行为，不能因为是试玩就全解锁）。
	##
	## ⚠️ 别在别处直接写 `is_release() or is_demo()`：以后再加一档（展会包之类）
	##    只有这一个口要改。要区分「具体是哪一档」仍用 `is_release()` / `is_demo()`。
	return is_release() or is_demo()


static func is_release() -> bool:
	## ⚠️ 试玩版优先：demo 包不进入任何「正式版独有」的分支。
	if is_demo():
		return false
	if _test_release >= 0:
		return _test_release == 1
	if OS.has_feature(RELEASE_FEATURE):
		return true
	return "--release" in OS.get_cmdline_user_args()


static func set_test_release(v: int) -> void:
	## 测试注入口：`GameBuild.set_test_release(1)` 强制进入发布版逻辑，`-1` 恢复自动判定。
	## 生产代码别调用它。
	_test_release = v


static func set_test_demo(v: int) -> void:
	## 测试注入口：`GameBuild.set_test_demo(1)` 强制进入试玩版逻辑，`-1` 恢复自动判定。
	## 生产代码别调用它。
	_test_demo = v
