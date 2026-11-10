extends Control
## R530：**通关结算界面** —— 打通第三层 Boss 之后不再弹「胜利」小面板，
## 而是切到这里，逐行浮现本局数据，最后点「确定」离开。
##
## 用户口径（原话）：
##   使用角色（左侧）玩家使用角色（右侧）
##   造成伤害（左侧）本局玩家总伤害（所有方式，右侧）
##   花费时间（左侧）本局花费总时间（仅包含实际游戏时间，如有中断继续游戏时再开始计算，右侧）
##   战斗胜利（左侧）本局胜利数（右侧）
##   精英胜利（左侧）本局精英胜利数（右侧）
##   之后正下方让玩家点击按钮确定
##
## 数据来源（全部来自 `RunState.run_summary`，由 `battle_scene._show_over` 在
## **`RunRecord.finish()` 之前**填好 —— 那一步会删掉 pending，用时就读不到了）：
##   * 角色 / 难度 / 层数 → `RunState`
##   * 伤害 → `RunState.total_damage`（引擎三个落地口记账，实际扣血）
##   * 用时 → `RunRecord.peek_elapsed()`（各段累加，不含关掉游戏的时间）
##   * 胜场 → `RunState.total_battle_wins` / `total_elite_wins`（换层不清）
##
## 视觉：沿用奖励页 R502/R505 的**奶油纸面 + 双金边 + 胶囊按钮**语言，
## 整屏羊皮纸背景 + 四边暗角（`UiTheme.draw_panel_bg` + 本文件的 `_draw_vignette`）。
## 出场动画 = 逐行淡入 + 上浮 10px，数字同时从 0 滚到目标值（「流式输出」）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_DELAY := 0.11          # 每行之后的延迟（秒）
const ROW_FADE := 0.30           # 单行淡入时长
const HEAD_DELAY := 0.06         # 标题比第一行早一点
const BTN_DELAY := 0.20          # 最后一行之后多久出按钮

const PAPER := Color("f3eee2")       # 纸面底
const GOLD_LINE := Color("cbb47e")   # 金边
const INNER_LINE := Color("fffaf0")  # 内白边
const TEXT := Color("514735")        # 主文字（深棕）
const TEXT_MUTED := Color("857249")  # 次要文字
const TITLE_COL := Color("8a5f1c")   # 标题（深金棕）
const NUM_COL := Color("2f5d8a")     # 数字（墨蓝，纸面上可读性最好）
const BTN_GREEN := Color("5bb873")
const BTN_GREEN_LINE := Color("48985b")

var _font: Font
var _font_bold: Font
var sfx: Sfx

var _t := 0.0                    # 从 _ready 起累计（秒）
var _data: Dictionary = {}
var _rows: Array = []            # [{label, text, num, suffix}]
var _hover_btn := false
var _leaving := false
## 烟测接缝（与 `battle_scene.over_route_fn` 同形）：只记录目标，不真换场景树。
var route_fn: Callable = Callable()


func _ready() -> void:
	UiTheme.attach_stage(self)   # 宽屏下内容居中，背景溢出铺满两侧
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	set_process(true)
	var args := OS.get_cmdline_user_args()
	# 出图 / 调试：`--summarydemo` 灌一组假数据（真实流程永远从 run_summary 来）。
	# R551：加 `--summarydemo-lose` 出「失败」结算页（标题 + 副标题走失败口径）。
	# 注意 `--summarydemo-lose` 是独立参数，不是 `--summarydemo` 的子串，两个都要判。
	if "--summarydemo" in args or "--summarydemo-lose" in args:
		RunState.run_summary = {
			"class": PlayerClass.DRUID, "difficulty": 6, "layer": GameLayers.LAYER_THREE,
			"damage": 13847, "seconds": 4823, "battles": 24, "elites": 5,
		}
		if "--summarydemo-lose" in args:
			RunState.run_summary["result"] = "lose"
			RunState.run_summary["layer"] = GameLayers.LAYER_TWO
			RunState.run_summary["battles"] = 11
			RunState.run_summary["elites"] = 2
	_load_data()
	_build_rows()
	if "--screenshot" in args:
		# 出图：时间轴钉住（与帧率无关），`--summaryanim <秒>` 可看中途帧
		var at := 1.6
		var ai := args.find("--summaryanim")
		if ai >= 0 and ai + 1 < args.size():
			at = float(args[ai + 1])
		var timer := Timer.new()
		timer.wait_time = at
		timer.one_shot = true
		timer.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_summary.png"))
			get_tree().quit())
		add_child(timer)
		timer.start()


