extends Control
## 角色选择（R166 改版）—— 不再摆三张大卡，而是：
##   ① 一排在底部的**头像**（只有头，占面积小）；
##   ② 点某个头像 → **背景换成该职业的 CG**（16:9 整屏），
##      左侧一块**不遮挡 CG 人物**的面板放：职业名 / 副标题 / 介绍 / **难度档位**；
##   ③ 点「确认进入」才开局。
## 难度不再在标题页选（R166 起挪到这里，与职业一起在开局前定好）。
## 角色决定两件事（见 PlayerClass）：初始卡组专属卡 + 战斗赠品道具。

const UiTheme = preload("res://scripts/ui_theme.gd")

const AV := 88.0                       # 头像边长（小，别占太多面积）
const AV_GAP := 16.0
# R519b（用户口径「选人物界面新增一个随机」）：头像行右端一枚「随机」，点一下换一个职业。
# ⚠️ 只**选中**不直接开局 —— 玩家还得看一眼 CG 和难度档位；连点会一直换人，不会卡住不动。
# R519c（用户口径「随机不能只做按钮，再生成一个黑底的"？"图标」）：从横条改成
# **与头像同构的方块**（边长 = AV + 黑底问号图标 + 同名牌），一眼就知道是「换人」而不是某项设置。
# R545（用户口径「随机不要立即看到选了什么」）：随机改成**盲选** —— 点随机只摇不显示，
# 点「确认进入」才揭晓随到谁并开局（点具体头像 = 取消盲选）。
const RAND_W := 88.0
const RAND_H := 88.0
const RAND_GAP := 10.0
const ROW_PAD := 20.0          # 头像行与左右两栏之间的最小间隙
const PANEL_W := 416.0
# R223：难度档位从「三个固定按钮」改成「左箭头 / 档位盒 / 右箭头」一行（0~10 共 11 档，
# 钳制不循环）。下面那条 debuff 文本随之变宽变高。
# R224：文本口径改成「只写当前档新增」（用户口径），通常一行就够；行数预算仍按 3 行留。
const DIFF_ARROW_W := 44.0     # 箭头按钮宽
const DIFF_ROW_H := 38.0       # 档位行高
const DIFF_GAP := 8.0          # 箭头与档位盒的间距
const DIFF_ROW_W := 272.0      # 整组收窄并居中，箭头不压面板边框
const NOTE_LINES := 3          # 当前档新增 debuff 文本行数预算（FS_CAPTION 12px / 行距 14）
const NOTE_LH := 14.0
const SUM_LINES := 2           # 数值摘要行数预算（FS_MICRO 10px / 行距 12）
const SUM_LH := 12.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null      # Esc 主菜单（R148）
var _hover := -1              # 悬停的头像下标
var _selected := -1           # 已选职业下标（_ready 里默认置 0 = 第一角色；-1 仅作初值）
var _picked := false
var _rand_hover := false      # R519b：「随机」钮的悬停态（自绘按钮，得自己跟）
var _rand_pending := false    # R545：盲选已摇，结果待「确认进入」才揭晓
var _rand_pick := -1          # R545：盲选摇中的职业下标（揭晓前不显示）
var _seed_edit: LineEdit = null   # R261：种子输入框（唯一的原生控件，手机点它弹软键盘）
var _seed_guard := false          # 防止 text_changed 里改 text 触发二次回调
var _seed_bad := false            # 输入的种子不合法（红框 + 提示；不静默换成随机）
## R346：上次选中的角色下标 —— 从「禁卡表」回来时**恢复**原来的选择。
## 这个界面每次进都重建，不留一份就会「去禁个卡，回来角色变回第一个」。
static var last_selected := 0


