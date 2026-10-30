extends Node
## R409：AI 对局接口（AI Bridge）
##
## 目的：让 AI（或任何脚本）**不看截图**就能完整读取局面并用纯文
## 字指令操作游戏。所有动作都收敛成一句话：**点一个带编号的目标**。
##
##   GET  /state    纯文本局面（人 / LLM 直接读）
##   GET  /json     JSON 局面（脚本读）
##   POST /act      body = {"target": "h0"}  执行一次点击
##   POST /seq      body = {"targets": ["h0","r3c0"]}  连着点一串（中途失败即停）
##   POST /new      body = {"class":"暗影刺客","seed":"ABC1234567"}  指定种子开新局
##   POST /rewind   回到**本场战斗刚开打**那一刻（战斗 SL）
##
## 它**不是** bot：这里只有「读局面 / 下指令」两件事，策略由外面的 AI 决定。
##
## 启动方式（默认不开，普通玩家玩不受影响）：
##   Godot.exe --path . -- --ai-bridge          （默认 127.0.0.1:8770）
##   Godot.exe --path . -- --ai-bridge=8799     （指定端口）
##
## 设计约定（**新增场景时照这个来**）：
##   1. `describe()` 只**读**状态，不改任何东西；
##   2. 每个「可以点的东西」必须有一个稳定 id，id 同时出现在 describe 的
##      `可点目标` 段里 —— AI 只认 id，不认坐标；
##   3. 点击一律走场景**已有的**交互函数的路径（`_on_board_click` /
##      `_on_left_click` 的等价分支 / 场景自己的 `_xxx()`），绝不另写一套
##      结算逻辑，否则界面与状态会分叉。

const PORT_DEFAULT := 8770
const MAX_CONN := 8
const FLUSH_FRAMES := 3

var _srv: TCPServer = null
var _conns: Array = []
var port := PORT_DEFAULT
var _last_action := ""
var _last_target := ""
var _last_ms := 0
const REPEAT_LOCK_MS := 260      # 同一目标的连点保护窗口
var _battle_mark: Dictionary = {}   # 本场战斗开打那一刻的快照（战斗 SL 用）


# ---------------------------------------------------------------- 生命周期

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p := _bridge_port()
	if p <= 0:
		return
	port = p
	_start()


func _bridge_port() -> int:
	## 从命令行里找 `--ai-bridge` / `--ai-bridge=PORT`。找不到 = 不开。
	var all: Array = []
	all.append_array(OS.get_cmdline_args())
	all.append_array(OS.get_cmdline_user_args())
	for a: String in all:
		if a == "--ai-bridge":
			return PORT_DEFAULT
		if a.begins_with("--ai-bridge="):
			var v := int(a.substr("--ai-bridge=".length()))
			return v if v > 0 else PORT_DEFAULT
	return 0


func _start() -> void:
	_srv = TCPServer.new()
	var err := _srv.listen(port, "127.0.0.1")
	if err != OK:
		push_warning("[AiBridge] 端口 %d 监听失败（%d）" % [port, err])
		_srv = null
		return
	print("[AiBridge] http://127.0.0.1:%d  ——  GET /state  GET /json  POST /act" % port)


func _process(_delta: float) -> void:
	if _srv == null:
		return
	_track_battle_mark()
	_accept()
	_pump()


func _track_battle_mark() -> void:
	## 进战斗自动记一份「开打那一刻」的局状态，供 `/rewind` 用（战斗 SL）。
	## 快照直接取 `battle_scene._pre_battle_snap` —— 那是**进战斗之前**抓的，
	## 开局第 1 回合的各种跨战斗计数（lucky 7 等）都还没 +1，正是重打要的起点。
	## 离开战斗就清空：别把上一场的存档点带进下一场。
	if _kind() != "battle":
		_battle_mark = {}
		return
	if not _battle_mark.is_empty():
		return
	var s: Variant = _scene()
	if s == null:
		return
	var pre: Variant = s.get("_pre_battle_snap")
	if not (pre is Dictionary) or (pre as Dictionary).is_empty():
		return
	var lvl: Variant = s.get("_cur_level")
	_battle_mark = {
		"snap": (pre as Dictionary).duplicate(true),
		"level": (lvl as Dictionary).duplicate(true) if lvl is Dictionary else {},
	}


func _accept() -> void:
	while _srv.is_connection_available() and _conns.size() < MAX_CONN:
		var peer := _srv.take_connection()
		if peer == null:
			break
		_conns.append({"peer": peer, "buf": PackedByteArray(),
				"done": false, "flush": 0})


func _pump() -> void:
	var keep: Array = []
	for c: Dictionary in _conns:
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var n: int = peer.get_available_bytes()
		if n > 0:
			var r: Array = peer.get_data(n)
			if int(r[0]) == OK:
				var buf: PackedByteArray = c["buf"]
				buf.append_array(r[1] as PackedByteArray)
				c["buf"] = buf
		if not bool(c["done"]):
			_try_parse(c)
		if bool(c["done"]):
			var f: int = int(c["flush"]) - 1
			c["flush"] = f
			if f <= 0:
				peer.disconnect_from_host()
				continue
		keep.append(c)
	_conns = keep


# ---------------------------------------------------------------- HTTP

func _find_crlfcrlf(b: PackedByteArray) -> int:
	var i := 0
	var lim: int = b.size() - 3
	while i < lim:
		if b[i] == 13 and b[i + 1] == 10 and b[i + 2] == 13 and b[i + 3] == 10:
			return i
		i += 1
	return -1


func _try_parse(c: Dictionary) -> void:
	var buf: PackedByteArray = c["buf"]
	var sep := _find_crlfcrlf(buf)
	if sep < 0:
		if buf.size() > 65536:
			_send(c, 413, "text/plain; charset=utf-8", "request too large")
			c["done"] = true
		return
	var head := buf.slice(0, sep).get_string_from_utf8()
	var body := buf.slice(sep + 4)
	var lines := head.split("\r\n")
	var req := lines[0].split(" ")
	var method := req[0] if req.size() > 0 else "GET"
	var path := req[1] if req.size() > 1 else "/"
	var clen := 0
	for k in range(1, lines.size()):
		var ln: String = lines[k]
		var low := ln.to_lower()
		if low.begins_with("content-length:"):
			clen = int(ln.substr(15).strip_edges())
	if clen > 0 and body.size() < clen:
		return   # 还没收全
	if clen <= 0:
		body = PackedByteArray()
	elif body.size() > clen:
		body = body.slice(0, clen)
	_route(c, method.to_upper(), path, body.get_string_from_utf8())
	c["done"] = true


func _send(c: Dictionary, code: int, ctype: String, body: String) -> void:
	var data := body.to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
			% [code, _stext(code), ctype, data.size()]
	var out := head.to_utf8_buffer()
	out.append_array(data)
	var peer: StreamPeerTCP = c["peer"]
	peer.put_data(out)
	c["flush"] = FLUSH_FRAMES


func _stext(code: int) -> String:
	match code:
		200: return "OK"
		400: return "Bad Request"
		404: return "Not Found"
		413: return "Payload Too Large"
		500: return "Internal Server Error"
	return "OK"


func _route(c: Dictionary, method: String, path: String, body: String) -> void:
	var clean := path.split("?")[0]
	if clean == "/state" or clean == "/" or clean == "/text":
		_send(c, 200, "text/plain; charset=utf-8", describe())
		return
	if clean == "/json":
		_send(c, 200, "application/json; charset=utf-8",
				JSON.stringify(snapshot(), "  "))
		return
	if clean == "/act":
		var d: Variant = JSON.parse_string(body)
		if not (d is Dictionary):
			_send(c, 400, "text/plain; charset=utf-8", "body 必须是 JSON 对象，如 {\"target\":\"h0\"}")
			return
		var res := act(d as Dictionary)
		var state_txt := describe()
		var payload := {
			"ok": bool(res.get("ok", false)),
			"msg": str(res.get("msg", "")),
			"scene": _kind(),
			"sig": _sig(state_txt),
			"state": state_txt,
		}
		_send(c, 200, "application/json; charset=utf-8", JSON.stringify(payload))
		return
	if clean == "/seq":
		var dq: Variant = JSON.parse_string(body)
		if not (dq is Dictionary):
			_send(c, 400, "text/plain; charset=utf-8", "body 必须是 JSON 对象，如 {\"targets\":[\"h0\",\"r3c0\"]}")
			return
		_send(c, 200, "application/json; charset=utf-8", JSON.stringify(act_seq(dq as Dictionary)))
		return
	if clean == "/new":
		var dn: Variant = JSON.parse_string(body)
		if not (dn is Dictionary):
			_send(c, 400, "text/plain; charset=utf-8", "body 必须是 JSON 对象，如 {\"class\":\"暗影刺客\",\"seed\":\"\"}")
			return
		_send(c, 200, "application/json; charset=utf-8", JSON.stringify(new_run(dn as Dictionary)))
		return
	if clean == "/rewind":
		_send(c, 200, "application/json; charset=utf-8", JSON.stringify(rewind_battle()))
		return
	if clean == "/save":
		# ⚠️ 直接调 `RunSave.save_run()`，绕过 map_scene 里那道
		# `DisplayServer.get_name() != "headless"` 守卫 —— 那个守卫是给截图 / 回归探针
		# 用的，可 AI 对局恰好也是 headless 跑的，结果整局一次盘都没写，
		# 进程一被回收（实测跑 18 分钟就被系统杀掉过两次）局面全丢。
		var ok_sw := RunSave.save_run()
		_send(c, 200, "application/json; charset=utf-8", JSON.stringify({
			"ok": ok_sw,
			"msg": "已存盘：%s" % RunSave.SAVE_PATH if ok_sw else "存盘失败（看 save_trace.log）",
			"layer": RunState.current_layer, "node": RunState.current_node_id,
			"hp": RunState.hp, "chocolate": RunState.chocolate,
			"seed": RunState.seed_text() if RunState.run_active else "",
		}))
		return
	if clean == "/load":
		var ok_ld := RunSave.load_run()
		if ok_ld:
			SceneFx.goto("res://scenes/map.tscn", true)
		_send(c, 200, "application/json; charset=utf-8", JSON.stringify({
			"ok": ok_ld,
			"msg": "已从存档续上，正在进地图" if ok_ld else "续档失败（没有档 / 档坏了）",
			"layer": RunState.current_layer, "node": RunState.current_node_id,
			"hp": RunState.hp, "seed": RunState.seed_text() if RunState.run_active else "",
		}))
		return
	_send(c, 404, "text/plain; charset=utf-8", "未知路径：%s" % clean)


# ---------------------------------------------------------------- 公共入口

