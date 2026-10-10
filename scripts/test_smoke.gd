extends SceneTree
## 冒烟测试（基本功能自检）—— 把每个场景按真实进入条件实例化、渲染若干帧，
## 检查是否存在脚本错误（缺失方法 / 空引用 / 解析错误 / _draw 崩溃）。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://scripts/test_smoke.gd
## 说明：
##   * 必须**非 headless** 运行 —— headless 不渲染，_draw() 里的错误抓不到
##     （历史上出现过的 rel.kind_color() 崩溃就是这类）。
##   * 每个场景前会重置 RunState 并铺一套「进入该场景所需的最小状态」
##     （例如 relic_pick 需要 relic_choice）。
##   * 错误不会被脚本捕获，而是由引擎打到 stderr —— 由外层脚本 grep
##     「SCRIPT ERROR / Nonexistent / Invalid call」判定失败。

const MapBridge = preload("res://scripts/map_bridge.gd")

const FRAMES_PER_SCENE := 8

# 每个场景的进入前置：用 [_reset, 说明] 的形式，_reset 为 Callable
var _plan: Array = []
var _cur: Node = null
var _idx := -1
var _frames := 0
var _ok := 0
var _fail := 0
var _check := Callable()   # 用例可选的「加进场景后第 2 帧」行为断言
var _pair_reported := {}  # R66：已打印过「牌库/道具成对」的场景名，避免同一场景重复刷屏


func _initialize() -> void:
	_plan = [
		["res://scenes/title.tscn", func(): _reset()],
		# 角色选择（R43 新增：定角色 → 发专属卡与赠品道具 → 进地图）
		["res://scenes/class_pick.tscn", func(): _reset()],
		# 角色选择 + 机械之心（R82：第三个角色，3 张卡面要放得下 1280 视口）
		["res://scenes/class_pick.tscn", func():
				_reset()
				RunState.player_class = PlayerClass.MECH],
		# 地图场景（R69 的 14 层 + 第 9 层固定休息层）。
		# `relic_choice = []` 是**必须的**：start_run 会填 3 个待选初始道具，
		# 而 map_scene._ready 见它非空就 `change_scene_to_file(relic_pick)` 直接 return，
		# _clamp_scroll / _scroll_to_current 都不会跑 → 滚动范围停在默认 0。
		["res://scenes/map.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [],
			_check_map_scene],
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"}),
			_check_battle],
		# 战斗场景 + 机械之心（R82）：开场「机械核心」6025 要往手牌塞 2 张素体，
		# 且素体带「留手」—— 这一路能跑通就说明新道具 / 新卡 / 衍生物判定都接好了。
		["res://scenes/battle.tscn", func():
				_reset()
				var mrng := RandomNumberGenerator.new()
				mrng.seed = 20261005
				RunState.start_run(RogueMap.generate(mrng), GameLayers.LAYER_DEFAULT,
						PlayerClass.MECH)
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"})],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}],
		# R119：奖励悬浮窗 —— 列表 / 道具详情 / 卡牌三选一，三个视图各渲染一遍。
		# 面板由 event 场景自带（battle / event / map 都挂了），这里只负责铺奖励 + 切视图。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards(),
			func(s): _check_reward_panel_view(s, RewardPanel.VIEW_LIST, "列表")],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards(),
			func(s): _check_reward_panel_view(s, RewardPanel.VIEW_RELIC, "道具详情")],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards(),
			func(s): _check_reward_panel_view(s, RewardPanel.VIEW_CARDS, "卡牌三选一")],
		["res://scenes/relic_pick.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [6001, 6002, 6003]],
		["res://scenes/deck_edit.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relics = [6004]
				RunState.pending_relic = 6004],
		# 卡组编辑的「鸭血」多选模式（R81）—— 唯一 limit=2 的模式，
		# 顺带在这里真的走一遍「选 2 张 → 复制」的完整路径。
		["res://scenes/deck_edit.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relics = [RunState.DUCK_BLOOD_RELIC_ID]
				RunState.pending_relic = RunState.DUCK_BLOOD_RELIC_ID,
			_check_deck_duck_blood],
		["res://scenes/gallery.tscn", func(): _reset()],
		# 回放列表场景（R46）
		["res://scenes/replay_list.tscn", func(): _reset()],
		# 事件场景的其它子类型
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "treasure"],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "whisper"],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "struggle"],
		# 鸭之凝视（一袋米抗几楼）—— 现在是**第二层**事件
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "gaze"],
		# 奥秘之泉（第一层专属：护符 / 喝泉水）—— R71：**已经戴过护符也要能选「喝下泉水」**
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "arcane",
			_check_arcane_with_charm],
		# 遗忘之泉（全层通用：删一张卡 / 离开）
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "oblivion"],
		# 遗忘之泉的后续：卡组编辑场景的「删卡」模式
		["res://scenes/deck_edit.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_event = "oblivion"
				RunState.pending_deck_edit = "delete"],
		# 宝箱层（第六层：开箱得 1 个随机奖励道具）
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "chest"}],
		# R121：覆盖层让位 —— 奖励悬浮窗盖住道具栏时，道具悬停必须停止响应
		#   ① 事件页：RelicViewer 的速览浮层与按钮 tooltip 读的是**鼠标坐标**，不认覆盖层
		#   ② 战斗页：右栏道具栏的悬浮说明由 _on_hover 跟着鼠标画
		# 注意顺序：_seed_rewards() 会把 relics 清空，所以道具要**之后**再给。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards()
				RunState.relics = [6001, 6002],
			_check_relic_hover_gate],
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"})
				_seed_rewards()
				RunState.relics = [6001, 6002],
			_check_battle_hover_gate],
	]
	print("SMOKE === 开始（%d 项场景用例）===" % _plan.size())
	_next()


func _reset() -> void:
	RunState.end_run()
	RunState.reset()
	# R119：end_run **故意**不清待领奖励队列（通关那一场的战利品要留在结算面板上给玩家看），
	# 但冒烟用例之间必须互不污染 → 在这里显式清掉。
	RunState.pending_rewards = []
	# R121：同理清掉覆盖层登记 —— 用例里 open() 过面板又没 close() 就结束的话，
	# 阻塞态会漏给后面的用例，让那些用例的道具悬停莫名其妙全部失灵。
	UiGate.reset()


func _map() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	return RogueMap.generate(rng)


func _seed_rewards() -> void:
	## R119：给奖励悬浮窗铺一批奖励 —— 一件长描述道具 + 一组卡牌三选一 + 一件普通道具。
	## 走真实入队口，顺带覆盖 queue_relic_reward / queue_card_reward。
	RunState.relics = []
	RunState.skipped_relics = []
	RunState.pending_relic_drop = -1
	RunState.pending_rewards = []
	RunState.queue_relic_reward(6013)   # 叠加态的鸭：desc 最长的一件（专治「介绍太长」）
	RunState.queue_card_reward("normal")
	RunState.queue_relic_reward(6005)


func _check_reward_panel_view(scene: Variant, want_view: int, label: String) -> void:
	## R119：奖励悬浮窗 —— 打开并切到指定视图，后面几帧会真的把它画出来。
	## ⚠️ 逻辑断言（入队 / 领取置灰 / 三选一入卡组）在 test_engine；这里只管「三个视图都渲染得出」，
	##    因为面板里的绘制错误（越界 / 空引用）只有真渲染才抓得到。
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R119 奖励悬浮窗（%s）：场景没有挂上 RewardPanel" % label)
		return
	if RunState.pending_reward_count() != 3:
		_smoke_fail("R119 奖励悬浮窗（%s）：应入队 3 条待领，实际 %d"
				% [label, RunState.pending_reward_count()])
		return
	p.open()
	if not p.is_open():
		_smoke_fail("R119 奖励悬浮窗（%s）：open() 之后应处于打开态" % label)
		return
	if want_view != RewardPanel.VIEW_LIST:
		var idx := -1
		for i in RunState.pending_rewards.size():
			var e: Dictionary = RunState.pending_rewards[i]
			var is_cards := str(e.get("kind", "")) == "cards"
			if (want_view == RewardPanel.VIEW_CARDS) == is_cards:
				idx = i
				break
		if idx < 0:
			_smoke_fail("R119 奖励悬浮窗（%s）：找不到要展示的条目" % label)
			return
		p._open_entry(idx)
		if int(p._view) != want_view:
			_smoke_fail("R119 奖励悬浮窗（%s）：视图应为 %d，实际 %d"
					% [label, want_view, int(p._view)])
			return
	p._hover_row = 0
	p._hover_card = 0
	p._root.queue_redraw()
	print("SMOKE OK R119 奖励悬浮窗：%s 视图渲染（%d 条待领，宿主 %s）"
			% [label, RunState.pending_reward_count(), str(scene.name)])