func _load_data() -> void:
	## 读结算快照。为空（直接打开场景 / 单关）→ 用当前 RunState 兜底，绝不崩。
	_data = RunState.run_summary.duplicate(true)
	if _data.is_empty():
		_data = {
			"class": RunState.player_class,
			"difficulty": RunState.difficulty,
			"layer": RunState.current_layer,
			"damage": RunState.total_damage,
			"seconds": RunRecord.peek_elapsed(),
			"battles": RunState.total_battle_wins,
			"elites": RunState.total_elite_wins,
		}


func _build_rows() -> void:
	## 五行的文字口径。数字行（`num >= 0`）走滚动，文本行直接显示。
	var cid := str(_data.get("class", PlayerClass.default_id()))
	_rows = [
		{"label": "使用角色", "text": PlayerClass.name_of(cid), "num": -1, "suffix": ""},
		{"label": "造成伤害", "text": "", "num": int(_data.get("damage", 0)), "suffix": ""},
		{"label": "花费时间", "text": _fmt_time(int(_data.get("seconds", 0))), "num": -1, "suffix": ""},
		{"label": "战斗胜利", "text": "", "num": int(_data.get("battles", 0)), "suffix": " 场"},
		{"label": "精英胜利", "text": "", "num": int(_data.get("elites", 0)), "suffix": " 场"},
	]


func _process(delta: float) -> void:
	_t += delta
	_hover_btn = _btn_rect().has_point(get_local_mouse_position()) and _btn_visible()
	queue_redraw()


# ---------------------------------------------------------------- 几何

func _panel_rect() -> Rect2:
	## 主框：居中 720×528（1280×720 舞台里上下各留 96）。
	return Rect2(Vector2((UiTheme.STAGE_W - 720.0) * 0.5, 96.0), Vector2(720.0, 528.0))


func _row_y(i: int) -> float:
	## 第 i 行的**基线** y。
	return _panel_rect().position.y + 178.0 + i * 56.0


func _btn_rect() -> Rect2:
	var pr := _panel_rect()
	return Rect2(pr.position.x + (pr.size.x - 232.0) * 0.5, pr.end.y - 92.0, 232.0, 52.0)


# ---------------------------------------------------------------- 动画时间轴

func _row_ease(i: int) -> float:
	## 第 i 行此刻的出场进度（0~1，缓出）。标题算第 -1 行。
	var t0: float = HEAD_DELAY + i * ROW_DELAY
	if i < 0:
		t0 = 0.0
	var a: float = clampf((_t - t0) / ROW_FADE, 0.0, 1.0)
	return 1.0 - pow(1.0 - a, 3.0)


func _btn_ease() -> float:
	## 按钮在最后一行之后出现（同一条缓动曲线）。
	var t0: float = HEAD_DELAY + _rows.size() * ROW_DELAY + BTN_DELAY
	var a: float = clampf((_t - t0) / ROW_FADE, 0.0, 1.0)
	return 1.0 - pow(1.0 - a, 3.0)


func _btn_visible() -> bool:
	return _btn_ease() >= 0.999


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	var vs := UiTheme.bleed_rect(self)
	UiTheme.draw_panel_bg(self, vs)
	_draw_vignette(vs)

	var pr := _panel_rect()
	_paper_panel(pr)
	_draw_head(pr)
	_draw_rows(pr)
	_draw_button()


func _paper_panel(r: Rect2) -> void:
	## 奶油纸面 + 细金边 + 内白边。与奖励页 `_paper_panel()` 同一套语言
	## （那边的实现在 `reward_panel.gd`，本页不共享代码，只共享视觉）。
	_round_box(r, 26.0, PAPER, GOLD_LINE, true)
	_round_box(r.grow(-6.0), 21.0, Color(1, 1, 1, 0), INNER_LINE, false)
	_draw_paper_motif(r)


func _round_box(r: Rect2, radius: float, bg: Color, line: Color, shadow := true) -> void:
	## 圆角底 —— 走 StyleBoxFlat（手画多边形圆角在屏幕上看得出毛边）。
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	if line.a > 0.0:
		sb.set_border_width_all(1)
		sb.border_color = line
	if shadow:
		sb.shadow_color = Color(0.18, 0.13, 0.05, 0.18)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, r)


func _draw_paper_motif(r: Rect2) -> void:
	## 极淡斜纹（纸纤维感）。透明度压在 0.07 —— 高于 0.25 会开始抢文字。
	var inner := r.grow(-30.0)
	var step := 26.0
	var a := Color(GOLD_LINE.r, GOLD_LINE.g, GOLD_LINE.b, 0.07)
	var n: int = int((inner.size.x + inner.size.y) / step) + 1
	for i in n:
		var off := i * step
		if off <= inner.size.y:
			draw_line(inner.position + Vector2(off, 0),
					inner.position + Vector2(off, inner.size.y), a, 1.0, true)