func act(d: Dictionary) -> Dictionary:
	## 执行一个动作。返回 {ok: bool, msg: String}。
	var target := str(d.get("target", ""))
	var res: Dictionary
	if _scene() == null:
		return {"ok": false, "msg": "当前没有场景"}
	var kind := _kind()
	if target == "":
		return {"ok": false, "msg": "缺 target（看看 /state 里的「可点目标」）"}
	# 连点保护：同一目标在很短时间里点第二下，多半是在**打断转场**
	# （地图入场过场 / 场景切换），结果就是「点了没反应」。直接挡掉并说清楚。
	var now_ms := Time.get_ticks_msec()
	if target == _last_target and now_ms - _last_ms < REPEAT_LOCK_MS:
		return {"ok": false, "msg": "「%s」刚点过（%d ms 前），等局面变一下再点"
				% [target, now_ms - _last_ms]}
	_last_target = target
	_last_ms = now_ms
	# R415：`rd<下标>` 也得走奖励口 —— `_reward_click()` 里早就写了 `rd` 分支，
	# 但这里是**唯一入口**，只放 `rw` 进来，于是「卡组页列出 rd0..rd22、点上去
	# 却回一句『认不出这个目标』」。targets 与 click 两套前缀必须在这里对齐。
	if target.begins_with("rw") or target.begins_with("rd"):
		res = _reward_click(target)
		_last_action = "%s → %s" % [target, str(res.get("msg", ""))]
		if bool(res.get("ok", false)):
			res["msg"] = "%s\n\n%s" % [str(res.get("msg", "")), describe()]
		return res
	match kind:
		"battle": res = _battle_click(target)
		"map": res = _map_click(target)
		"shop": res = _shop_click(target)
		"class_pick": res = _class_pick_click(target)
		"relic_pick": res = _relic_pick_click(target)
		"deck_edit": res = _deck_edit_click(target)
		_: res = _button_click(target)
	_last_action = "%s → %s" % [target, str(res.get("msg", ""))]
	if bool(res.get("ok", false)):
		res["msg"] = "%s\n\n%s" % [str(res.get("msg", "")), describe()]
	return res


func act_seq(d: Dictionary) -> Dictionary:
	## 连着点一串目标，**中途失败即停**（返回哪一步挂的）。
	## 存在的意义：AI 想好一整个回合的连招后，一条指令打完，不用一步一次往返。
	## 不是 bot —— 这里没有任何决策，顺序完全由调用方给。
	var arr: Array = []
	var raw: Variant = d.get("targets")
	if raw is Array:
		arr = raw
	var steps: Array = []
	var failed := ""
	var kind0 := _kind()
	for t in arr:
		var one := act({"target": str(t)})
		steps.append({"target": str(t), "ok": bool(one.get("ok", false)),
				"msg": str(one.get("msg", ""))})
		_last_target = ""          # 序列里同一个目标连点是有意的，不受连点保护限制
		if not bool(one.get("ok", false)):
			failed = "%s：%s" % [str(t), str(one.get("msg", ""))]
			break
		if _kind() != kind0:
			# 转场了（战斗打完 / 进奖励 / 回地图）→ 后面的目标已经属于另一个场景，别再点
			break
	var state_txt := describe()
	return {"ok": failed == "", "failed": failed, "steps": steps,
			"scene": _kind(), "sig": _sig(state_txt), "state": state_txt}


func new_run(d: Dictionary) -> Dictionary:
	## 指定职业 / 种子直接开局（跳过标题与选人界面）。
	## 种子留空 = 现摇一个；要复现某一局，把 `describe()` 里那 10 位码抄回来。
	var cid := str(d.get("class", "")).strip_edges()
	if cid == "":
		cid = PlayerClass.default_id()
	if not PlayerClass.ids().has(cid):
		return {"ok": false, "msg": "职业只能是：%s" % "、".join(PlayerClass.ids())}
	var code := str(d.get("seed", "")).strip_edges().to_upper()
	if code != "" and RunState.seed_value_of(code) < 0:
		return {"ok": false, "msg": "种子码不合法（10 位 A-Z / 0-9）：%s" % code}
	GameSettings.ensure_loaded()
	RunState.start_run([], GameLayers.LAYER_DEFAULT, cid, 0, code)
	if code != "":
		GameSettings.set_next_seed_code("")
	RunRecord.begin_run(cid)
	_battle_mark = {}
	SceneFx.goto("res://scenes/map.tscn")
	var state_txt := describe()
	return {"ok": true, "msg": "开新局：%s　种子 %s" % [cid, RunState.seed_text()],
			"seed": RunState.seed_text(), "state": state_txt}


func rewind_battle() -> Dictionary:
	## 战斗 SL：回到**本场刚开打**那一刻（局状态回到战前，战斗重开）。
	## 用来「这一场明显要输了 / 掉血太多 → 重打，换个打法」。
	## ⚠️ 只有本场战斗内有效；离开战斗后就没了（那是故意的：别拿它当全局作弊）。
	if _battle_mark.is_empty():
		return {"ok": false, "msg": "没有存档点（不在战斗中，或刚重开过还没重新记上）"}
	var snap: Dictionary = (_battle_mark.get("snap", {}) as Dictionary).duplicate(true)
	var lvl: Dictionary = (_battle_mark.get("level", {}) as Dictionary).duplicate(true)
	if snap.is_empty():
		return {"ok": false, "msg": "存档点里没有局状态"}
	if not RunSave.apply(snap):
		return {"ok": false, "msg": "恢复战斗起点失败（快照读不出来）"}
	RunState.pending_level = lvl
	_battle_mark = {}
	SceneFx.goto("res://scenes/battle.tscn")
	var state_txt := describe()
	return {"ok": true, "msg": "已回到本场开打那一刻", "state": state_txt}


func snapshot() -> Dictionary:
	var s: Variant = _scene()
	var out := {
		"scene": _kind(),
		"layer": RunState.current_layer,
		"node": RunState.current_node_id,
		"hp": RunState.hp, "max_hp": RunState.max_hp,
		"gold": RunState.gold, "chocolate": RunState.chocolate,
		"class": RunState.player_class,
		"deck": RunState.deck_ids.duplicate(),
		"relics": RunState.relics.duplicate(),
		"run_active": RunState.run_active,
		"last_action": _last_action,
	}
	out["targets"] = _all_targets(s)
	out["busy"] = _is_busy(s)
	out["sig"] = _sig(describe())
	out["seed"] = RunState.seed_text() if RunState.run_active else ""
	out["can_rewind"] = not _battle_mark.is_empty()
	if _kind() == "map":
		out["links"] = _map_links()
	if _kind() == "battle" and s != null and s.engine != null:
		out["battle"] = _battle_json(s)
	return out


func _is_busy(s: Variant) -> String:
	## 「现在点了也不一定算」的时段：敌方回合、演出中、转场过场。
	## 客户端据此等待，别把同一个动作连点好几遍。
	if s == null:
		return "无场景"
	match _kind():
		"battle":
			if s.engine != null and str(s.engine.current_side) != GameEngine.SIDE_SELF:
				return "敌方回合"
			if bool(s.get("_foe_phase") if s.get("_foe_phase") != null else false):
				return "敌方 AI 行动中"
			return ""
		"curtain":
			if bool(s.get("_typing") if s.get("_typing") != null else false):
				return "开场演出中"
			return ""
		"map":
			var anim: Variant = s.get("_anim_cell")
			if anim is Dictionary and not (anim as Dictionary).is_empty():
				return "过场动画中"
			return ""
	return ""


func _sig(txt: String) -> String:
	## 局面指纹：去掉「上一步」这类**每次动作都变**的行，剩下的才是真实局面。
	## AI 判断「这一步到底有没有推进」靠它（比对 state 全文会被「上一步」骗）。
	var keep: Array[String] = []
	for ln in txt.split("\n"):
		if ln.begins_with("上一步："):
			continue
		keep.append(ln)
	return "\n".join(keep)


func _all_targets(s: Variant) -> Array:
	## 统一的可点目标清单（JSON 版）—— 与 describe 里的「可点目标」段同源。
	if s == null:
		return []
	match _kind():
		"battle": return _battle_targets(s)
		"map": return _map_targets(s)
		"shop": return _shop_targets(s)
		"deck_edit": return _deck_edit_targets(s)
		"class_pick":
			var arr: Array = []
			var ids: Array = PlayerClass.ids()
			for i in ids.size():
				arr.append({"id": "c%d" % i, "hint": PlayerClass.name_of(str(ids[i]))})
			return arr
		"relic_pick":
			var arr2: Array = []
			for i in RunState.relic_choice.size():
				arr2.append({"id": "i%d" % i,
						"hint": RunState.relic_display_name(int(RunState.relic_choice[i]))})
			return arr2
	var btns := _collect_buttons(s)
	var out2: Array = []
	# 奖励**任何场景都能领** —— 事件房开箱 / 神秘泉会给奖励，而奖队是全局队列，
	# 不挂在这里的话 AI 在事件页就永远看不到「有东西要拿」，只能干点「离开」。
	if RunState.pending_reward_count() > 0:
		out2.append_array(_reward_targets())
		out2.append({"id": "rwdone", "hint": "奖励处理完"})
	for b: Dictionary in btns:
		out2.append({"id": b["id"], "hint": b["text"], "node": str(b.get("path", ""))})
	return out2


func describe() -> String:
	var s: Variant = _scene()
	if s == null:
		return "（没有场景）"
	var out: Array[String] = []
	out.append("═══ 卡牌肉鸽 · AI 视图 ═══")
	out.append("场景：%s" % _kind_cn())
	out.append(_run_line())
	if RunState.run_active and RunState.seed_text() != "":
		out.append("种子 %s%s" % [RunState.seed_text(),
				"　（本场可 rewind）" if not _battle_mark.is_empty() else ""])
	if RunState.pending_reward_count() > 0:
		out.append("⚠ 有 %d 条奖励待处理（进入奖励页或在地图上处理）"
				% RunState.pending_reward_count())
	if _last_action != "":
		out.append("上一步：%s" % _last_action)
	out.append("")
	match _kind():
		"battle": out.append_array(_battle_lines(s))
		"map": out.append_array(_map_lines(s))
		"shop": out.append_array(_shop_lines(s))
		"class_pick": out.append_array(_class_pick_lines())
		"relic_pick": out.append_array(_relic_pick_lines())
		"deck_edit": out.append_array(_deck_edit_lines(s))
		_: out.append_array(_button_lines(s))
	return "\n".join(out)


# ---------------------------------------------------------------- 场景定位

func _scene() -> Variant:
	return get_tree().current_scene


func _kind() -> String:
	var s: Variant = _scene()
	if s == null:
		return "none"
	return s.scene_file_path.get_file().get_basename()


func _kind_cn() -> String:
	match _kind():
		"battle": return "战斗"
		"map": return "地图"
		"shop": return "商店"
		"event": return "事件 / 休息"
		"class_pick": return "选职业"
		"relic_pick": return "选初始道具"
		"deck_edit":
			var s0: Variant = _scene()
			if s0 != null:
				var m0 := str(s0._mode())
				if _de_mode_name.has(m0):
					return "卡组编辑 — %s" % str(_de_mode_name[m0])
			return "卡组编辑"
		"title": return "标题"
		"settings": return "设置"
		"gallery": return "图鉴"
		"story": return "故事"
		"curtain": return "开场"
		"record_list": return "战绩"
		"ban": return "禁用卡"
	return _kind()


func _run_line() -> String:
	if not RunState.run_active:
		return "（不在 run 中：单关 / 演示模式）生命 %d/%d" % [RunState.hp, RunState.max_hp]
	var relic_txt := "无"
	if not RunState.relics.is_empty():
		var names: Array[String] = []
		for rid: int in RunState.relics:
			names.append(RunState.relic_display_name(rid))
		relic_txt = "、".join(names)
	return "第 %d 层   房间 %d   生命 %d/%d   金币 %d   巧克力 %d   职业 %s\n卡组 %d 张   道具：%s" % [
			RunState.current_layer, RunState.current_node_id,
			RunState.hp, RunState.max_hp, RunState.gold, RunState.chocolate,
			RunState.player_class, RunState.deck_ids.size(), relic_txt]