func _ready() -> void:
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
	UiTheme.stretch_topbar($TopBar)   # R519b：顶栏通屏宽，右侧按钮组贴窗口右缘
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	# R176：角色选择 BGM（Piano_Refreshing）—— 与标题同曲系，进选人不断氛围。
	Bgm.play("class_pick")
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	_build_seed_edit()   # R261：种子输入框（设置页的「下一局种子」会预填进来）
	# -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("screenshot_class_pick.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# 出图核验用：`-- --screenshot --sel N` 预选第 N 个职业（看 CG + 面板态）。
	# 默认选中第一个角色（R167：进入即选中，不再「默认不选」）。
	_selected = 0
	var uargs := OS.get_cmdline_user_args()
	for ai in uargs.size():
		if uargs[ai] == "--sel" and ai + 1 < uargs.size():
			_selected = clampi(int(uargs[ai + 1]), 0, PlayerClass.ids().size() - 1)
	# R346：从禁卡表回来 → 恢复上次选的角色（`--sel` 显式指定时以它为准）
	if uargs.find("--sel") < 0:
		_selected = clampi(last_selected, 0, PlayerClass.ids().size() - 1)
	# R223：`-- --screenshot --diff N` 预选难度档位（0~10，看累计 debuff 文本的换行情况）。
	for ai in uargs.size():
		if uargs[ai] == "--diff" and ai + 1 < uargs.size():
			RunState.set_difficulty(int(uargs[ai + 1]))
	queue_redraw()
	# R148：Esc 主菜单
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续选角色",
		"sub": "选择角色",
	})


# ──────────────────────────────────────────────────────────────
# 几何（绘制与命中**同源**，改版式只改这里）
# ──────────────────────────────────────────────────────────────

func _av_row_w() -> float:
	## 头像行 + 右端「随机」的**整体**宽度。居中要按整组算，否则加了个按钮头像就偏左。
	var n := PlayerClass.ids().size()
	return n * AV + maxi(0, n - 1) * AV_GAP + RAND_GAP + RAND_W


func _av_row_x0() -> float:
	## R519c：头像行**不能按窗口居中**。
	## 加「随机」之后整组变宽、居中点左移 53px，第一枚头像连同名牌就压进了左侧详情面板
	## （实测重叠 43×66，用户报的「人物图标重叠在左侧详情上」就是这个）。
	## 改成在「详情面板右缘 → 右列（禁卡表 / 随机种子）左缘」这段**空档**里居中 ——
	## 空档是按面板矩形算出来的，将来面板变宽变窄也不会再撞。
	var l := _panel_rect().end.x + ROW_PAD
	var r := _seed_panel_rect().position.x - ROW_PAD
	var w := _av_row_w()
	if r - l <= w:
		# 空档塞不下（更窄的屏 / 将来加职业）→ 贴左界，宁可右侧紧一点也不压面板
		return l
	return l + (r - l - w) * 0.5


func _av_rect(i: int) -> Rect2:
	var x0 := _av_row_x0()
	return Rect2(x0 + i * (AV + AV_GAP), size.y - AV - 64.0, AV, AV)


func _rand_rect() -> Rect2:
	## R519c：紧跟在最后一个头像右边，**与头像同一水平线**（等高，做成同构方块）。
	var last := _av_rect(PlayerClass.ids().size() - 1)
	return Rect2(last.end.x + RAND_GAP, last.position.y, RAND_W, RAND_H)


func _panel_rect() -> Rect2:
	# R223：底边从 size.y-214 改为 -190（给难度档位块让出空间）；
	# 头像行顶边 = size.y-160，靠这 30px 缝隙分开。
	return Rect2(40.0, 96.0, PANEL_W, size.y - 190.0)


# 难度档位行：左箭头 / 档位盒 / 右箭头（R223，原来是三按钮 _diff_rect(i)）。
# 从面板底边往上排：确认钮(54) -8- 摘要(SUM) -2- 累计文本(NOTE) -6- 档位行(38)。
func _diff_row_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.get_center().x - DIFF_ROW_W * 0.5, p.end.y - 154.0 - DIFF_ROW_H,
			DIFF_ROW_W, DIFF_ROW_H)


func _diff_left_rect() -> Rect2:
	var r := _diff_row_rect()
	return Rect2(r.position.x, r.position.y, DIFF_ARROW_W, DIFF_ROW_H)