func _draw_head(pr: Rect2) -> void:
	## 标题 + 副标题（层 · 难度）+ 一条金饰线。整块比第一行早 0.06s 浮现。
	var e := _row_ease(-1)
	var a := e
	var cx := pr.get_center().x
	var ty := pr.position.y + 78.0 - (1.0 - e) * 8.0
	# R543（用户口径）：标题按结局区分 —— 凑齐信物并通关第三层 =「胜利」；
	# 未凑齐信物、打通第二层就进入结算 =「胜利？」。
	# 判据 = 结算快照里的 `layer`：真通关必然停在第三层（LAYER_THREE）。
	# R551（用户口径「失败也进这张结算页」）：快照带 `result: "lose"` 时显示「失败」。
	var title := "胜  利"
	if str(_data.get("result", "")) == "lose":
		title = "失  败"
	elif int(_data.get("layer", GameLayers.LAYER_THREE)) != GameLayers.LAYER_THREE:
		title = "胜利？"
	draw_string(_font_bold, Vector2(pr.position.x, ty), title,
			HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_TITLE,
			Color(TITLE_COL.r, TITLE_COL.g, TITLE_COL.b, a))

	# 副标题：第三层 · 噩梦
	var lay := int(_data.get("layer", GameLayers.LAYER_THREE))
	var diff := clampi(int(_data.get("difficulty", 0)), 0, RunState.DIFFICULTY_COUNT - 1)
	var sub := "%s · %s" % [GameLayers.layer_name(lay), RunState.DIFFICULTY_NAMES[diff]]
	draw_string(_font, Vector2(pr.position.x, pr.position.y + 110.0),
			sub, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_LABEL,
			Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, a * 0.95))

	# 金饰线：细线 + 中央菱形（奖励页 `_draw_ornament()` 的同族语言，这里压扁成一条）
	var ly := pr.position.y + 132.0
	var col := Color(GOLD_LINE.r, GOLD_LINE.g, GOLD_LINE.b, a * 0.75)
	var half := 190.0
	draw_line(Vector2(cx - half, ly), Vector2(cx - 14.0, ly), col, 1.2, true)
	draw_line(Vector2(cx + 14.0, ly), Vector2(cx + half, ly), col, 1.2, true)
	var d := 7.0
	draw_colored_polygon(PackedVector2Array([
			Vector2(cx, ly - d), Vector2(cx + d * 0.72, ly),
			Vector2(cx, ly + d), Vector2(cx - d * 0.72, ly)]),
			Color(col.r, col.g, col.b, a * 0.9))


func _draw_rows(pr: Rect2) -> void:
	var lx := pr.position.x + 72.0
	var rw := pr.size.x - 144.0
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var e := _row_ease(i)
		if e <= 0.0:
			continue
		var a := e
		var dy := (1.0 - e) * 10.0          # 上浮 10px
		var y := _row_y(i) - dy

		# 行标签（左）
		draw_string(_font, Vector2(lx, y), str(row["label"]),
				HORIZONTAL_ALIGNMENT_LEFT, rw * 0.5, UiTheme.FS_SUBHEAD,
				Color(TEXT.r, TEXT.g, TEXT.b, a * 0.92))

		# 值（右）
		var val := ""
		if int(row["num"]) >= 0:
			# 数字滚动：按同一条缓动从 0 走到目标值
			var shown: int = int(round(float(row["num"]) * e))
			val = _thousands(shown) + str(row["suffix"])
		else:
			val = str(row["text"])
		draw_string(_font_bold, Vector2(lx + rw * 0.5, y), val,
				HORIZONTAL_ALIGNMENT_RIGHT, rw * 0.5, UiTheme.FS_HEADING,
				Color(NUM_COL.r, NUM_COL.g, NUM_COL.b, a))

		# 左右之间的**引导点线**：从标签末尾拉到数值开头。
		# 右端按「目标值」的宽度算（不是滚动中的当前值）—— 否则数字滚动的每一帧
		# 宽度都在变，点线会像呼吸一样来回抽动。
		var lw := _font.get_string_size(str(row["label"]), HORIZONTAL_ALIGNMENT_LEFT,
				-1, UiTheme.FS_SUBHEAD).x
		var final_text := ""
		if int(row["num"]) >= 0:
			final_text = _thousands(int(row["num"])) + str(row["suffix"])
		else:
			final_text = str(row["text"])
		var vw := _font_bold.get_string_size(final_text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, UiTheme.FS_HEADING).x
		_draw_leader(Vector2(lx + lw + 14.0, y - 6.0),
				Vector2(lx + rw - vw - 14.0, y - 6.0), a)

		# 行底淡金分隔线（最后一行不画）
		if i < _rows.size() - 1:
			var ly := y + 18.0
			draw_line(Vector2(lx, ly), Vector2(lx + rw, ly),
					Color(GOLD_LINE.r, GOLD_LINE.g, GOLD_LINE.b, a * 0.22), 1.0, true)