# ---------------------------------------------------------------- 战斗

func _battle_lines(s: Variant) -> Array[String]:
	var out: Array[String] = []
	if s.engine == null:
		out.append("（引擎还没建好）")
		return out
	var e: GameEngine = s.engine
	var st: FieldState = e.state
	var side := "我方" if str(e.current_side) == GameEngine.SIDE_SELF else "敌方（等 AI 行动）"
	out.append("── 战斗 ──")
	out.append("关卡：%s   第 %d 回合   %s" % [
			st.level_name if st.level_name != "" else "自由对战",
			st.self_turn_no, side])
	# R413：**必须照抄游戏 UI 的口径** —— 关卡把「敌方 HP 归零」这条胜利条件关掉
	# （`enemy_hp_infinite`，第三层 Boss 启示者）时，UI 显示的是 ∞/∞。这里以前硬写
	# `%d/%d`，AI 读到「敌方 HP 100/100」就会以为**直击 100 点即可通关**，
	# 而实际上这条路根本不存在（唯一胜利条件是击破本体）。工具骗人比没有工具更糟。
	var opp_hp: String = "∞/∞" if e.enemy_hp_infinite \
			else "%d/%d" % [st.hp_opponent, st.max_hp_opponent]
	out.append("我方 HP %d/%d   敌方 HP %s   费用 %d/%d" % [
			st.hp_self, st.max_hp_self, opp_hp,
			st.energy, e.max_energy()])
	out.append("手牌 %d   牌库 %d   弃牌 %d   消失 %d" % [
			st.hand.size(), st.deck.size(), st.discard.size(), st.void_count])
	if not st.enemy_effects.is_empty():
		out.append("敌方效果区：%s" % _names(st.enemy_effects))
	if not st.effects.is_empty():
		out.append("我方效果区：%s" % _names(st.effects))

	out.append("")
	out.append("战场（r0 = 敌方底线，r5 = 我方底线；[我]/[敌] 是**归属**，不是行）：")
	out.append_array(_board_grid(st))

	out.append("")
	out.append("手牌：")
	if st.hand.is_empty():
		out.append("  （空）")
	for i in st.hand.size():
		var c: CardData = st.hand[i]
		out.append("  h%d  %s" % [i, _card_brief(e, c)])

	var tg := _battle_targets(s)
	out.append("")
	out.append("可点目标：")
	for t: Dictionary in tg:
		out.append("  [%s] %s" % [str(t["id"]), str(t["hint"])])

	var note: String = str(s.status_text)
	if note != "":
		out.append("")
		out.append("界面提示：%s" % note)
	return out


func _board_grid(st: FieldState) -> Array[String]:
	## 一张 6 行全图，按**归属**标注 —— 以前按行号切成「敌方场面 / 我方场面」，
	## 结果敌人越过中线走进第 3~5 行时被塞进「我方场面」，我照着算伤害直接错。
	## 行坐标还是要留着（距离 = 行列差之和），所以画成全图而不是两侧列表。
	var out: Array[String] = []
	for r in FieldState.BOARD_ROWS:
		var cells: Array[String] = []
		for col in FieldState.BOARD_COLS:
			var cell := Vector2i(r, col)
			var p: Placement = st.unit_at(cell)
			var f: CardData = st.field_at(cell)
			if p != null:
				var who := "我" if str(p.owner) == GameEngine.SIDE_SELF else "敌"
				cells.append("[%s]%s %s" % [who, _unit_line(p), _state_tags(p)])
			elif f != null:
				var who2 := "我" if str(st.field_owner.get(cell, "self")) == "self" else "敌"
				cells.append("[%s]〔场地〕%s" % [who2, f.card_name])
			else:
				cells.append("—")
		out.append("  r%d  %s" % [r, " ｜ ".join(cells)])
	return out


func _unit_line(p: Placement) -> String:
	var c: CardData = p.card
	return "%s %d攻/%d血 射%d 移%d" % [c.card_name, c.power, p.health,
			c.attack_range, c.move_speed]


func _state_tags(p: Placement) -> String:
	var t: Array[String] = []
	if p.tapped:
		t.append("已横置")
	if p.moved:
		t.append("已移动")
	if p.acts_left > 0 and not p.tapped:
		t.append("可行动×%d" % p.acts_left)
	if p.upgrade_stacks > 0:
		t.append("改造×%d" % p.upgrade_stacks)
	if p.first_hit_shield:
		t.append("护盾")
	if p.sleep_left > 0:
		t.append("沉睡%d" % p.sleep_left)
	if p.stun_left > 0:
		t.append("眩晕%d" % p.stun_left)
	if p.frozen:
		t.append("冰封")
	if p.rooted > 0:
		t.append("禁足")
	if p.boss_phase > 0:
		t.append("阶段%d" % p.boss_phase)
	if t.is_empty():
		return ""
	return "[" + " ".join(t) + "]"


func _card_brief(e: GameEngine, c: CardData) -> String:
	var cost := e.cost_of(c)
	var pay := "可出" if e.can_pay_card(c) else "费用不足"
	var kind := "盟友"
	if c.is_spell():
		kind = "技能"
	elif c.is_effect():
		kind = "效果"
	elif c.is_field():
		kind = "场地"
	elif c.is_curse():
		kind = "诅咒"
	elif c.is_fort():
		# ⚠️ 这一支以前漏了 → 工事（木栅栏 8001 等）落到默认值被显示成「盟友」。
		# 踩过：靠这个字段判「自然之力 9051 能回几点费用」（它数的是**盟友**，
		# 工事不算），视图把工事写成盟友 → 误以为花 1 费回 3 费，实际净 0。
		kind = "工事"
	var stat := ""
	if c.power > 0 or c.health > 0:
		stat = " %d/%d 射%d 移%d" % [c.power, c.health, c.attack_range, c.move_speed]
	var extra := ""
	if c.is_spell():
		var now := e.spell_now(c)
		if not now.is_empty():
			var parts: Array[String] = []
			for k: String in now:
				parts.append("%s=%s" % [k, str(now[k])])
			extra = "  " + " ".join(parts)
	var body := (c.effect_text as String).replace("\n", " ")
	if body.length() > 46:
		body = body.substr(0, 46) + "…"
	return "%s（%s）%d费%s %s | %s%s" % [c.card_name, kind, cost, stat, pay, body, extra]


func _battle_json(s: Variant) -> Dictionary:
	var e: GameEngine = s.engine
	var st: FieldState = e.state
	var board: Array = []
	for pair: Array in st.iter_board():
		var cell: Vector2i = pair[0]
		var p: Placement = pair[1]
		board.append({"cell": [cell.x, cell.y], "owner": str(p.owner),
				"name": p.card.card_name, "id": p.card.id,
				"power": p.card.power, "hp": p.health,
				"range": p.card.attack_range, "speed": p.card.move_speed,
				"tapped": p.tapped, "moved": p.moved, "acts_left": p.acts_left})
	var hand: Array = []
	for i in st.hand.size():
		var c: CardData = st.hand[i]
		hand.append({"index": i, "name": c.card_name, "id": c.id,
				"cost": e.cost_of(c), "payable": e.can_pay_card(c)})
	var tg: Array = []
	for t: Dictionary in _battle_targets(s):
		tg.append({"id": t["id"], "hint": t["hint"]})
	return {"turn": st.self_turn_no, "side": str(e.current_side),
			"hp_self": st.hp_self, "hp_opp": st.hp_opponent,
			"hp_opp_infinite": e.enemy_hp_infinite,
			"win_on_boss": e.win_on_boss,
			"energy": st.energy, "max_energy": e.max_energy(),
			"board": board, "hand": hand, "targets": tg,
			"deck": st.deck.size(), "discard": st.discard.size()}


