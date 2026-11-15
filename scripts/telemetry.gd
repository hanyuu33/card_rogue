class_name Telemetry
extends RefCounted
## 对局遥测（R757）—— 一条**只追加的事件流**，目的是调平衡，不是给玩家看的东西。
##
## 为什么不是「统计计数器」：`ProfileData.stats` 只记总数（这张卡一共被打出几次），
## 回答不了「它被提议过几次、被选过几次、选了以后那局赢没赢」。要算**选择率**就
## 必须有分母（提议次数），要算**选择的收益**就必须能把这局追到底 —— 所以这里存的是
## 「谁在什么处境下，从哪几个候选里选了谁，那一局后来怎么了」，逐条一行 JSON。
##
## 与其它存档的分工（别混）：
##   * `ProfileData`（user://profile.json）= 玩家账号进度，**总数**性质，会被覆盖式保存；
##   * `RunRecord`（user://run_records.json）= 一局一条结果，只留最近 100 条，给玩家看；
##   * `Telemetry`（user://telemetry.jsonl）= **只追加**的明细事件流，给作者调平衡用。
##
## 事件类型（一行一条，`ev` 字段区分）：
##   `run_start` 一局开始：种子 / 职业 / 难度 + **玩家熟练度标签**（开局前的总局数、
##               历史最高难度、历史最深层、历史通关数）—— 分层比较的前提，没有它
##               raw 胜率会系统性偏向「保命卡」（强玩家选上限卡、弱玩家选回血卡）。
##   `offer`     一组候选被摆到玩家面前：卡牌三选一 / 道具掉落 / 工具掉落，含
##               **当时的处境**（层、HP、金币、卡组张数）。⚠️ 这一条是全套数据里
##               **唯一不可回溯**的字段：不记就永远补不出选择率的分母。
##   `pick`      玩家从那一组里选了谁 / 跳过。`oid` 与 `offer` 配对，`ms` 是犹豫时长。
##   `battle`    一场战斗的结局：关卡 key / 层级 / 胜负 / 回合数 / 双方血量 /
##               本场受伤 / 卡组张数。用于算「各敌人胜率」与「掉血」两种敏感度不同的指标。
##   `run_end`   一局收尾：胜负 / 用时 / 最深到哪层 / 本局**实际打出过**的卡（差集算出）
##               与拿到过的道具。
##
## 写盘纪律：`_write()` 只进缓冲，`flush()` 才落盘。调用点 = 战斗结算 / 选卡 / 局收尾 /
##           回标题 —— 与 `ProfileData.flush()` 同一套节奏，别在热路径（每帧 / 每张牌）里写。
## 测试纪律：`set_test_mode()` 之后**完全不写**（连测试文件都不建）—— 回归与出图会跑
##           几千次结算，混进来就是一片脏数据。`_e.txt` 里能看到的行数必须恒为 0。
##
## 隐私：不写任何能定位到人的东西 —— 没有设备 id、没有 IP、没有持久玩家标识。
##       `run` 是「种子 + 毫秒时间戳」，只用来把同一局的事件串起来，跨局不可关联。

const SCHEMA := 1

const PATH := "user://telemetry.jsonl"
## 单文件上限：超过就轮转一份 `.1` 覆盖旧的（只留一份）。一局约几百条、几十 KB，
## 2MB 大约等于几十局，够分析一个版本，又不至于把玩家磁盘塞满。
const ROTATE_BYTES := 2 * 1024 * 1024

## 上报端点（Phase B）。留空 = **不上报**（当前形态：只在本机攒，等玩家同意后再谈）。
## 填上之后必须同时满足「玩家同意」，否则照样不发。
const UPLOAD_ENDPOINT := ""

# ------------------------------------------------------------ 运行时状态

static var _path := PATH             ## 落盘位置（正常恒定，只为测试注入留口）
static var _forced_off := false      ## 测试 / 出图：**彻底关掉**（连文件都不建）
static var _f: FileAccess = null     ## 缓存的句柄（懒打开，轮转时置空）

