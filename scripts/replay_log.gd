class_name ReplayLog
extends RefCounted
## 游戏录像（后台记录 + 完整回放）—— R46。
##
## 录制：一局 run 一个 JSON 文件（user://replays/），包含：
##   * meta：版本 / 时间 / 角色 / run 种子（RunState.run_seed）/ 战斗数 / 结果；
##   * entries：按时间顺序的完整流程条目 ——
##       {"k":"relic_pick","id":6003}                  起点道具三选一
##       {"k":"map","node":17}                         地图前进（含鸭之低语）
##       {"k":"battle_begin","seed":..,"level":..}     战斗开始（含战斗 RNG 种子）
##       {"k":"act","f":"play_from_hand","a":[..]}     玩家操作（引擎入口记录）
##       {"k":"battle_end","win":true,"hp":41}         战斗结束
##       {"k":"reward_pick","idx":1,"id":9087}         卡牌奖励选择
##       {"k":"drop_claim"/"drop_skip"/"drop_later"}   掉落道具决定
##       {"k":"event_main"/"event_bbq"/"event_leave"}  事件/休息选项
##       {"k":"deck_edit","idx":2}                     卡组编辑（遗忘/删除/改造，单选）
##       {"k":"deck_edit","idxs":[1,4]}                卡组编辑（鸭血复制，多选：一组下标）
##       {"k":"run_end","result":"win/lose/quit"}      整局结束
##
## 回放原理：**种子化确定性重放**。
##   * run 层随机（地图生成 / 道具三选一 / 关卡抽取 / 掉落 / 五换一）统一走
##     RunState.run_rng（由 run_seed 播种）→ 重放时代码原样重跑，结果必然一致；
##   * 战斗层随机（engine.rng + 牌库洗牌）由每场战斗的种子播种（记录在
##     battle_begin）→ AI 行为由引擎从同一状态确定性重建，**只需重放玩家动作**；
##   * 玩家决策（选节点 / 选牌 / 事件选项 / 战斗内操作）逐条从 entries 取出，
##     通过与原界面完全相同的处理器执行。
## 因此录像文件只记录「决策序列 + 种子」，体积小且对未来的结算改动健壮。

const DIR := "user://replays"
const KEEP := 30                  # 最多保留的录像份数（超出删最旧）
const FORMAT := 1                 # 录像格式版本（结构不兼容时 +1）

# ---- 录制状态 ----
static var recording := false     # 正在录制（真实 run 流程中）
static var _meta: Dictionary = {}
static var _entries: Array = []

# ---- 回放状态 ----
static var playing := false       # 正在回放（各场景进入自动决策模式）
static var speed := 1.0           # 回放倍速（空格切换 1→2→4→8）
static var _play_entries: Array = []
static var _idx := 0
static var _play_path := ""
static var _saved_difficulty := 0   # 回放前的玩家档位（回放结束还原，免得「看了录像改了难度」）
static var _last_progress := 0      # 上次**真正消费掉**一条条目的时刻（msec）—— 卡死看门狗用


# ------------------------------------------------------------ 录制

static func begin_run(cls: String) -> void:
	## 一局 run 开始录制（角色选定后调用；run_seed 已由 RunState.start_run 定好）。
	_meta = {
		"format": FORMAT,
		"time": Time.get_datetime_string_from_system().replace("T", " "),
		"class": cls,
		"run_seed": RunState.run_seed,
		# 难度档位（R47）：回放时按它还原 —— 休息回复量与战斗胜利回血都跟着它走。
		"difficulty": RunState.difficulty,
	}
	_entries = []
	recording = true


static func ev(k: String, data: Dictionary = {}) -> void:
	## 记录一条流程条目（未在录制中则忽略）。
	if not recording:
		return
	var e := {"k": k}
	for key: String in data:
		e[key] = _enc(data[key])
	_entries.append(e)


static func act(f: String, a: Array) -> void:
	## 记录一条玩家操作（引擎动作入口调用）。
	ev("act", {"f": f, "a": a})


static func finish(result: String) -> void:
	## 整局结束（win / lose / quit）：落盘并停止录制。
	if not recording:
		return
	ev("run_end", {"result": result})
	recording = false
	_save(result)


static func stop() -> void:
	## 中途停止（异常退出兜底）：已录内容照常保存。
	if recording:
		recording = false
		_save("interrupted")
	playing = false


static func _save(result: String) -> void:
	if _entries.is_empty():
		return
	var battles := 0
	for e: Dictionary in _entries:
		if str(e.get("k", "")) == "battle_begin":
			battles += 1
	_meta["battles"] = battles
	_meta["result"] = result
	_meta["entries"] = _entries
	var stamp := Time.get_datetime_string_from_system()
	for ch in [":", " ", "-", "T"]:
		stamp = stamp.replace(ch, "")
	var dir := DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_play_path = "%s/replay_%s_%s.json" % [dir, stamp, _meta.get("run_seed", 0)]
	var f := FileAccess.open(_play_path, FileAccess.WRITE)
	if f == null:
		push_warning("ReplayLog：录像写入失败 " + _play_path)
		return
	f.store_string(JSON.stringify(_meta))
	_rotate()


