class_name UiGate
extends RefCounted
## UI 覆盖层登记（R121）—— 「顶上盖着一层满屏面板时，下面的常驻道具控件不许再跟着鼠标」。
##
## 为什么需要它：
##   道具悬停（RelicViewer 的速览浮层 / 战斗右栏的道具说明 / 地图右栏的道具说明）
##   判定的是**鼠标坐标**，不是 Godot 的 GUI 命中。面板盖上去以后，鼠标坐标照样落在
##   道具区，于是出现「看不见道具栏却弹出道具悬浮说明」（R121 用户报告：
##   查看卡牌奖励与事件时，鼠标划过右上角就会触发道具栏的悬浮效果）。
##
## 约定（唯一口）：
##   任何「满屏 + 接管鼠标（`mouse_filter = MOUSE_FILTER_STOP`）」的覆盖层，
##   在打开 / 关闭时 push / pop 自己的 id；场景被释放时必须 pop（见 `_exit_tree`）。
##   常驻控件只要问一句 `UiGate.blocked()`。
##
## ⚠️ 登记表描述的是「这个覆盖层**现在开着吗**」，不是「开过几次」——
##    所以 push 是**幂等**的（同一个 id 重复 push 不会重复计数）。
##    这样每个覆盖层只需要在自己的开关唯一口里写一对 push / pop，不用维护计数。

static var _ids: Array[String] = []


static func push(id: String) -> void:
	if not _ids.has(id):
		_ids.append(id)


static func pop(id: String) -> void:
	_ids.erase(id)


static func blocked() -> bool:
	## 当前有没有覆盖层压着 → 下层控件必须停止响应鼠标悬停。
	return not _ids.is_empty()


static func blockers() -> Array[String]:
	## 当前登记在案的覆盖层 id（排查用）。
	return _ids.duplicate()


static func reset() -> void:
	## 测试专用：冒烟用例之间必须互不污染（场景里开着面板就被 free 掉时也该调它兜底）。
	_ids.clear()
