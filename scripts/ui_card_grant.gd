extends CanvasLayer
## 卡牌入组演出唯一口（R474）—— 「这张卡进卡组了」要**看得见**，不能只弹一句轻提示。
##
## `UiCardGrant.grant(card_id, to_pos)`：一张**正面卡牌**从屏幕中部浮起 → 停住展示 →
## 缩成一张小卡收进 `to_pos`（调用方传卡组堆中心），落点炸一圈金色圆环 + 「+1」。
## 四段时间轴（ms）：RISE 220（浮起 + 淡入 + 放大）→ HOLD 460（停住，底部挂「已加入卡组」）
## → FLY 400（缩小飞向落点、后 55% 淡出）→ FLASH 180（落点圆环，不挡下一张）。
##
## 为什么做成 **CanvasLayer** 而不是画进 battle_scene：
##   胜利瞬间只要还有待领奖励，`_reward_panel.open()` 就会压在结算面板之上 ——
##   画在场景里的东西会被它整个盖住，那样等于没做。本层挂在 root 下，
##   天然盖在所有场景内 Control 之上（layer 98：在 UiToast 99 / SceneFx 100 之下）。
##   附带好处是**跨场景存活**：玩家秒点「返回地图」，卡照样飞完再消失。
##
## 美术纪律（规范 §3）：硬边色块、无辉光。金色在这里是**奖励语义**（`ACCENT_GOLD`），
## 所以这张卡带金框；落点圆环用 `ACCENT_LIT` 亮金。别给卡面加泛光 / 模糊。
##
## 队列串行：同一场同时到账两张（武术大师的两张单凑到一场时）一张接一张播；
## 后面还排着队时，当前这张的 HOLD 自动压到 `HOLD_FAST_MS`，不让人等两遍。
##
## 出图核验：`--grantdemo` 配 `--grantpin <ms>` 把时间轴钉在固定毫秒（与帧率无关）。
##
## ## ⚠️ 为什么**故意不写 `class_name`**
## 和 `ui_theme.gd` 同一个坑（R113 实测）：新增 `class_name` 后，headless 的 `--script`
## 与 `_verify.py` 会报 `Identifier "UiCardGrant" not declared` —— 全局类名存在
## `.godot/global_script_class_cache.cfg` 里，那份缓存只能由编辑器扫描重建，
## 而 CI / 回归是直接 headless 起的。调用方一律 `const UiCardGrant = preload(...)`。

## ⚠️ `UiTheme` 故意不写 `class_name`（见其文件头），全局类缓存里没有它 → 必须 preload。
const UiTheme = preload("res://scripts/ui_theme.gd")
const CardText = preload("res://scripts/card_text.gd")

const RISE_MS := 220
const HOLD_MS := 460
const HOLD_FAST_MS := 260      # 队列里还有下一张时 → 停留段压短
const FLY_MS := 400
const FLASH_MS := 180
const CARD_SIZE := Vector2(150.0, 181.0)   # 约手牌（63x76）的 2.4 倍：卡名与效果文字要能读
const CAP_FS := 15
const BODY_FS := 13
const BODY_MAX_LINES := 4
const PLUS_FS := 16
const GOLD := Color("c8951c")               # UiTheme.ACCENT_GOLD
const GOLD_LIT := Color("f2c14e")           # UiTheme.ACCENT_LIT
const CAP_BG := Color(0.05, 0.045, 0.04, 0.96)

## 出图用：>= 0 时四段时间轴一律按这个毫秒数画（真实时间不参与）。只在演示参数里设。
## 只经 `set_demo_pin()` 写 —— 调用方是 preload 得到的 Script，别直接赋静态变量。
static var demo_pin_ms := -1


static func set_demo_pin(ms: int) -> void:
	## 出图钉帧口。`ms < 0` = 恢复真实时间。
	demo_pin_ms = ms

static var _inst: CanvasLayer = null

var _q: Array = []          # 排队待播：{card, to, start}
var _cur: Dictionary = {}   # 正在播的那一张：{card, to, start, hold}
var _flash: Array = []      # 落点圆环：{pos, start}
var _cv: Control = null
var _font: Font = null
var _font_bold: Font = null


