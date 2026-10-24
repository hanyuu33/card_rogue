extends Control
## 禁卡表（R346）—— 开局前（角色选择页「禁卡表」）把不想要的卡从**奖励池**里永久摘掉。
##
## 规则（R352 用户口径，覆盖 R346 的扁平口径）：
##   「每获得一张卡，新增一个 ban 位（公用卡则是每个职业一个 ban 位），玩家可以在
##    ban 卡界面选择同等稀有度的卡，将其禁用，使其不会出现在奖励池。」
##   → 禁卡表**按职业记账**：一页一个职业，三个职业各自的名额与禁用互不相干。
##   → 额度按稀有度分档，算法唯一口 = `ProfileData.ban_quota_for(repo, 职业)`：
##       · 解锁一张**职业卡** → 该职业 +1 个该档名额；
##       · 解锁一张**公用卡**（class 为空）→ **三个职业各** +1 个该档名额
##         （它在三个职业的奖励池里都会出现，所以要 ban 三次）。
##   → 没有任何卡被剧情解锁时额度是 0，一行都禁不了 —— 这是**正确表现**，
##     不是 bug（界面会写明「暂时没有禁卡名额」）。
##
## ⚠️ **局内只认开局快照**（`RunState.run_bans`）：在这里改禁用**不影响**正在进行的这一局，
##    下一局开局时才生效（用户口径：「当前正在进行的战斗只遵照开始前设置的禁用」）。
##
## 禁卡是**账号级**选择（存 `ProfileData.banned_by_class`），可以随时取消。
## 禁掉的卡不会消失于这个列表（否则点一下就没了、再也点不回来）——
## 列表口径 = `CardRepo.obtainable_cards()`（奖励池的**去禁卡版**）。
##
## 出图参数：`-- --screenshot`（可加 `--demo`：在测试档案里解锁几张卡，看满额度态）

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_H := 40.0
const ROW_W := 980.0
const LIST_Y := 196.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _repo: CardRepo = null
var _cards: Array = []
var _hover := -1
var _scroll := 0
## R352：当前正在看的职业（禁卡表按职业分页）。
var _cls := ""
var _toast := ""
var _toast_t := 0.0
var _last_mp := Vector2.INF


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		ProfileData.set_test_mode()
		_demo_unlock()
	_repo = CardRepo.load_json()
	ProfileData.ensure_loaded()
	_cls = PlayerClass.ids()[0]
	# 出图用：`-- --cls rogue` 直接切到指定职业页签（验收三职业记账，R352）。
	var _ci := args.find("--cls")
	if _ci >= 0 and _ci + 1 < args.size() and PlayerClass.ids().has(str(args[_ci + 1])):
		_cls = str(args[_ci + 1])
	_refresh()
	# 出图用：`-- --banfirst` 先禁掉第一张点得动的卡（看在册禁用行的样子）。
	if "--banfirst" in args:
		for _bc: CardData in _cards:
			if ProfileData.can_ban_for(_bc.id, _repo, _cls):
				_toggle(_bc)
				break
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_ban.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "禁卡表",
	})


func _demo_unlock() -> void:
	## 出图用（只写测试档案，退出即丢）：**每个职业每档各 3 张** + 两张公用剧情卡。
	## R352 改口径：以前是「每档整体 3 张」，谁 id 小谁被解锁 → 三张图全是暗影的卡，
	## 另外两个页签名额是 0，验收「公用卡给三个职业各 +1」的效果根本看不到。
	var repo := CardRepo.load_json()
	var count := {}
	for c: CardData in repo.obtainable_cards():
		if c.card_class == "":
			continue            # 公用卡单独处理（要显式解锁剧情卡）
		var key := "%s|%d" % [c.card_class, c.rarity]
		if int(count.get(key, 0)) >= 3:
			continue
		ProfileData.unlock_card(c.id)
		count[key] = int(count.get(key, 0)) + 1
	ProfileData.unlock_card(9182)   # 摇篮曲：公用史诗
	ProfileData.unlock_card(9183)   # 森林的朋友们：公用稀有


