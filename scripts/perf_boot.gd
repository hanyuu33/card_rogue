extends Node
## R747：桌面端限帧（`Engine.max_fps`）。
##
## 为什么需要它：手机的画面由系统合成器钉在 60 / 120，而**电脑版不锁帧**——
## 本机实测地图界面跑到 **300fps**（`DisplayServer.window_get_vsync_mode()` 报 1，
## 说明有些驱动上垂直同步并不生效）。地图是一整块自绘画布，**每一帧都要把
## 整屏背景 + 所有格子 + 图标 + 迷雾重画一遍**，300fps 等于把显存带宽按 5 倍消耗：
## 强显卡看不出来，老显卡 / 集显会被打满，帧间隔开始漂 → 玩家看到的就是
## 「手机不卡、电脑版卡」。把上限钉到显示器刷新率，一秒的重画量立刻回到手机同档。
##
## ⚠️ 上限取「刷新率 + 2」而不是正好刷新率：垂直同步真的生效时，若限帧与刷新
##    完全相等，帧预算和呈现时刻会互相顶到边界，个别驱动会掉成半帧率（60 → 30）。
##    多给 2 帧让垂直同步当主节拍，限帧只作兜底。
##
## R749（店长口径）：桌面端固定锁 **99fps**。只有「显示器刷新率本身低于 99」时
## 才退回「刷新率 + 2」（60Hz 屏锁 62）—— 否则限帧高于刷新率会重新引入帧间隔漂移。

const DESKTOP_MAX_FPS := 99


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 无头（回归 / 出图流水线）不干预。
	if DisplayServer.get_name() == "headless":
		return
	# 手机 / 掌机由系统合成器限帧，别插手。
	if OS.has_feature("mobile"):
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var hz := 60
	var r := DisplayServer.screen_get_refresh_rate()
	if r > 1.0:
		hz = int(round(r))
	hz = clampi(hz, 30, 240)
	Engine.max_fps = DESKTOP_MAX_FPS if hz > DESKTOP_MAX_FPS else hz + 2
	print("[PerfBoot] 刷新率 %.1f → max_fps=%d，vsync=%d"
			% [r, Engine.max_fps, DisplayServer.window_get_vsync_mode()])