func _draw_leader(p0: Vector2, p1: Vector2, a: float) -> void:
	## 点线：3px 短划 + 6px 间隔。只在两端都有富余时画（窄屏 / 长文本时不画，
	## 免得点线从文字里穿过去）。
	if p1.x - p0.x < 24.0:
		return
	var col := Color(GOLD_LINE.r, GOLD_LINE.g, GOLD_LINE.b, 0.40 * a)
	var x := p0.x
	while x < p1.x:
		draw_line(Vector2(x, p0.y), Vector2(minf(x + 3.0, p1.x), p0.y), col, 1.0, true)
		x += 9.0


func _draw_button() -> void:
	var e := _btn_ease()
	if e <= 0.0:
		return
	var r := _btn_rect()
	var dy := (1.0 - e) * 8.0
	r.position.y += dy
	var bg := BTN_GREEN.lightened(0.08) if _hover_btn and e >= 0.999 else BTN_GREEN
	_round_box(r, r.size.y * 0.5, bg, BTN_GREEN_LINE, true)
	# 顶部高光（胶囊按钮的固定装饰，与奖励页主按钮一致）
	draw_line(Vector2(r.position.x + r.size.y * 0.48, r.position.y + 3.0),
			Vector2(r.end.x - r.size.y * 0.48, r.position.y + 3.0),
			Color(1, 1, 1, 0.30 * e), 1.2, true)
	draw_string(_font_bold, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 9.0),
			"确 定", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_SUBHEAD,
			Color(1, 1, 1, e))


func _draw_vignette(vs: Rect2) -> void:
	## 四边三层递减透明的暗角（奖励页 R505 同款）。透明度低，不压任何文字。
	var base := Color(0.55, 0.42, 0.26)
	var bw := vs.size.x * 0.20
	var bh := vs.size.y * 0.18
	for k in 3:
		var col := Color(base.r, base.g, base.b, 0.06 * (1.0 - k * 0.28))
		var w := bw * (1.0 - k * 0.30)
		var h := bh * (1.0 - k * 0.30)
		draw_rect(Rect2(vs.position.x, vs.position.y, vs.size.x, h), col, true)
		draw_rect(Rect2(vs.position.x, vs.position.y + vs.size.y - h, vs.size.x, h), col, true)
		draw_rect(Rect2(vs.position.x, vs.position.y, w, vs.size.y), col, true)
		draw_rect(Rect2(vs.position.x + vs.size.x - w, vs.position.y, w, vs.size.y), col, true)


# ---------------------------------------------------------------- 交互

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_visible() and _btn_rect().has_point(event.position):
			_on_confirm()


func _unhandled_key_input(event: InputEvent) -> void:
	## Esc / Enter / 空格 都能离开（按钮出现之后才认，免得连击把动画跳掉）。
	if not _btn_visible() or _leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_on_confirm()


func _on_confirm() -> void:
	## 出口与 `battle_scene._on_over_restart()` 的收尾分支同形：
	## 还欠着「要选卡」的待办（鸭血 / 源数 / 失忆）→ 先去那个场景，办完它自己回标题；
	## 否则真的结束这一局（清内存 + 删续档）再回标题。
	if _leaving:
		return
	_leaving = true
	sfx.play("click")
	if RunState.run_finished:
		var tgt := RewardPanel.route_target_after_pick()
		if tgt != "":
			_goto(tgt)
			return
		RunState.end_run()
	_goto("res://scenes/title.tscn")


func _goto(path: String) -> void:
	## 切场景的唯一收口（烟测里用 `route_fn` 截获目标）。
	if route_fn.is_valid():
		route_fn.call(path)
	else:
		SceneFx.goto(path)


# ---------------------------------------------------------------- 文案格式化

static func _thousands(n: int) -> String:
	## 12345 → 12,345（结算数字要好读，用户没要求但纸面上长数字不分组很难扫）。
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + out


static func _fmt_time(secs: int) -> String:
	## 秒 →「1 小时 23 分」/「23 分 05 秒」/「45 秒」。
	## 只算实际游戏时间：`RunRecord.peek_elapsed()` 把「关掉游戏」的那段排除在外。
	var s := maxi(0, secs)
	if s < 60:
		return "%d 秒" % s
	var m := s / 60
	var r := s % 60
	if m < 60:
		return "%d 分 %02d 秒" % [m, r]
	var h := m / 60
	m = m % 60
	return "%d 小时 %02d 分" % [h, m]