static var _run := ""                ## 本局 id（种子 + 起点毫秒），只用于串事件
static var _seq := 0                 ## 事件序号（同局内单调递增）
static var _oid := 0                 ## 候选组序号
static var _offers: Dictionary = {}  ## oid -> {k, cand, t, open}（pick/skip 配对用）

static var _stat0: Dictionary = {}   ## 开局时的 ProfileData.stats 快照（算「本局打过哪些卡」）
static var _t0 := 0                  ## 开局毫秒（算用时）
static var _battles := 0
static var _wins := 0
static var _deaths := 0
static var _deepest := 0

static var _battle: Dictionary = {}  ## 当前战斗的开局快照（结束事件补齐）


# ============================================================ 开关

static func set_test_mode(on := true) -> void:
	## 测试 / 出图：**彻底不写**。不是换个路径写 —— 换路径也会在 CI 里留下成吨的
	## jsonl，分析时还得再过滤一次，不如直接关掉。
	_forced_off = on
	close()


static func is_enabled() -> bool:
	return _on()


static func _on() -> bool:
	## **唯一开关**：这一整套是**发布版独有**的功能（R757 用户口径）——
	## 测试版 / 开发版不写事件流、不弹同意框、设置页也不出现那一项。
	## 判据只读 `GameBuild.is_release()`，不另设一套「我是不是正式包」的判断。
	## `--release` 命令行可以让编辑器里也跑发布版路径，出图核验用。
	if _forced_off:
		return false
	## 模拟 / 自测口子：**测试版加上 `--telemetry` 也写事件流** —— Phase C 的机器人跑局
	## 走这条（模拟局带着 `--sim` 标记，分析时与真实玩家分开算）。正常玩家不会带这个参数。
	if "--telemetry" in OS.get_cmdline_user_args():
		return true
	return GameBuild.is_release()


static func reset_context() -> void:
	## 回标题 / 测试用例之间：把「局」相关的内存状态清干净，别让下一局继承上一局的序号。
	_run = ""
	_offers.clear()
	_stat0.clear()
	_t0 = 0
	_battles = 0
	_wins = 0
	_deaths = 0
	_deepest = 0
	_battle.clear()


# ============================================================ 局生命周期

static func begin_run(seed: int, cls: String, diff: int, runs_before := -1) -> void:
	## 一局开始。`runs_before` = **本局之前**玩过多少局（调用方在 `run_start` 计数 +1 之后
	## 调这里，所以要么显式传「减一之后的值」，要么传 -1 让我从档案里减一次）。
	if not _on():
		return
	reset_context()
	_run = "%d.%d" % [seed, Time.get_ticks_msec()]
	_t0 = Time.get_ticks_msec()
	_stat0 = ProfileData.stats.duplicate()
	var runs := int(runs_before)
	if runs < 0:
		runs = maxi(0, ProfileData.stat(ProfileData.K_RUN_START) - 1)
	_write({"ev": "run_start", "schema": SCHEMA, "seed": seed, "cls": cls, "diff": diff,
			"runs": runs, "max_diff": _max_diff_seen(), "deepest": _deepest_seen(),
			"wins": _wins_seen(), "sim": _is_sim()})
	flush()


static func _is_sim() -> bool:
	## 这一局是**机器人打的**（Phase C 的 AI 模拟先验）。带 `--sim` 启动即视为模拟局 ——
	## 分析脚本会把模拟与真实玩家数据分开算：混在一起会把「bot 的选卡偏好」当成玩家偏好。
	return "--sim" in OS.get_cmdline_user_args()


static func end_run(win: bool, extra: Dictionary = {}) -> void:
	## 一局收尾。`played` / `relics` 由**统计差集**得出（开局快照 vs 现在）——
	## 这样不必在出牌热路径埋点：「这张卡这局到底打出去过没有」是判断死卡的关键，
	## 而它恰好可以从 `card_play:*` 的增量免费拿到。
	if not _on() or _run == "":
		return
	var ev := {"ev": "run_end", "win": win,
			"secs": int((Time.get_ticks_msec() - _t0) / 1000),
			"layer": _deepest, "battles": _battles, "bwins": _wins, "deaths": _deaths,
			"played": _diff_ids(ProfileData.K_CARD_PLAY),
			"relics": _diff_ids(ProfileData.K_RELIC_GOT)}
	for k: Variant in extra.keys():
		ev[str(k)] = extra[k]
	_write(ev)
	flush()
	reset_context()