func _menu_items() -> Array:
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": func(): return "清空「%s」的禁用" % _cls, "fn": _clear_all},
		{"text": "返回角色选择", "fn": _back},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _clear_all() -> void:
	ProfileData.clear_bans(_cls)
	sfx.play("click")
	_set_toast("已清空「%s」的禁用" % _cls)
	queue_redraw()


func _refresh() -> void:
	# 只列**这个职业拿得到**的卡：公用卡（class 为空）+ 该职业专属卡。
	_cards = []
	for c: CardData in _repo.obtainable_cards():
		if c.card_class != "" and c.card_class != _cls:
			continue
		_cards.append(c)
	# 按「稀有度 → id」排，同档挨在一起（普通 → 稀有 → 史诗），扫一眼就知道各档有多少可禁。
	_cards.sort_custom(func(a: CardData, b: CardData):
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.id < b.id)
	_scroll = 0
	queue_redraw()


# ------------------------------------------------------------ 几何

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + (i - _scroll) * ROW_H,
			ROW_W, ROW_H - 6.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 150, 34)


func _tab_rect(i: int) -> Rect2:
	## R352：三个职业的页签（禁卡表按职业分页）。
	var n := PlayerClass.ids().size()
	var w := 168.0
	var gap := 10.0
	var total := w * n + gap * (n - 1)
	var x0 := (size.x - total) / 2.0
	return Rect2(x0 + i * (w + gap), 110.0, w, 36.0)


func _max_rows() -> int:
	return maxi(1, int((size.y - LIST_Y - 30.0) / ROW_H))


func _row_at(pos: Vector2) -> int:
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _cards.size():
			break
		if _row_rect(idx).has_point(pos):
			return idx
	return -1


# ------------------------------------------------------------ 输入

func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _row_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back()
			return
		# R352：职业页签
		for ti in PlayerClass.ids().size():
			if _tab_rect(ti).has_point(event.position):
				var ids := PlayerClass.ids()
				if _cls != ids[ti]:
					_cls = ids[ti]
					sfx.play("click")
					_refresh()
				return
		var hit := _row_at(event.position)
		if hit >= 0:
			_toggle(_cards[hit])
			return
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		var step := 4 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -4
		var hi := maxi(0, _cards.size() - _max_rows())
		_scroll = clampi(_scroll + step, 0, hi)
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _toggle(c: CardData) -> void:
	## 点一下切禁 / 取消禁。**先看原来是什么状态**再调 toggle（toggle 的返回值是
	## 「操作之后是不是已禁」，但「本来已禁 → 取消成功」也返回 false，两者要分清）。
	var had: bool = ProfileData.is_banned_for(c.id, _cls)
	if had:
		ProfileData.toggle_ban_for(c.id, _repo, _cls)
		sfx.play("click")
		_set_toast("已取消：%s（仅「%s」）" % [c.card_name, _cls])
	else:
		if ProfileData.toggle_ban_for(c.id, _repo, _cls):
			sfx.play("attack")
			_set_toast("已禁：%s（「%s」的奖励池不再出现，下一局生效）" % [c.card_name, _cls])
		else:
			sfx.play("lose")
			_set_toast("「%s」这一档没有剩余名额（先通过剧情解锁更多卡牌）"
					% CardData.RARITY_NAMES[clampi(c.rarity, 0, 6)])
	queue_redraw()


func _set_toast(msg: String) -> void:
	_toast = msg
	_toast_t = 3.0
	queue_redraw()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t = maxf(0.0, _toast_t - delta)
		if _toast_t <= 0.0:
			_toast = ""
		queue_redraw()
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


