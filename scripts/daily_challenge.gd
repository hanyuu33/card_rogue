class_name DailyChallenge
extends RefCounted
## R762 每日挑战：日期根种子 / 固定配置 / 每日一次 / 本地成绩。
##
## 这里不生成另一套玩法：确认配置后仍走 RunState.start_run → 地图 → 战斗 → RunRecord。
## 本模块只拥有「今天是什么局、今天是否已经开过、成绩是多少」三本账。
## Steam 上传由 DailyLeaderboard 负责；离线时本地成绩照常保存。

const RULES_VERSION := 2
## ⚠️ 必须与 `DailyModifiers.RULES_VERSION` 保持一致 —— 两处一起加，别只改一边：
## 规则一改，同一天的局就该变，而旧成绩必须留在旧板上（榜名带 V 号）。
const PATH := "user://daily_challenge.json"
const TEST_PATH := "user://daily_challenge_test.json"
const FORMAT := 1
const FIXED_DIFFICULTY := 2

static var _path := PATH
static var _loaded := false
static var _attempts: Dictionary = {}


static func today() -> String:
	## UTC 日历日：全球同日同榜；不外连校时，回拨到已玩日期仍受原记录约束。
	return Time.get_date_string_from_system(true)


static func set_test_mode() -> void:
	## 与 ProfileData / RunSave 同纪律：回归连测试文件都从零开始，绝不碰玩家成绩。
	_path = TEST_PATH
	_loaded = true
	_attempts = {}
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