func _check_relic_hover_gate(scene: Variant) -> void:
	## R121：奖励悬浮窗（满屏覆盖层）盖着时，RelicViewer 的道具悬停必须让位。
	## ⚠️ 这里**不**读真实鼠标位置 —— 直接调悬停判定的唯一口 `_want_hover()`。
	##    否则断言会随鼠标停在哪里而飘（同一份代码在不同机器上结果不同）。
	var rv: Variant = null
	for c in scene.get_children():
		if c is RelicViewer:
			rv = c
	if rv == null:
		_smoke_fail("R121 覆盖层让位：事件场景没有挂上 RelicViewer")
		return
	if RunState.relics.is_empty():
		_smoke_fail("R121 覆盖层让位：用例需要先给玩家道具，否则悬停判定本就是空跑")
		return
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R121 覆盖层让位：事件场景没有挂上 RewardPanel")
		return
	var btn_pt: Vector2 = Rect2(rv._btn.position, rv._btn.size).get_center()
	var far_pt := Vector2(200, 640)
	# ① 面板关着：指着「道具 N」按钮 → 该悬停；指着远端 → 不该悬停
	p.close()
	if not bool(rv._want_hover(btn_pt)):
		_smoke_fail("R121 覆盖层让位：没有覆盖层时，指着「道具 N」按钮应判定为悬停")
		return
	if bool(rv._want_hover(far_pt)):
		_smoke_fail("R121 覆盖层让位：鼠标在远端时不该判定为悬停")
		return
	# ② 面板开着：哪怕指着按钮也必须让位。
	#    ⚠️ `_want_hover()` 是纯判定（立刻生效）；按钮的显隐 / tooltip 与速览浮层
	#       是**逐帧**刷的 → 断言前必须先跑一帧 `_process()`，与真实运行一致。
	p.open()
	if not UiGate.blocked():
		_smoke_fail("R121 覆盖层让位：奖励悬浮窗打开后 UiGate 应处于阻塞态（push 漏了）")
		return
	if bool(rv._want_hover(btn_pt)):
		_smoke_fail("R121 覆盖层让位：奖励悬浮窗盖着时，指着按钮仍判定为悬停")
		return
	rv._hover_on = true          # 故意留一个「已经亮着的速览浮层」看它会不会被灭掉
	rv._hover_layer.visible = true
	rv._process(0.016)
	if bool(rv._hover_on) or bool(rv._hover_layer.visible):
		_smoke_fail("R121 覆盖层让位：面板盖着时已展开的速览浮层没有被灭掉")
		return
	if str(rv._btn.tooltip_text) != "":
		_smoke_fail("R121 覆盖层让位：奖励悬浮窗盖着时道具按钮仍有 tooltip「%s」"
				% str(rv._btn.tooltip_text))
		return
	# ③ 关掉面板：阻塞解除，按钮 / tooltip / 悬停全部回来（证明 pop 接在同一个唯一口上）
	p.close()
	if UiGate.blocked():
		_smoke_fail("R121 覆盖层让位：面板关闭后 UiGate 仍在阻塞态（pop 漏了）")
		return
	rv._process(0.016)
	if not bool(rv._want_hover(btn_pt)):
		_smoke_fail("R121 覆盖层让位：面板关闭后道具悬停没有恢复")
		return
	if str(rv._btn.tooltip_text) == "":
		_smoke_fail("R121 覆盖层让位：面板关闭后道具按钮的 tooltip 没有恢复")
		return
	print("SMOKE OK R121 覆盖层让位：奖励悬浮窗开/关 → 道具速览浮层与 tooltip 正确让位/恢复")


func _check_battle_hover_gate(scene: Variant) -> void:
	## R121：战斗页右栏道具栏的悬浮说明（`_hover_relic_tip`）同样要给覆盖层让位。
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R121 覆盖层让位（战斗）：场景没有挂上 RewardPanel")
		return
	if scene.engine == null or (scene.engine.self_relics as Array).is_empty():
		_smoke_fail("R121 覆盖层让位（战斗）：用例需要先在道具栏里放几件道具")
		return
	var probe_pt: Vector2 = scene._relic_rect(0).get_center()
	# ① 面板关着：悬停道具徽章 → 该出说明（正向对照，证明断言不是空跑）
	p.close()
	scene._on_hover(probe_pt)
	if str(scene._hover_relic_tip) == "":
		_smoke_fail("R121 覆盖层让位（战斗）：没有覆盖层时，悬停道具徽章应弹出说明")
		return
	# ② 面板开着：同一个位置必须什么都不弹（旧说明也要被清掉）
	p.open()
	scene._on_hover(probe_pt)
	if str(scene._hover_relic_tip) != "" or scene._hover_card != null:
		_smoke_fail("R121 覆盖层让位（战斗）：奖励悬浮窗盖着时仍弹了说明（tip=「%s」）"
				% str(scene._hover_relic_tip))
		return
	# ③ 场景自带的全屏面板（道具浏览）同理
	p.close()
	scene._relics_visible = true
	scene._on_hover(probe_pt)
	scene._relics_visible = false
	if str(scene._hover_relic_tip) != "":
		_smoke_fail("R121 覆盖层让位（战斗）：道具浏览面板开着时仍弹了道具说明")
		return
	print("SMOKE OK R121 覆盖层让位：战斗道具栏说明在奖励悬浮窗 / 道具浏览面板下正确让位")


func _check_deck_duck_blood(scene: Variant) -> void:
	## 卡组编辑的「鸭血」模式（R81）：多选上限 2，且选中/确定真的会复制卡。
	## 这里直接调场景内部方法（与 _check_map_scene 同一套路），比截图可靠。
	if str(scene._mode()) != "duplicate":
		_smoke_fail("鸭血卡组编辑：模式应为 duplicate，实际 %s" % str(scene._mode()))
		return
	if int(scene._limit()) != 2:
		_smoke_fail("鸭血卡组编辑：可选上限应为 2，实际 %d" % int(scene._limit()))
		return
	# 选 3 张 → 只留最早选中的被替换掉，最终恰好 2 张
	scene._toggle_sel(0)
	scene._toggle_sel(1)
	scene._toggle_sel(2)
	if (scene._sel as Array).size() != 2 or not (scene._sel as Array).has(1) \
			or not (scene._sel as Array).has(2):
		_smoke_fail("鸭血卡组编辑：选 3 张后应保留最新 2 张，实际 %s" % str(scene._sel))
		return
	# 再点已选中的 → 取消选中
	scene._toggle_sel(1)
	if (scene._sel as Array).has(1):
		_smoke_fail("鸭血卡组编辑：再点已选中的卡应取消选中")
		return
	scene._toggle_sel(1)
	# 走真实结算：卡组 +2，标题与按钮文案对得上
	var before: int = RunState.deck_ids.size()
	var nm0: String = scene.confirm_btn.text
	scene._on_confirm()
	if RunState.deck_ids.size() != before + 2:
		_smoke_fail("鸭血卡组编辑：确定后卡组应 +2（%d → %d），按钮原为「%s」"
				% [before, RunState.deck_ids.size(), nm0])
		return
	if RunState.pending_relic != -1:
		_smoke_fail("鸭血卡组编辑：确定后应解除待选")
		return
	print("SMOKE OK 鸭血卡组编辑：多选上限 2 / 选 3 张保留最新 2 张 / 确定后卡组 %d → %d"
			% [before, RunState.deck_ids.size()])