func _battle_targets(s: Variant) -> Array:
	## 当前**这一步**能点的一切。顺序 = 推荐阅读顺序。
	var out: Array = []
	var e: GameEngine = s.engine
	var st: FieldState = e.state
	if e.over:
		if RunState.pending_reward_count() > 0:
			out.append_array(_reward_targets())
			out.append({"id": "rwdone", "hint": "奖励处理完 → 结算离场"})
		else:
			out.append({"id": "leave", "hint": "战斗已结束：返回地图"})
		return out

	# ① 奖励窗开着 → 只处理奖励
	var rp: Variant = s.get("_reward_panel")
	if rp != null and bool(rp.is_open()):
		out.append_array(_reward_targets())
		out.append({"id": "rwdone", "hint": "处理完 / 关掉奖励窗"})
		return out

	# ①a 复活术 / 返修 / 暗影步 的「从弃牌区取一张」小面板（`_recall_pending()`）
	#     它**不是** `_pick`（走另一套小面板），以前这里一条分支都没有：面板开着、
	#     一个目标都不列、`end` 又被 `_on_end_turn` 的 guard 拦住（"复活术：请先选择
	#     一张要回到手牌的卡"）→ AI 直接卡死，只能盲点取消，而取消又是不允许的
	#     （R413 卡死在第 3 层 Boss 第 5 回合）。这里补一条：列候选 + 暴露 rcN。
	if s.has_method("_recall_pending") and bool(s._recall_pending()):
		var rlbl: String = str(s._recall_mode()) if s.has_method("_recall_mode") else "取牌"
		var ropts: Array = s._recall_options()
		for di: int in ropts:
			if di < 0 or di >= st.discard.size():
				continue
			var dc: CardData = st.discard[di]
			out.append({"id": "rc%d" % di,
					"hint": "%s：取回「%s」（%d费）" % [rlbl, dc.card_name, dc.cost]})
		return out

	# ①a2 鲸鱼之怒（`whale_pending`）—— **单独一条口**。
	# 它本该走 ①b 的全屏选卡页，但实测（R415，第 2 层「量产流水线」第 8 回合）
	# `_ensure_pick_visible("whale")` 建不出 cfg：`_pick.is_picking()` 一直 false，
	# 于是 `p*` / `pok` / `pcancel` 一条都列不出来，`_battle_targets` 返回**空数组**
	# —— AI 那边看到「可点目标：」后面什么都没有，整局卡死（和 R413 那次一样，
	# 只是那次是复活术走的小面板，这次是鲸鱼走的大面板）。
	# 候选本来就在引擎里（`whale_options()` 把弃牌区全列出来），不必依赖面板：
	# 直接按 `wp<弃牌下标>` 列出来，点击走 `engine.whale_pick()`。
	if e.whale_pending:
		var pk0: Variant = s._pick
		# 空 cfg 的残留面板先关掉，免得挡着「结束回合」的 guard 又说不清
		if pk0 != null and pk0.is_picking() and (pk0.opts() as Array).is_empty():
			pk0.close()
		for wi: int in e.whale_options():
			if wi < 0 or wi >= st.discard.size():
				continue
			var wc: CardData = st.discard[wi]
			out.append({"id": "wp%d" % wi,
					"hint": "鲸鱼之怒：取回「%s」（%d费；还可取 %d 张）"
							% [wc.card_name, wc.cost, int(e.whale_remaining)]})
		out.append({"id": "pcancel", "hint": "不选了（结束取牌）"})
		return out

	# ①a3 新生（`rebirth_pending`，9148）—— 与 ①a2 同一个坑：面板建不出来就自己列。
	# 实测（R416，第 3 层 Boss 第 6 回合）：效果区挂着「新生」，回合开始后界面提示
	# 「新生：请先从手牌里选一张使其消失（不能不选）」，但 `可点目标：` 后面**空的**，
	# 连 `end` 都不给 —— `_ensure_pick_visible("rebirth")` 没能把 cfg 建出来
	# （`_pick` 不处于 is_picking），于是 ①b 整段跳过，AI 一步都走不了。
	# 候选在引擎里现成（`rebirth_options()` = 全部手牌下标），不必依赖面板。
	if e.rebirth_pending:
		var pkR: Variant = s._pick
		if pkR != null and pkR.is_picking() and (pkR.opts() as Array).is_empty():
			pkR.close()
		for rbi: int in e.rebirth_options():
			if rbi < 0 or rbi >= st.hand.size():
				continue
			var rbc: CardData = st.hand[rbi]
			out.append({"id": "rb%d" % rbi,
					"hint": "新生：让手牌「%s」（%d费）消失（本层还要选 %d 张）"
							% [rbc.card_name, rbc.cost, int(e.rebirth_remaining)]})
		return out

	# ①a4 乌鸦（`crow_pending`）—— 与 ①a2 / ①a3 同一类：全屏选卡页建不出来就自己列。
	# 实测（R417，第 2 层「百眼动员」第 4 回合）：0 费的乌鸦下场后提示
	# 「乌鸦：请先选择一张要回到手牌的盟友」，`可点目标：` 后面**空的**，`end` 又点不动
	# （`_on_end_turn` 的 guard 挡住）→ AI 一步都走不了。
	# 候选在引擎里现成（`crow_options()` = 弃牌堆里所有「盟友」的下标，乌鸦自己排除）。
	if e.crow_pending:
		var pkC: Variant = s._pick
		if pkC != null and pkC.is_picking() and (pkC.opts() as Array).is_empty():
			pkC.close()
		for ci: int in e.crow_options():
			if ci < 0 or ci >= st.discard.size():
				continue
			var cc: CardData = st.discard[ci]
			out.append({"id": "cr%d" % ci,
					"hint": "乌鸦：取回「%s」（%d费）" % [cc.card_name, cc.cost]})
		return out

	# ①a5 专注（9122）/ 负重减轻（8066）—— 与 ①a2~a4 同一类「面板一开、targets 就空」。
	# 根因不同：这两张卡的选卡页 `opts` 存的是**卡 id**（`_build_pick_cfg("focus")`
	# 走 `_merged_deck()` 合并视图，元素是 `CardData.id` 而不是 `CardData`），而下面
	# ①b 通用分支写的是 `var c: CardData = opts[i]` —— 对 int 赋值类型不匹配，
	# GDScript 在**运行时**抛错、整个 `_battle_targets` 中断，targets 就成了空数组
	# （R442 实测：第 2 层「量产铁砧」第 2 回合打出专注后 AI 完全动不了）。
	# 候选本来就在引擎里（`focus_options()` = 抽牌库全部下标），不必依赖面板：
	# 直接按 `fk<抽牌库下标>` 列，点击走 `engine.focus_pick()`。
	if e.focus_pending:
		var pkF: Variant = s._pick
		if pkF != null and pkF.is_picking() and (pkF.opts() as Array).is_empty():
			pkF.close()
		var flbl: String = str(e.focus_label)
		for fi: int in e.focus_options():
			if fi < 0 or fi >= st.deck.size():
				continue
			var fc: CardData = st.deck[fi]
			out.append({"id": "fk%d" % fi,
					"hint": "%s：移除「%s」（%d费；还要移除 %d 张）"
							% [flbl, fc.card_name, fc.cost, int(e.focus_remaining)]})
		out.append({"id": "fkcancel", "hint": "不选了（已移除的不回收）"})
		return out

	# ①b 全屏选卡页 → 只能选卡 / 确认 / 取消
	# R413：**先主动把面板建出来**。引擎侧的取牌 pending（鲸鱼之怒 9084 / 乌鸦 /
	# 复活术 / 无尽黑暗 / 新生 / 预判…）不是「点了就开」——`_sync_pick()` 要到**下一帧**
	# 才按 `_pick_active_kind()` 建出 cfg。AI 在这一帧抓 state 时 `_pick._cfg` 还是空的，
	# 于是一个 `p*` 都列不出来（连 `pcancel` 都不给），只能盲点结束回合或硬着头皮点
	# `pcancel`，把「鲸鱼之怒取 2 张」「复活术取 1 张」白扔掉（R413 实测一局丢了 4 张）。
	var pick: Variant = s._pick
	if s.has_method("_pick_active_kind") and s.has_method("_ensure_pick_visible"):
		var ak: String = str(s._pick_active_kind())
		if ak != "" and pick != null and not pick.is_picking():
			s._ensure_pick_visible(ak)
	if pick != null and pick.is_picking():
		var opts: Array = pick.opts()
		for i in opts.size():
			# ⚠️ 不是所有选卡页的 opts 都是 CardData：专注 / 负重减轻存的是卡 id，
			#    淘汰 / 惊喜运单存的是卡组下标。以前这里硬转 CardData 会运行时抛错，
			#    把整个 targets 打空（R442）。非 CardData 一律退化成「第 N 项」。
			var ov: Variant = opts[i]
			var pnm := "第 %d 项" % i
			var pcst := 0
			if ov is CardData:
				pnm = (ov as CardData).card_name
				pcst = (ov as CardData).cost
			out.append({"id": "p%d" % i,
					"hint": "选卡页：%s（%d费）" % [pnm, pcst]})
		out.append({"id": "pok", "hint": "确认当前选择（已选 %d 张）" % pick.selected_count()})
		out.append({"id": "pcancel", "hint": "取消 / 关闭选卡页"})
		return out

	# ② 涂装机器人等「场上点一个单位」
	if e.paint_pending:
		for cell: Vector2i in e.paint_options():
			var pp: Placement = st.unit_at(cell)
			out.append({"id": "r%dc%d" % [cell.x, cell.y],
					"hint": "涂装目标：%s" % (pp.card.card_name if pp != null else "?")})
		return out

	# ③ 技能选目标中
	if int(s.spell_pending) >= 0:
		var sp: CardData = st.hand[int(s.spell_pending)]
		for cell: Vector2i in s.spell_targets:
			out.append({"id": "r%dc%d" % [cell.x, cell.y],
					"hint": "「%s」的目标格" % sp.card_name})
		return out

	# ④ 已选中场上单位 → 移动 / 攻击 / 打 HP / 主动发动
	if s.selection != null and str(s.selection[0]) == "board":
		var src: Vector2i = s.selection[1]
		var sp2: Placement = st.unit_at(src)
		for cell: Vector2i in s.attack_targets_arr:
			var tp: Placement = st.unit_at(cell)
			out.append({"id": "r%dc%d" % [cell.x, cell.y],
					"hint": "攻击 %s" % (tp.card.card_name if tp != null else "?")})
		for cell: Vector2i in s.hp_targets_arr:
			out.append({"id": "r%dc%d" % [cell.x, cell.y], "hint": "直击敌方 HP"})
		for cell: Vector2i in s.move_targets:
			out.append({"id": "r%dc%d" % [cell.x, cell.y], "hint": "移动到这里"})
		if sp2 != null and e.can_activate(src, GameEngine.SIDE_SELF):
			out.append({"id": "r%dc%d" % [src.x, src.y],
					"hint": "原地发动（%s）" % sp2.card.card_name})
		out.append({"id": "cancel", "hint": "取消选择"})
		return out

	# ⑤ 已选中手牌 → 放置格 / 使用
	if s.selection != null and str(s.selection[0]) == "hand":
		var i: int = int(s.selection[1])
		var c: CardData = st.hand[i]
		out.append({"id": "h%d" % i, "hint": "再点一次 = 使用「%s」" % c.card_name})
		# 技能 / 效果 / 诅咒都不落在格子上 —— 别再列「放到这里」（会误导 AI 去点空格）
		if c.is_spell() or c.is_effect() or c.is_curse():
			out.append({"id": "cancel", "hint": "取消选择"})
			return out
		var cells: Array = []
		if c.is_field():
			cells = s._field_place_cells(c)
		else:
			cells = s._own_place_cells(c)
			cells.append_array(s._fence_merge_cells(c))
		for cell: Vector2i in cells:
			out.append({"id": "r%dc%d" % [cell.x, cell.y],
					"hint": "把「%s」放到这里" % c.card_name})
		out.append({"id": "cancel", "hint": "取消选择"})
		return out

	# ⑥ 常规：选一张手牌 / 选一个己方单位 / 结束回合
	if str(e.current_side) == GameEngine.SIDE_SELF:
		for i in st.hand.size():
			var c2: CardData = st.hand[i]
			out.append({"id": "h%d" % i, "hint": "选中手牌「%s」（%d费，%s）" % [
					c2.card_name, e.cost_of(c2),
					"可出" if e.can_pay_card(c2) else "费用不足"]})
		for pair: Array in st.iter_board():
			var cell2: Vector2i = pair[0]
			var p2: Placement = pair[1]
			if str(p2.owner) != GameEngine.SIDE_SELF or p2.tapped:
				continue
			# 只列「这一步真能做点什么」的单位：木栅栏这类移0攻0的，
			# 点进去只会得到一句「只能取消」，对决策是纯噪音。
			var can_move := not (e._reachable(cell2, GameEngine.SIDE_SELF) as Array).is_empty()
			var can_hit := not (e.legal_attack_targets(cell2) as Array).is_empty()
			var can_fire := e.can_activate(cell2, GameEngine.SIDE_SELF)
			if not (can_move or can_hit or can_fire):
				continue
			out.append({"id": "r%dc%d" % [cell2.x, cell2.y],
					"hint": "选中我方单位「%s」" % p2.card.card_name})
		out.append({"id": "end", "hint": "结束回合"})
	else:
		out.append({"id": "wait", "hint": "敌方回合，等它打完（读一次 /state 看进度）"})
	return out