static func grant(card_id: int, to_pos := Vector2(-1.0, -1.0), lead_ms := 0) -> void:
	## 唯一入口。没有场景树（纯逻辑测试）时静默丢弃，不崩 —— 同 UiToast 的纪律。
	## `to_pos` 缺省（-1）→ 落在右下角；`lead_ms` 只对**空队列的第一张**生效
	## （胜利那一刻要让结算面板先 UiPop 进场，再让卡浮起来，不然两层一起动很糊）。
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var card: CardData = CardRepo.load_json().get_card(card_id)
	if card == null:
		return
	if _inst == null:
		_inst = load("res://scripts/ui_card_grant.gd").new()
		# ⚠️ **必须 deferred**：本函数经常在 battle_scene 的 `_ready()`（演示参数解析）里被调，
		# 那一刻 root 正在「setting up children」，直接 `add_child()` 会被拒
		#（`Parent node is busy setting up children, add_child() failed`）——
		# 节点进不了树 → `_process` 永不执行 → 整段演出静默消失，一个错都不报。
		# 绘制层先在实例内部建好（那一步 parent 不是 root，不受限制），整层再排队入树。
		_inst._ensure_ui()
		tree.root.add_child.call_deferred(_inst)
	_inst._push(card, to_pos, lead_ms)


func _ready() -> void:
	_ensure_ui()


func _ensure_ui() -> void:
	## 绘制层懒建。**不能只靠 `_ready()`**：从 `_ready()` 里 `add_child()` 出来的实例，
	## 下一层 `_ready()` 的触发时机不保证就在 `add_child()` 当帧 —— 实测 `UiCardGrant.grant()`
	## 紧接着调 `_push()` 时 `_cv` 还是 null（`Cannot call method 'queue_redraw' on a null value`）。
	## 两边都过这一道幂等口。
	if _cv != null:
		return
	layer = 98
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	_cv = Control.new()
	_cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cv.draw.connect(_on_draw)
	add_child(_cv)


func _push(card: CardData, to_pos: Vector2, lead_ms: int) -> void:
	# ⚠️ 入队时**不设 start**：同一场到账两张时，两张的「现在」是同一刻，
	# 而第一张要播满 RISE+HOLD+FLY 才轮到第二张 —— 若沿用入队时刻，第二张一出队
	# 就已经「超时」，会被 `_process` 当场判成播完（直接跳落点，等于没播）。
	# start 一律由 `_process` 出队那一刻定。
	var lead := maxi(lead_ms, 0) if (_cur.is_empty() and _q.is_empty()) else 0
	_q.append({"card": card, "to": to_pos, "lead": lead})
	_ensure_ui()
	_cv.queue_redraw()


func _process(_delta: float) -> void:
	var n := _now()
	_flash = _flash.filter(func(f): return n - int(f["start"]) < FLASH_MS)
	# 当前这张播完（以 FLY 结束为准，落点圆环不许挡下一张）→ 记圆环、让位。
	if not _cur.is_empty():
		var span := RISE_MS + int(_cur["hold"]) + FLY_MS
		if n - int(_cur["start"]) >= span:
			_flash.append({"pos": _cur["to"], "start": int(_cur["start"]) + span})
			_cur = {}
	if _cur.is_empty() and not _q.is_empty():
		_cur = _q.pop_front()
		_cur["hold"] = HOLD_FAST_MS if not _q.is_empty() else HOLD_MS
		# 出队这一刻才记 start。钉帧（出图）时基准归零 —— `_now()` 返回的是钉住的
		# 毫秒数，两边不同基准的话 `t = pin - 真实毫秒` 恒为负，一帧都画不出来。
		if demo_pin_ms >= 0:
			_cur["start"] = 0
		else:
			_cur["start"] = Time.get_ticks_msec() + int(_cur.get("lead", 0))
	if not _cur.is_empty() or not _flash.is_empty():
		_ensure_ui()
		_cv.queue_redraw()