func _check_map_scene(scene: Variant) -> void:
	## 地图场景（R128）：**5×7 相接正方形格子** + 起点固定 (3,4) + 两角固定大宝箱。
	## 只断言状态与几何（格子数 / 位置 / 相接 / 点击判定同源），真正的绘制
	## 由 smoke 非 headless 跑满帧验证。
	var cells: Array = RunState.map_cells
	if cells.size() != RogueMap.CELLS:
		_smoke_fail("地图场景：应有 %d 格，实际 %d" % [RogueMap.CELLS, cells.size()])
		return
	var sc: Dictionary = RogueMap.start_cell(cells)
	if sc.is_empty() or str(sc["type"]) != "start":
		_smoke_fail("地图场景：起点房缺失或类型不对")
		return
	if int(sc["col"]) != RogueMap.START_COL or int(sc["row"]) != RogueMap.START_ROW:
		_smoke_fail("地图场景：起点应在 (%d,%d)，实际 (%d,%d)"
				% [RogueMap.START_COL, RogueMap.START_ROW, int(sc["col"]), int(sc["row"])])
		return
	for bp: Vector2i in RogueMap.BIGCHEST_POS:
		var bc: Dictionary = RogueMap.cell_at(cells, bp.x, bp.y)
		if str(bc["type"]) != "bigchest":
			_smoke_fail("地图场景：(%d,%d) 应是大宝箱房，实际 %s"
					% [bp.x, bp.y, str(bc["type"])])
			return
	# 几何：格子是正方形、彼此相接、整体落在窗口内
	var c0: Rect2 = scene._cell_rect(cells[0])
	var c_last: Rect2 = scene._cell_rect(cells[RogueMap.CELLS - 1])
	var cell_sz: float = scene.CELL
	if absf(c0.size.x - cell_sz) > 0.01 or absf(c0.size.y - cell_sz) > 0.01:
		_smoke_fail("地图场景：格子应为正方形 %.0f，实际 %.1f×%.1f"
				% [cell_sz, c0.size.x, c0.size.y])
		return
	var nb0: Rect2 = scene._cell_rect(RogueMap.cell_at(cells, 1, 0))
	if absf(nb0.position.x - (c0.position.x + c0.size.x)) > 0.01 \
			or absf(nb0.position.y - c0.position.y) > 0.01:
		_smoke_fail("地图场景：相邻格子没有相接（横向间隙 %.1f、纵向偏移 %.1f）"
				% [nb0.position.x - (c0.position.x + c0.size.x),
					nb0.position.y - c0.position.y])
		return
	if c0.position.x < 0.0 or c0.position.y < 0.0 \
			or c_last.end.x > 1280.0 or c_last.end.y > 720.0:
		_smoke_fail("地图场景：地图整体超出窗口（左上 %.0f,%.0f 右下 %.0f,%.0f）"
				% [c0.position.x, c0.position.y, c_last.end.x, c_last.end.y])
		return
	# 格子中心反查回同一格
	var hit: Dictionary = scene._cell_at(c0.position + c0.size * 0.5)
	if hit.is_empty() or int(hit["id"]) != int(cells[0]["id"]):
		_smoke_fail("地图场景：格子坐标反查不对（期望 id 0，得到 %s）"
				% str(hit.get("id", -1)))
		return
	# 可走房间 = RunState.available_nodes（场景与状态同源）
	var avail := RunState.available_nodes()
	if avail.is_empty():
		_smoke_fail("地图场景：起点应至少有 1 个可走的相邻房")
		return
	for a: Dictionary in avail:
		if not scene._is_available(a):
			_smoke_fail("地图场景：可走房间 %d 未被场景认作可走" % int(a["id"]))
			return
	# 通路（R130）：判定口 `scene._bridge_kind` + `MapBridge` 的真值表 + 几何。
	# 起点就是当前房 → 它每个门都通向「真能走过去」的房 → 一律亮青；
	# 两端都没走过的格子之间只能是「鹰哨」档。
	var bridge_start: Dictionary = RogueMap.start_cell(cells)
	for nid2 in bridge_start["doors"]:
		if scene._bridge_kind(bridge_start, cells[int(nid2)]) != MapBridge.LIT:
			_smoke_fail("地图场景：从起点通向 %d 的通路应为「可以走」语义" % int(nid2))
			return
	if MapBridge.kind_for(true, false, false) != MapBridge.DONE \
			or MapBridge.kind_for(false, false, false) != MapBridge.UNSEEN \
			or MapBridge.kind_for(false, false, true) != MapBridge.LIT:
		_smoke_fail("通路语义：kind_for 真值表不对（走过→暖白 / 都没走过→灰蓝 / 可走→亮青）")
		return
	# 朝向：左右相邻用侧视图、上下相邻用俯视图（两枚素材缺一就有半个方向没桥）。
	if MapBridge.is_vertical(Vector2(0, 0), Vector2(100, 0)) \
			or not MapBridge.is_vertical(Vector2(0, 0), Vector2(0, 100)):
		_smoke_fail("通路朝向：左右相邻应判为横向、上下相邻应判为竖向")
		return
	# 素材只有一张**竖直的俯视图**：上下照画（0°），左右转 90°（R132）。
	if absf(MapBridge.rotation_of(Vector2(0, 0), Vector2(0, 100))) > 0.001 \
			or absf(MapBridge.rotation_of(Vector2(0, 0), Vector2(100, 0)) - PI * 0.5) > 0.001:
		_smoke_fail("通路朝向：上下相邻应不旋转、左右相邻应转 90°")
		return
	# 几何：桥心必须落在**两格共用的那面墙的中点**，且整座桥小于一格
	# （否则会横穿格子、把房间图标压住）。
	var bh: Rect2 = MapBridge.box_of(Vector2(0, 0), Vector2(118, 0), MapBridge.DONE, 118.0)
	var bv: Rect2 = MapBridge.box_of(Vector2(0, 0), Vector2(0, 118), MapBridge.DONE, 118.0)
	if absf(bh.get_center().x - 59.0) > 0.01 or absf(bh.get_center().y) > 0.01 \
			or absf(bv.get_center().y - 59.0) > 0.01 or absf(bv.get_center().x) > 0.01:
		_smoke_fail("通路几何：桥心应落在两格中点（横向 %s / 竖向 %s）"
				% [str(bh.get_center()), str(bv.get_center())])
		return
	if bh.size.x <= 0.0 or bh.size.x >= 118.0 or bv.size.y <= 0.0 or bv.size.y >= 118.0:
		_smoke_fail("通路几何：桥应小于一格（横 %s / 竖 %s）" % [str(bh.size), str(bv.size)])
		return
	# 进场过场（R131）：文字表齐全 / 走过的房间不播 / 没去过的会播，且**播完才动 RunState**。
	for ty2 in ["battle", "elite", "event", "rest", "unknown", "chest", "bigchest", "start"]:
		if not scene.ENTER_LABELS.has(ty2):
			_smoke_fail("进场过场：房间类型 %s 没有文字（过场会空着）" % ty2)
			return
	if str(scene.ENTER_LABELS["unknown"]) != "不确定的命运" \
			or str(scene.ENTER_LABELS["elite"]) != "精英战斗":
		_smoke_fail("进场过场：「不确定的命运」/「精英战斗」文案不对")
		return
	if scene.CHOCO_ICON_W < scene.CHOCO_ICON_H:
		_smoke_fail("巧克力计数：图标槽要做成横向的（素材是长方形整块，竖槽会把它压扁）")
		return
	# 回到走过的房间（起点）→ 不该起过场
	scene._anim_cell = {}
	scene._anim_t = 0.0
	scene._enter_node(RogueMap.start_cell(cells), true)
	if not scene._anim_cell.is_empty():
		_smoke_fail("进场过场：走进走过的房间不该播过场")
		return
	# 走进没去过的房间 → 起过场，且**过场中 RunState 一动不动**
	var anim_nid := -1
	for a3: Dictionary in RunState.available_nodes():
		if not RunState.cleared_ids.has(int(a3["id"])):
			anim_nid = int(a3["id"])
			break
	if anim_nid < 0:
		_smoke_fail("进场过场：起点居然没有没走过的邻居（无法核验）")
		return
	var anim_cell_d: Dictionary = cells[anim_nid]
	var cur_before2 := RunState.current_node_id
	var choco_before2 := RunState.chocolate
	scene._enter_node(anim_cell_d, true)
	if scene._anim_cell.is_empty() or int(scene._anim_cell["id"]) != anim_nid:
		_smoke_fail("进场过场：走进没去过的房间没有起过场")
		return
	if RunState.current_node_id != cur_before2 or RunState.chocolate != choco_before2:
		_smoke_fail("进场过场：过场还没播完就改了 RunState（应该等播完才 advance）")
		return
	if scene._enter_label(anim_cell_d) \
			!= str(scene.ENTER_LABELS[RogueMap.display_type(anim_cell_d)]):
		_smoke_fail("进场过场：文字映射与 display_type 不同源")
		return
	scene._anim_cell = {}      # 复原：别影响后面的用例
	# 视野规则的前提：走过的房间必须至少有一个门（不然玩家会被困死）
	for c: Dictionary in cells:
		if RunState.cleared_ids.has(int(c["id"])) and (c["doors"] as Array).is_empty():
			_smoke_fail("地图场景：走过的房间 %d 竟然一个门都没有" % int(c["id"]))
			return
	print("SMOKE OK 地图场景：5×7 = %d 格相接正方形 / 起点 (%d,%d) / 两角大宝箱 / 巧克力 ×%d / 可走 %d 间"
			% [RogueMap.CELLS, RogueMap.START_COL, RogueMap.START_ROW,
				RunState.chocolate, avail.size()])
	_check_relic_bar(scene)


func _check_relic_bar(scene: Variant) -> void:
	## R75：**道具悬浮即看说明；只有一行放不下时才允许点开详情**，且详情字号更大。
	## 地图侧断言：徽章不越界、装得下时无 +N、装不下时恰好一个 +N 且可点。
	var n_max: int = scene.RELIC_BADGE_MAX
	# 徽章行整体不能压到标题（最左一个徽章的左沿要在标题右侧）
	var left: float = scene._relic_rect(n_max - 1).position.x
	if left < 470.0:
		_smoke_fail("道具徽章：一行 %d 个时最左徽章左沿 %.1f，压到标题区"
				% [n_max, left])
		return
	var saved: Array = RunState.relics.duplicate()
	# 少：装得下 → 不该有 +N，也就不该给点击入口
	RunState.relics = [6001, 6003, 6005]
	if scene._relic_bar_overflowed():
		_smoke_fail("道具徽章：3 件（上限 %d）却判定为溢出" % n_max)
		return
	if scene._relic_shown() != 3:
		_smoke_fail("道具徽章：装得下时只应列出全部 3 件，实际 %d" % scene._relic_shown())
		return
	# 多：装不下 → 恰好留一个 +N，且 +N 落在允许点击的位置
	RunState.relics = [6001, 6002, 6003, 6005, 6006, 6007, 6008, 6009, 6013, 6015]
	if not scene._relic_bar_overflowed():
		_smoke_fail("道具徽章：10 件（上限 %d）却判定为装得下" % n_max)
		return
	var shown: int = scene._relic_shown()
	if shown != n_max - 1:
		_smoke_fail("道具徽章：溢出时应留 1 个 +N 位（列 %d 个），实际 %d" % [n_max - 1, shown])
		return
	var more: Rect2 = scene._relic_rect(shown)
	if more.size.x <= 0.0 or more.position.y < 0.0 or more.end.y > 44.0:
		_smoke_fail("道具徽章：+N 摘要块不在顶部徽章行内（%s）" % str(more))
		return
	if not more.has_point(more.get_center()):
		_smoke_fail("道具徽章：+N 摘要块自身中心不在块内（%s）" % str(more))
		return
	# 详情面板：能列出全部 10 件，且说明字号 > 悬浮提示字号
	var rows: Array = scene._relic_panel_rows()
	if rows.size() != RunState.relics.size():
		_smoke_fail("道具详情面板：应列出全部 %d 件，实际 %d"
				% [RunState.relics.size(), rows.size()])
		return
	if int(scene.RELIC_P_NAME) <= 14 or int(scene.RELIC_P_DESC) <= 12:
		_smoke_fail("道具详情面板：字号没放大（名称 %d / 说明 %d，悬浮是 14 / 12）"
				% [int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])
		return
	if scene.RELIC_P_DESC <= 12:
		_smoke_fail("道具详情面板：说明字号 %d 未大于悬浮提示的 12" % int(scene.RELIC_P_DESC))
		return
	RunState.relics = saved
	print("SMOKE OK 道具查看：地图徽章上限 %d 个 / 3 件不溢出无 +N / 10 件留 1 个 +N 可点 / 详情 %d 件全列且字号 %d>%d"
			% [n_max, rows.size(), int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])