func _battle_click(target: String) -> Dictionary:
	var s: Variant = _scene()
	if s == null or s.engine == null:
		return {"ok": false, "msg": "战斗还没开始"}
	var e: GameEngine = s.engine
	var st: FieldState = e.state

	if target == "end":
		s._on_end_turn()
		return {"ok": true, "msg": "结束回合"}
	if target == "cancel":
		s._on_right_click()
		return {"ok": true, "msg": "取消选择"}
	if target == "leave":
		# 走**正式离场**：`_on_over_restart` 会推进层 / 标记房间完成 / 发奖励，
		# 直接 goto(map) 会把这些全跳过（奖励丢、层不推进）。
		if s.has_method("_on_over_restart"):
			s._on_over_restart()
		return {"ok": true, "msg": "结算离场"}
	if target == "wait":
		return {"ok": false, "msg": "敌方回合，先等一拍再读 /state"}

	# 复活术 / 返修 / 暗影步：从弃牌区取一张（`rc<弃牌下标>`）
	if target.begins_with("rc") and target.substr(2).is_valid_int():
		if not (s.has_method("_recall_pending") and bool(s._recall_pending())):
			return {"ok": false, "msg": "现在没有开着的取牌面板"}
		var ri := int(target.substr(2))
		var rname: String = str(st.discard[ri].card_name) if ri >= 0 and ri < st.discard.size() else "?"
		var rok: bool = bool(s._recall_discard_index(ri))
		return {"ok": rok, "msg": "取回「%s」%s" % [rname, "" if rok else "（失败）"]}

	# 鲸鱼之怒取牌（R415：见 `_battle_targets` ①a2）
	if target.begins_with("wp") and target.substr(2).is_valid_int():
		if not e.whale_pending:
			return {"ok": false, "msg": "现在没有鲸鱼之怒取牌"}
		var wi := int(target.substr(2))
		if wi < 0 or wi >= st.discard.size():
			return {"ok": false, "msg": "弃牌区没有第 %d 张" % wi}
		var wn: String = str(st.discard[wi].card_name)
		var wok: bool = e.whale_pick(wi)
		var pk1: Variant = s._pick
		if not e.whale_pending and pk1 != null and pk1.is_picking() \
				and (pk1.opts() as Array).is_empty():
			pk1.close()
		return {"ok": wok, "msg": "鲸鱼之怒：取回「%s」%s" % [wn, "" if wok else "（失败）"]}

	# 新生（R416：见 `_battle_targets` ①a3）
	if target.begins_with("rb") and target.substr(2).is_valid_int():
		if not e.rebirth_pending:
			return {"ok": false, "msg": "现在没有新生结算"}
		var rbi2 := int(target.substr(2))
		if rbi2 < 0 or rbi2 >= st.hand.size():
			return {"ok": false, "msg": "手牌里没有第 %d 张" % rbi2}
		var rbn: String = str(st.hand[rbi2].card_name)
		var rbok: bool = e.rebirth_pick(rbi2)
		var pkR2: Variant = s._pick
		if not e.rebirth_pending and pkR2 != null and pkR2.is_picking() \
				and (pkR2.opts() as Array).is_empty():
			pkR2.close()
		return {"ok": rbok, "msg": "新生：%s %s" % [rbn, "消失" if rbok else "（失败）"]}

	# 乌鸦取牌（R417：见 `_battle_targets` ①a4）
	if target.begins_with("cr") and target.substr(2).is_valid_int():
		if not e.crow_pending:
			return {"ok": false, "msg": "现在没有乌鸦取牌"}
		var ci2 := int(target.substr(2))
		if ci2 < 0 or ci2 >= st.discard.size():
			return {"ok": false, "msg": "弃牌区没有第 %d 张" % ci2}
		var cn: String = str(st.discard[ci2].card_name)
		var cok: bool = e.crow_recall(ci2)
		var pkC2: Variant = s._pick
		if not e.crow_pending and pkC2 != null and pkC2.is_picking() \
				and (pkC2.opts() as Array).is_empty():
			pkC2.close()
		return {"ok": cok, "msg": "乌鸦：取回「%s」%s" % [cn, "" if cok else "（失败）"]}

	# 专注 / 负重减轻（R442：见 `_battle_targets` ①a5）
	if target == "fkcancel":
		if not e.focus_pending:
			return {"ok": false, "msg": "现在没有专注 / 负重减轻在等选卡"}
		var flc: String = str(e.focus_label)
		e.focus_cancel()
		return {"ok": true, "msg": "%s：已取消剩余的移除（已移除的不回收）" % flc}
	if target.begins_with("fk") and target.substr(2).is_valid_int():
		if not e.focus_pending:
			return {"ok": false, "msg": "现在没有专注 / 负重减轻在等选卡"}
		var fi2 := int(target.substr(2))
		if fi2 < 0 or fi2 >= st.deck.size():
			return {"ok": false, "msg": "抽牌库没有第 %d 张" % fi2}
		var fnm: String = str(st.deck[fi2].card_name)
		var flab: String = str(e.focus_label)
		var fok: bool = e.focus_pick(fi2)
		return {"ok": fok, "msg": "%s：移除「%s」%s" % [flab, fnm, "" if fok else "（失败）"]}

	# 选卡页
	if target.begins_with("p"):
		var pick: Variant = s._pick
		if pick == null or not pick.is_picking():
			return {"ok": false, "msg": "现在没有开着的选卡页"}
		if target == "pok":
			var sel: Array = pick._selected.duplicate()
			if sel.is_empty():
				return {"ok": false, "msg": "还没选任何卡"}
			s._on_pick_confirmed(sel)
			return {"ok": true, "msg": "已确认选择 %s" % str(sel)}
		if target == "pcancel":
			s._on_pick_cancelled()
			return {"ok": true, "msg": "已取消选卡"}
		var pi := int(target.substr(1))
		var opts: Array = pick.opts()
		if pi < 0 or pi >= opts.size():
			return {"ok": false, "msg": "选卡页没有 p%d" % pi}
		if not pick.visible:
			pick.reopen()
		# 走真实点击路径（`_tap` 内部按上限 toggle 选中）
		pick._tap(pick._card_rect(pi).get_center())
		var piov: Variant = opts[pi]
		var pnml := "第 %d 项" % pi
		if piov is CardData:
			pnml = (piov as CardData).card_name
		return {"ok": true, "msg": "选卡页点了第 %d 张：%s（已选 %d）"
				% [pi, pnml, pick.selected_count()]}

	# 手牌
	if target.begins_with("h") and target.substr(1).is_valid_int():
		var hi := int(target.substr(1))
		if hi < 0 or hi >= st.hand.size():
			return {"ok": false, "msg": "手牌里没有 h%d" % hi}
		if str(e.current_side) != GameEngine.SIDE_SELF:
			return {"ok": false, "msg": "现在是敌方回合"}
		if s.selection != null and str(s.selection[0]) == "hand" and int(s.selection[1]) == hi:
			var used: String = st.hand[hi].card_name
			s._use_hand_card(hi)
			return {"ok": true, "msg": "使用手牌「%s」" % used}
		s._pass_moved_pending()
		s._clear_selection()
		s.selection = ["hand", hi]
		var c: CardData = st.hand[hi]
		var advice := "再点一次 h%d 使用它" % hi
		if not c.is_spell() and not c.is_effect() and not c.is_curse():
			advice = "再点一个自己半场的格子把它放下"
		return {"ok": true, "msg": "选中手牌「%s」—— %s" % [c.card_name, advice]}

	# 棋盘格
	if target.begins_with("r") and target.contains("c"):
		var cell := _parse_cell(target)
		if cell.x < 0:
			return {"ok": false, "msg": "格子 id 格式应为 r3c1"}
		if s.selection != null and str(s.selection[0]) == "hand":
			var idx: int = int(s.selection[1])
			s._on_board_click(cell)   # 内部按卡种分流（场地 / 随从 / 技能提示）
			return {"ok": true, "msg": "点了 %s（手牌落位）" % target}
		s._on_board_click(cell)
		return {"ok": true, "msg": "点了 %s" % target}

	return {"ok": false, "msg": "认不出这个目标：%s" % target}


func _parse_cell(id: String) -> Vector2i:
	var ci := id.find("c")
	if ci < 2:
		return Vector2i(-1, -1)
	var r := int(id.substr(1, ci - 1))
	var c := int(id.substr(ci + 1))
	if r < 0 or r >= FieldState.BOARD_ROWS or c < 0 or c >= FieldState.BOARD_COLS:
		return Vector2i(-1, -1)
	return Vector2i(r, c)


func _names(arr: Array) -> String:
	var out: Array[String] = []
	for c: CardData in arr:
		out.append(c.card_name)
	return "、".join(out)


# ---------------------------------------------------------------- 地图

func _map_lines(s: Variant) -> Array[String]:
	var out: Array[String] = []
	out.append("── 地图 · 第 %d 层 ──" % RunState.current_layer)
	var cells: Array = RunState.map_cells
	if cells.is_empty():
		out.append("（地图还没生成）")
		return out
	var cur := RunState.current_node_id
	out.append("当前房间：%s" % ("未出发" if cur < 0 else "n%d（%s）"
			% [cur, _cell_type_cn(cells[cur]) if cur < cells.size() else "?"]))
	out.append("")
	out.append("可前往：")
	# R415（我自己踩的）：这里以前只判 `_map_reachable()` 就列出来，而 `_map_targets()`
	# 还多一道「跳过已走过」的过滤 —— 于是同一屏上「可前往」列 12 个、可点目标只有 5 个，
	# 差的那 7 个全是我**已经逛过**的房间（本局实测：n23 商店 / n29 鸭子窑精英 / n30 /
	# n32 休息 / n31 起点…）。文字版看着「还能去商店」，实际走进去什么都不发生，
	# 按它规划路线就是白扔层数。现在两边**同一口径**：先收「可达且未走」，
	# 一个都没有（死路）才退化成「全部可达」，与 `_map_targets()` 的 fresh/all 一一对应。
	var fresh_parts: Array[String] = []
	var all_parts: Array[String] = []
	for c: Dictionary in cells:
		var cid := int(c.get("id", -1))
		if cid < 0 or cid == cur:
			continue
		if not _map_reachable(s, cid):
			continue
		var sline := "  [n%d] %s · 第%d行" % [cid, _cell_type_cn(c), int(c.get("row", 0))]
		all_parts.append(sline)
		if not RunState.cleared_ids.has(cid):
			fresh_parts.append(sline)
	var parts: Array[String] = fresh_parts if not fresh_parts.is_empty() else all_parts
	for p2 in parts:
		out.append(p2)
	if parts.is_empty():
		out.append("  （没有能去的房间 —— 可能得先处理完奖励）")
	out.append("")
	# 只列**还没走过**的房间：走过的对决策没有价值，全列出来会占掉半屏
	# （35 个房间一行），AI 反而看不清「下一步能去哪」。
	out.append("未走的房间（可规划路线用）：")
	var line: Array[String] = []
	for c: Dictionary in cells:
		var cid2 := int(c.get("id", -1))
		if cid2 == cur or RunState.cleared_ids.has(cid2):
			continue
		line.append("n%d:%s" % [cid2, _cell_type_cn(c)])
	if line.is_empty():
		out.append("  （都走过了）")
	else:
		out.append("  " + "  ".join(line))
	out.append("")
	# 光有房间列表看不出「从哪能到哪」—— 每层只有 12 块巧克力，走到死胡同
	# 就是白扔一间。连线只列**未走房间 + 当前房**：走过的房间可以零消耗穿行，
	# 把它们的边也画出来只会让图变成一团毛线。
	var links := _map_links()
	if not links.is_empty():
		out.append("连线（未走房间 + 当前房）：")
		for nl: Dictionary in links:
			out.append("  n%d → %s" % [int(nl["id"]),
					" ".join(nl["to"])])
		out.append("")
	out.append("可点目标：")
	for t: Dictionary in _map_targets(s):
		out.append("  [%s] %s" % [str(t["id"]), str(t["hint"])])
	return out