func _now() -> int:
	## 出图钉帧口：demo_pin_ms >= 0 时把「当前时刻」钉住，帧率再抖也截得到同一帧。
	if demo_pin_ms >= 0:
		return demo_pin_ms
	return Time.get_ticks_msec()


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in_out(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


func _base_center() -> Vector2:
	# 屏幕中部偏上一点：下方要给「已加入卡组」胶囊留位置，上方避开顶栏。
	return Vector2(_cv.size.x / 2.0, _cv.size.y * 0.44)


func _on_draw() -> void:
	var n := _now()
	_draw_flash(n)
	if _cur.is_empty():
		return
	var t := n - int(_cur["start"])
	if t < 0:
		return                      # LEAD 还没到 —— 这期间什么都不画（别提前闪一下）
	var card: CardData = _cur["card"]
	var base := _base_center()
	var to: Vector2 = _cur["to"]
	if to.x < 0.0:
		to = _cv.size - Vector2(120.0, 96.0)
	var hold := int(_cur["hold"])

	var pos := base
	var sc := 1.0
	var a := 1.0
	if t < RISE_MS:
		var e := _ease_out(float(t) / RISE_MS)
		pos = base + Vector2(0.0, 46.0 * (1.0 - e))
		sc = lerpf(0.86, 1.0, e)
		a = e
	elif t < RISE_MS + hold:
		# 停住：只做极轻的上浮（3px 走完整个停留段），不呼吸、不晃 —— 硬边演出的节奏靠「不动」.
		pos = base + Vector2(0.0, -3.0 * float(t - RISE_MS) / float(maxi(hold, 1)))
	elif t < RISE_MS + hold + FLY_MS:
		var e := _ease_in_out(float(t - RISE_MS - hold) / float(FLY_MS))
		pos = (base + Vector2(0.0, -3.0)).lerp(to, e)
		sc = lerpf(1.0, 0.32, e)
		a = 1.0 - clampf((e - 0.78) / 0.22, 0.0, 1.0)
	else:
		return

	var r := Rect2(pos - CARD_SIZE * sc / 2.0, CARD_SIZE * sc)
	# 投影：硬边偏移块（不是柔光）。卡面自己带纸底，压一层深色垫底就能浮起来。
	_cv.draw_rect(Rect2(r.position + Vector2(0.0, 5.0), r.size),
			Color(0.0, 0.0, 0.0, 0.22 * a), true)
	# 展示期背板（飞出去那一段收掉）：结算面板弹出来时卡就压在上面，
	# 没有背板会像「一张卡掉在了别人的面板里」。背板在 FLY 之前淡出。
	if t < RISE_MS + hold:
		var fade := 1.0 - clampf(float(t - RISE_MS - hold * 0.7) / (hold * 0.3), 0.0, 1.0)
		var pr := r.grow(20.0 * sc)
		_cv.draw_rect(pr, Color(0.05, 0.045, 0.04, 0.80 * a * fade), true)
		_cv.draw_rect(pr, Color(GOLD.r, GOLD.g, GOLD.b, 0.55 * a * fade), false, 2.0)
	CardFace.draw(_cv, card, r, card.health, false, false, _font, _font_bold,
			-1, false, false, true)
	if a > 0.02:
		# 金框 = 「这是一份奖励」，与奖励面板的卡牌同语义。
		_cv.draw_rect(r.grow(3.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.90 * a), false, 3.0)
	# 说明板（「已加入卡组」+ 效果文字）：**只在展示期存在**。
	# 入场压到浮起段的 55% 之后（和卡一起淡进来会糊成一团），
	# 退场在 FLY 开始前 120ms 淡掉 —— 卡一收向卡组，板子必须跟着走，
	# 不能留在原地（否则看起来像「卡飞走了、说明还晾在那儿」）。
	if t >= RISE_MS * 0.55 and t < RISE_MS + hold:
		var ba := a * clampf(float(t - RISE_MS * 0.55) / 90.0, 0.0, 1.0)
		ba *= 1.0 - clampf(float(t - (RISE_MS + hold - 120)) / 120.0, 0.0, 1.0)
		if ba > 0.02:
			_draw_board(rect_bottom_center(r), card, ba)


func rect_bottom_center(r: Rect2) -> Vector2:
	return Vector2(r.position.x + r.size.x / 2.0, r.position.y + r.size.y)


func _draw_board(anchor: Vector2, card: CardData, a: float) -> void:
	## 卡下方的说明板：**「✦ 已加入卡组」+ 这张卡的效果文字**。
	## 卡面本身只画卡名（`name_only`，与战斗内同一口径），所以效果这一段必须由这里补上 ——
	## 否则玩家只看得到一个卡名，不知道自己刚拿到的是张什么卡。
	## 硬边深底 + 细金线，与 UiToast 同一套色；金色是奖励语义，这里用得着。
	var title := GameI18n.ui("reward", "REWARD_CARD_GRANTED", "✦ 已加入卡组")
	var body: String = CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
	var bw: float = maxf(CARD_SIZE.x + 74.0, 236.0)
	var inner: float = bw - 32.0
	var lines: Array = []
	if body != "":
		lines = CardFace.wrap_text(_font, body, inner, BODY_FS)
		while lines.size() > BODY_MAX_LINES:
			lines.pop_back()          # 说明板不是阅读器，超长就只保留前几行（卡面本身也能看到卡名）
	var line_h := float(BODY_FS) * 1.26
	var bh: float = 40.0 + float(lines.size()) * line_h + (4.0 if lines.is_empty() else 0.0)
	var rect := Rect2(Vector2(anchor.x - bw / 2.0, anchor.y + 14.0), Vector2(bw, bh))
	_cv.draw_rect(rect, Color(CAP_BG.r, CAP_BG.g, CAP_BG.b, CAP_BG.a * a), true)
	_cv.draw_rect(rect, Color(GOLD.r, GOLD.g, GOLD.b, 0.62 * a), false, 1.5)
	var tw := _font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FS).x
	_cv.draw_string(_font_bold, Vector2(anchor.x - tw / 2.0, rect.position.y + 24.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FS, Color(GOLD_LIT.r, GOLD_LIT.g, GOLD_LIT.b, a))
	if lines.is_empty():
		return
	# 标题与正文之间一条极细的分隔线（硬边，不用投影）
	var sep_y := rect.position.y + 32.0
	_cv.draw_rect(Rect2(rect.position.x + 16.0, sep_y, inner, 1.0),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.30 * a), true)
	var y := sep_y + 8.0 + float(_font.get_ascent(BODY_FS))
	for ln: String in lines:
		_cv.draw_string(_font, Vector2(rect.position.x + 16.0, y), ln,
				HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_FS, Color(0.95, 0.93, 0.87, a))
		y += line_h