static func _rotate() -> void:
	var files := _list_files()
	if files.size() <= KEEP:
		return
	files.sort()   # 文件名含时间戳：升序 = 最旧在前
	for i in files.size() - KEEP:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(files[i]))


static func _list_files() -> Array[String]:
	var out: Array[String] = []
	var gdir := ProjectSettings.globalize_path(DIR)
	if not DirAccess.dir_exists_absolute(gdir):
		return out
	for f: String in DirAccess.get_files_at(gdir):
		if f.ends_with(".json"):
			out.append(DIR + "/" + f)
	return out


static func list_replays() -> Array[Dictionary]:
	## 全部录像（新在前）：[{path, time, class, result, battles, run_seed}]。
	var out: Array[Dictionary] = []
	for p: String in _list_files():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if data is Dictionary and int(data.get("format", 0)) == FORMAT:
			out.append({"path": p, "meta": data})
	out.sort_custom(func(a, b): return str(a["meta"].get("time", "")) > str(b["meta"].get("time", "")))
	return out


# ------------------------------------------------------------ 回放

static func start_playback(path: String) -> Dictionary:
	## 载入一份录像并进入回放模式。返回 meta（失败返回 {}）。
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or int(data.get("format", 0)) != FORMAT:
		return {}
	_play_path = path
	_play_entries = data.get("entries", [])
	_idx = 0
	speed = 1.0
	_saved_difficulty = RunState.difficulty
	playing = true
	_touch()
	return data


static func stop_playback() -> void:
	playing = false
	_play_entries = []
	_idx = 0
	_last_progress = 0
	RunState.difficulty = _saved_difficulty   # 还原玩家自己的难度档位（R47）


static func peek() -> Dictionary:
	## 下一条待执行条目（不消费）；放完返回 {}。
	if not playing or _idx >= _play_entries.size():
		return {}
	var e: Variant = _play_entries[_idx]
	return e if e is Dictionary else {}


static func take(kind: String) -> Dictionary:
	## 消费下一条指定类型的条目；类型不符或已放完 → 停止回放并返回 {}。
	var e := peek()
	if e.is_empty() or str(e.get("k", "")) != kind:
		stop_playback()
		return {}
	_idx += 1
	_touch()
	return e


static func advance() -> void:
	## 消费下一条（peek 后手动执行时用）。
	if playing:
		_idx += 1
		_touch()


static func skip_info() -> void:
	## R167：跳过「纯信息」条目 —— 它们**没有任何消费方**（录制时写下来只为存档 / 调试）。
	##   * `battle_end`：战斗结束标记（引擎侧已自行结算，回放时跳过即可）；
	##   * `run_end`   ：整局结束 → 回放**到此为止**。
	## ⚠️ 不跳的后果：这两个条目排到队头后，地图 / 战斗 / 事件 / 奖励四个 `_replay_tick()`
	##   全部「类型不符 → 直接 return」，没有任何一方会推进 `_idx` → **回放永久卡死**
	##   （这就是「播放重放经常卡死」的根因）。每个 `_replay_tick()` 开头调一次。
	if not playing:
		return
	# R167 看门狗：真卡住了（长时间没有任何条目被消费）就优雅停掉回放 ——
	# 阈值 60 秒远大于任何正常等待（战斗内 AI 演出 / 回放节流都只有 1~2 秒），
	# 所以触发的必然是真死锁，停掉不会误伤。
	if stalled_sec() > 60.0:
		stop_playback()
		return
	while _idx < _play_entries.size():
		var e: Variant = _play_entries[_idx]
		var k := str((e as Dictionary).get("k", "")) if e is Dictionary else ""
		if k == "battle_end":
			_idx += 1
			_touch()
		elif k == "run_end":
			stop_playback()
			return
		else:
			return


static func stalled_sec() -> float:
	## 距上次真正消费条目过了多久（秒）。**看门狗**用：真卡住时由界面兜底停掉回放。
	if not playing or _last_progress <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _last_progress) / 1000.0


static func _touch() -> void:
	_last_progress = Time.get_ticks_msec()


static func delay(sec: float) -> float:
	## 回放等待时长（按倍速缩放）。
	return sec / speed


static func is_empty_log() -> bool:
	return _play_entries.is_empty() or _idx >= _play_entries.size()


# ------------------------------------------------------------ 参数编码

static func _enc(v: Variant) -> Variant:
	## JSON 化：Vector2i/Vector2 → [x, y]；数组/字典递归。
	if v is Vector2i or v is Vector2:
		return [v.x, v.y]
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			out.append(_enc(x))
		return out
	if v is Dictionary:
		var d := {}
		for key: String in v:
			d[key] = _enc(v[key])
		return d
	return v


static func vec(a: Variant) -> Vector2i:
	## [x, y] → Vector2i（回放执行时还原参数）。
	if a is Vector2i:
		return a
	if a is Array and (a as Array).size() >= 2:
		return Vector2i(int((a as Array)[0]), int((a as Array)[1]))
	return Vector2i(-999, -999)


static func vec_or_null(a: Variant) -> Variant:
	## 技能目标：null / [x, y]。
	if a == null:
		return null
	return vec(a)