func _map_links() -> Array:
	## 路线图：每个「未走房间 / 当前房」直接相邻的同集合房间。
	## 判定与地图点击同源（`RogueMap.doors_between`），不自己算坐标。
	var cells: Array = RunState.map_cells
	if cells.is_empty():
		return []
	var keep: Array = []
	var cur := RunState.current_node_id
	if cur >= 0 and cur < cells.size():
		keep.append(cur)
	for c: Dictionary in cells:
		var cid := int(c.get("id", -1))
		if cid < 0 or cid == cur or RunState.cleared_ids.has(cid):
			continue
		keep.append(cid)
	keep.sort()
	var out: Array = []
	for a: int in keep:
		var to: Array[String] = []
		for b: int in keep:
			if a == b:
				continue
			if RogueMap.doors_between(cells, a, b):
				to.append("n%d" % b)
		if not to.is_empty():
			out.append({"id": a, "to": to})
	return out


func _map_targets(s: Variant) -> Array:
	## 奖励面板开着 → **只列奖励**。地图上的宝箱 / 事件给的奖励走的是同一条全局队列
	## (`RunState.pending_rewards`)，但以前这个分支只列房间，于是面板明明开着、
	## `rw*` 一个都看不见，AI 只能反复点「打开待领奖励」原地打转（R412 踩过）。
	## 战斗场景早就有这一支（`_battle_targets` 的 ①），地图这边漏了。
	var rp: Variant = s.get("_reward_panel")
	if rp != null and bool(rp.is_open()):
		var ro: Array = _reward_targets()
		ro.append({"id": "rwdone", "hint": "处理完 / 关掉奖励窗"})
		return ro
	## 只列**没去过**的房间 —— 已走过的房间走进去什么都不会发生，
	## 列出来只会让 AI 在两张图之间来回踱步（实测过）。
	## 万一同行都走完了（死路），退化成「全部可达」，至少不卡死。
	var fresh: Array = []
	var all: Array = []
	var cells: Array = RunState.map_cells
	var cur := RunState.current_node_id
	for c: Dictionary in cells:
		var cid := int(c.get("id", -1))
		if cid < 0 or cid == cur or not _map_reachable(s, cid):
			continue
		var item := {"id": "n%d" % cid, "hint": "走进 %s" % _cell_type_cn(c)}
		all.append(item)
		if not RunState.cleared_ids.has(cid):
			fresh.append(item)
	var out: Array = fresh if not fresh.is_empty() else all
	if RunState.pending_reward_count() > 0:
		out.append({"id": "reward", "hint": "打开待领奖励"})
	return out


func _map_reachable(_s: Variant, id: int) -> bool:
	## 与地图场景的高亮 / 点击**同源**：`RunState.can_reach()` =
	## 「走过的连通区 + 它们的相邻格」。走过的那几间可以零消耗穿行，
	## `map_scene._enter_node()` 会自己把中间那段静默走掉。
	## ⚠️ 别用 `can_move_to()` —— 它只看**直接相邻**。走到一条支路的末端时，
	## 真正能去的下一间隔着几间走过的空房，用 `can_move_to` 会全判成「去不了」，
	## 表现为「地图上哪里都不能去」（实测踩过，还以为是地图生成坏了）。
	if RunState.shop_revisit_ok(id):
		return true          # 站在这格的商店上时，允许重进
	return RunState.can_reach(id)


func _cell_type_cn(c: Dictionary) -> String:
	var t := str(c.get("type", ""))
	if t == "":
		t = str(c.get("display", ""))
	match t:
		"start": return "起点"
		"battle": return "战斗"
		"elite": return "精英"
		"boss": return "Boss"
		"event": return "事件"
		"rest": return "休息"
		"chest": return "宝箱"
		"bigchest": return "大宝箱"
		"shop": return "商店"
		"unknown", "?": return "未知"
	return t


func _map_click(target: String) -> Dictionary:
	var s: Variant = _scene()
	if target == "reward":
		if s.has_method("_open_reward_panel"):
			s._open_reward_panel()
			return {"ok": true, "msg": "打开奖励面板"}
		return {"ok": false, "msg": "这里不能开奖励面板"}
	if not target.begins_with("n"):
		return {"ok": false, "msg": "地图上的目标形如 n12"}
	var id := int(target.substr(1))
	var cells: Array = RunState.map_cells
	if id < 0 or id >= cells.size():
		return {"ok": false, "msg": "没有房间 n%d" % id}
	if not _map_reachable(s, id):
		return {"ok": false, "msg": "n%d 现在去不了（不相邻或未开放）" % id}
	s._enter_node(cells[id])
	return {"ok": true, "msg": "走进 n%d（%s）" % [id, _cell_type_cn(cells[id])]}


# ---------------------------------------------------------------- 商店

func _shop_overlay(s: Variant) -> bool:
	## 商店里两种「选卡覆盖层」：第二行附魔（`_enchanting >= 0`）、第三行删卡（`_deleting`）。
	return int(s.get("_enchanting")) >= 0 or bool(s.get("_deleting"))


func _shop_targets(s: Variant) -> Array:
	var out: Array = []
	if _shop_overlay(s):
		var dc: Array = []
		var raw: Variant = s.get("_deck_cards")
		if raw is Array:
			dc = raw
		for i in dc.size():
			var d: Dictionary = dc[i]
			if not bool(d.get("ok", true)):
				continue
			var c: Variant = d.get("card")
			var nm := "?"
			if c != null:
				nm = str(c.card_name)
			out.append({"id": "p%d" % i, "hint": "选「%s」并成交" % nm})
		out.append({"id": "pcancel", "hint": "取消，回到货架"})
		return out
	var r1: Array = []
	var r2: Array = []
	var r3: Array = []
	var v1: Variant = s.get("_row1")
	if v1 is Array:
		r1 = v1
	var v2: Variant = s.get("_row2")
	if v2 is Array:
		r2 = v2
	var v3: Variant = s.get("_row3")
	if v3 is Array:
		r3 = v3
	for i in r1.size():
		var e1: Dictionary = r1[i]
		if bool(e1.get("sold", false)):
			continue
		var c1: Variant = e1.get("card")
		var nm1 := "?"
		if c1 != null:
			nm1 = str(c1.card_name)
		out.append({"id": "s%d" % (i + 1000), "hint": "买卡「%s」（%d 金币）" % [nm1, int(s._card_price(c1))]})
	for i in r2.size():
		var e2: Dictionary = r2[i]
		if bool(e2.get("sold", false)):
			continue
		out.append({"id": "s%d" % (i + 2000), "hint": "买附魔 #%d" % i})
	for i in r3.size():
		var e3: Dictionary = r3[i]
		if bool(e3.get("sold", false)):
			continue
		out.append({"id": "s%d" % (i + 3000),
				"hint": "买服务「%s」" % _row3_cn(str(e3.get("key", "")))})
	out.append({"id": "leave", "hint": "离开商店"})
	return out


func _shop_pick_lines(s: Variant) -> Array[String]:
	var out: Array[String] = []
	out.append("── 商店 · 选卡 ──")
	var is_del := bool(s.get("_deleting"))
	if is_del:
		out.append("用途：选择要删除的卡")
	else:
		var ench: Dictionary = (s.get("_row2") as Array)[int(s.get("_enchanting"))]["ench"]
		out.append("用途：给一张卡附上「%s」" % CardData.enchant_name(str(ench.get("id", ""))))
	out.append("金币 %d" % RunState.gold)
	out.append("")
	var dc: Array = []
	var raw: Variant = s.get("_deck_cards")
	if raw is Array:
		dc = raw
	var any_ok := false
	for i in dc.size():
		var d: Dictionary = dc[i]
		var c: Variant = d.get("card")
		var ok := bool(d.get("ok", true))
		if ok:
			any_ok = true
		var nm := "?"
		var cost := 0
		if c != null:
			nm = str(c.card_name)
			cost = int(c.cost)
		out.append("  %s  %s（%d费）%s" % [
				"[p%d]" % i if ok else " p%d " % i, nm, cost,
				"" if ok else "　不能选"])
	if not dc.is_empty() and not any_ok:
		out.append("（卡组里没有符合条件的卡）")
	out.append("")
	out.append("可点目标：")
	for i in dc.size():
		if bool((dc[i] as Dictionary).get("ok", true)):
			out.append("  [p%d] 选这张并成交" % i)
	out.append("  [pcancel] 取消，回到货架")
	return out


func _shop_lines(s: Variant) -> Array[String]:
	if _shop_overlay(s):
		return _shop_pick_lines(s)
	var out: Array[String] = []
	out.append("── 商店 ──")
	out.append("金币 %d" % RunState.gold)
	out.append("")
	out.append("货架一（卡牌）：")
	var r1: Array = s.get("_row1") if s.get("_row1") != null else []
	for i in r1.size():
		var e: Dictionary = r1[i]
		var c: CardData = e["card"]
		var price: int = s._card_price(c)
		var sold := bool(e.get("sold", false))
		out.append("  %s  %s（%d费 %s）%d 金币%s" % [
				"s%d" % (i + 1000), c.card_name, c.cost, _kind_cn_card(c),
				price, "  【已售出】" if sold else ""])
	out.append("货架二（附魔）：")
	var r2: Array = s.get("_row2") if s.get("_row2") != null else []
	for i in r2.size():
		var e2: Dictionary = r2[i]
		var en: Dictionary = e2.get("ench", {})
		out.append("  %s  %s%s" % ["s%d" % (i + 2000),
				str(en.get("name", en.get("id", "?"))),
				"  【已售出】" if bool(e2.get("sold", false)) else ""])
	out.append("货架三（服务）：")
	var r3: Array = s.get("_row3") if s.get("_row3") != null else []
	for i in r3.size():
		var e3: Dictionary = r3[i]
		out.append("  %s  %s%s" % ["s%d" % (i + 3000),
				_row3_cn(str(e3.get("key", ""))),
				"  【已售出】" if bool(e3.get("sold", false)) else ""])
	out.append("")
	out.append("可点目标：")
	for i in r1.size():
		var e4: Dictionary = r1[i]
		if not bool(e4.get("sold", false)):
			out.append("  [s%d] 买卡「%s」（%d 金币）" % [
					i + 1000, (e4["card"] as CardData).card_name, s._card_price(e4["card"])])
	for i in r2.size():
		if not bool((r2[i] as Dictionary).get("sold", false)):
			out.append("  [s%d] 买附魔 #%d" % [i + 2000, i])
	for i in r3.size():
		if not bool((r3[i] as Dictionary).get("sold", false)):
			out.append("  [s%d] 买服务「%s」" % [i + 3000,
					_row3_cn(str((r3[i] as Dictionary).get("key", "")))])
	out.append("  [leave] 离开商店")
	var hint := str(s.get("_hint") if s.get("_hint") != null else "")
	if hint != "":
		out.append("")
		out.append("商店提示：%s" % hint)
	return out


func _kind_cn_card(c: CardData) -> String:
	if c.is_spell():
		return "技能"
	if c.is_effect():
		return "效果"
	if c.is_field():
		return "场地"
	return "盟友"


func _row3_cn(k: String) -> String:
	match k:
		"delete": return "删除一张卡"
		"maxhp": return "最大生命 +"
		"choco": return "巧克力 +"
	return k


