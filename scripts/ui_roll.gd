extends RefCounted
## 数值滚动唯一口（R151 批 1 · P0-3，动效设计 §三-3）——
## HP / 费用 / 巧克力这类「跳变数字」统一从旧值滚到新值（设计口径 180~260ms，取 220）。
##
## 用法（绘制处）：
##   `str(实际值)`  →  `str(UiRoll_show("键", 实际值))`
## 滚动进行中调用方必须逐帧重绘：`_process` 里 `if UiRoll_rolling("键"): queue_redraw()`。
## 探针 / 演示钉帧（--screenshot）下用 `UiRoll_snap("键", 实际值)` 直接钉死，不出中间值。
##
## ⚠️ 状态是 **static**（进程内跨场景共享）—— 巧克力在战斗/事件回来后才变化，
##    跨场景也能从旧值接着滚；新进程首调静默建档（首值不滚，探针天然安全）。
## ⚠️ 不写 class_name（同 ui_theme.gd：headless 下全局类名缓存认不到，一律 preload）。

static var _st := {}   # key -> {from, to, start, dur}

const DEFAULT_DUR := 220   # 设计稿口径 180~260ms，取中


static func value(key: String, target: float, dur := DEFAULT_DUR) -> float:
	## 当前应显示的值。目标变了 → 从当前显示值重新起滚（不打断视觉连续性）。
	var n := Time.get_ticks_msec()
	if not _st.has(key):
		_st[key] = {"from": target, "to": target, "start": n, "dur": dur}
		return target
	var c: Dictionary = _st[key]
	if not is_equal_approx(float(c["to"]), target):
		var v := _val(c, n)
		_st[key] = {"from": v, "to": target, "start": n, "dur": dur}
		return v
	return _val(c, n)


static func snap(key: String, target: float) -> void:
	## 立即钉死（探针 / 初始化），之后的 value 直接返回 target。
	_st[key] = {"from": target, "to": target, "start": Time.get_ticks_msec(), "dur": 1}


static func rolling(key: String) -> bool:
	## 还在滚（调用方据此逐帧重绘）。
	if not _st.has(key):
		return false
	var c: Dictionary = _st[key]
	return not is_equal_approx(_val(c, Time.get_ticks_msec()), float(c["to"]))


static func _val(c: Dictionary, n: int) -> float:
	var t := clampf(float(n - int(c["start"])) / float(maxi(1, int(c["dur"]))), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - t, 2.0)   # ease-out
	return lerpf(float(c["from"]), float(c["to"]), e)