static func note_run_interrupted() -> void:
	## 一局**没打完就没了**（关窗口 / 崩溃 / 开新局把上一局顶掉）。
	## 这类局必须留一条 `run_end`：否则「玩家在哪一层不玩了」这个最有价值的问题
	## 永远回答不了 —— 而它恰恰是难度悬崖与流失点最直接的证据。
	## 调用点只有一个：`RunRecord.finish("interrupted")`（那是「中断」的唯一定义处）。
	if not _on() or _run == "":
		return
	end_run(false, {"out": "interrupted"})


# ============================================================ 候选 / 选择

static func note_card_offer(cands: Array, src: String, ctx: Dictionary) -> int:
	## 一组**卡牌**候选摆到玩家面前（三选一 / 固定单张都算）。返回 oid（0 = 没记）。
	## `src`：battle / elite / boss / shop / event / treasure / bonus —— 分析时按来源分开看，
	## 因为「战斗后必给」和「商店里要花 80 金」的选择压力完全不同。
	return _note_offer("card", cands, src, ctx)


static func note_relic_offer(ids: Array, src: String, ctx: Dictionary) -> int:
	return _note_offer("relic", ids, src, ctx)


static func note_tool_offer(ids: Array, src: String, ctx: Dictionary) -> int:
	return _note_offer("tool", ids, src, ctx)


static func note_pick(oid: int, id: int) -> void:
	## 从第 oid 组里选了 id。`ms` = 从摆出来到点下去，犹豫时长（>8s 往往意味着在算）。
	if not _on():
		return
	var o: Dictionary = _offers.get(oid, {})
	if o.is_empty() or not bool(o.get("open", false)):
		return
	o["open"] = false
	_write({"ev": "pick", "oid": oid, "k": str(o.get("k", "")), "id": id,
			"cand": o.get("cand", []),
			"ms": Time.get_ticks_msec() - int(o.get("t", 0))})
	flush()


static func note_skip(oid: int) -> void:
	## 整组跳过（不要这组卡 / 放弃这件道具）。**分母里必须留着它** ——
	## 「摆出来但没人要」比「没人选」更说明问题，丢掉这一条会把选择率整体抬高。
	if not _on():
		return
	var o: Dictionary = _offers.get(oid, {})
	if o.is_empty() or not bool(o.get("open", false)):
		return
	o["open"] = false
	_write({"ev": "pick", "oid": oid, "k": str(o.get("k", "")), "id": 0, "skip": true,
			"cand": o.get("cand", []),
			"ms": Time.get_ticks_msec() - int(o.get("t", 0))})
	flush()


static func _note_offer(kind: String, ids: Array, src: String, ctx: Dictionary) -> int:
	if not _on() or _run == "" or ids.is_empty():
		return 0
	_oid += 1
	var oid := _oid
	var clean: Array = []
	for v: Variant in ids:
		var n := int(v)
		if n > 0:
			clean.append(n)
	if clean.is_empty():
		return 0
	_offers[oid] = {"k": kind, "cand": clean, "t": Time.get_ticks_msec(), "open": true}
	var ev := {"ev": "offer", "oid": oid, "k": kind, "src": src, "cand": clean}
	for k: Variant in ctx.keys():
		ev[str(k)] = ctx[k]
	_write(ev)
	return oid


# ============================================================ 战斗

static func note_battle_start(lvl: Dictionary, hp: int, max_hp: int, deck: int,
		layer := 0) -> void:
	## 战斗开局快照。只存内存，等 `note_battle_end` 时并成一条 `battle` 事件 ——
	## 一场战斗写两行的话，分析时每条都要 join，没必要。
	## ⚠️ `layer` 由调用方给（`RunState.current_layer`）—— 这里**不反向 import RunState**，
	##    两个静态类互相引用会形成双向依赖，将来谁改谁都提心吊胆。
	if not _on() or _run == "":
		return
	var units: Array = []
	for e: Variant in lvl.get("enemy_units", []):
		if e is Array and (e as Array).size() > 0:
			units.append(int((e as Array)[0]))
	_battle = {
		"key": str(lvl.get("key", "")),
		"name": str(lvl.get("name", "?")),
		"tier": int(lvl.get("tier", -1)),
		"units": units,
		"hp0": hp, "mhp": max_hp, "deck": deck,
		"layer": int(ctx_layer()),
		"t": Time.get_ticks_msec(),
	}


