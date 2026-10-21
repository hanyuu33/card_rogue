class_name RunRecord
extends RefCounted
## 对战记录（R215）—— **只记一局的结果**，不再录完整回放。
##
## 为什么砍掉回放：录像要「种子化确定性重放」（run_rng / 每场战斗种子 / 每条玩家决策），
## 任何一处结算改动都可能让旧录像失效；代价是六个场景里散着几百行驱动代码 + 一个
## 60 秒卡死看门狗，收益却只有「看自己打过的局」—— 用户明确要求删掉，只留结果。
##
## 一条记录：
##   {"time": 开始时间, "end": 结束时间, "class": 角色 id, "difficulty": 档位,
##    "result": "win" / "lose" / "quit" / "interrupted", "secs": 用时秒,
##    "seed": 本局种子,                                    ← R241
##    "hp" / "max_hp" / "gold" / "layer" / "battles" / "elites",   ← R241 快照
##    "relics": [道具 id...], "deck": [{"id":卡 id, "e":附魔 id}...]}  ← R241 快照
## ⚠️ 后加的字段**全部可选**：老记录没有就判空（详情页显示「旧记录无详情」），
##    FORMAT 仍是 1 —— 升版本会把玩家已有的历史记录全丢掉。
## 落盘 `user://run_records.json`（数组，**最旧在前**，最多 KEEP 条）。
##
## **「中断也记录」靠一份 pending 文件**（`user://run_pending.json`）：
##   * `begin_run()` 开局（角色选定）写 pending：开始时间 / 角色 / 难度 / 本次进程 id；
##   * `finish()` 结束时把它转成正式记录，并删掉 pending；
##   * 直接关窗口 / 进程崩掉 → pending 留在盘上，**下次启动 `recover()` 补一条「中断」**；
##   * 回标题后开新局 → `begin_run()` 先把上一局的 pending 收成「中断」；
##   * **中断之后又续档（R289）** → `resume()` 把刚补的那条「中断」**撤回**（见下）。
##
## **一局只该有一条记录**（R289）：中断 → 继续游戏 → 打完，记录页不能出现
## 「中断」+「通关」两条。做法是 `resume()` 先 `_revive_interrupted()`：若**最后一条**
## 记录是「中断」且种子与本局一致，就把它删掉、拿它的开局时间 / 累计用时当新 pending
## 的起点。待在 pending 里的 `elapsed` 是「中断之前已经打了多久」，这样续档后
## `secs` 是**各段累加**，不会把关掉游戏的那几个小时算进去。
## 进程 id 用来区分两种「半路没了」：
##   * **同一进程内**回标题（续档还能接着打）→ pending 的 id 与当前一致，`recover()` 不动它；
##   * **上次启动**留下的 pending → id 对不上，判定为真中断。

const PATH := "user://run_records.json"
const PENDING_PATH := "user://run_pending.json"
const FORMAT := 1
const KEEP := 100                 # 最多保留多少条（超出删最旧）

## 本次启动的随机标识（惰性生成；同进程内所有 pending 共用一个）。
static var _session := ""


# ------------------------------------------------------------ 会话

static func session_id() -> String:
	if _session == "":
		_session = "%d-%d" % [Time.get_ticks_usec(), randi()]
	return _session


# ------------------------------------------------------------ 写入

static func begin_run(cls: String) -> void:
	## 一局开始（角色选定后调用）。**先把上一局的 pending 收尾** —— 开新局就意味着
	## 旧那局不会再打了（回标题保留的那份续档也随之作废，`_on_start` 会删存档）。
	recover()
	if not _read_pending().is_empty():
		finish("interrupted")
	_write_pending(cls)


static func resume() -> void:
	## 续档进入（跨启动续档）：盘上有 pending 就接着用；没有就先试着**把上一次那条
	## 「中断」记录复活**（中断后又继续 = 同一局，不能记成两条），复活不了再补一份新的 ——
	## 免得这一局打完时 `finish()` 找不到开始时间。
	if not _read_pending().is_empty():
		return
	var base := _revive_interrupted()
	if base.is_empty():
		_write_pending(RunState.player_class)
		return
	var cls := RunState.player_class
	if cls == "":
		cls = str(base.get("class", PlayerClass.default_id()))
	_write_pending(cls, base)