func _diff_right_rect() -> Rect2:
	var r := _diff_row_rect()
	return Rect2(r.end.x - DIFF_ARROW_W, r.position.y, DIFF_ARROW_W, DIFF_ROW_H)


func _diff_box_rect() -> Rect2:
	var r := _diff_row_rect()
	return Rect2(r.position.x + DIFF_ARROW_W + DIFF_GAP, r.position.y,
			r.size.x - 2.0 * (DIFF_ARROW_W + DIFF_GAP), DIFF_ROW_H)


func _note_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 106.0 - NOTE_LINES * NOTE_LH,
			PANEL_W - 40.0, NOTE_LINES * NOTE_LH)


func _summary_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 80.0 - SUM_LINES * SUM_LH,
			PANEL_W - 40.0, SUM_LINES * SUM_LH)


func _confirm_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 72.0, PANEL_W - 40.0, 54.0)


func _seed_panel_rect() -> Rect2:
	## R261：种子面板摆在右下角 —— CG 人物一般在中左、头像行在底部居中，
	## 这一块既不挡角色也不压头像（右上角是道具 / 牌库查看器）。
	return Rect2(size.x - 356.0, size.y - 236.0, 316.0, 150.0)


func _seed_edit_rect() -> Rect2:
	var p := _seed_panel_rect()
	return Rect2(p.position.x + 18.0, p.position.y + 40.0, p.size.x - 36.0, 34.0)


func _ban_rect() -> Rect2:
	## R346：禁卡表入口 —— 摆在种子面板正上方（同一列、同宽），不挡 CG 也不压头像行。
	var p := _seed_panel_rect()
	return Rect2(p.position.x, p.position.y - 48.0, p.size.x, 36.0)


func _build_seed_edit() -> void:
	## 原生 LineEdit（手机上点它才会弹软键盘）—— 样式与设置页的种子框同一套。
	GameSettings.ensure_loaded()
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "留空 = 每局随机"
	_seed_edit.max_length = RunState.SEED_LEN
	_seed_edit.text = GameSettings.next_seed_code
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.ADVENTURE_INPUT
	sb.border_color = UiTheme.ADVENTURE_BRASS
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	_seed_edit.add_theme_stylebox_override("normal", sb)
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = UiTheme.PAGE_PAPER
	sbf.border_color = UiTheme.ADVENTURE_BRASS_LIT
	sbf.set_border_width_all(1)
	sbf.set_corner_radius_all(4)
	sbf.content_margin_left = 8.0
	sbf.content_margin_right = 8.0
	_seed_edit.add_theme_stylebox_override("focus", sbf)
	_seed_edit.add_theme_font_override("font", _font)
	_seed_edit.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	_seed_edit.add_theme_color_override("font_color", UiTheme.PAGE_INK)
	_seed_edit.add_theme_color_override("caret_color", UiTheme.SAND)
	_seed_edit.add_theme_color_override("placeholder_color", Color("7d8590"))
	_seed_edit.text_changed.connect(_on_seed_changed)
	add_child(_seed_edit)
	_sync_seed_edit()
	resized.connect(_sync_seed_edit)