func _next() -> void:
	if _cur != null:
		root.remove_child(_cur)
		_cur.free()
		_cur = null
	_idx += 1
	_frames = 0
	if _idx >= _plan.size():
		print("SMOKE === 结束：%d 通过 / %d 失败 ===" % [_ok, _fail])
		quit()
		return
	var entry: Array = _plan[_idx]
	var path: String = entry[0]
	var note: String = str(entry[1])
	(entry[1] as Callable).call()
	_check = Callable()
	if entry.size() > 2 and entry[2] is Callable:
		_check = entry[2]   # 第 3 项：场景就绪后的行为断言（见 _process）
	var packed: PackedScene = load(path)
	if packed == null:
		print("SMOKE FAIL %s：资源加载失败" % path)
		_fail += 1
		_next()
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		print("SMOKE FAIL %s：instantiate 返回 null" % path)
		_fail += 1
		_next()
		return
	_cur = inst
	root.add_child(inst)
	print("SMOKE OK %s  [用例 %d/%d]" % [path, _idx + 1, _plan.size()])


func _process(_delta: float) -> bool:
	if _cur == null:
		return false
	_frames += 1
	if _frames == 2 and _check.is_valid():
		var c := _check
		_check = Callable()
		c.call(_cur)
	# R66：凡是挂了「牌库 N」按钮的界面，都必须也有「道具 N」按钮（两个查看器对等）。
	# 同一个场景在 _plan 里可能重复出现（不同前置），打印只出一次，免得刷屏。
	var dv: int = 0
	var rv: int = 0
	for child in _cur.get_children():
		if child is DeckViewer:
			dv += 1
		elif child is RelicViewer:
			rv += 1
	if dv > 0 and rv == 0:
		_smoke_fail("道具查看：挂了 %d 个牌库查看器却没有道具查看器" % dv)
	elif dv > 0 and not _pair_reported.has(str(_cur.name)):
		_pair_reported[str(_cur.name)] = true
		print("SMOKE OK 道具查看：%s 牌库 %d 个 / 道具 %d 个（两个查看器成对）"
				% [_cur.name, dv, rv])
	if _frames >= FRAMES_PER_SCENE:
		_ok += 1
		_next()
	return false


func _smoke_fail(msg: String) -> void:
	print("SMOKE FAIL %s" % msg)
	_fail += 1


func _hand_card_extent(scene: Variant, i: int) -> Vector2:
	## 第 i 张手牌**旋转后**的左右极值 (x_left, x_right)。
	## 卡是绕底部中心转的，两端的卡会向左/右探出去，只看未旋转矩形会漏判越界。
	var r: Rect2 = scene._hand_rect(i)
	var p: Vector2 = scene._hand_pivot(i)
	var a: float = scene._hand_angle(i)
	var lo := 99999.0
	var hi := -99999.0
	for corner in [Vector2(0, 0), Vector2(r.size.x, 0), Vector2(0, r.size.y),
			Vector2(r.size.x, r.size.y)]:
		var q: Vector2 = p + (r.position + corner - p).rotated(a)
		lo = minf(lo, q.x)
		hi = maxf(hi, q.x)
	return Vector2(lo, hi)


func _check_hand_fan(scene: Variant) -> void:
	## 扇形手牌：绘制时卡是**转着画的**，命中判定必须用同一个角度反向旋转。
	## 这里先把牌抽到满手（覆盖重叠 + hand_full），再用「旋转后的卡牌中心」回测。
	var n0: int = scene.engine.state.hand.size()
	if n0 < 3:
		_smoke_fail("扇形手牌：起手只有 %d 张，不足 3 张" % n0)
		return
	scene.engine._draw_many(FieldState.HAND_LIMIT)   # 抽到上限（会广播一次 hand_full）
	var n: int = scene.engine.state.hand.size()
	if n != FieldState.HAND_LIMIT:
		_smoke_fail("扇形手牌：应抽到上限 %d 张，实际 %d" % [FieldState.HAND_LIMIT, n])
		return
	if not scene.engine.state.hand_full():
		_smoke_fail("扇形手牌：满手后 hand_full() 仍为假")
	var bad := 0
	for i in n:
		var r: Rect2 = scene._hand_rect(i)
		var pivot: Vector2 = scene._hand_pivot(i)
		var center := Vector2(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)
		var hit_pos: Vector2 = pivot + (center - pivot).rotated(scene._hand_angle(i))
		if not scene._hand_hit(i, hit_pos):
			bad += 1
	if bad > 0:
		_smoke_fail("扇形手牌：%d/%d 张的命中判定与绘制角度不一致" % [bad, n])
	# 两端要有倾角、左右对称、且倾角随下标单调递增（真扇形而不是一排）。
	# 注意：张数为偶数时没有「正好 0°」的中间那张，所以只要求左右对称。
	var left_deg: float = rad_to_deg(scene._hand_angle(0))
	var right_deg: float = rad_to_deg(scene._hand_angle(n - 1))
	var monotonic := true
	for i in range(1, n):
		if scene._hand_angle(i) <= scene._hand_angle(i - 1):
			monotonic = false
	if not (left_deg < -1.0 and right_deg > 1.0 and monotonic
			and absf(left_deg + right_deg) < 0.01):
		_smoke_fail("扇形手牌：倾角不对（左 %.2f° / 右 %.2f° / 单调 %s）"
				% [left_deg, right_deg, monotonic])
	# 重叠：满手时步进必须小于卡宽
	if scene._hand_step(n) >= scene.HAND_CARD_W:
		_smoke_fail("扇形手牌：%d 张的步进 %.1f 不小于卡宽 %.1f，没有重叠"
				% [n, scene._hand_step(n), scene.HAND_CARD_W])
	# 尺寸：手牌明显比战场小卡大（空间换来的放大）
	if scene.HAND_CARD_H <= scene.CARD_H * 1.4:
		_smoke_fail("手牌尺寸：应比战场卡大 1.4 倍以上，实际 %.1f / %.1f（×%.2f）"
				% [scene.HAND_CARD_H, scene.CARD_H, scene.HAND_CARD_H / scene.CARD_H])
	# 卡底**沉出**窗口下沿：底部那截被裁掉。卡面仍是整张排版（不重锚、不补偿），
	# 所以这里只管「沉出量符合预期」和「别沉过头把卡片淹了」，不再断言内容必须可见。
	var bottom: float = scene.OWN_HAND_Y + scene.HAND_CARD_H
	if scene.HAND_CROP_BOTTOM <= 0.0:
		_smoke_fail("手牌位置：卡底没有沉出窗口下沿（HAND_CROP_BOTTOM=%.1f）"
				% scene.HAND_CROP_BOTTOM)
	if absf((bottom - scene.WINDOW_H) - scene.HAND_CROP_BOTTOM) > 0.5:
		_smoke_fail("手牌位置：沉出量应为 %.1f，实际 %.1f"
				% [scene.HAND_CROP_BOTTOM, bottom - scene.WINDOW_H])
	# 沉出量不能吃掉半张卡（否则手牌看着只剩一条边）
	var vis_min := 99999.0
	for i in n:
		vis_min = minf(vis_min, scene._hand_vis_h(i))
	if vis_min < scene.HAND_CARD_H * 0.5:
		_smoke_fail("手牌位置：露出高度只有 %.1f（卡高 %.1f 的一半以下），沉得太狠"
				% [vis_min, scene.HAND_CARD_H])
	# 卡顶不能顶进战场（否则会盖住棋盘单位）
	if scene.OWN_HAND_Y - scene.HAND_FAN_HOVER_LIFT < scene.GRID_Y + scene.GRID_H - 2.0:
		_smoke_fail("手牌位置：抬手后卡顶 %.1f 盖住了战场下沿 %.1f"
				% [scene.OWN_HAND_Y - scene.HAND_FAN_HOVER_LIFT,
					scene.GRID_Y + scene.GRID_H])
	# 两端要比中间下沉（弧线）
	if scene._hand_rect(0).position.y <= scene._hand_rect(n / 2).position.y:
		_smoke_fail("扇形手牌：两端没有下沉，缺少弧线")
	# 越界：卡放大后最容易压到右侧道具栏（x=900 起）或左侧信息栏
	var rz: Rect2 = scene._relic_zone_rect()
	var er: Vector2 = _hand_card_extent(scene, n - 1)
	var el: Vector2 = _hand_card_extent(scene, 0)
	if er.y > rz.position.x - 2.0:
		_smoke_fail("手牌越界：满手时最右一张到 %.1f，压到右侧道具栏（%.1f 起）"
				% [er.y, rz.position.x])
	if el.x < scene.INFO_X + scene.INFO_W + 4.0:
		_smoke_fail("手牌越界：最左一张到 %.1f，压到左侧信息栏（右沿 %.1f）"
				% [el.x, scene.INFO_X + scene.INFO_W])
	# 从上往下取最上层：最后一张的旋转中心必须命中最后一张
	var rl: Rect2 = scene._hand_rect(n - 1)
	var pl: Vector2 = scene._hand_pivot(n - 1)
	var cl := Vector2(rl.position.x + rl.size.x / 2, rl.position.y + rl.size.y / 2)
	var pl_hit: Vector2 = pl + (cl - pl).rotated(scene._hand_angle(n - 1))
	if scene._hand_index_at(pl_hit) != n - 1:
		_smoke_fail("扇形手牌：重叠区没有取最上层那张（期望 %d，实际 %d）"
				% [n - 1, scene._hand_index_at(pl_hit)])
	else:
		var msg := "SMOKE OK 扇形手牌：满手 %d 张，%.0f×%.0f（战场卡 %.0f×%.0f 的 %.2f 倍，" % [
				n, scene.HAND_CARD_W, scene.HAND_CARD_H, scene.CARD_W, scene.CARD_H,
				scene.HAND_CARD_H / scene.CARD_H]
		msg += "卡底沉出下沿 %.0f，露出 %.0f）" % [
				bottom - scene.WINDOW_H, vis_min]
		msg += " / 倾角 左 %.1f° 右 %.1f° / 横向 %.0f~%.0f（不越界）" % [
				left_deg, right_deg, el.x, er.y]
		print(msg)