static func note_battle_end(win: bool, ctx: Dictionary) -> void:
	## 战斗结束。`ctx` 必须给：`turns`（回合数）、`hp1`（结束血量）、`ehp0` / `ehp1`
	## （双方总血，用来算「这场掉了多少」）、`dmg_in`（本场实际承受伤害）、`out`（lose/flee）。
	## ⚠️ 没有开局快照（换关重进 / 续档直接进战斗）时**不写** —— 半条战斗记录比没有更误导。
	if not _on() or _battle.is_empty():
		return
	var ev := {
		"ev": "battle",
		"key": str(_battle.get("key", "")),
		"name": str(_battle.get("name", "")),
		"tier": int(_battle.get("tier", -1)),
		"layer": int(_battle.get("layer", 0)),
		"units": _battle.get("units", []),
		"win": win,
		"hp0": int(_battle.get("hp0", 0)),
		"mhp": int(_battle.get("mhp", 0)),
		"hp1": int(ctx.get("hp1", 0)),
		"turns": int(ctx.get("turns", 0)),
		"dmg_in": int(ctx.get("dmg_in", 0)),
		"deck": int(_battle.get("deck", 0)),
		"secs": int((Time.get_ticks_msec() - int(_battle.get("t", 0))) / 1000),
		"out": str(ctx.get("out", "win" if win else "lose")),
	}
	_battles += 1
	if win:
		_wins += 1
	else:
		_deaths += 0 if str(ev["out"]) == "flee" else 1
	_deepest = maxi(_deepest, int(ev["layer"]))
	_battle.clear()
	_write(ev)
	flush()


static func has_battle() -> bool:
	## 有没有一场战斗还挂着没结算（逃跑 / 中断时可以用来补一条）。
	return not _battle.is_empty()


# ============================================================ 商店 / 事件（可选）

static func note_shop_shelf(items: Array, ctx: Dictionary = {}) -> void:
	## 商店**货架快照**（每次进货记一次）。买了什么只说明成交，摆了什么才是分母 ——
	## 「这卡摆在店里没人买」与「这卡根本没上过货架」是两件事，后者不该拉低它的选择率。
	if not _on() or _run == "" or items.is_empty():
		return
	var ev := {"ev": "shop_shelf", "items": items}
	for k: Variant in ctx.keys():
		ev[str(k)] = ctx[k]
	_write(ev)
	flush()


static func note_shop(kind: String, id: int, cost: int, bought: bool, ctx: Dictionary = {}) -> void:
	## 商店的一次成交判定：**看了没买**和**买了**同样有价值（标价太贵的证据）。
	if not _on() or _run == "":
		return
	var ev := {"ev": "shop", "k": kind, "id": id, "cost": cost, "bought": bought}
	for k: Variant in ctx.keys():
		ev[str(k)] = ctx[k]
	_write(ev)


static func note_event(kind: String, choice: int, label: String, ctx: Dictionary = {}) -> void:
	## 事件的一个选项被点下去。用于看「哪个分支从来没人选」。
	if not _on() or _run == "":
		return
	var ev := {"ev": "event", "kind": kind, "choice": choice, "label": label}
	for k: Variant in ctx.keys():
		ev[str(k)] = ctx[k]
	_write(ev)


static func note_deck_change(op: String, old_id: int, new_id: int,
		ctx: Dictionary = {}) -> void:
	## 卡组变化：`del`（删掉 old）/ `transform`（old → new）。
	## 「被删最多的卡」是玩家用行动投的**负票** —— 比任何胜率数字都直接：
	## 没人删的卡不一定强，人人都删的一定弱。
	if not _on() or _run == "":
		return
	var ev := {"ev": "deck", "op": op, "old": old_id, "new": new_id}
	for k: Variant in ctx.keys():
		ev[str(k)] = ctx[k]
	_write(ev)