func _draw_ban_button() -> void:
	## R346：禁卡表按钮（额度 / 已禁张数直接写在按钮上，不用进去才知道有没有名额）。
	var r := _ban_rect()
	var repo := CardRepo.load_json()
	# R352：禁卡按职业分页记账 → 按钮上显示三个职业的**合计**（一行放不下三行）。
	var quota := ProfileData.ban_total_quota_all(repo)
	var used: int = ProfileData.ban_total_used_all()
	var hov := r.has_point(get_local_mouse_position())
	var bg := Color(0.10, 0.11, 0.15, 0.86) if not hov else Color(0.16, 0.18, 0.24, 0.92)
	UiTheme.draw_action(self, r, false, false, hov)
	draw_rect(r, UiTheme.ADVENTURE_BRASS_LIT if hov else Color(1, 1, 1, 0.22), false, 1.4)
	var label := "禁卡表 · 已禁 %d / 名额 %d" % [used, quota]
	var col := UiTheme.PAGE_INK if quota > 0 else Color("9a968c")
	draw_string(_font_bold, Vector2(r.position.x, r.position.y + 24.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL, col)


func _sync_seed_edit() -> void:
	if _seed_edit == null:
		return
	var r := _seed_edit_rect()
	_seed_edit.position = r.position
	_seed_edit.size = r.size


func _on_seed_changed(txt: String) -> void:
	## 只收 A-Z / 0-9（小写自动转大写）；其余字符当场剃掉。
	if _seed_guard:
		return
	var code := ""
	for i in txt.length():
		var ch := txt[i].to_upper()
		if RunState.SEED_ALPHABET.find(ch) >= 0:
			code += ch
	if code != txt:
		_seed_guard = true
		_seed_edit.text = code
		_seed_edit.caret_column = code.length()
		_seed_guard = false
	_seed_bad = false
	queue_redraw()


func _draw_seed_panel() -> void:
	_draw_ban_button()
	var p := _seed_panel_rect()
	UiTheme.draw_info_card(self, p)
	draw_rect(p, Color("b4523f") if _seed_bad else Color(1, 1, 1, 0.22), false, 1.6)
	draw_string(_font_bold, p.position + Vector2(18, 26), "随机种子",
			HORIZONTAL_ALIGNMENT_LEFT, 200, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	draw_string(_font, p.position + Vector2(18, 96), "留空 = 每局随机",
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 36.0, UiTheme.FS_CAPTION, Color("9a968c"))
	var hint2 := "或填 10 位（A-Z / 0-9）复现同一局"
	var hint_col := Color("7d8590")
	if _seed_bad:
		hint2 = "种子需 10 位：大写字母 / 数字"
		hint_col = Color("e07a6a")
	draw_string(_font, p.position + Vector2(18, 116), hint2,
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 36.0, UiTheme.FS_CAPTION, hint_col)


# ──────────────────────────────────────────────────────────────

func _draw() -> void:
	# R519：UI（面板/头像/种子）留在居中的 1280 舞台里；**CG 铺满整个窗口**
	# 并用「顶部优先」的 cover —— 屏一宽，纵向能留的高度就少，居中裁会先削掉头顶。
	var bleed := UiTheme.bleed_rect(self)
	var full := Rect2(Vector2.ZERO, size)
	if _rand_pending:
		# R545：盲选态 —— 不揭晓结果，中性背景 + 带难度/确认的「?」面板
		UiTheme.draw_page(self, bleed)
		_draw_pending_panel()
		_draw_seed_panel()
	elif _selected < 0:
		UiTheme.draw_page(self, bleed)
		draw_string(_font, Vector2(0, 288), "选择与你同行的精灵……",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_TITLE, UiTheme.PAGE_INK)
		draw_string(_font, Vector2(0, 330), "点头像查看该角色，再选难度、确认进入",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
	else:
		var cid := PlayerClass.ids()[_selected]
		var cg := UiAssets.class_cg(cid)
		if cg != null:
			draw_texture_rect_region(cg, bleed,
					CardFace.cover_region_top(cg.get_size(), bleed), Color.WHITE)
		else:
			UiTheme.draw_page(self, bleed)
		_draw_panel(cid)
		_draw_seed_panel()
	for i in PlayerClass.ids().size():
		_draw_avatar(i)
	_draw_rand_button()


func _draw_rand_button() -> void:
	## R519b（用户口径：「选人物界面新增一个随机」）。
	## 只把 `_selected` 换成别人，**不**直接开局 —— 随机到谁还得让人看一眼 CG 和难度；
	## 想开局仍然是「确认进入」那一下，行为上没有第二条路径。
	## R519c（用户口径：「随机不能只做按钮，再生成一个黑底的"？"图标」）：
	## 外观做成**与头像同构** —— 同样大小的方块（黑底问号图标）+ 同样式的下方名牌。
	## 这样「随机」不再是一枚光秃秃的按钮，而是头像行里的第四个「选项」。
	var r := _rand_rect()
	var hov := _rand_hover
	UiTheme.draw_info_card(self, r)
	var tex := UiAssets.get_tex("icon_random")
	if tex != null:
		# 图标自带黑底 + 金边，内缩 4px 让纸面卡框露出来一圈
		draw_texture_rect(tex, r.grow(-4.0), false)
	else:
		# 缺图回退：代码画同款黑底方块 + 居中问号（不空白、不报错）
		var body := r.grow(-4.0)
		draw_rect(body, Color("0d0d10"), true)
		draw_rect(body, UiTheme.ADVENTURE_BRASS, false, 1.5)
		draw_string(_font_bold, Vector2(body.position.x, body.position.y + body.size.y * 0.5 + 26.0),
				"?", HORIZONTAL_ALIGNMENT_CENTER, body.size.x, UiTheme.FS_TITLE,
				UiTheme.ADVENTURE_LIGHT)
	# ⚠️ 外框用黄铜色而不是「当前职业色」：_selected 可能还是 -1（未选），
	#    取 class_color(ids()[-1]) 会越界。这枚本来也不属于任何职业。
	draw_rect(r, UiTheme.ADVENTURE_BRASS_LIT if (hov or _rand_pending) else Color(1, 1, 1, 0.25), false, 2.0)
	if hov:
		draw_rect(r.grow(3.0), Color(1, 1, 1, 0.55), false, 2.0)
	# 名牌：与头像下方那套同一尺寸 / 同一字体，读起来是一行东西
	var np := Rect2(r.position.x - 4.0, r.end.y + 4.0, r.size.x + 8.0, 48.0)
	UiTheme.draw_info_card(self, np)
	draw_string(_font_bold, Vector2(np.position.x, np.position.y + 22.0), "随机",
			HORIZONTAL_ALIGNMENT_CENTER, np.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(np.position.x, np.position.y + 41.0), "已随机" if _rand_pending else "换一个",
			HORIZONTAL_ALIGNMENT_CENTER, np.size.x, UiTheme.FS_CAPTION, Color("9a968c"))


func _roll_random() -> void:
	## R545（用户口径「随机不要立即看到选了什么」）：随机结果**先藏起来**，
	## 直到点「确认进入」才揭晓并开局。所以这里只摇、只记，不改 `_selected`、
	## 不换 CG —— 面板与头像行都保持在盲选态（`_rand_pending`）。
	var n := PlayerClass.ids().size()
	if n <= 0:
		return
	_rand_pick = randi() % n
	_rand_pending = true
	sfx.play("click")
	queue_redraw()


func _draw_avatar(i: int) -> void:
	var cid := PlayerClass.ids()[i]
	var r := _av_rect(i)
	var sel := i == _selected and not _rand_pending   # R545：盲选态不标任何头像
	var cc: Color = UiTheme.class_color(cid)
	UiTheme.draw_info_card(self, r)
	var tex := UiAssets.class_avatar(cid)
	if tex != null:
		var fr := CardFace.fit_rect(tex.get_size(), r.grow(-6.0))
		draw_texture_rect(tex, fr, false)
	else:
		# 缺图回退：职业圆徽（再缺则只留框）
		var badge := UiAssets.class_badge(cid)
		if badge != null:
			draw_texture_rect(badge, r.grow(-8.0), false)
	draw_rect(r, cc if sel else Color(1, 1, 1, 0.25), false, 4.0 if sel else 2.0)
	if i == _hover and not sel:
		draw_rect(r.grow(3.0), Color(1, 1, 1, 0.55), false, 2.0)
	UiTheme.draw_info_card(self, Rect2(r.position.x - 4, r.end.y + 4, r.size.x + 8, 48))
	draw_string(_font_bold, Vector2(r.position.x, r.end.y + 24.0), PlayerClass.name_of(cid),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	# 初始最大生命（R182：选职业界面明示，便于对比）
	var hp_txt := "生命 %d" % PlayerClass.base_hp_of(cid)
	draw_string(_font, Vector2(r.position.x, r.end.y + 44.0), hp_txt,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_CAPTION,
			UiTheme.class_color(cid).lightened(0.35))


func _draw_panel(cid: String) -> void:
	var p := _panel_rect()
	UiTheme.draw_panel_bg(self, p)
	var x := p.position.x + 48.0
	var w := PANEL_W - 88.0
	var y := p.position.y + 46.0
	draw_string(_font_bold, Vector2(x, y), PlayerClass.name_of(cid),
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_TITLE, UiTheme.PAGE_INK)
	y += 30.0
	draw_string(_font, Vector2(x, y), PlayerClass.subtitle_of(cid),
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL,
			UiTheme.class_color(cid).darkened(0.15))
	y += 30.0
	# 初始最大生命（R182：按职业不同，选职业界面明示）
	y += 2.0
	draw_string(_font, Vector2(x, y), "初始最大生命",
			HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	draw_string(_font_bold, Vector2(x + w * 0.5, y), "%d" % PlayerClass.base_hp_of(cid),
			HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, UiTheme.FS_HEADING,
			UiTheme.class_color(cid).darkened(0.15))
	y += 26.0
	# 角色介绍（R223：字号降到 FS_CAPTION / 行距 17，给下面的难度档位块腾垂直空间）
	for para: String in PlayerClass.desc_of(cid).split("\n"):
		for line: String in _wrap_text(para, w, UiTheme.FS_CAPTION):
			draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, w,
					UiTheme.FS_CAPTION, UiTheme.PAGE_INK)
			y += 17.0
		y += 4.0
	_draw_difficulty_block(x, w)


func _draw_difficulty_block(x: float, w: float) -> void:
	## R545：从 _draw_panel 抽出的难度档位 + 摘要 + 确认钮（盲选面板与角色面板共用）。
	# 难度档位（R223：左箭头 / 档位盒 / 右箭头，0~10 共 11 档，钳制不循环）
	draw_string(_font_bold, Vector2(x, _diff_row_rect().position.y - 13.0), "难度档位",
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var d := clampi(RunState.difficulty, 0, RunState.DIFFICULTY_COUNT - 1)
	var lr := _diff_left_rect()
	var rr := _diff_right_rect()
	UiTheme.draw_action(self, lr, false, d == 0)
	UiTheme.draw_action(self, rr, false, d == RunState.DIFFICULTY_COUNT - 1)
	var arrow_on := UiTheme.PAGE_INK
	var arrow_off := Color("6b675f")
	draw_string(_font_bold, Vector2(lr.position.x, lr.position.y + 26.0), "<",
			HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, UiTheme.FS_HEADING,
			arrow_on if d > 0 else arrow_off)
	draw_string(_font_bold, Vector2(rr.position.x, rr.position.y + 26.0), ">",
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_HEADING,
			arrow_on if d < RunState.DIFFICULTY_COUNT - 1 else arrow_off)
	var br := _diff_box_rect()
	UiTheme.draw_info_card(self, br, true)
	# R543：难度 ≥ 11（第三层上锁）→ 难度框描边变橙色（美术风格不变，只换描边色）。
	var locked := d >= RunState.DIFF_LOCK_FROM
	if locked:
		var ob := StyleBoxFlat.new()
		ob.bg_color = Color(1, 0.5, 0.1, 0.0)
		ob.border_color = Color("e08a20")
		ob.set_border_width_all(2)
		ob.set_corner_radius_all(10)
		draw_style_box(ob, br)
	var number_box := Rect2(br.position + Vector2(4, 3), Vector2(42, br.size.y - 6))
	if locked:
		# R543：难度 ≥ 11 时数字框底整个换成橙色（原 `draw_action` 是森林绿底）。
		var nb := StyleBoxFlat.new()
		nb.bg_color = Color("c96a14")
		nb.border_color = Color("f0a336")
		nb.set_border_width_all(1)
		nb.set_corner_radius_all(6)
		draw_style_box(nb, number_box)
	else:
		UiTheme.draw_action(self, number_box, true)
	draw_string(_font_bold, Vector2(number_box.position.x, br.position.y + 26.0),
			str(d), HORIZONTAL_ALIGNMENT_CENTER, number_box.size.x,
			UiTheme.FS_HEADING, Color("fff3d5"))
	draw_string(_font_bold, Vector2(br.position.x + 52, br.position.y + 26.0),
			RunState.DIFFICULTY_NAMES[d], HORIZONTAL_ALIGNMENT_CENTER, br.size.x - 58,
			UiTheme.FS_SUBHEAD, Color("c9700f") if locked else UiTheme.PAGE_INK)
	# 当前档新增 debuff 文本（R224：只写当前档这一条；高档继承的低档 debuff
	# 由下面那行数值摘要体现 —— 摘要列的都是「实际生效」的数值）
	var ny := _note_rect().position.y + 11.0
	for line: String in _wrap_text(RunState.difficulty_note(), w, UiTheme.FS_CAPTION):
		draw_string(_font, Vector2(x, ny), line, HORIZONTAL_ALIGNMENT_LEFT, w,
				UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
		ny += NOTE_LH
	# 数值摘要（金钱 / 巧克力恒定显示，其余只在生效时列出）
	var sy := _summary_rect().position.y + 10.0
	for line: String in _wrap_text(RunState.difficulty_summary(), w, UiTheme.FS_MICRO):
		draw_string(_font, Vector2(x, sy), line, HORIZONTAL_ALIGNMENT_LEFT, w,
				UiTheme.FS_MICRO, UiTheme.PAGE_MUTED)
		sy += SUM_LH
	# 确认进入
	var cr := _confirm_rect()
	UiTheme.draw_action(self, cr, true)
	draw_string(_font_bold, Vector2(cr.position.x, cr.position.y + 37.0), "确认进入",
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_HEADING, UiTheme.ADVENTURE_LIGHT)


func _draw_pending_panel() -> void:
	## R545：盲选态面板 —— 职业名写「随机」，难度档位与确认照常（不揭晓具体角色）。
	var p := _panel_rect()
	UiTheme.draw_panel_bg(self, p)
	var x := p.position.x + 48.0
	var w := PANEL_W - 88.0
	var y := p.position.y + 46.0
	draw_string(_font_bold, Vector2(x, y), "随机",
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_TITLE, UiTheme.PAGE_INK)
	y += 30.0
	draw_string(_font, Vector2(x, y), "已随机 —— 确认进入后揭晓角色",
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	_draw_difficulty_block(x, w)


func _wrap_text(t: String, max_w: float, px: int) -> Array[String]:
	## 折行唯一口 = `TextWrap.wrap_plain`（R292）。
	return TextWrap.wrap_plain(_font, t, max_w, px)


func _menu_items() -> Array:
	## 本界面的 Esc 菜单项（R148）。每次打开都会重新调用，文案永远最新。
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	## 流程界面里直接回标题 = **放弃本局**（与战斗中「返回标题」同一口径）。
	if RunState.run_active:
		RunState.end_run()
	SceneFx.goto("res://scenes/title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return
	if _picked:
		return
	# R223：键盘 ←/→ 也能调难度档位（与点箭头同效果）
	if event is InputEventKey and event.pressed and _selected >= 0:
		match event.keycode:
			KEY_LEFT:
				RunState.set_difficulty(RunState.difficulty - 1)
				sfx.play("click")
				queue_redraw()
			KEY_RIGHT:
				RunState.set_difficulty(RunState.difficulty + 1)
				sfx.play("click")
				queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _picked:
		return
	if event is InputEventMouseMotion:
		var idx := -1
		for i in PlayerClass.ids().size():
			if _av_rect(i).grow(5.0).has_point(event.position):
				idx = i
		if idx != _hover:
			_hover = idx
			queue_redraw()   # R186：悬停变化才重绘（原来靠 _process 每帧重绘）
		# R519b：「随机」钮与头像行是两套命中，悬停态各记各的（头像没变也要重绘这一枚）。
		var rh := _rand_rect().grow(4.0).has_point(event.position)
		if rh != _rand_hover:
			_rand_hover = rh
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if _selected >= 0:
			if _confirm_rect().has_point(pos):
				_choose(PlayerClass.ids()[_selected])
				return
			if _ban_rect().has_point(pos):
				# R346：去禁卡表（账号级选择，回来还停在原来选的角色上）
				sfx.play("click")
				SceneFx.goto("res://scenes/ban.tscn")
				return
			if _diff_left_rect().has_point(pos) or _diff_right_rect().has_point(pos):
				var dir := -1 if _diff_left_rect().has_point(pos) else 1
				RunState.set_difficulty(RunState.difficulty + dir)
				sfx.play("click")
				queue_redraw()   # R186（原来靠 _process 每帧重绘）
				return
		for i in PlayerClass.ids().size():
			if _av_rect(i).grow(5.0).has_point(pos):
				_selected = i
				last_selected = i
				_rand_pending = false   # R545：点具体角色 = 取消盲选
				sfx.play("click")
				queue_redraw()   # R186（原来靠 _process 每帧重绘）
				return
		# R519b：「随机」钮 —— 放在头像循环之后判，两者不重叠所以顺序无所谓，
		# 但**必须在 `_selected >= 0` 那个块之外**：`_selected` 为 -1 时也要能点。
		if _rand_rect().grow(4.0).has_point(pos):
			_roll_random()
			return


func _choose(cid: String) -> void:
	sfx.play("click")
	# 角色决定：初始卡组追加的专属卡 + 战斗赠品道具（见 PlayerClass）。
	# 地图由 RunState.start_run 用本局种子生成（同一种子必然生成同一张图）。
	# R261：种子输入框优先（10 位 A-Z / 0-9）；留空 → 现摇一个。
	# 设置页的「下一局种子」会预填进这个框 —— 两条入口同一套口径。
	var code := ""
	if _seed_edit != null:
		code = _seed_edit.text.strip_edges().to_upper()
	if code != "" and RunState.seed_value_of(code) < 0:
		# 半截 / 含非法字符：**不开局**，红框提示。绝不静默改成随机 —— 玩家会以为复现了。
		_seed_bad = true
		queue_redraw()
		return
	# R545：盲选确认 —— 先揭晓随机结果，短暂停留后再开局
	if _rand_pending:
		_reveal_random(code)
		return
	_start_run(cid, code)


func _reveal_random(code: String) -> void:
	## R545：揭晓盲选结果。先把 CG / 面板换成随到的角色，0.6 秒后真正开局。
	_selected = clampi(_rand_pick, 0, PlayerClass.ids().size() - 1)
	last_selected = _selected
	_rand_pending = false
	_picked = true          # 揭晓瞬间锁定输入（防连点再摇）
	queue_redraw()
	var t := Timer.new()
	t.wait_time = 0.6
	t.one_shot = true
	t.timeout.connect(func(): _start_run(PlayerClass.ids()[_selected], code))
	add_child(t)
	t.start()


func _start_run(cid: String, code: String) -> void:
	_picked = true
	GameSettings.ensure_loaded()
	RunState.start_run([], GameLayers.LAYER_DEFAULT, cid, 0, code)
	# 指定种子**用一次就清空**：否则玩家会莫名其妙「每局地图都一样」。
	# 要再复现同一局，把记录详情里那 10 位码抄回来即可。
	if code != "":
		GameSettings.set_next_seed_code("")
	if _seed_edit != null:
		_seed_edit.text = ""
	RunRecord.begin_run(cid)   # 本局开始：对战记录从这里计时
	SceneFx.goto("res://scenes/map.tscn")