func _shop_click(target: String) -> Dictionary:
	var s: Variant = _scene()
	if target == "pcancel":
		s._enchanting = -1
		s._deleting = false
		s._hover_enchant_card = -1
		s._sel_pick = -1
		s._ask_redraw()
		return {"ok": true, "msg": "取消选卡，回到货架"}
	if target.begins_with("p") and target.substr(1).is_valid_int():
		if not _shop_overlay(s):
			return {"ok": false, "msg": "现在没有选卡页，目标形如 s1000 / leave"}
		var pi := int(target.substr(1))
		var dc: Array = []
		var raw: Variant = s.get("_deck_cards")
		if raw is Array:
			dc = raw
		if pi < 0 or pi >= dc.size():
			return {"ok": false, "msg": "没有 p%d（候选 %d 张）" % [pi, dc.size()]}
		if not bool((dc[pi] as Dictionary).get("ok", true)):
			return {"ok": false, "msg": "p%d 这张卡不符合条件，选不了" % pi}
		s._sel_pick = pi
		var ctr: Vector2 = s._pick_confirm_rect().get_center()
		s._on_pick_click(ctr)
		var hint := str(s.get("_hint") if s.get("_hint") != null else "")
		if int(s.get("_enchanting")) >= 0:
			return {"ok": true, "msg": "选了 p%d（覆盖层仍开着）" % pi}
		return {"ok": true, "msg": "选了 p%d 并成交%s" % [pi, ("：" + hint) if hint != "" else ""]}
	if target == "leave":
		s._leave()
		return {"ok": true, "msg": "离开商店"}
	if not target.begins_with("s"):
		return {"ok": false, "msg": "商店的目标形如 s1000 / s2000 / s3000 / leave"}
	var n := int(target.substr(1))
	if n >= 1000 and n < 2000:
		s._buy_card(n - 1000)
		return {"ok": true, "msg": "买第 %d 张卡：%s" % [n - 1000, str(s.get("_hint"))]}
	if n >= 2000 and n < 3000:
		s._start_enchant(n - 2000)
		return {"ok": true, "msg": "开始附魔 %d（接下来要在选卡覆盖层里选一张卡，读 /state 看目标）" % (n - 2000)}
	if n >= 3000 and n < 4000:
		s._buy_row3(n - 3000)
		return {"ok": true, "msg": "买服务 %d：%s" % [n - 3000, str(s.get("_hint"))]}
	return {"ok": false, "msg": "认不出商店目标 %s" % target}


# ---------------------------------------------------------------- 通用（按钮型场景）

func _button_lines(s: Variant) -> Array[String]:
	var out: Array[String] = []
	out.append("── %s ──" % _kind_cn())
	var picks := _collect_buttons(s)
	if picks.is_empty():
		out.append("（这个场景没有可点的按钮；如果是事件页，语句在画面上，选项在下方）")
	# 事件页的正文
	var desc: Variant = s.get("desc")
	if desc != null and (desc is Label or desc is RichTextLabel):
		var txt: String = str(desc.text)
		if txt != "":
			out.append("")
			out.append("正文：")
			for ln in txt.split("\n"):
				out.append("  " + ln)
	out.append("")
	out.append("可点目标：")
	if RunState.pending_reward_count() > 0:
		for t: Dictionary in _reward_targets():
			out.append("  [%s] %s" % [str(t["id"]), str(t["hint"])])
		out.append("  [rwdone] 奖励处理完")
	for b: Dictionary in picks:
		out.append("  [%s] %s" % [str(b["id"]), str(b["text"])])
	return out


func _collect_buttons(root: Node) -> Array:
	## 递归收集「看得见、可点」的按钮 / 可点控件，按**树遍历顺序**编号。
	## ⚠️ 这里绝对**不能**按屏幕坐标排序 —— 踩过：事件页刚打开时按钮还没走完
	##    layout（`get_global_rect()` 全是 0/旧值），几毫秒后再采集 rect 才正确，
	##    两次采集出来的顺序因此不同 → AI 看到的 `b0` 是「荆棘指环」，
	##    点下去却按到了 `b1`「烈火之剑」。静默点错比点不到更致命。
	##    树的 child 顺序在两次采集之间是稳定的，用它做唯一依据。
	var found: Array = []
	_walk_buttons(root, found)
	var out: Array = []
	for i in found.size():
		var nd: Node = found[i]["node"]
		out.append({"id": "b%d" % i, "text": found[i]["text"],
				"rect": found[i]["rect"], "node": nd,
				"path": str(nd.get_path()) if nd != null else ""})
	return out


func _walk_buttons(n: Node, acc: Array) -> void:
	# **全局浮层不是本场景的选项**，一律不往外报：
	#   * `RelicViewer`（「道具 N」按钮）/ `DeckViewer`（「牌库 N」）—— 各场景
	#     `attach()` 到**自己身上**的速览浮层，点开只是一个目录，不推进任何流程；
	#   * `UiMenu`（Esc 菜单）；
	#   * 场景自己的 `TopBar`（标题条，万一带按钮）。
	# 不排除的话，事件页的「可点目标」里永远混着「道具 2」「牌库 13」，
	# AI 会一遍遍去点 → 实测死循环 50+ 步。
	# ⚠️ autoload 的 `/root/TopBar` 是 CanvasLayer、里面没有 Button —— 排它等于没排；
	# 真正要排的是**挂在场景下**的这几个兄弟。
	if n is RelicViewer or n is DeckViewer or n is UiMenu:
		return
	var sc: Variant = _scene()
	if sc != null:
		var tb: Node = sc.get_node_or_null("TopBar")
		if tb != null and (n == tb or tb.is_ancestor_of(n)):
			return
	if n is Button or n is BaseButton:
		var b := n as Control
		if b.visible and b.is_visible_in_tree() and not (n is BaseButton and (n as BaseButton).disabled):
			var txt := ""
			if n is Button:
				txt = (n as Button).text
			if txt == "":
				txt = n.name
			acc.append({"text": txt.strip_edges(), "rect": b.get_global_rect(), "node": n})
	for ch in n.get_children():
		if ch is Control and not (ch as Control).visible:
			continue
		_walk_buttons(ch, acc)


func _button_click(target: String) -> Dictionary:
	var s: Variant = _scene()
	if not target.begins_with("b") or not target.substr(1).is_valid_int():
		return {"ok": false, "msg": "这个场景的目标形如 b0 / b1"}
	var picks := _collect_buttons(s)
	var i := int(target.substr(1))
	if i < 0 or i >= picks.size():
		return {"ok": false, "msg": "没有 b%d（共 %d 个按钮）" % [i, picks.size()]}
	var node: Node = picks[i]["node"]
	var label := str(picks[i]["text"])
	if node is BaseButton:
		(node as BaseButton).emit_signal("pressed")
		return {"ok": true, "msg": "按下「%s」" % label}
	return {"ok": false, "msg": "b%d 不是按钮" % i}


# ---------------------------------------------------------------- 选职业

func _class_pick_lines() -> Array[String]:
	var out: Array[String] = []
	out.append("── 选职业（点一个就开局）──")
	out.append("")
	var ids: Array = PlayerClass.ids()
	for i in ids.size():
		var cid := str(ids[i])
		var deck_n: int = (PlayerClass.start_deck_ids(cid) as Array).size()
		out.append("  [c%d] %s —— %s" % [i, PlayerClass.name_of(cid),
				PlayerClass.subtitle_of(cid)])
		out.append("       起始生命 %d   起始卡组 %d 张   赠品道具 %s" % [
				PlayerClass.base_hp_of(cid), deck_n,
				RunState.relic_display_name(PlayerClass.relic_of(cid))])
		var d := str(PlayerClass.desc_of(cid)).replace("\n", " ")
		if d != "":
			out.append("       %s" % d)
	out.append("")
	out.append("可点目标：")
	for i in ids.size():
		out.append("  [c%d] 选 %s" % [i, PlayerClass.name_of(str(ids[i]))])
	return out


func _class_pick_click(target: String) -> Dictionary:
	if not target.begins_with("c") or not target.substr(1).is_valid_int():
		return {"ok": false, "msg": "选职业的目标形如 c0 / c1 / c2"}
	var ids: Array = PlayerClass.ids()
	var i := int(target.substr(1))
	if i < 0 or i >= ids.size():
		return {"ok": false, "msg": "没有 c%d" % i}
	var cid := str(ids[i])
	_scene()._choose(cid)
	return {"ok": true, "msg": "选了职业 %s，开局" % cid}


# ---------------------------------------------------------------- 选初始道具

func _relic_pick_lines() -> Array[String]:
	var out: Array[String] = []
	out.append("── 选初始道具（点一个就开局）──")
	out.append("")
	var repo := RelicRepo.load_json()
	var ids: Array = RunState.relic_choice
	if ids.is_empty():
		out.append("（没有候选 —— 可能已经选过了）")
	for i in ids.size():
		var rid := int(ids[i])
		var rel: RelicData = repo.get_relic(rid)
		out.append("  [i%d] %s" % [i, RunState.relic_display_name(rid)])
		if rel != null:
			var d := str(rel.relic_desc).replace("\n", " ")
			if d != "":
				out.append("       %s" % d)
	out.append("")
	out.append("可点目标：")
	for i in ids.size():
		out.append("  [i%d] %s" % [i, RunState.relic_display_name(int(ids[i]))])
	return out


func _relic_pick_click(target: String) -> Dictionary:
	if not target.begins_with("i") or not target.substr(1).is_valid_int():
		return {"ok": false, "msg": "选道具的目标形如 i0 / i1 / i2"}
	var ids: Array = RunState.relic_choice
	var i := int(target.substr(1))
	if i < 0 or i >= ids.size():
		return {"ok": false, "msg": "没有 i%d" % i}
	var rid := int(ids[i])
	_scene()._choose(rid)
	return {"ok": true, "msg": "选了道具 %s" % RunState.relic_display_name(rid)}


# ---------------------------------------------------------------- 卡组编辑（删卡 / 选卡）

var _de_mode_name := {
	"oblivion": "遗忘之泉 · 删卡",
	"delete": "失忆药水 · 删卡",
	"transform": "源数之力 · 改造",
	"smith": "鸭鸭工匠 · 锻造",
	"transform_class": "卡片商人 · 旧换新",
	"vendor": "卡片商人 · 以卡易物",
	"duplicate": "鸭血 · 复制",
}


func _deck_edit_targets(s: Variant) -> Array:
	## 与 `_deck_edit_lines` 的「可点目标」段同源（JSON 版）。
	var out: Array = []
	if bool(s.get("_done")):
		return out
	var cards: Array = []
	var raw: Variant = s.get("_cards")
	if raw is Array:
		cards = raw
	for i in cards.size():
		if not bool(s._pick_allowed(i)):
			continue
		var cid := int(cards[i])
		var nm := str(cid)
		var cost := 0
		var repo: Variant = s.get("repo")
		if repo != null:
			var c: Variant = repo.get_card(cid)
			if c != null:
				nm = str(c.card_name)
				cost = int(c.cost)
		var sel: Array = []
		var raw_sel: Variant = s.get("_sel")
		if raw_sel is Array:
			sel = raw_sel
		out.append({"id": "d%d" % i,
				"hint": ("取消选中「%s」" % nm) if sel.has(i) else ("选中「%s」（%d费）" % [nm, cost])})
	var btn: Variant = s.get("confirm_btn")
	if btn != null and not bool(btn.disabled):
		out.append({"id": "ok", "hint": str(btn.text)})
	out.append({"id": "leave", "hint": "放弃这次编辑，直接回地图"})
	return out


