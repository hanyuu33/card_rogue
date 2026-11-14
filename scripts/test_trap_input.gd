extends SceneTree
## R667 陷阱栏输入回归：godot --headless --path . --script res://scripts/test_trap_input.gd
## 真把鼠标 / 触摸事件喂进 battle.tscn 的 _gui_input，断言「拖放成功 / 取消不消耗 /
## 安卓原生 ScreenTouch+ScreenDrag / 长按窗口 / 返回键取消 / 轻点不消耗 / 底图合一」。
## 重点：安卓用例故意**不发任何 InputEventMouseMotion**，证明不靠 emulate_mouse_from_touch 也能拖。

var _ok := 0
var _bad := 0
var _sc: Variant = null   # 必须是 Variant：声明成 Node 会挡住对场景脚本属性的动态访问


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("✓ ", msg)
	else:
		_bad += 1
		print("✗ ", msg)


func _feed(ev: InputEvent) -> void:
	_sc._gui_input(ev)


func _mb(pos: Vector2, pressed: bool, btn: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = pressed
	e.position = pos
	return e


func _mm(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


func _touch(pos: Vector2, pressed: bool, idx: int = 0) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = pressed
	e.position = pos
	return e


func _sdrag(pos: Vector2, idx: int = 0) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	return e


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _slot(i: int) -> Vector2:
	return _sc._trap_slot_rect(i).get_center()


func _target() -> Vector2i:
	var cells = _sc.engine.trap_legal_cells()
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)


func _reset_case() -> void:
	# 每个用例都从「栏里有 1 件、场上没有陷阱、没有任何拖拽/长按残留」开始。
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7001)
	_sc.engine.state.trap_fields.clear()
	_sc.engine.state.field_effects.clear()
	_sc.engine.state.field_owner.clear()
	_sc._trap_drag_slot = -1
	_sc._trap_press_slot = -1
	_sc._trap_drag_cells.clear()   # 泛型数组：不能赋普通 []
	_sc._lp_active = false
	_sc._lp_fired = false
	_sc._grid_drag_arm = false
	_sc._grid_dragging = false
	_sc._info_drag_arm = false
	_sc._info_dragging = false
	_sc._press_idx = -1


func _arm_drag(pos: Vector2) -> void:
	## 已经按下槽 0 之后，把它推进到「正在拖」的状态（PC 路径）。
	_feed(_mm(pos))