static func valid_date(date: String) -> bool:
	var p := date.split("-")
	if p.size() != 3 or p[0].length() != 4 or p[1].length() != 2 or p[2].length() != 2:
		return false
	for s: String in p:
		if not s.is_valid_int():
			return false
	var y := int(p[0])
	var m := int(p[1])
	var d := int(p[2])
	if y < 2026 or m < 1 or m > 12 or d < 1:
		return false
	var days := [31, 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28,
			31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return d <= int(days[m - 1])


static func seed_for_date(date: String, rules := RULES_VERSION) -> int:
	## 独立根种子：绝不能拿 RunState.seed_of("daily", yyyymmdd) 代替 ——
	## 那个函数还依赖上一局的 run_seed，跨启动就不保证同日同局。
	var text := "R762|daily|%d|%s" % [rules, date]
	var h := 2166136261 & 0x7FFFFFFF
	for i in text.length():
		h = (h ^ text.unicode_at(i)) & 0x7FFFFFFF
		h = (h * 16777619) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	h = (h * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return maxi(1, h)


static func config_for_date(date: String) -> Dictionary:
	## 固定配置唯一口。职业轮换只读可见三职业，隐藏职业永不进每日池。
	##
	## R767：从「固定角色 + 固定难度」升级成「固定角色 + 固定难度 + 每日修饰 + 随机卡组」。
	## 两条都从同一个根种子派生，所以同一天在任何机器上算出来完全一样；
	## 而修饰池 / 卡池一旦变动就得升 `RULES_VERSION`，让旧榜留在旧规则下。
	var root := seed_for_date(date)
	var ids := PlayerClass.ids()
	var cid := ids[root % ids.size()]
	var mods := DailyModifiers.roll(root)
	var fx := DailyModifiers.fx_of(mods)
	return {
		"date": date,
		"rules": RULES_VERSION,
		"seed": root,
		"class": cid,
		"difficulty": FIXED_DIFFICULTY,
		"deck": DailyModifiers.roll_deck(root, cid, fx),
		"mods": mods,
		"fx": fx,
	}


static func begin_attempt(cfg: Dictionary) -> bool:
	## 在真正开局前落账：退出再进也不能靠反复开新局刷新同一日挑战。
	## 续档不走这里；标题的「继续游戏」直接恢复原局，不算第二次。
	var date := str(cfg.get("date", ""))
	if not valid_date(date):
		return false
	_ensure_loaded()
	if _attempts.has(date):
		return false
	_attempts[date] = {
		"date": date,
		"rules": int(cfg.get("rules", RULES_VERSION)),
		"seed": int(cfg.get("seed", 0)),
		"class": str(cfg.get("class", "")),
		"difficulty": int(cfg.get("difficulty", FIXED_DIFFICULTY)),
		"started": int(Time.get_unix_time_from_system()),
		"result": "playing",
		"score": 0,
	}
	if not _save():
		_attempts.erase(date)   # 写盘失败不白扣次数；玩家可处理磁盘问题后重试。
		return false
	return true


static func attempt_for(date: String) -> Dictionary:
	_ensure_loaded()
	var a: Variant = _attempts.get(date, {})
	return (a as Dictionary).duplicate(true) if a is Dictionary else {}


static func has_attempt(date: String) -> bool:
	_ensure_loaded()
	return _attempts.has(date)


static func score_of(entry: Dictionary) -> int:
	## 高分优先。进度是主分，通关大额加分；血量/金币只作同进度下的细分。
	## 不用现实日期、Steam id 或随机数，离线榜与 Steam 榜拿到的是同一个分数。
	var score := maxi(0, int(entry.get("layer", 0))) * 1000
	score += maxi(0, int(entry.get("battles", 0))) * 100
	score += maxi(0, int(entry.get("elites", 0))) * 250
	score += maxi(0, int(entry.get("hp", 0))) * 5
	score += maxi(0, int(entry.get("gold", 0)))
	if str(entry.get("result", "")) == "win":
		score += 10000
	return score


static func record_result(entry: Dictionary) -> void:
	## RunRecord.finish 的唯一回调。中断也更新本地进度，但不抢传 Steam；
	## 玩家续档后打出胜/负时，同一条日期记录会被最终结果覆盖。
	var date := str(entry.get("daily_date", ""))
	if not valid_date(date):
		return
	_ensure_loaded()
	var a := attempt_for(date)
	if a.is_empty():
		a = {"date": date, "started": int(Time.get_unix_time_from_system())}
	var result := str(entry.get("result", "interrupted"))
	var score := score_of(entry)
	a.merge({
		"rules": int(entry.get("daily_rules", RULES_VERSION)),
		"seed": int(entry.get("seed", 0)),
		"class": str(entry.get("class", "")),
		"difficulty": int(entry.get("difficulty", FIXED_DIFFICULTY)),
		"result": result,
		"score": score,
		"secs": maxi(0, int(entry.get("secs", 0))),
		"layer": maxi(0, int(entry.get("layer", 0))),
	}, true)
	_attempts[date] = a
	_save()
	if result == "win" or result == "lose" or result == "quit":
		var queued := DailyLeaderboard.submit_score(date,
				int(a.get("rules", RULES_VERSION)), score,
				PackedInt32Array([int(a.get("layer", 0)), int(a.get("secs", 0))]))
		a["upload"] = "queued" if queued else "offline"
		_attempts[date] = a
		_save()


static func local_scores(limit := 8) -> Array:
	_ensure_loaded()
	var out: Array = []
	for a: Variant in _attempts.values():
		if a is Dictionary and str((a as Dictionary).get("result", "")) != "playing":
			out.append((a as Dictionary).duplicate(true))
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var xs := int(x.get("score", 0))
		var ys := int(y.get("score", 0))
		return str(x.get("date", "")) > str(y.get("date", "")) if xs == ys else xs > ys)
	if out.size() > limit:
		out.resize(limit)
	return out


static func leaderboard_name(date: String, rules := RULES_VERSION) -> String:
	## Steamworks 后台/API 同名；规则版本入名，改计时或计分口径不会污染旧榜。
	return "DAILY_%s_V%d" % [date.replace("-", ""), rules]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_attempts = {}
	if not FileAccess.file_exists(_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not (data is Dictionary) or int((data as Dictionary).get("format", 0)) != FORMAT:
		return
	var a: Variant = (data as Dictionary).get("attempts", {})
	if a is Dictionary:
		_attempts = a


static func _save() -> bool:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_warning("DailyChallenge：成绩写入失败 " + _path)
		return false
	f.store_string(JSON.stringify({"format": FORMAT, "attempts": _attempts}, "\t"))
	f.close()
	return true