func _draw_flash(n: int) -> void:
	## 落点：一圈金环扩出去 + 「+1」往上飘。表示「这一张真的进堆了」。
	for f in _flash:
		var t := float(n - int(f["start"])) / float(FLASH_MS)
		if t < 0.0 or t > 1.0:
			continue
		var a := 1.0 - t
		var c: Vector2 = f["pos"]
		# ⚠️ 半径从 46 起（不是 10）：卡组堆本身就是一块金纹圆盘，小圈一出来就被花纹吃掉，
	#    屏幕上等于没反馈。整圈走在外框之外才看得见。
		var rad := lerpf(46.0, 82.0, _ease_out(t))
		# 深色描边垫底 + 亮金线：卡组图标底是深蓝金，亮金细线才压得住。
		_cv.draw_arc(c, rad, 0.0, TAU, 34, Color(0.0, 0.0, 0.0, 0.45 * a), 5.0)
		_cv.draw_arc(c, rad, 0.0, TAU, 34, Color(1.0, 0.94, 0.72, 0.92 * a), 3.0)
		_cv.draw_arc(c, rad * 0.72, 0.0, TAU, 28, Color(GOLD_LIT.r, GOLD_LIT.g, GOLD_LIT.b,
				0.55 * a), 1.5)
		# 「+1」走**右上方斜角**：正上方会被卡组张数徽章（「+8」）压住。
		var plus := "+1"
		var pw := _font_bold.get_string_size(plus, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_FS).x
		var pp := c + Vector2(rad * 0.70 - pw / 2.0, -rad * 0.70 - 14.0 * t)
		_cv.draw_string(_font_bold, pp + Vector2(1.0, 1.0), plus,
				HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_FS, Color(0.0, 0.0, 0.0, 0.55 * a))
		_cv.draw_string(_font_bold, pp, plus,
				HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_FS,
				Color(GOLD_LIT.r, GOLD_LIT.g, GOLD_LIT.b, a))