func _initialize() -> void:
	# R346 / R378：绝不写玩家真实档案或存档。
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = RunState.next_level({"type": "battle"})
	_sc = load("res://scenes/battle.tscn").instantiate()
	root.add_child(_sc)
	# battle._ready 只铺 UI 与素材，engine 要等关卡装载那一帧才建；输入测试不跑帧，
	# 所以直接注入一台干净引擎（与 test_traps.gd 同款），让 _gui_input 的守卫能通过。
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "陷阱输入测试", false))
	eng.ai_enabled = false
	_sc.engine = eng

	check(_sc.engine != null, "战斗场景实例化成功且注入的 engine 就绪")
	check(_sc.engine.current_side == GameEngine.SIDE_SELF, "开局是己方回合（陷阱可布置）")
	check(_target().x >= 0, "trap_legal_cells() 至少有一个合法空格")

	# ---- ① PC：按住槽 → 拖过阈值 → 落在高亮格，放置成功并清空槽 ----
	_reset_case()
	var s0 := _slot(0)
	var cell := _target()
	var dest: Vector2 = _sc._cell_center(cell)
	_feed(_mb(s0, true))
	check(_sc._trap_press_slot == 0, "PC：按下有货的槽 0 记为 press（不误触 _on_left_click）")
	_arm_drag(s0 + Vector2(30, 30))
	check(_sc._trap_drag_slot == 0, "PC：位移超过 DRAG_THRESHOLD 进入拖放")
	_feed(_mm(dest))
	check(_sc._trap_drag_pos.distance_to(dest) < 1.0, "PC：MouseMotion 更新幽灵图位置")
	_feed(_mb(dest, false))
	check(RunState.trap_at(0) == -1, "PC：成功放置后槽 0 清空（用了就没）")
	check(_sc.engine.state.trap_fields.has(cell), "PC：目标格写入 trap_fields")
	check(_sc._trap_drag_slot == -1 and _sc._trap_press_slot == -1, "PC：结算后拖拽态清干净")

	# ---- ② PC：拖到棋盘外松手 = 取消，不消耗 ----
	_reset_case()
	_feed(_mb(_slot(0), true))
	_arm_drag(_slot(0) + Vector2(30, 30))
	_feed(_mb(Vector2(20, 20), false))
	check(RunState.trap_at(0) == 7001, "PC：非法落点取消后陷阱仍在栏里")
	check(_sc.engine.state.trap_fields.is_empty(), "PC：非法落点不写场地")
	check(_sc._trap_drag_slot == -1, "PC：非法落点后拖拽态清空")

	# ---- ③ PC：右键取消 ----
	_reset_case()
	_feed(_mb(_slot(0), true))
	_arm_drag(_slot(0) + Vector2(30, 30))
	_feed(_mb(Vector2(600, 400), true, MOUSE_BUTTON_RIGHT))
	check(_sc._trap_drag_slot == -1, "PC：右键取消拖拽")
	check(RunState.trap_at(0) == 7001 and _sc.engine.state.trap_fields.is_empty(), "PC：右键取消不消耗")

	# ---- ④ 安卓原生路径：全程不发 MouseMotion，只靠 ScreenTouch + ScreenDrag ----
	_reset_case()
	cell = _target()
	dest = _sc._cell_center(cell)
	s0 = _slot(0)
	_feed(_touch(s0, true))
	_feed(_mb(s0, true))          # emulate_mouse_from_touch 合成的按下
	_feed(_sdrag(dest))           # 只有原生触摸拖动，故意不给 MouseMotion
	check(_sc._trap_drag_slot == 0, "安卓：仅 ScreenDrag 也能越过阈值启动拖放")
	check(_sc._trap_drag_pos.distance_to(dest) < 1.0, "安卓：ScreenDrag 更新幽灵图位置")
	_feed(_touch(dest, false))    # 松手先到（Godot 的真实顺序）
	check(RunState.trap_at(0) == -1, "安卓：ScreenTouch 松手兜底结算，槽清空")
	check(_sc.engine.state.trap_fields.has(cell), "安卓：放置落到目标格")
	_feed(_mb(dest, false))       # 随后到达的合成松手
	check(_sc.engine.state.trap_fields.size() == 1 and RunState.trap_at(0) == -1, "安卓：合成松手空转，不重复放置")

	# ---- ⑤ 安卓：拖到非法区松手 = 取消 ----
	_reset_case()
	s0 = _slot(0)
	_feed(_touch(s0, true))
	_feed(_mb(s0, true))
	_feed(_sdrag(Vector2(20, 20)))
	_feed(_touch(Vector2(20, 20), false))
	check(RunState.trap_at(0) == 7001 and _sc.engine.state.trap_fields.is_empty(), "安卓：非法落点取消不消耗")
	check(_sc._trap_drag_slot == -1, "安卓：非法落点后拖拽态清空")

	# ---- ⑥ 长按窗口：DRAG_THRESHOLD(14) < LP_SLOP(18) 时，拖放不能被 500ms 长按误取消 ----
	_reset_case()
	s0 = _slot(0)
	_feed(_touch(s0, true))
	_feed(_mb(s0, true))
	_feed(_sdrag(s0 + Vector2(15, 0)))   # 15px：过 14 但没到 18，_lp_active 原本还活着
	check(_sc._trap_drag_slot == 0, "长按窗口：15px 已进入拖放")
	check(not _sc._lp_active, "长按窗口：_start_trap_drag 立即作废长按计时")
	# 恶意复原长按计时，模拟修复前状态。不直接调 _process（它会摸到未铺好的顶栏节点，
	# 在 headless 注入场景里刷假 SCRIPT ERROR），改为复算守卫表达式 + 读源码确认守卫在位。
	_sc._lp_active = true
	_sc._lp_fired = false
	_sc._lp_t0 = _sc._now() - 1000
	var would_fire: bool = _sc._lp_active and not _sc._lp_fired and _sc._drag_idx < 0 and _sc._trap_drag_slot < 0 and not _sc._grid_dragging and (_sc._now() - _sc._lp_t0 >= 500)
	check(not would_fire, "长按窗口：计时到点也不会误触发右键取消")
	var psrc := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	check(psrc.contains("if _lp_active and not _lp_fired and _drag_idx < 0 and _trap_drag_slot < 0"), "源码守卫：_process 长按判据显式排除陷阱拖拽")
	_sc._lp_active = false

	# ---- ⑦ 安卓返回键（KEY_ESCAPE）= 取消，不弹主菜单 ----
	_reset_case()
	_feed(_mb(_slot(0), true))
	_arm_drag(_slot(0) + Vector2(30, 30))
	_feed_key()
	check(_sc._trap_drag_slot == -1, "安卓：返回键取消拖拽")
	check(RunState.trap_at(0) == 7001 and _sc.engine.state.trap_fields.is_empty(), "安卓：返回键取消不消耗")
	check(_sc._menu == null or not _sc._menu.is_open(), "安卓：返回键不弹主菜单")

	# ---- ⑧ 轻点 = 只读看说明，不消耗 ----
	_reset_case()
	s0 = _slot(0)
	_feed(_touch(s0, true))
	_feed(_mb(s0, true))
	_feed(_touch(s0, false))   # 真实顺序：原生松手先于合成松手
	_feed(_mb(s0, false))
	check(RunState.trap_at(0) == 7001 and _sc.engine.state.trap_fields.is_empty(), "轻点：不放置也不消耗")

	# ---- ⑨ 底图合一：两处共用一张，停用版不在 assets/ui ----
	var tex := UiAssets.trap_bar_bg()
	check(tex != null, "UiAssets.trap_bar_bg() 取到共用竖栏底图")
	check(not FileAccess.file_exists("res://assets/ui/trap_bar_map.png"), "trap_bar_map.png 已移出 assets/ui")
	var bsrc := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	var msrc := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
	check(bsrc.contains("TrapArt.draw_bar_bg(self, bar)") and msrc.contains("TrapArt.draw_bar_bg(self, bar)"), "战斗与地图都调无 kind 的同一绘制口")
	check(not bsrc.contains("draw_bar_bg(self, bar, \"battle\")") and not msrc.contains("draw_bar_bg(self, bar, \"map\")"), "源码里不再有按场景分版的底板参数")

	# ---- ⑩ R667：与卡组/弃牌/消耗严格同列（同一中轴 x=1200、底板同 x 同宽）----
	var zone_cx: float = _sc._zone_rect("deck").get_center().x
	var s0cx: float = _sc._trap_slot_rect(0).get_center().x
	var s1cx: float = _sc._trap_slot_rect(1).get_center().x
	var s2cx: float = _sc._trap_slot_rect(2).get_center().x
	check(absf(s0cx - zone_cx) < 0.01 and absf(s1cx - zone_cx) < 0.01 and absf(s2cx - zone_cx) < 0.01, "三槽中轴与卡组/弃牌/消耗完全一致")
	check(bsrc.contains("Rect2(DECK_X, TRAP_BAR_Y - 10.0,") and bsrc.contains("ZONE_W"), "竖栏底板取资源列同一 x / 同一宽")
	var badge_top: float = _sc._zone_rect("void").position.y - 24.0 * 0.6
	check(_sc._trap_slot_rect(2).end.y <= badge_top, "第三槽仍在真空带内，不压消耗区张数徽章")

	# 走项目统一的中文汇总口径：_verify.py 优先认「N 通过 / N 失败」，
	# 否则按符号计数会把汇总行本身印的那个 ✗ 也算成一条失败。
	print("TRAPINPUT === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
	quit(0 if _bad == 0 else 1)


func _feed_key() -> void:
	_sc._unhandled_key_input(_key(KEY_ESCAPE))