func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var k: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * k)


func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := 99999.0
	for i in pts.size() - 1:
		best = minf(best, _dist_to_seg(p, pts[i], pts[i + 1]))
	return best


func _check_move_path(scene: Variant) -> void:
	## 多格移动动画必须沿「真实路径」走，而不是从起点直连终点。
	## 链路：引擎 move_path 逐格路径 → move 事件 → 场景 _slides 的 pts →
	##      _display_center 按 pts 分段插值。这里采样 9 个时刻，
	##      位置必须落在折线上（相差不得超过 1 像素）。
	var st: FieldState = scene.engine.state
	if st.unit_at(Vector2i(3, 0)) != null or st.unit_at(Vector2i(4, 0)) != null \
			or st.unit_at(Vector2i(3, 1)) != null or st.unit_at(Vector2i(4, 1)) != null:
		_smoke_fail("多格移动：(3,0)/(4,0)/(3,1)/(4,1) 已被占用，用例前提不成立")
		return
	var repo := CardRepo.load_json()
	var fast: CardData = repo.get_card(9027)    # 夜鸭：移动距离 2
	var wall: CardData = repo.get_card(8001)    # 木栅栏：占住 (4,0) 逼出 L 形走法
	st.place(fast, Vector2i(3, 0), "self")
	st.place(wall, Vector2i(4, 0), "opponent")
	scene.engine.move(Vector2i(3, 0), Vector2i(4, 1), "self")
	var pl2: Placement = st.unit_at(Vector2i(4, 1))
	if pl2 == null or not scene._slides.has(pl2):
		_smoke_fail("多格移动：单位没到 (4,1) 或场景没排队滑行动画")
		return
	var sl: Dictionary = scene._slides[pl2]
	var pts: Array = sl.get("pts", [])
	var want: Array[Vector2] = []
	for c in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1)]:
		want.append(scene._cell_center(c))
	if pts != want:
		_smoke_fail("多格移动：动画途经点与真实路径不符（%s）" % str(pts))
		return
	# 滑行时长随格数增加：2 格 = MOVE_SLIDE_BASE + PER_STEP * 2
	var two_dur: int = scene.MOVE_SLIDE_BASE_MS + scene.MOVE_SLIDE_PER_STEP_MS * 2
	if int(sl.get("dur", 0)) != two_dur:
		_smoke_fail("多格移动：2 格滑行时长应为 %d，实际 %d"
				% [two_dur, int(sl.get("dur", 0))])
	# 采样整段动画：任一时刻的位置都必须落在那条 L 形折线上
	var worst := 0.0
	var dur: int = int(sl.get("dur", 0))
	for i in 9:
		var frac: float = float(i) / 8.0
		sl["start"] = Time.get_ticks_msec() - int(float(dur) * frac)
		var pos: Vector2 = scene._display_center(pl2, Vector2i(4, 1))
		worst = maxf(worst, _dist_to_polyline(pos, want))
	# 反证：直线插值（修复前的行为）在这条 L 形路径上必然偏得很远，
	# 否则说明这条用例根本抓不到回归。
	var diag := 0.0
	for i in 9:
		var f2: float = float(i) / 8.0
		var e2: float = 1.0 - pow(1.0 - f2, 3.0)
		diag = maxf(diag, _dist_to_polyline(want[0].lerp(want[2], e2), want))
	if worst > 1.0:
		_smoke_fail("多格移动：最大偏离真实路径 %.1f 像素（动画走了捷径）" % worst)
	elif diag < 20.0:
		_smoke_fail("多格移动：直线插值只偏离 %.1f 像素，这条用例抓不到回归" % diag)
	else:
		print("SMOKE OK 多格移动走真实路径：途经点 %d 个 / 时长 %dms / 最大偏离 %.2f 像素（直线插值会偏 %.0f）" % [pts.size(), dur, worst, diag])
	st.board.erase(Vector2i(4, 1))
	st.board.erase(Vector2i(4, 0))

func _check_battle(scene: Variant) -> void:
	## 战斗场景的所有行为断言：扇形手牌 + 多格移动动画走真实路径 + 效果/道具溢出兜底
	## + 战斗内地图总览（R64）。
	_check_hand_fan(scene)
	_check_move_path(scene)
	_check_overflow(scene)
	_check_map_panel(scene)
	_check_frozen_aura(scene)
	_check_sleep_aura(scene)
	_check_turn_gate(scene)
	_check_relic_gate(scene)
	_check_r106(scene)
	_check_cancel_armed(scene)


func _check_r106(scene: Variant) -> void:
	## R106：① 效果卡可以**直接拖到左侧效果区**松手启用（真跑一遍拖动调用栈）；
	##       ② 战场单位「已获得的增益/减益」列表与卡面徽标能正常产出（并让后续帧真实绘制）。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("R106：拿不到 engine")
		return
	# ---- ① 效果区矩形：点击浏览与拖拽投放必须共用同一个矩形 ----
	var zone: Rect2 = scene._own_effect_zone_rect()
	if zone.size.x <= 0.0 or zone.size.y <= 0.0:
		_smoke_fail("R106：效果区矩形尺寸异常 %s" % str(zone.size))
		return
	eng.over = false
	eng.current_side = GameEngine.SIDE_SELF
	# 从**真实卡库**取一张效果卡（不手搓假卡，保证 class / traits 齐全）。
	var eff: CardData = null
	for c in scene.repo.all_cards():
		if c.is_effect():
			eff = c
			break
	if eff == null:
		_smoke_fail("R106：卡库里找不到效果卡，无法验证「拖到效果区」")
		return
	eng.state.hand.insert(0, CardData.from_dict(eff.to_dict()))
	eng.state.energy = 99
	var n_effects: int = eng.state.effects.size()
	var n_hand: int = eng.state.hand.size()
	scene._start_drag(0, zone.get_center())
	if not scene._drag_to_effects:
		_smoke_fail("R106：效果卡起拖后没有置起「可拖到效果区」标记")
		return
	scene._finish_drag(zone.get_center())
	if eng.state.effects.size() != n_effects + 1:
		_smoke_fail("R106：效果卡拖到效果区没有启用（效果区 %d → %d）"
				% [n_effects, eng.state.effects.size()])
		return
	if eng.state.hand.size() != n_hand - 1:
		_smoke_fail("R106：效果卡启用后没离开手牌（手牌 %d → %d）"
				% [n_hand, eng.state.hand.size()])
		return
	# 反面：拖到效果区**之外**的空白处 → 取消，不进效果区
	eng.state.hand.insert(0, CardData.from_dict(eff.to_dict()))
	var n_effects2: int = eng.state.effects.size()
	scene._start_drag(0, Vector2(2, 2))
	scene._finish_drag(Vector2(2, 2))
	if eng.state.effects.size() != n_effects2:
		_smoke_fail("R106：效果卡拖到空白处却生效了（效果区 %d → %d）"
				% [n_effects2, eng.state.effects.size()])
		return
	# ---- ② 状态列表 / 卡面徽标：给场上一个单位叠 buff + debuff ----
	var cell := Vector2i(FieldState.OPPONENT_ROWS, 0)
	var unit: Placement = eng.state.unit_at(cell)
	if unit == null:
		unit = eng.state.place(scene.repo.get_card(8003), cell, GameEngine.SIDE_SELF)
	unit.atk_buff = 2
	unit.atk_debuff = 1
	unit.debuff_stage = 1
	unit.upgrade_stacks = 1
	unit.frozen = true
	if unit.status_entries().size() < 3 or unit.status_badges().is_empty():
		_smoke_fail("R106：状态列表/徽标没有产出（列表 %d 条 / 徽标 %d 条）"
				% [unit.status_entries().size(), unit.status_badges().size()])
		return
	# 悬停到它 → 后续帧会真实走 _draw_info_panel（状态逐条 + 富文本效果）与卡面徽标
	scene._hover_card = unit.card
	scene._hover_pl = unit
	scene._drag_idx = -1
	scene.queue_redraw()
	print("SMOKE OK R106：效果卡拖入效果区即启用（%d→%d）/ 悬停单位列出 %d 条状态 + %d 个徽标"
			% [n_effects, eng.state.effects.size(), unit.status_entries().size(),
			unit.status_badges().size()])


func _check_relic_gate(scene: Variant) -> void:
	## R75：战斗右栏道具 —— 悬浮已能逐个看说明，**装得下时不允许点开浏览面板**。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("道具查看：拿不到 engine")
		return
	var cap: int = scene._relic_max_slots()
	if cap < 1:
		_smoke_fail("道具栏：可见槽位数 %d（应 >= 1）" % cap)
		return
	var saved: Array[int] = eng.self_relics.duplicate()
	eng.self_relics = [6001, 6003]
	if scene._relic_bar_overflowed():
		_smoke_fail("道具栏：2 件（容量 %d）却判定为装不下" % cap)
		return
	# 装满不溢出：点道具栏不该打开面板
	eng.self_relics = []
	for i in cap:
		eng.self_relics.append(6001)
	scene._relics_visible = false
	scene._on_left_click(scene._relic_zone_rect().get_center())
	if scene._relics_visible:
		_smoke_fail("道具栏：装得下（%d/%d）却仍能点开浏览面板" % [cap, cap])
		eng.self_relics = saved
		return
	# 超出容量：必须能点开
	for i in range(0, cap + 2):
		eng.self_relics.append(6001)
	if not scene._relic_bar_overflowed():
		_smoke_fail("道具栏：%d 件（容量 %d）却判定为装得下" % [eng.self_relics.size(), cap])
		eng.self_relics = saved
		return
	scene._on_left_click(scene._relic_zone_rect().get_center())
	if not scene._relics_visible:
		_smoke_fail("道具栏：装不下（%d>%d）却点不开浏览面板" % [eng.self_relics.size(), cap])
		eng.self_relics = saved
		return
	scene._relics_visible = false
	# 详情面板：能列出全部，且字号比悬浮提示大
	if scene._relic_panel_rows().size() != eng.self_relics.size():
		_smoke_fail("道具浏览面板：应列出全部 %d 件，实际 %d"
				% [eng.self_relics.size(), scene._relic_panel_rows().size()])
		eng.self_relics = saved
		return
	if int(scene.RELIC_P_NAME) <= 10 or int(scene.RELIC_P_DESC) <= 9:
		_smoke_fail("道具浏览面板：字号没放大（名称 %d / 说明 %d，原为 10 / 9）"
				% [int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])
		eng.self_relics = saved
		return
	eng.self_relics = saved
	print("SMOKE OK 道具查看：战斗道具栏容量 %d 个 / 装满点不开 / %d 件可点开 / 详情全列且字号 %d>%d"
			% [cap, cap + 2, int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])