static func finish(result: String) -> void:
	## 一局结束（win / lose / quit / interrupted）：落盘并清掉 pending。
	## 没有 pending（续档补记失败 / 单关模式）→ 什么都不写，绝不凭空造记录。
	## R241：连**最终状态快照**一起记（血量 / 道具 / 卡组…），记录页才能看详情。
	var p := _read_pending()
	if p.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var start := float(p.get("start_unix", now))
	if start <= 0.0:
		start = now     # 老 pending 没有 start_unix / 写成 0 → 不拿 1970 年当起点算用时
	# R289：跨中断续档时 pending 里带着「中断前已经打的时间」，两段相加才是真实用时。
	var spent := maxi(0, int(p.get("elapsed", 0))) + maxi(0, int(now - start))
	var entry := {
		"format": FORMAT,
		"time": str(p.get("time", "")),
		"end": Time.get_datetime_string_from_system(),
		"class": str(p.get("class", PlayerClass.default_id())),
		"difficulty": int(p.get("difficulty", 2)),
		"result": result,
		"secs": spent,
		"seed": int(p.get("seed", 0)),
	}
	# 快照来源：本局还活着 → 现取；否则（启动时补记「中断」）→ 用 pending 里存的
	# 最后一份检查点快照（`update_pending()` 写的）。
	var snap: Variant = p.get("snap", {})
	if RunState.run_active:
		snap = snapshot()
	if snap is Dictionary:
		entry.merge(snap as Dictionary, true)
	# 用户口径：**失败时生命记 0**（战斗输掉那一刻 RunState.hp 还是进战斗前的值，
	# 不能直接抄）；中断 / 放弃则保留当时的真实血量。
	if result == "lose":
		entry["hp"] = 0
	var all := list_records()
	all.append(entry)
	while all.size() > KEEP:
		all.pop_front()
	_write_records(all)
	_delete_pending()


static func snapshot() -> Dictionary:
	## 一局的**最终状态快照**（记录详情用）。字段都可选，老记录没有就空着。
	## 卡组按 `{id, e}` 记（卡 id + 附魔 id）：详情页据此还原卡名与附魔标记，
	## 不存整张 CardData —— 记录是历史，卡表以后再改也读得回来（id 找不到就跳过）。
	var deck: Array = []
	for i in RunState.deck_ids.size():
		var mod: Dictionary = RunState.deck_mods[i] if i < RunState.deck_mods.size() else {}
		deck.append({
			"id": int(RunState.deck_ids[i]),
			"e": RunState.enchant_id_of(mod),
		})
	var relics: Array = []
	for id: int in RunState.relics:
		relics.append(int(id))
	return {
		"seed": RunState.run_seed,
		"hp": RunState.hp,
		"max_hp": RunState.max_hp,
		"gold": RunState.gold,
		"layer": RunState.current_layer,
		"battles": RunState.battle_wins,
		"elites": RunState.elite_wins,
		"relics": relics,
		"deck": deck,
	}


static func update_pending() -> void:
	## 地图检查点上顺手把**快照**同步进 pending（与 `RunSave.save_run()` 同一时刻）。
	## 这样直接关掉游戏留下的「中断」记录也有卡组 / 道具 / 血量可看，而不是只有一行结果。
	if not RunState.run_active:
		return
	var p := _read_pending()
	if p.is_empty():
		return
	p["snap"] = snapshot()
	p["seed"] = RunState.run_seed
	_write_pending_dict(p)


static func recover() -> bool:
	## 启动兜底：上次启动留下的 pending = 那一局没打完就被关掉了 → 补一条「中断」。
	## 返回是否真的补了（测试与日志用）。
	var p := _read_pending()
	if p.is_empty():
		return false
	if str(p.get("session", "")) == session_id():
		return false            # 本进程自己的 pending：这一局还在打，不动它
	finish("interrupted")
	return true