func _back() -> void:
	SceneFx.goto("res://scenes/class_pick.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	var top := Color("191b23")
	var bottom := Color("2d3140")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 62), "禁 卡 表", HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	draw_string(_font, Vector2(0, 92),
			"禁卡表按职业分别记账：解锁一张职业卡 → 该职业 +1 名额；解锁一张公用卡 → 三个职业各 +1",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	# R352：三个职业页签
	var ids := PlayerClass.ids()
	for ti in ids.size():
		var tr := _tab_rect(ti)
		var cur := ids[ti] == _cls
		var hov := tr.has_point(get_local_mouse_position())
		var bg := Color("3d4762") if cur else (Color("2b3040") if hov else Color("22242c"))
		draw_rect(tr, bg, true)
		draw_rect(tr, Color("f0c860") if cur else Color("444a58"), false, 2.0 if cur else 1.4)
		var tot := ProfileData.ban_total_quota_for(_repo, ids[ti])
		var use := 0
		var br := ProfileData.banned_by_rarity_for(_repo, ids[ti])
		for rr in [0, 1, 2]:
			use += int(br.get(rr, 0))
		draw_string(_font_bold, tr.position + Vector2(0, 24),
				"%s  %d / %d" % [ids[ti], use, tot],
				HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, UiTheme.FS_LABEL,
				Color("f2ead0") if cur else Color("9aa0ad"))
	var quota := ProfileData.ban_total_quota_for(_repo, _cls)
	var summary := ProfileData.ban_summary_for(_repo, _cls)
	draw_string(_font_bold, Vector2(0, 172), summary,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY,
			Color("f0c860") if quota > 0 else Color("8a8f9c"))
	if quota == 0:
		draw_string(_font, Vector2(0, 190),
				"没有任何这个职业能用的禁卡名额 —— 剧情里解锁卡牌后才有（故事界面看完剧情才会有）",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION, Color("9aa0ad"))
	# 返回
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回角色选择",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	if _cards.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40), "奖励池是空的。",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
		return
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _cards.size():
			break
		_draw_row(idx, _cards[idx])
	if _cards.size() > _max_rows():
		draw_string(_font, Vector2(0, size.y - 12),
				"第 %d–%d 张 / 共 %d 张"
				% [_scroll + 1, mini(_scroll + _max_rows(), _cards.size()), _cards.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.INK_ON_DARK)
	if _toast != "":
		var tw := minf(size.x - 80.0, 760.0)
		var tr := Rect2((size.x - tw) / 2.0, size.y - 60.0, tw, 32.0)
		draw_rect(tr, Color(0.08, 0.09, 0.12, 0.92), true)
		draw_rect(tr, Color("c8951c"), false, 1.6)
		draw_string(_font_bold, tr.position + Vector2(0, 22), _toast,
				HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, UiTheme.FS_LABEL, Color("f2d99a"))


func _draw_row(idx: int, c: CardData) -> void:
	var r := _row_rect(idx)
	var banned: bool = ProfileData.is_banned_for(c.id, _cls)
	var hov := idx == _hover
	var bg := Color("22242c")
	if banned:
		bg = Color("3a2430")
	elif hov:
		bg = Color("2b3040")
	draw_rect(r, bg, true)
	draw_rect(r, Color("6a768c") if hov else Color("444a58"), false, 1.4)
	# 稀有度色条
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			CardData.RARITY_COLORS[clampi(c.rarity, 0, 6)], true)
	draw_string(_font, r.position + Vector2(18, 24),
			CardData.RARITY_NAMES[clampi(c.rarity, 0, 6)],
			HORIZONTAL_ALIGNMENT_LEFT, 60, UiTheme.FS_CAPTION,
			CardData.RARITY_COLORS[clampi(c.rarity, 0, 6)].lightened(0.45))
	draw_string(_font_bold, r.position + Vector2(84, 24), c.card_name,
			HORIZONTAL_ALIGNMENT_LEFT, 420, UiTheme.FS_BODY, Color("e8e4da"))
	draw_string(_font, r.position + Vector2(520, 24), c.kind,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, Color("9aa0ad"))
	draw_string(_font, r.position + Vector2(640, 24), "费用 %d" % c.cost,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, Color("8fb4d8"))
	var tag := "禁"
	var tcol := Color("b9ae8a")
	if banned:
		tag = "已禁"
		tcol = Color("ff8fa8")
	else:
		var quota := ProfileData.ban_quota_for(_repo, _cls)
		var used := ProfileData.banned_by_rarity_for(_repo, _cls)
		if int(used.get(c.rarity, 0)) >= int(quota.get(c.rarity, 0)):
			tag = "无名额"
			tcol = Color("6f7684")
	draw_string(_font_bold, r.position + Vector2(r.size.x - 120, 24), tag,
			HORIZONTAL_ALIGNMENT_RIGHT, 100, UiTheme.FS_BODY, tcol)
