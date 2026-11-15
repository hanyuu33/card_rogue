class_name DailyLeaderboard
extends Node
## R762 / D3-5：Steam 每日排行榜桥（可选依赖，反射调用，离线不阻塞）。
## 每天 + 每套规则一张榜；降序、Numeric、keep-best。上传与读取共用 find-or-create。
## 本文件绝不直接写 `Steam.xxx` 标识符，没装 GodotSteam 的工程也能解析。

signal board_ready(entries: Array)
signal board_failed(reason: String)

var _steam: Object = null
var _name := ""
var _score := 0
var _details := PackedInt32Array()
var _mode := ""
var _handle := 0


static func submit_score(date: String, rules: int, score: int,
		details := PackedInt32Array()) -> bool:
	## 返回「是否已交给 Steam 异步处理」，不是上传成功；失败不反写游戏结果。
	if not SteamAchievements.is_ready() or score < 0:
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var n: DailyLeaderboard = load("res://scripts/daily_leaderboard.gd").new()
	n._steam = Engine.get_singleton("Steam")
	n._name = DailyChallenge.leaderboard_name(date, rules)
	n._score = score
	n._details = details
	n._mode = "upload"
	tree.root.add_child(n)
	n._begin()
	return true


static func request_board(host: Node, date: String, rules: int) -> DailyLeaderboard:
	## 调用方连接 board_ready / board_failed。Steam 不可用返回 null，UI 显示本地榜。
	if host == null or not SteamAchievements.is_ready():
		return null
	var n: DailyLeaderboard = load("res://scripts/daily_leaderboard.gd").new()
	n._steam = Engine.get_singleton("Steam")
	n._name = DailyChallenge.leaderboard_name(date, rules)
	n._mode = "download"
	host.add_child(n)
	n._begin()
	return n


func _begin() -> void:
	if _steam == null or _mode == "":
		_fail("offline")
		return
	_steam.connect("leaderboard_find_result", _on_find)
	# 2 = Descending（高分优先），1 = Numeric。常量值属于 Steamworks 稳定 ABI。
	_steam.call("findOrCreateLeaderboard", _name, 2, 1)


func _on_find(handle: int, found: int) -> void:
	# 同一天可能有上传与读取两个请求，句柄名过滤可避免互相吃掉回调。
	if _steam == null:
		return
	var found_name := ""
	if _steam.has_method("getLeaderboardName"):
		found_name = str(_steam.call("getLeaderboardName", handle))
	if found_name != "" and found_name != _name:
		return
	_disconnect_find()
	if found != 1:
		_fail("not_found")
		return
	_handle = handle
	if _mode == "upload":
		_steam.connect("leaderboard_score_uploaded", _on_uploaded)
		# true = keep best；每天一次，但续档产生的中断→终局更新也不会把高分压回低分。
		_steam.call("uploadLeaderboardScore", _score, true, _details, _handle)
	elif _mode == "download":
		_steam.connect("leaderboard_scores_downloaded", _on_downloaded)
		# 0 = GLOBAL，取前 10 名。
		_steam.call("downloadLeaderboardEntries", 1, 10, 0, _handle)


func _on_uploaded(success: int, handle: int, score: Dictionary) -> void:
	if handle != _handle:
		return
	if success == 1:
		print("[Daily] Steam 成绩已上传：%s = %d（名次 %s）" % [
				_name, int(score.get("score", _score)), str(score.get("new_rank", "?"))])
	else:
		push_warning("[Daily] Steam 成绩上传失败：" + _name)
	queue_free()


func _on_downloaded(message: String, handle: int, entries: Array) -> void:
	if handle != _handle:
		return
	if message == "ok" or message == "":
		board_ready.emit(entries)
	else:
		board_failed.emit(message)
	queue_free()


func _disconnect_find() -> void:
	if _steam != null and _steam.is_connected("leaderboard_find_result", _on_find):
		_steam.disconnect("leaderboard_find_result", _on_find)


func _fail(reason: String) -> void:
	board_failed.emit(reason)
	queue_free()


func _exit_tree() -> void:
	_disconnect_find()
