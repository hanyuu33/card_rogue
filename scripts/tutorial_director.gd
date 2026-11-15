class_name TutorialDirector
extends RefCounted
## R744：新手教程的**调度器**（什么时候弹、弹完记什么）。
##
## 判据只有一句：`ProfileData.is_tutorial_seen(id)`。所以
##   · 老玩家（档案里已有）→ 一条都不弹；
##   · 新档 / 清过进度 → 每条只弹一次；
##   · 换关卡、换职业、重开一局 → 不影响（教程绑的是「初次体验」）。
##
## 宿主场景只需要做两件事：
##   ① 在合适时机 `TutorialDirector.play(self, id)` 或 `play_chain(self, [...])`；
##   ② 实现 `tutorial_cue_rects(cue: String) -> Array`（返回**屏幕坐标**矩形）。
## 出图模式（`--screenshot`）由调用方自己判断跳过，别让截图里飘着对话框。

const OVERLAY_NAME := "TutorialOverlay"


static func disabled() -> bool:
	## headless（回归 / 出包脚本）一律不弹：它会暂停整棵树，
## 而 smoke 那套「关菜单必须恢复暂停」的用例正在测这个状态 —— 弹层一进来就误红。
	## 与 `story_unlock_toast.gd` 同一个判法。
	return DisplayServer.get_name() == "headless"


static func busy(host: Node) -> bool:
	return host != null and host.get_node_or_null(OVERLAY_NAME) != null


static func play(host: Node, id: String) -> TutorialOverlay:
	## 弹一条。已看过 / 没有这个 id / 已有弹层 / 正在暂停 → 返回 null。
	if host == null or disabled() or busy(host):
		return null
	if not TutorialScript.unseen(id):
		return null
	var ov := TutorialOverlay.play(host, TutorialScript.pages(id), func() -> void:
		ProfileData.mark_tutorial_seen(id)
		ProfileData.flush())
	return ov


static func play_chain(host: Node, ids: Array) -> void:
	## 按顺序连播若干条（例如「先教走格子，再教巧克力」）。
	## 只把**还没看过**的排进队列；前一条关掉之后延迟一帧再开下一条 ——
	## 同一帧里连开两个弹层会互相压暂停状态，第二个会立刻被第三个顶掉。
	if disabled():
		return
	var todo: Array = []
	for id: String in ids:
		if TutorialScript.unseen(id):
			todo.append(id)
	_play_next(host, todo)


static func _play_next(host: Node, todo: Array) -> void:
	if host == null or not is_instance_valid(host) or todo.is_empty():
		return
	var id: String = str(todo.pop_front())
	var ov := TutorialOverlay.play(host, TutorialScript.pages(id), func() -> void:
		ProfileData.mark_tutorial_seen(id)
		ProfileData.flush()
		if todo.is_empty() or not is_instance_valid(host):
			return
		var t := host.get_tree().create_timer(0.08, true, false, true)
		t.timeout.connect(func() -> void:
			if is_instance_valid(host):
				_play_next(host, todo)))
	if ov == null and not todo.is_empty():
		_play_next(host, todo)