func _check_turn_gate(scene: Variant) -> void:
	## R71：**玩家只能在自己（我方）的回合操作我方单位**。
	## 原来 `_on_board_click` / 手牌点击 / `_finish_drag` 三条出手路径**都没有回合门禁**
	## → 敌方 AI 正在行动时玩家仍能点选/移动/攻击自己的单位，
	## 看起来就像「AI 错误地操作了我方没行动过的单位」。
	## 这里逐条路径验证：敌方回合时点击/拖拽都不该改变任何我方单位状态。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("回合门禁：拿不到 engine")
		return
	# 摆一个我方单位 + 一个目标格，记录初始状态
	var src := Vector2i(4, 3)
	var dst := Vector2i(4, 2)
	var card := CardData.new()
	card.id = 7901
	card.card_name = "门禁 Dummy"
	card.kind = "盟友"
	card.power = 3
	card.health = 9
	card.attack_range = 1
	card.move_speed = 2
	card.rarity = 0
	card.group = "player"
	card.card_class = "森林精魄"
	if eng.state.unit_at(src) == null:
		eng.state.place(CardData.from_dict(card.to_dict()), src, GameEngine.SIDE_SELF)
	var me: Placement = eng.state.unit_at(src)
	if me == null:
		_smoke_fail("回合门禁：没能摆下我方单位")
		return

	# ① 我方回合：点击应当**能**选中（门禁不能挡掉正常操作）
	eng.current_side = GameEngine.SIDE_SELF
	eng.state.reset_units(GameEngine.SIDE_SELF)
	scene._on_board_click(src)
	if scene.selection == null or scene.selection[0] != "board":
		_smoke_fail("回合门禁：我方回合点我方单位应能选中（门禁挡错了）")
		return
	scene._clear_selection()

	# ② 敌方回合：点击 / 拖拽都不应动我方单位
	eng.current_side = GameEngine.SIDE_OPPONENT
	eng.state.reset_units(GameEngine.SIDE_OPPONENT)
	var hp0: int = me.health
	var cell0: Vector2i = src
	scene._on_board_click(src)               # 点自己 → 不该被选中
	var picked: bool = scene.selection != null and scene.selection[0] == "board"
	scene._on_board_click(dst)               # 点目标格 → 不该触发移动/攻击
	var moved: bool = eng.state.unit_at(dst) != null
	# 拖拽路径也挡一道（它独立于 _on_board_click）
	scene._drag_idx = 0
	scene._finish_drag(dst)
	var moved2: bool = eng.state.unit_at(dst) != null
	if picked or moved or moved2 or me.health != hp0 \
			or eng.state.unit_at(cell0) != me:
		_smoke_fail("回合门禁：敌方回合仍能操作我方单位（选中=%s 移动=%s 拖拽移动=%s 血 %d→%d）"
				% [str(picked), str(moved), str(moved2), hp0, me.health])
		return
	eng.current_side = GameEngine.SIDE_SELF
	print("SMOKE OK 回合门禁：敌方回合点棋盘/点目标格/拖牌都动不了我方单位；我方回合正常可操作")


func _smoke_free(eng: GameEngine, cell: Vector2i) -> bool:
	## R118 用例专用：这一格既没有单位也没有场地（场上「空位」的判据）。
	return eng.state.unit_at(cell) == null and eng.state.field_at(cell) == null


func _check_cancel_armed(scene: Variant) -> void:
	## R118：**左键点空位不再一步取消**。
	## 误点一下草地就把「已移动、还没攻击」的单位就地横置（放弃攻击、不可逆）是玩家最常
	## 踩的坑 —— 用户口径「不应该直接取消攻击，而是在第二次点击才取消，这个状态点击目标
	## 卡片依然可以攻击」。这里把三条路都真跑一遍：
	##   ① 第一次点空位 → 只「上膛」：选区 / 攻击目标**原样保留**、单位**没有**横置；
	##   ② 上膛之后点敌方单位 → **照样打出去**（用户口径的核心，也是「误点不致命」的前提）；
	##   ③ 再点一次空位 → 才真取消（单位横置 = 放弃攻击、选区清空、上膛归位）。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("R118 误点空位：拿不到 engine")
		return
	# 找两个相邻空格（我方半场）放「我方单位 + 敌方靶子」
	var src := Vector2i(-1, -1)
	var tgt := Vector2i(-1, -1)
	for r: int in [3, 4, 5]:
		for c: int in range(FieldState.BOARD_COLS - 1):
			if _smoke_free(eng, Vector2i(r, c)) and _smoke_free(eng, Vector2i(r, c + 1)):
				src = Vector2i(r, c)
				tgt = Vector2i(r, c + 1)
				break
		if src.x >= 0:
			break
	if src.x < 0:
		_smoke_fail("R118 误点空位：我方半场找不到两个相邻空格，用例前提不成立")
		return
	var far := Vector2i(-1, -1)
	eng.current_side = GameEngine.SIDE_SELF
	scene._clear_selection()
	var base := CardData.new()
	base.id = 7904
	base.card_name = "取消烟测 Dummy"
	base.kind = "盟友"
	base.power = 4
	base.health = 12
	base.attack_range = 1
	base.move_speed = 2
	base.rarity = 0
	base.group = "player"
	base.card_class = "森林精魄"
	var foe_card := CardData.from_dict(base.to_dict())
	foe_card.id = 7905
	foe_card.card_name = "烟测靶子"
	foe_card.health = 30
	foe_card.group = "enemy"
	var me: Placement = eng.state.place(
			CardData.from_dict(base.to_dict()), src, GameEngine.SIDE_SELF)
	var foe: Placement = eng.state.place(foe_card, tgt, GameEngine.SIDE_OPPONENT)
	# 「已移动、还没攻击」= 危险态：任何一次非攻击点击都会让它就地横置
	me.moved = true
	me.tapped = false
	me.acts_left = 1
	scene._on_board_click(src)          # 选中它（此时只剩攻击权）
	if scene.selection == null or scene.selection[0] != "board" or scene.selection[1] != src:
		_smoke_fail("R118 误点空位：点自己应当选中它，实际 %s" % str(scene.selection))
		_cleanup_cancel_dummy(eng, src, tgt)
		return
	if not scene.attack_targets_arr.has(tgt):
		_smoke_fail("R118 误点空位：靶子应当在攻击目标里（用例前提不成立）")
		_cleanup_cancel_dummy(eng, src, tgt)
		return
	# 「空位」= 空格 且 **不在** move / attack / hp 任何一个目标集里 ——
	# 这才是「点下去会掉到上膛分支」的定义，与关卡占了哪些格无关。
	for r2: int in range(FieldState.BOARD_ROWS):
		for c2: int in range(FieldState.BOARD_COLS):
			var cell := Vector2i(r2, c2)
			if not _smoke_free(eng, cell) or cell == src or cell == tgt:
				continue
			if scene.move_targets.has(cell) or scene.attack_targets_arr.has(cell) \
					or scene.hp_targets_arr.has(cell):
				continue
			far = cell
			break
		if far.x >= 0:
			break
	if far.x < 0:
		_smoke_fail("R118 误点空位：全盘找不到一个「空位」，用例前提不成立")
		_cleanup_cancel_dummy(eng, src, tgt)
		return

	# ---- ① 第一次点空位：只上膛，绝不取消 ----
	scene._on_board_click(far)
	var bad: Array[String] = []
	if scene.selection == null or scene.selection[0] != "board" or scene.selection[1] != src:
		bad.append("① 选区被清掉了（应当原样保留），实际 %s" % str(scene.selection))
	if me.tapped:
		bad.append("① 单位被就地横置了（放弃攻击）—— 这正是要修掉的误操作")
	if not scene.attack_targets_arr.has(tgt):
		bad.append("① 攻击目标消失了（那也就不叫「依然可以攻击」）")
	if not bool(scene._cancel_armed):
		bad.append("① 没有进入「待取消」状态（_cancel_armed 仍为假）")
	if not bad.is_empty():
		_smoke_fail("R118 误点空位 " + "；".join(bad))
		_cleanup_cancel_dummy(eng, src, tgt)
		return

	# ---- ② 上膛之后点敌方单位 → 照样打出去（用户口径的核心）----
	var foe_hp0: int = foe.health
	scene._on_board_click(tgt)
	if foe.health >= foe_hp0:
		_smoke_fail("R118 ② 上膛之后点目标应当照常攻击（靶子 %d → %d 血）" % [foe_hp0, foe.health])
		_cleanup_cancel_dummy(eng, src, tgt)
		return
	if bool(scene._cancel_armed):
		_smoke_fail("R118 ② 攻击真的打出去之后，上膛状态应当归位")
		_cleanup_cancel_dummy(eng, src, tgt)
		return

	# ---- ③ 第二次点空位 → 才真取消（单位横置 = 放弃攻击、选区清空）----
	me.tapped = false
	me.moved = true
	me.acts_left = 1
	# 用 `_select_board` 直接选中：`_on_board_click(src)` 走的是「点自己」那条会先把
	# 「已移动未攻击」的单位放弃攻击（横置）的路径，拿不到干净的前置状态。
	scene._select_board(src)
	scene._on_board_click(far)          # 第一次：上膛
	scene._on_board_click(far)          # 第二次：取消
	bad = []
	if scene.selection != null:
		bad.append("③ 第二次点空位没有取消选择（实际 %s）" % str(scene.selection))
	if not me.tapped:
		bad.append("③ 第二次点空位没有把「已移动未攻击」的单位横置（放弃攻击没生效）")
	if bool(scene._cancel_armed):
		bad.append("③ 取消之后上膛状态没有归位")
	if not bad.is_empty():
		_smoke_fail("R118 误点空位 " + "；".join(bad))
	else:
		print("SMOKE OK R118 误点空位：① 第一次点只上膛（选区/目标全保留、不横置）"
				+ " ② 上膛后点目标照常打（%d→%d 血）" % [foe_hp0, foe.health]
				+ " ③ 第二次点空位才真取消（单位横置）")
	_cleanup_cancel_dummy(eng, src, tgt)


