extends RefCounted
## 二级界面的「返回去哪」临时记录（R590）。
##
## 为什么需要：`SceneFx.goto(path)` 只带目标、不带来源，而图鉴 / 故事从
## 「百科」进来时，返回应该退回百科而不是一路弹回标题 —— 玩家刚从那页来，
## 丢回标题等于把他刚走过的路重走一遍。
##
## 用法（只有三步，别扩散）：
##   1. 上级页面跳出去之前 `UiRoute.set_back("res://scenes/codex.tscn")`；
##   2. 下级页面的返回按钮读 `has_back()` 决定文案、`take_back()` 决定去向；
##   3. 回到标题（或任何顶层页面）时 `clear()`，别把旧去向留给下一轮。
##
## ⚠️ `take_back()` 会**顺手清空** —— 不清的话，下次从别处进故事页会莫名退回百科。
## ⚠️ 这是 static var（脚本级），跨场景存活；不要拿它记状态，只记「这一次从哪来」。

static var _back: String = ""


static func set_back(path: String) -> void:
	_back = path


static func has_back() -> bool:
	return _back != ""


static func peek() -> String:
	## 只看不取（画返回文案时用）。
	return _back


static func take_back() -> String:
	## 取出并清空：调用方拿到空串就按「回标题」处理。
	var p := _back
	_back = ""
	return p


static func clear() -> void:
	_back = ""
