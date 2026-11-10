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

static var _test_release := -1   # -1 = 自动；0 = 强制测试版；1 = 强制发布版（仅测试用）


static func is_release() -> bool:
	if _test_release >= 0:
		return _test_release == 1
	if OS.has_feature(RELEASE_FEATURE):
		return true
	return "--release" in OS.get_cmdline_user_args()


static func set_test_release(v: int) -> void:
	## 测试注入口：`GameBuild.set_test_release(1)` 强制进入发布版逻辑，`-1` 恢复自动判定。
	## 生产代码别调用它。
	_test_release = v