static func _revive_interrupted() -> Dictionary:
	## 把「上次启动 recover() 补的那条中断」收回来当 pending 的起点（R289）。
	## 只在玩家点「继续游戏」（`resume()`）时调用 —— 那一刻才确定那局还要接着打。
	## 判据三条，缺一不可：**最后一条记录** + 结果 interrupted + 种子与本局一致。
	## 种子非 0 才认（老记录 / 单关没有 seed，宁可按「中断 + 新记录」两条留着也不误删）。
	if not RunState.run_active or RunState.run_seed == 0:
		return {}
	var all := list_records()
	if all.is_empty():
		return {}
	var last: Dictionary = all[all.size() - 1]
	if str(last.get("result", "")) != "interrupted":
		return {}
	if int(last.get("seed", 0)) != RunState.run_seed:
		return {}
	all.pop_back()
	_write_records(all)
	return {
		"time": str(last.get("time", "")),
		"start_unix": Time.get_unix_time_from_system(),
		"elapsed": maxi(0, int(last.get("secs", 0))),
		"class": str(last.get("class", "")),
		"difficulty": int(last.get("difficulty", RunState.difficulty)),
	}


static func clear_all() -> void:
	## 清空全部记录（设置 / 记录页的「清空」按钮）。
	_write_records([])


static func list_records() -> Array:
	## 全部记录（**最旧在前**，文件里的顺序即时间顺序）。
	if not FileAccess.file_exists(PATH):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Array):
		return []
	var out: Array = []
	for e: Variant in data:
		if e is Dictionary and int((e as Dictionary).get("format", 0)) == FORMAT:
			out.append(e)
	return out


# ------------------------------------------------------------ 展示

static func result_label(result: String) -> String:
	match result:
		"win":
			return "通关"
		"lose":
			return "失败"
		"quit":
			return "中途放弃"
		"interrupted":
			return "中断"
	return "未结束"


static func result_color(result: String) -> Color:
	match result:
		"win":
			return Color("7fd18a")
		"lose":
			return Color("e07a6a")
		"interrupted":
			return Color("d8a45a")
	return Color("9a958a")


static func fmt_time(v: String) -> String:
	## "2026-10-17T23:40:12" → "2026-10-17 23:40"
	var s := v.replace("T", " ")
	if s.length() >= 16:
		return s.substr(0, 16)
	return s


static func fmt_secs(secs: int) -> String:
	if secs <= 0:
		return "—"
	var m := secs / 60
	if m <= 0:
		return "%d 秒" % secs
	return "%d 分 %d 秒" % [m, secs % 60]


# ------------------------------------------------------------ 落盘

static func _write_pending(cls: String, base: Dictionary = {}) -> void:
	## base：中断记录复活时带进来的起点（开局时间 / 本段起点 / 已累计秒 / 档位），
	## 没有就当作全新一局。`elapsed` 只统计**真的在打**的时间（见文件头 R289 说明）。
	var now := Time.get_unix_time_from_system()
	var p := {
		"format": FORMAT,
		"session": session_id(),
		"time": str(base.get("time", Time.get_datetime_string_from_system())),
		"start_unix": int(base.get("start_unix", now)),
		"elapsed": maxi(0, int(base.get("elapsed", 0))),
		"class": cls,
		"difficulty": int(base.get("difficulty", RunState.difficulty)),
		"seed": RunState.run_seed,
		"snap": snapshot() if RunState.run_active else {},
	}
	_write_pending_dict(p)


static func _write_pending_dict(p: Dictionary) -> void:
	## pending 落盘（`begin_run` 建的那份 / `update_pending` 刷新的那份都走这里）。
	var f := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunRecord：pending 写入失败")
		return
	f.store_string(JSON.stringify(p))


static func _read_pending() -> Dictionary:
	if not FileAccess.file_exists(PENDING_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
	if not (data is Dictionary):
		return {}
	if int((data as Dictionary).get("format", 0)) != FORMAT:
		return {}
	return data


static func _delete_pending() -> void:
	if FileAccess.file_exists(PENDING_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))


static func _write_records(all: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunRecord：记录写入失败")
		return
	f.store_string(JSON.stringify(all, "  "))