func _cleanup_cancel_dummy(eng: GameEngine, src: Vector2i, tgt: Vector2i) -> void:
	## R118 用例收尾：别把 dummy 留给后续用例（与 `_check_frozen_aura` 同一套路）。
	eng.state.board.erase(src)
	eng.state.board.erase(tgt)


func _check_arcane_with_charm(scene: Variant) -> void:
	## 奥秘之泉（R71 修复）：**已经持有「奥秘护符」时，「喝下泉水」选项依然可用**。
	## 原来那条分支把 bbq_btn 一起 `visible = false` 了 → 玩家只能点「继续」，
	## 第二个选项形同虚设。而且闸门用的是 `_arcane_charm_taken`（护符已到手）而不是
	## `_arcane_drunk`（是否已喝过）→ 已戴护符的玩家连泉水都喝不到。
	RunState.gain_relic(6020)                 # 先戴上护符，复现「已有护符」的局面
	scene._setup_arcane()                     # 重铺选项（UI 平时只在 _ready 里建一次）
	await process_frame
	var bbq: Button = scene.get_node_or_null("Center/BBQBtn")
	var rest: Button = scene.get_node_or_null("Center/RestBtn")
	if bbq == null or rest == null:
		_smoke_fail("奥秘之泉：找不到 RestBtn / BBQBtn 节点")
		return
	# 拿到护符之后也照样能点「喝下泉水」→ **卡牌奖励入队**（限定 效果/技能）＋ 奖励悬浮窗弹出
	scene._ui_bbq()
	await process_frame
	var kinds: Array = []
	var queued := -1
	for i in RunState.pending_rewards.size():
		var e: Dictionary = RunState.pending_rewards[i]
		if str(e.get("kind", "")) == "cards":
			queued = i
			kinds = e.get("kinds", [])
	if queued < 0 or not ("效果" in kinds and "技能" in kinds):
		_smoke_fail("奥秘之泉：已有护符时点「喝下泉水」应把卡牌奖励入队（限定 效果/技能），实际 kinds=%s（队列 %d 条）"
				% [str(kinds), RunState.pending_rewards.size()])
		return
	var panel: Variant = scene._reward_panel
	if panel == null or not panel.is_open():
		_smoke_fail("奥秘之泉：喝下泉水后奖励悬浮窗应当自动打开")
		return
	if not scene._arcane_drunk:
		_smoke_fail("奥秘之泉：点「喝下泉水」应记下 _arcane_drunk（防重复喝）")
		return
	print("SMOKE OK 奥秘之泉：已有护符时「喝下泉水」仍可选 → 卡牌奖励入队（限定 效果/技能）并弹出奖励悬浮窗")


func _check_frozen_aura(scene: Variant) -> void:
	## 冰封特效（R68）：`Placement.frozen` 必须常驻可见 —— 这是个**看卡面看不出来**的状态。
	## ① 引擎施加冰封 → 界面发出 frozen 事件（会加飘字/爆点）；
	## ② 场上被冰封的单位 → `_board_has_frozen()` 为真（_process 靠它逐帧重绘脉冲）；
	## ③ 常驻光环与「嘲讽光环」互不重叠：同时具备两个状态时冰封徽标要往下错开。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("冰封特效：拿不到 engine")
		return
	# 场上摆一个我方单位，直接置 frozen（走引擎真实字段，界面判据同源）
	var cell := Vector2i(4, 1)
	if eng.state.unit_at(cell) == null:
		var cd := CardData.new()
		cd.id = 7901
		cd.card_name = "冰封烟测 Dummy"
		cd.kind = "盟友"
		cd.health = 10     # _apply_frozen 对血量 ≤ 0 的单位不施加（死单位冰封没意义）
		cd.power = 2
		eng.state.place(cd, cell, GameEngine.SIDE_SELF)
	var pl: Placement = eng.state.unit_at(cell)
	pl.frozen = true
	if not scene._board_has_frozen():
		_smoke_fail("冰封特效：场上有 frozen 单位时 _board_has_frozen() 应为真")
		return
	# 常驻光环：直接调（内部只读 frozen，不改状态）——真渲染在后面的帧里发生
	var c2: Vector2 = scene._display_center(pl, cell)
	scene._draw_frozen_aura(c2, 40.0, 56.0, 0)
	scene._draw_frozen_aura(c2, 40.0, 56.0, 1)   # 徽标在第 2 行（上方留给嘲讽）
	if not scene._board_has_taunt():
		pass   # 本用例没放嘲讽单位，这里只是确认函数可共存调用
	# frozen 事件：引擎唯一入口会 emit，界面据此演飘字
	var got := [0]
	eng.action.connect(func(what: String, _d: Variant) -> void:
			if what == "frozen":
				got[0] = int(got[0]) + 1)
	eng._apply_frozen(pl, "烟测")
	if int(got[0]) != 1 or not pl.frozen:
		_smoke_fail("冰封特效：_apply_frozen 应发出 1 次 frozen 事件并置位 frozen（实际 %d）"
				% int(got[0]))
		return
	pl.frozen = false
	if pl.card.card_name == "冰封烟测 Dummy" and eng.state.unit_at(cell) == pl:
		eng.state.board.erase(cell)   # 清场：别把 dummy 留给后续用例
	print("SMOKE OK 冰封特效：frozen 事件 + 常驻寒霜光环 + 与嘲讽徽标错开，三者同源于 Placement.frozen")