# ============================================================ 写入

static func _write(ev: Dictionary) -> void:
	if not _on():
		return
	_seq += 1
	ev["q"] = _seq
	ev["ts"] = Time.get_unix_time_from_system()
	if _run != "":
		ev["run"] = _run
	if not _ensure_open():
		return
	_f.store_line(JSON.stringify(ev))


static func flush() -> void:
	if _f != null:
		_f.flush()


static func close() -> void:
	if _f != null:
		_f.flush()
		_f = null


static func _ensure_open() -> bool:
	if _f != null:
		return true
	if _need_rotate():
		_rotate()
	# ⚠️ **必须用 READ_WRITE，不能用 WRITE_READ**。实测（tools/_probe_append.gd）：
	#    `WRITE_READ` 打开后 `seek_end()` 不生效，写入从 0 开始**覆盖**旧内容 ——
	#    表现是「每次启动都把整份事件流重写一遍」，上一局的数据成批消失。
	#    `READ_WRITE` 要求文件已存在，所以先补一个空文件（只有首次会走到）。
	if not FileAccess.file_exists(_path):
		var c := FileAccess.open(_path, FileAccess.WRITE)
		if c == null:
			push_warning("[telemetry] 建不了 %s（%s）" % [_path, FileAccess.get_open_error()])
			return false
		c.store_string("")
		c.close()
	_f = FileAccess.open(_path, FileAccess.READ_WRITE)
	if _f == null:
		push_warning("[telemetry] 打不开 %s（%s），本局不记" % [_path, FileAccess.get_open_error()])
		return false
	_f.seek_end()
	return true


static func _need_rotate() -> bool:
	if not FileAccess.file_exists(_path):
		return false
	return FileAccess.get_file_as_bytes(_path).size() > ROTATE_BYTES


static func _rotate() -> void:
	## 只留一份旧文件：`.1` 直接覆盖。分析脚本会同时读 `.1` 与当前文件（按时间排序）。
	close()
	var abs_cur := ProjectSettings.globalize_path(_path)
	var abs_old := ProjectSettings.globalize_path(_path + ".1")
	if FileAccess.file_exists(_path + ".1"):
		DirAccess.remove_absolute(abs_old)
	DirAccess.rename_absolute(abs_cur, abs_old)


# ============================================================ 上下文小工具

static func ctx_layer() -> int:
	## 当前层。**不 import RunState 反过来问**（那会形成双向依赖），由调用方给；
	## 这里只作为 battle_start 的兜底默认值。
	return 0


static func _diff_ids(prefix: String) -> Array:
	## 「自开局以来这个前缀下涨过的 id」。卡牌与道具都用它算本局实际获得/打出。
	var out: Array = []
	for k: Variant in ProfileData.stats.keys():
		var key := str(k)
		if not key.begins_with(prefix):
			continue
		if int(ProfileData.stats[key]) > int(_stat0.get(key, 0)):
			var tail := key.substr(prefix.length())
			if tail.is_valid_int():
				out.append(int(tail))
	return out


static func _max_diff_seen() -> int:
	## 玩家历史最高**已解锁难度**（按职业取最大）。这是「熟练度」最有信息量的一维：
	## 敢打 11 档的人和只打 0 档的人，同名卡牌的胜率没有可比性。
	var best := 0
	for k: Variant in ProfileData.class_diff.keys():
		best = maxi(best, int(ProfileData.class_diff[k]))
	return best


static func _deepest_seen() -> int:
	## 历史最深到过第几层 —— 直接读对战记录文件（只留 100 条，够用）。
	## ⚠️ 不走 `RunState.load_records()`：那会形成 Telemetry ↔ RunState 的双向依赖。
	##    这里只借 `RunRecord.PATH` 这个**常量**，读法自己来。
	var best := 0
	if not FileAccess.file_exists(RunRecord.PATH):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RunRecord.PATH))
	if not (data is Array):
		return 0
	for r: Variant in data:
		if r is Dictionary:
			best = maxi(best, int((r as Dictionary).get("layer", 0)))
	return best


static func _wins_seen() -> int:
	return ProfileData.stat(ProfileData.K_RUN_WIN)