func _deck_edit_lines(s: Variant) -> Array[String]:
	var out: Array[String] = []
	out.append("── 卡组编辑 ──")
	var m := str(s._mode())
	var mname: String = str(_de_mode_name.get(m, "自由浏览"))
	out.append("用途：%s" % mname)
	if m == "vendor":
		out.append("只能选 %d 费及以上的卡" % RunState.MERCHANT_MIN_COST)
	elif m == "duplicate":
		out.append("最多选 %d 张（可以一张都不选直接继续）" % int(s._limit()))
	if bool(s.get("_done")):
		out.append("状态：已结算，正在返回地图")
		return out
	out.append("")
	var cards: Array = []
	var raw: Variant = s.get("_cards")
	if raw is Array:
		cards = raw
	var sel: Array = []
	var raw_sel: Variant = s.get("_sel")
	if raw_sel is Array:
		sel = raw_sel
	if cards.is_empty():
		out.append("（卡组是空的）")
	out.append("卡组 %d 张：" % cards.size())
	var repo: Variant = s.get("repo")
	for i in cards.size():
		var cid := int(cards[i])
		var nm := str(cid)
		var cost := 0
		var kind := ""
		if repo != null:
			var c: Variant = repo.get_card(cid)
			if c != null:
				nm = str(c.card_name)
				cost = int(c.cost)
				kind = str(c.kind)
		var marks: Array[String] = []
		if sel.has(i):
			marks.append("已选")
		var okpick := bool(s._pick_allowed(i))
		if not okpick:
			marks.append("不可选")
		var tag := ""
		if not marks.is_empty():
			tag = "　[%s]" % "·".join(marks)
		out.append("  [d%d] %s（%s %d费）%s" % [i, nm, kind, cost, tag])
	out.append("")
	out.append("可点目标：")
	for i in cards.size():
		if bool(s._pick_allowed(i)):
			if sel.has(i):
				out.append("  [d%d] 取消选中第 %d 张" % [i, i])
			else:
				out.append("  [d%d] 选中第 %d 张" % [i, i])
	var btn: Variant = s.get("confirm_btn")
	if btn != null and not bool(btn.disabled):
		out.append("  [ok] %s" % str(btn.text))
	else:
		out.append("  （确定按钮当前不可用：先选一张卡）")
	out.append("  [leave] 放弃这次编辑，直接回地图")
	return out


func _deck_edit_click(target: String) -> Dictionary:
	var s: Variant = _scene()
	if bool(s.get("_done")):
		return {"ok": false, "msg": "这次编辑已结算，等它自己回地图"}
	if target == "ok":
		if bool(s.get("_done")):
			return {"ok": false, "msg": "已经确认过了"}
		s._on_confirm()
		return {"ok": true, "msg": "已确认"}
	if target == "leave":
		s._go_back()
		return {"ok": true, "msg": "放弃了这次编辑，回地图"}
	if not target.begins_with("d") or not target.substr(1).is_valid_int():
		return {"ok": false, "msg": "卡组编辑的目标形如 d0 / ok / leave"}
	var i := int(target.substr(1))
	var cards: Array = []
	var raw: Variant = s.get("_cards")
	if raw is Array:
		cards = raw
	if i < 0 or i >= cards.size():
		return {"ok": false, "msg": "没有 d%d（卡组 %d 张）" % [i, cards.size()]}
	if not bool(s._pick_allowed(i)):
		return {"ok": false, "msg": "d%d 这张卡在当前用途下不能选" % i}
	# ⚠️ 必须走**和鼠标点击同一套**后续：只调 `_toggle_sel` 会改了 `_sel` 却不刷新
	# 确定按钮（`_refresh_ui` 平时是由 `_gui_input` 调的），AI 会看到「已选」却
	# 「确定按钮不可用」——自相矛盾的界面。
	s._hover = i
	s._toggle_sel(i)
	if s.get("sfx") != null:
		s.sfx.play("click")
	s._refresh_ui()
	s.queue_redraw()
	var grid: Variant = s.get("_grid")
	if grid != null:
		grid.queue_redraw()
	var sel_after: Variant = s.get("_sel")
	var n := 0
	if sel_after is Array:
		n = (sel_after as Array).size()
	return {"ok": true, "msg": "点了 d%d（当前已选 %d 张）" % [i, n]}


# ---------------------------------------------------------------- 奖励

func _reward_targets() -> Array:
	## 待领奖励（三选一卡牌 / 道具 / 删卡）。**直接用 RunState 的接口**，
	## 与界面上的悬浮窗是同一份数据，所以 AI 处理完界面自然就空了。
	var out: Array = []
	var arr: Array = RunState.pending_rewards
	var repo := CardRepo.load_json()
	for i in arr.size():
		var e: Dictionary = arr[i]
		if str(e.get("state", RunState.REWARD_PENDING)) != RunState.REWARD_PENDING:
			continue
		var kind := str(e.get("kind", ""))
		if kind == "cards":
			var cands: Array = e.get("candidates", [])
			for k in cands.size():
				var cid := int(cands[k])
				var c: CardData = repo.get_card(cid)
				var nm := c.card_name if c != null else str(cid)
				var cost_s := ""
				if c != null:
					cost_s = "（%d费 %s）" % [c.cost, c.kind]
				out.append({"id": "rw%dc%d" % [i, k], "hint": "奖励 %d：选「%s」%s" % [i, nm, cost_s]})
			out.append({"id": "rws%d" % i, "hint": "奖励 %d：放弃这组卡" % i})
		elif kind == "relic":
			var rid := int(e.get("id", 0))
			out.append({"id": "rw%d" % i, "hint": "奖励 %d：领取道具「%s」" % [
					i, RunState.relic_display_name(rid)]})
			out.append({"id": "rws%d" % i, "hint": "奖励 %d：放弃这件道具" % i})
		elif kind == "deck_delete":
			# R414：删卡**没有「接受」这一步** —— 点它就是摊开卡组，点一张当场删掉。
			# 以前这里只给一个 `rw%d`（转手走 `claim_pending_reward` 的「空手领下」），
			# 点完卡组一张没少、待办还挂着，AI 却以为领到了（一局白丢一次删卡机会）。
			var rpd: Variant = _scene().get("_reward_panel")
			var opened: bool = rpd != null and rpd.is_deck_delete_open(i)
			if opened:
				for di in RunState.deck_ids.size():
					if not RunState.deck_deletable(di):
						continue          # 带锁的卡（月亮 / 硬币 / 罐子）不列，点了也没用
					var dc: CardData = repo.get_card(int(RunState.deck_ids[di]))
					var dnm := dc.card_name if dc != null else "?"
					var dcost := dc.cost if dc != null else 0
					out.append({"id": "rd%d" % di,
							"hint": "删掉卡组第 %d 张「%s」（%d费）" % [di, dnm, dcost]})
			else:
				out.append({"id": "rw%d" % i, "hint": "奖励 %d：打开卡组挑一张删" % i})
			out.append({"id": "rws%d" % i, "hint": "奖励 %d：不要删卡" % i})
	return out


func _reward_delete_card(di: int) -> Dictionary:
	## R414：在摊开的卡组页上删掉第 di 张 —— `RunState.claim_deck_delete_reward()`
	## 一个口同时完成「删卡」与「这条奖励置为已领」，所以删完立刻生效、不用等界面结束。
	var s: Variant = _scene()
	var rp: Variant = s.get("_reward_panel")
	if rp == null or not rp.is_open():
		return {"ok": false, "msg": "奖励窗没开着"}
	if di < 0 or di >= RunState.deck_ids.size():
		return {"ok": false, "msg": "卡组没有第 %d 张" % di}
	if not RunState.deck_deletable(di):
		return {"ok": false, "msg": "那一张带锁（月亮 / 硬币 / 罐子），删不掉"}
	var dc: CardData = CardRepo.load_json().get_card(int(RunState.deck_ids[di]))
	var nm := dc.card_name if dc != null else "?"
	for i in RunState.pending_rewards.size():
		var e: Dictionary = RunState.pending_rewards[i]
		if str(e.get("kind", "")) != "deck_delete":
			continue
		if str(e.get("state", RunState.REWARD_PENDING)) != RunState.REWARD_PENDING:
			continue
		var before := RunState.deck_ids.size()
		if RunState.claim_deck_delete_reward(i, di):
			return {"ok": true, "msg": "删掉「%s」，卡组 %d → %d 张" % [
					nm, before, RunState.deck_ids.size()]}
		return {"ok": false, "msg": "删卡没成功（这条奖励可能已经被处理过）"}
	return {"ok": false, "msg": "现在没有待领的删卡奖励"}


func _reward_click(target: String) -> Dictionary:
	var s: Variant = _scene()
	if target == "rwdone":
		var rp: Variant = s.get("_reward_panel")
		if rp != null:
			if rp.is_open():
				rp.close()      # on_closed 会自己走「自动离场」
			return {"ok": true, "msg": "关掉奖励窗"}
		return {"ok": true, "msg": "没有奖励窗"}
	# R414：`rd<卡组下标>` —— 在摊开的卡组页上点一张，当场删掉。
	if target.begins_with("rd") and target.substr(2).is_valid_int():
		return _reward_delete_card(int(target.substr(2)))
	if target.begins_with("rws"):
		var si := int(target.substr(3))
		if RunState.skip_pending_reward(si):
			return {"ok": true, "msg": "放弃奖励 %d" % si}
		return {"ok": false, "msg": "奖励 %d 处理不了（可能已处理过）" % si}
	var body := target.substr(2)
	if body.contains("c"):
		var parts := body.split("c")
		var i := int(parts[0])
		var k := int(parts[1])
		if i < 0 or i >= RunState.pending_rewards.size():
			return {"ok": false, "msg": "没有奖励 %d" % i}
		var cands: Array = (RunState.pending_rewards[i] as Dictionary).get("candidates", [])
		if k < 0 or k >= cands.size():
			return {"ok": false, "msg": "奖励 %d 没有第 %d 张候选" % [i, k]}
		var cid := int(cands[k])
		if RunState.pick_pending_card(i, cid):
			return {"ok": true, "msg": "选了第 %d 组的第 %d 张" % [i, k]}
		return {"ok": false, "msg": "选卡失败（可能已处理过）"}
	if body.is_valid_int():
		var i2 := int(body)
		# R414：删卡奖励点下去 = **摊开卡组**，不是「领下」。
		if i2 >= 0 and i2 < RunState.pending_rewards.size() \
				and str((RunState.pending_rewards[i2] as Dictionary).get("kind", "")) == "deck_delete":
			var rp2: Variant = s.get("_reward_panel")
			if rp2 == null or not rp2.is_open():
				return {"ok": false, "msg": "奖励窗没开着，先用「打开待领奖励」把它弹出来"}
			rp2._open_entry(i2)
			return {"ok": true, "msg": "已摊开卡组，挑一张删（目标 rd<下标>）"}
		if RunState.claim_pending_reward(i2):
			return {"ok": true, "msg": "领取奖励 %d" % i2}
		return {"ok": false, "msg": "奖励 %d 领取失败（可能已处理过）"}
	return {"ok": false, "msg": "奖励目标形如 rw0c1 / rw0 / rws0 / rwdone"}