func _check_sleep_aura(scene: Variant) -> void:
	## 沉睡特效（R72）：恶魔鸭 9116「还不能动」是**看卡面看不出来**的
	## 隐藏状态，而且「还差几下」直接决定「现在打不打它」（R76：挨一下 -1、打空立刻醒）。
	##   ① `Placement.sleep_left > 0` → `_board_has_sleep()` 为真（_process 靠它逐帧重绘）；
	##   ② 常驻光环 + 徽标（「沉睡 N」）与冰封/嘲讽共用底座，按行号错开不重叠；
	##   ③ 苏醒事件 wake → 挣脱环进 `_wake_rings` 并被 `_tick_anims` 认作「还在演」。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("沉睡特效：拿不到 engine")
		return
	# ⚠️ 格子必须避开其它用例的占位：回合门禁用 (4,3)→(4,2)、冰封用 (4,1)。
	# 本轮最初摆在 (4,2)，结果门禁用例的 dst 本来就有单位 → 被误判成「移动成功」。
	#
	# R76：这里**不能**沿用「格子空着才建卡」的老写法 —— 整套跑时敌方 AI 可能已经
	# 在这一格部署了单位（实测拿到过「爆炎鸭」），于是 sp 变成别人的卡：没有「沉睡」
	# trait，挨打当然不会醒（表现为 wake 0 次 / sleep_left 仍 1）。
	# 改成**先清场再摆自己的卡**，让这个用例与场上其它单位彻底无关。
	var cell := Vector2i(2, 2)
	eng.state.board.erase(cell)
	var cd := CardData.new()
	cd.id = 7902
	cd.card_name = "沉睡烟测 Dummy"
	cd.kind = "盟友"
	cd.health = 10
	cd.power = 2
	# 必须带「沉睡」trait，否则 _demon_duck_hurt 不会分派、挨打也不会醒。
	cd.traits = [FieldState.SLEEP_TRAIT]
	eng.state.place(cd, cell, GameEngine.SIDE_SELF)
	var sp: Placement = eng.state.unit_at(cell)
	# 记下这是我们摆的，用完挪走（不给后面的用例留垃圾）
	var ours := sp != null and sp.card.card_name == "沉睡烟测 Dummy"
	if sp == null:
		_smoke_fail("沉睡特效：在 %s 摆烟测卡失败" % str(cell))
		return
	sp.sleep_left = 2
	if not scene._board_has_sleep():
		_smoke_fail("沉睡特效：场上有 sleep_left > 0 的单位时 _board_has_sleep() 应为真")
		return
	# 徽标行号 0/1/2 都画一遍 → 三个状态同时成立时也不该有绘制错误/重叠
	var cs: Vector2 = scene._display_center(sp, cell)
	for row in 3:
		scene._draw_sleep_aura(cs, 40.0, 56.0, 2, row)
	# 徽标宽度随文案长度自适应（「沉睡 2」比「冰封」长，写死宽度会被截断）
	var bw2 := maxf(40.0, 14.0 + float("沉睡 2".length()) * 11.0)
	if bw2 <= 40.0:
		_smoke_fail("沉睡特效：徽标宽度应随文案自适应（实际 %.1f）" % bw2)
		return
	# 苏醒事件 → 挣脱环（用引擎真实入口走一遍，不手搓事件）
	# 这里是**受伤递减口**：`_hit_unit` → `_demon_duck_hurt`，挨够次数 sleep_left 归零。
	# （R122 起**回合递减口** `_sleep_tick` 也回来了，两个口并存 —— 见本用例末尾。）
	sp.sleep_left = 1
	var woke := [0]
	eng.action.connect(func(what: String, _d: Variant) -> void:
			if what == "wake":
				woke[0] = int(woke[0]) + 1)
	var rings_before: int = scene._wake_rings.size()
	eng._hit_unit(sp, 1, "沉睡烟测")
	if int(woke[0]) != 1 or sp.sleep_left != 0:
		_smoke_fail(("沉睡特效：挨打应发 1 次 wake 并把 sleep_left 归零（实际 %d / %d；卡=%s 有沉睡trait=%s ours=%s）"
				% [int(woke[0]), sp.sleep_left, sp.card.card_name,
					str(sp.card.traits.has(FieldState.SLEEP_TRAIT)), str(ours)]))
		return
	# 顺带锁住 R122 的**回合递减口** —— 放在「醒来后 _board_has_sleep() 转假」之后断言，
	# 否则会把 sleep_left 改回 2。
	if scene._wake_rings.size() <= rings_before:
		_smoke_fail("沉睡特效：wake 事件应往 _wake_rings 加挣脱环（%d → %d）"
				% [rings_before, scene._wake_rings.size()])
		return
	if scene._board_has_sleep():
		_smoke_fail("沉睡特效：醒来后 _board_has_sleep() 应转为假（光环不该再画）")
		return
	# ① 它自己那一方回合结束 → -1（R76 曾把这一步删掉，于是「没人打它就永远不醒」，
	#    R122 用户实测反馈后补回；与之并存的受伤口就是上面刚走过的那一段）。
	sp.sleep_left = 2
	eng._sleep_tick(sp.owner)
	if sp.sleep_left != 1:
		_smoke_fail("沉睡特效：R122 起 _sleep_tick 应在自己那一方回合结束 -1（2 → 1，实际 %d）"
				% sp.sleep_left)
		eng.state.board.erase(cell)
		return
	# ② 别人那一方的回合结束**不该**减它（只认「它自己那一方」）
	var r122_other: String = GameEngine.SIDE_OPPONENT
	if sp.owner == GameEngine.SIDE_OPPONENT:
		r122_other = GameEngine.SIDE_SELF
	eng._sleep_tick(r122_other)
	if sp.sleep_left != 1:
		_smoke_fail("沉睡特效：别人那一方的回合结束不该减它的沉睡（应仍为 1，实际 %d）"
				% sp.sleep_left)
		eng.state.board.erase(cell)
		return
	scene._wake_rings.clear()
	scene._draw_wake_rings()   # 真渲染空/非空两种状态都不出错
	if ours and eng.state.unit_at(cell) == sp:
		eng.state.board.erase(cell)   # 清场：别把 dummy 留给后续用例
	print("SMOKE OK 沉睡特效：常驻紫环 + 「沉睡 N」徽标（3 行互不重叠）+ 苏醒挣脱环，同源于 Placement.sleep_left；R122 起回合口与受伤口并存（都在减）")


func _check_map_panel(scene: Variant) -> void:
	## 战斗内地图总览（R128）：**格子视图**、只读、整屏装得下（不再滚动）。
	##   ① 「重开一局」按钮已删除、换成「地图」按钮；
	##   ② 打开面板 → 标出可走 / 当前房间，关掉后复原；
	##   ③ 面板只读：点房间不会改路线（current_node_id 不变）。
	var tb: Variant = scene.get_node_or_null("Toolbar")
	if tb == null:
		_smoke_fail("战斗内地图：找不到 Toolbar 节点")
		return
	if tb.get_node_or_null("RestartBtn") != null:
		_smoke_fail("战斗内地图：「重开一局」按钮应已删除")
		return
	if tb.get_node_or_null("MapBtn") == null:
		_smoke_fail("战斗内地图：Toolbar 里没有 MapBtn")
		return
	if not scene.map_btn.visible:
		_smoke_fail("战斗内地图：run 中「地图」按钮应可见")
		return
	scene._toggle_map()
	if not scene._map_visible:
		_smoke_fail("战斗内地图：_toggle_map 后面板没有打开")
		return
	# 可走判定与 RunState 同源
	var nxt := 0
	var avail := RunState.available_nodes()
	for n in avail:
		if scene._mapview_is_next(n):
			nxt += 1
	if nxt != avail.size():
		_smoke_fail("战斗内地图：%d/%d 个可走房间被标出" % [nxt, avail.size()])
		return
	# 通路（R130）：面板与冒险地图同一套语义 —— 当前房 → 可走房 = 亮青
	for node2: Dictionary in RunState.map_cells:
		if not scene._mapview_is_current(node2):
			continue
		for node3: Dictionary in RunState.map_cells:
			if scene._mapview_is_next(node3) \
					and scene._mapview_bridge_kind(node2, node3) != MapBridge.LIT:
				_smoke_fail("战斗内地图：当前房 → 可走房 %d 的通路语义不对"
						% int(node3["id"]))
				return
	# 只读：点面板里的房间不改路线
	var cur_before := RunState.current_node_id
	var some_cell: Dictionary = {}
	for node: Dictionary in RunState.map_cells:
		if scene._mapview_is_next(node):
			some_cell = node
			break
	if not some_cell.is_empty():
		scene._on_left_click(scene._mapview_cell_rect(some_cell).get_center())
		if RunState.current_node_id != cur_before:
			_smoke_fail("战斗内地图：面板应当只读，点房间却把路线改到了 %d"
					% RunState.current_node_id)
			return
	if scene._map_visible:
		_smoke_fail("战斗内地图：点任意处应关闭面板")
		return
	scene._toggle_map()
	if not scene._map_visible:
		_smoke_fail("战斗内地图：关闭后应能再次打开")
		return
	# 几何：35 个格子必须**完整**落在可视区内（整屏装得下，所以不再需要滚动）
	var view: Rect2 = scene._mapview_view_rect()
	var out_cnt := 0
	for node: Dictionary in RunState.map_cells:
		if not view.encloses(scene._mapview_cell_rect(node)):
			out_cnt += 1
	if out_cnt > 0:
		_smoke_fail("战斗内地图：%d 个格子越出了可视区（应当整屏装得下）" % out_cnt)
		return
	# **保持面板打开**：剩下的几帧会真的把 _draw_map_panel 画出来 ——
	# 面板里的绘制错误（越界访问 / 空引用）只有真渲染才抓得到（headless 抓不到）。
	print("SMOKE OK 战斗内地图：格子总览可开关 / 只读（可走 %d 间）/ %d 个格子全部完整落在面板内 / 保持打开供后续帧渲染"
			% [nxt, RogueMap.CELLS])


func _check_overflow(scene: Variant) -> void:
	## 效果区 / 敌方效果区 / 道具栏：可见槽位数必须 >= 1，且**最后一个可见槽位不得越出区域外框**。
	## 超出可见槽位的部分改画成「+N」摘要卡（点区域可查看全部）—— 这条锁保证
	## 「效果或道具再多，也不会溢出画到屏幕外、或者把后面的卡遮没」。
	var zb: float = scene.GRID_Y + scene.GRID_H
	var cap_eff: int = scene._effect_zone_max_slots()
	var last_eff: Rect2 = scene._effect_rect(cap_eff - 1)
	if cap_eff < 1:
		_smoke_fail("效果区：可见槽位数为 %d（应 >= 1）" % cap_eff)
	elif last_eff.position.y + last_eff.size.y > zb + 0.5:
		_smoke_fail("效果区：第 %d 张卡底部 %.1f 越出区域下沿 %.1f"
				% [cap_eff, last_eff.position.y + last_eff.size.y, zb])
	var rz: Rect2 = scene._relic_zone_rect()
	var cap_rel: int = scene._relic_max_slots()
	var last_rel: Rect2 = scene._relic_rect(cap_rel - 1)
	if cap_rel < 1:
		_smoke_fail("道具栏：可见槽位数为 %d（应 >= 1）" % cap_rel)
	elif last_rel.position.y + last_rel.size.y > rz.position.y + rz.size.y + 0.5:
		_smoke_fail("道具栏：第 %d 个徽章底部 %.1f 越出区域下沿 %.1f"
				% [cap_rel, last_rel.position.y + last_rel.size.y, rz.position.y + rz.size.y])
	var ez: Rect2 = scene._enemy_zone_rect()
	var cap_ee: int = scene._enemy_effect_zone_max_slots()
	var last_ee: Rect2 = scene._enemy_effect_rect(cap_ee - 1)
	if cap_ee < 1:
		_smoke_fail("敌方效果区：可见槽位数为 %d（应 >= 1）" % cap_ee)
	elif last_ee.position.y + last_ee.size.y > ez.position.y + ez.size.y + 0.5:
		_smoke_fail("敌方效果区：第 %d 张卡底部 %.1f 越出区域下沿 %.1f"
				% [cap_ee, last_ee.position.y + last_ee.size.y, ez.position.y + ez.size.y])
	else:
		print("SMOKE OK 溢出兜底：效果区 %d 槽 / 敌方效果 %d 槽 / 道具 %d 槽（末位均不越界，超出改画 +N 摘要）"
				% [cap_eff, cap_ee, cap_rel])
