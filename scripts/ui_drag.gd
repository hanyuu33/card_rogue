extends RefCounted
## R405：滚动面板的「手势 → 位移」**唯一口**（滚轮 / 鼠标按住拖 / 触屏拖）。
##
## ## 为什么要有这一层
##   用户报「安卓端菜单无法滑动，遗物 / 卡组多了只能看最上面一排」——
##   全工程的滚动原先**只认 `MOUSE_BUTTON_WHEEL_*`**（`deck_viewer` / `relic_viewer` /
##   战斗与地图的道具面板 / 记录页 / 商店 …都是各写一遍），而触屏设备**压根没有滚轮**：
##   面板一装不下，下半截就永远看不到，也没有第二种翻法。
##   逐个面板各补一套手势，迟早出现「这个能滑那个不能」的偏差 —— 所以收成一个口。
##
## ## 为什么不处理 `InputEventScreenDrag`
##   Godot 4 默认开着 `input_devices/pointing/emulate_mouse_from_touch`：**同一根手指**
##   会先产生一条 `ScreenTouch` / `ScreenDrag`，**同时**被模拟成 `MouseButton` / `MouseMotion`。
##   两套都收 = 一次拖动滚两倍（实测踩过）。触摸模拟出来的 `MouseMotion` 自带
##   `button_mask` 含左键，所以**只认 mouse 事件就能覆盖安卓**，且桌面「按住拖」
##   与触屏是完全同一套手感。
##
## ## 为什么用 `relative`（增量）而不是「按下点 - 当前点」（绝对）
##   增量式不需要调用方维护按下点，滚出边界被 clamp 之后也不会「攒着一股劲突然跳一下」；
##   调用方只需要一句 `_scroll = clampf(_scroll + delta, 0, max)`。

## 位移超过它才算「拖动」，否则算「点按」（点按要能穿透成点击 / 关闭）。
const SLOP := 8.0


static func scroll_delta(event: InputEvent, wheel_step: float) -> float:
	## 这一次事件该滚多少像素。**正数 = 看到更靠下的内容**。
	## 返回 0.0 = 与滚动无关（调用方照常往下判点击）。
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return 0.0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -wheel_step
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return wheel_step
		return 0.0
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		# 没按住左键 = 只是路过（悬停），不是拖动
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return 0.0
		return -mm.relative.y
	return 0.0


static func drag_moved(press_pos: Vector2, now_pos: Vector2) -> bool:
	## 这次按下到底算不算「拖动」（超过 SLOP 才算）。
	## 松手时用它决定「抬起是点击还是拖动的收尾」—— 少了这一句，触屏一滑就把面板关了。
	return press_pos.distance_to(now_pos) > SLOP
