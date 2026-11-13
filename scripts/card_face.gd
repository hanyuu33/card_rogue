class_name CardFace
## 卡面绘制共享工具 —— battle_scene（小卡）与图鉴（大卡）共用同一套视觉。
##
## 全部为静态方法：接收 CanvasItem 与两套字体，无实例状态。
##
## ## 卡面版式（R115：上半卡图 / 下半文字 / 数值「挂在框上」）
##
##    ┌───────────────────────┐  ① 费用     = 卡框**左上角**
##    │ ①      ← 卡图 →       │  ② 力量     = 卡框**左下角**（与 ① 同一条竖线）
##    ├───────────────────────┤  ③ 攻击距离 = ② 右侧
##    │         卡名           │  ④ 移动距离 = ⑤ 左侧
##    │       种类 · 字段       │  ⑤ 生命     = 卡框**右下角**（与 ① 左右反向）
##    │    效果文字（可折行）…  │
##    └───────────────────────┘
##     ②力 ③程         ④速 ⑤
##
## ⚠️ 每个数值的**圆心就落在卡框上** —— 一半在卡内、一半露在卡外。
##   力量与生命因此**分别向左右探出卡框**（R115 用户口径「攻击力和生命都可以
##   左右方向超出卡片范围」）—— 这不是装饰偏好：它把「四个数值都得挤进卡宽」
##   松成「只有中间两个受卡宽限制」，图标于是能画得更大（R 7 → 8.5），
##   同时卡片内部依然完整让给卡图与文字。代价是容器必须让出 UiTheme.CARD_BLEED。
##
## 数值 = **图标为底 + 数字压在图标上**，且**不垫圆盘**（R115 用户口径
## 「并不需要严格的圆盘，直接用图标 + 数字就可以」）。图标素材走 `assets/ui/icon_*.png`：
##   剑=力量 / 弓=攻击距离 / 鞋=移动距离 / 血=生命 / 水晶=费用
## 缺图时回退成该数值的**语义色圆盘 + 数字**（永远不空白、不报错）。
##
## ⚠️ R122：单个数值挂件的绘制口是 `draw_badge()`（**对外公开**）——
##   battle_scene 的「动态减费」要把同一个费用槽重画成绿色数字，
##   必须走这里（自己 draw_circle 会在 R115 起把水晶图标整个盖掉）。
##
## ⚠️ R118：`draw(..., on_board=true)` = **战场卡面**模式 ——「种类 · 字段」那一行
##   会滤掉「上场之后已无作用」的字段（交换 / 幻影，判据 `CardData.affix_on_board()`）。
##   手牌 / 图鉴 / 牌库 / 卡组编辑保持**完整字段**（默认 false）—— 那几处正需要它。

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_H_DESIGN := 70.0   # 缩放基准高（battle 版小卡高）

# R393b：「本局永久成长」角标的最小卡高。低于它（战场 58×70）不画 ——
# 最窄的 `力+1` 也要三个字符，58px 宽的卡上会横跨整张卡图；而那张卡的数字
# 本来就已经因为成长变绿，信息没丢。手牌 ~119 / 牌库 92 起全部照画。
const GROWTH_MARK_MIN_H := 84.0
# R165 卡面 v4：卡图**开放式**——左/右/上直接出血到卡边（不再留内框），
# 卡框只留在**底部**（文字区那一截）。卡图区 = 顶部 0 .. CARD_ART_RATIO 的整块，
# 直接在 `_draw_art()` 里按 rect 与 `UiTheme.CARD_ART_RATIO` 现算。
# （原 0.035..0.965 × 0.030..0.720 的内框常量已撤。）
# R170：底框改**中性木色**（`UiTheme.CARD_FRAME`）且四边内缩半线宽（描边外沿与卡边对齐）；
# 稀有度主通道 = 右上角**缎带素材**（`_draw_rarity_ribbon`），不再是框线色/色块旗。

static var _art_cache := {}   # "id[_职业后缀][_sleep]" -> Texture2D / null（找不到图也缓存，避免反复查盘）
# ── R301：数值「涨跌染色」用的**卡库原型**缓存 ──
## 卡面每帧都要画、一手牌 + 一战场十几张 → 不能每次都 `CardRepo.load_json()`（会反复读盘）。
## 这里缓存**一个 repo 实例** + 按 id 缓存四项原始数值。
## ⚠️ 存的是**原始数值**而不是 CardData 引用：卡库是共享实例，持有四个 int 更省也更快。
static var _repo_cache: CardRepo = null
static var _base_cache := {}   # id -> {power, health, range, speed}
## R292：折行算法搬到 `scripts/text_wrap.gd`（唯一口：断行禁则 / 引号成对 / 西文成词），
## 缓存也一并搬过去 —— 这里不再自己攒表（R187 那张 `_wrap_cache` 已删）。

# ── R281：卡名「单行 + 超宽横向滚动」 ──
## 旧版卡名最多折 2 行，但姓名牌内框（0.745~0.94）只有 11~18px 高，底部数值徽章
## 还要再吃掉 6~12px —— 8 号字两行 = 26px，必然溢出卡外 / 压在徽章上，
## 在小卡（77×92）上表现为「长卡名堆叠」。现在卡名**恒单行**：
##   ① 字号按宽度自适应（9 → 最小 CARD_NAME_MIN_SZ）；
##   ② 仍放不下 → 横向滚动（`marquee_offset` + `_draw_name_marquee`）。
## 判定口只有一个：`name_layout()`（绘制与回归断言共用）。
const CARD_NAME_MIN_SZ := 7          # 卡名自适应最小字号（再小不可读）
const MARQUEE_PAUSE_MS := 900.0      # 横向滚动：两端停顿时长
const MARQUEE_SPEED := 26.0          # 横向滚动速度（px/s）
const CHAR_CACHE_MAX := 2048        # 卡名滚动的逐字宽度缓存上限（R292：与折行缓存分家）
static var _char_cache := {}         # "字体|字号|文本" -> Array[float]（逐字宽度）
static var _scroll_watch_ms := 0     # 最近一次「画了滚动卡名」的时刻


static func _display_name(card: CardData) -> String:
	return GameI18n.card_name(card.id, card.card_name)


static func name_layout(card_name: String, rect: Rect2, font_bold: Font,
		max_h := 0.0) -> Dictionary:
	## **卡名单行排版唯一判定口**（绘制与测试共用，R281）。
	## 返回 {"sz", "maxw", "text_w", "need_scroll"}。
	## 字号同时受**宽度**与**高度**约束（`max_h` = 姓名牌内框到徽章带顶的距离，0 = 不限）：
	##   * 宽度放不下 → 继续缩，缩到底（CARD_NAME_MIN_SZ）再交给横向滚动；
	##   * 高度放不下 → 必须缩 —— 墨迹压住底部数值就是玩家口中的「叠字」。
	## 循环有硬边界（sz 单调递减到 CARD_NAME_MIN_SZ），不会死循环。
	var k: float = rect.size.y / CARD_H_DESIGN
	var kt: float = minf(k, UiTheme.CARD_TEXT_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	var maxw: float = rect.size.x * (UiTheme.CARD_NAMEPLATE_X1 - UiTheme.CARD_NAMEPLATE_X0) - pad * 2.0
	var sz: int = maxi(9, roundi(UiTheme.CARD_FS_TEXT * kt * 1.15))
	var tw: float = 0.0
	while true:
		tw = font_bold.get_string_size(card_name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var ink: float = float(font_bold.get_ascent(sz)) + 1.0
		var too_wide: bool = tw > maxw
		var too_tall: bool = max_h > 0.0 and ink > max_h
		if sz <= CARD_NAME_MIN_SZ or (not too_wide and not too_tall):
			break
		sz -= 1
	return {"sz": sz, "maxw": maxw, "text_w": tw, "need_scroll": tw > maxw + 0.5}


static func marquee_offset(text_w: float, maxw: float, now_ms: int) -> float:
	## 超宽卡名的**横向滚动偏移**（纯函数，便于断言）：两端各停 MARQUEE_PAUSE_MS，
	## 中间匀速走完 span = text_w - maxw，然后原路返回 —— 不跳变。
	if text_w <= maxw:
		return 0.0
	var span: float = text_w - maxw
	var move_ms: float = span / maxf(1.0, MARQUEE_SPEED) * 1000.0
	var cycle: float = 2.0 * (MARQUEE_PAUSE_MS + move_ms)
	var t: float = fmod(float(now_ms), cycle)
	if t < MARQUEE_PAUSE_MS:
		return 0.0
	t -= MARQUEE_PAUSE_MS
	if t < move_ms:
		return span * (t / move_ms)
	t -= move_ms
	if t < MARQUEE_PAUSE_MS:
		return span
	t -= MARQUEE_PAUSE_MS
	return span * (1.0 - clampf(t / move_ms, 0.0, 1.0))


static func scrolling_recent(window_ms := 1000) -> bool:
	## 最近 window_ms 内画过滚动卡名 → 宿主（battle_scene._process）据此每帧重绘。
	## 自持循环：draw → 记时刻 → _process 看到 → queue_redraw → 下一帧继续 draw。
	return Time.get_ticks_msec() - _scroll_watch_ms < window_ms


static func _char_widths(font: Font, text: String, size: int) -> Array[float]:
	## 逐字宽度（缓存）：只用来算「滚到哪里该画哪一段字」。
	var ck := "%d|%d|%s" % [font.get_instance_id(), size, text]
	if _char_cache.has(ck):
		var hit: Array[float] = _char_cache[ck]
		return hit
	var out: Array[float] = []
	for ch in text:
		out.append(font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if _char_cache.size() >= CHAR_CACHE_MAX:
		_char_cache.clear()
	_char_cache[ck] = out
	return out


static func _draw_name_marquee(canvas: CanvasItem, font: Font, sz: int, text: String,
		x0: float, baseline: float, maxw: float, col: Color, text_w: float) -> void:
	## 横向滚动绘制：把**落在可视窗口内的那一段连续字符**整段 draw_string 出去
	## （不是逐字画 —— 逐字会丢字距、也更慢）。窗口 = [x0, x0 + maxw]。
	_scroll_watch_ms = Time.get_ticks_msec()
	var off: float = marquee_offset(text_w, maxw, Time.get_ticks_msec())
	var ws := _char_widths(font, text, sz)
	var x: float = x0 - off
	var first := -1
	var last := -1
	var fx: float = x0
	for i in ws.size():
		var w: float = ws[i]
		if x + w > x0 + 0.5 and x < x0 + maxw - 0.5:
			if first < 0:
				first = i
				fx = x
			last = i
		x += w
	if first < 0 or last < first:
		return
	canvas.draw_string(font, Vector2(fx, baseline), text.substr(first, last - first + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

# ── 【公用初始卡的职业皮】（R185 起 / R328 扩到木栅栏）──
## 木栅栏 8001 与攻击 8002 是**三职业共用的初始卡**（归属 class 留空），
## 但卡面要「吃本职业的色 + 本职业的图」—— 取哪套由 `PlayerClass.skin_class()` 决定。
## 这里只负责「职业 → 文件名后缀」的映射（`<id>_forest.png` 等）。
## 缺图自动回退 `<id>.png`（见 art_for），所以新增变体图不需要改代码。
const ART_VARIANT_SUFFIX := {"森林精魄": "forest", "暗影刺客": "shadow", "机械之心": "mech"}
const ATTACK_ART_ID := 8002       # 旧名保留（test_smoke 引用了它）


## ── 【卡底面的职业色】（R267）──
##
## 用户口径「三个职业的卡底面换成各职业的颜色（能否做到图不变，只改填色）」
## → 做得到：**不换素材、不重画**，同一张 `card_paper.png` 走 `draw_texture_rect`
##   的 modulate（相乘）—— 纸纹、雕花、明暗全部保留，只把色相换成职业色。
##
## ⚠️ 必须**大幅向白混合再乘**：直接乘饱和职业色（如 3a7d44）会把羊皮纸
##   压成深色，而卡名用的是 `INK_900` 深墨 → 字就没了。混白后仍是**浅纸**，
##   只带职业色相，对比度不受影响。
## R277：上色口径 = **卡的所属**（`CardData.card_class`），四类各有各的颜色：
##   森林精魄 绿 / 暗影刺客 紫 / 机械之心 黄铜 / 敌人 红 / **class 留空（公用卡）灰**。
##   全部走 `UiTheme.class_color()` 唯一口，这里不再另写判断。
const CLASS_PAPER_MIX := 0.60


static func paper_tint(card: CardData) -> Color:
	## 卡底面的乘色（唯一口）。`Color.WHITE` = 不上色。
	## R328：取色过 `PlayerClass.skin_class()` —— 公用初始卡（木栅栏/攻击）穿**当前职业**色，
	## 其余卡仍按自身 `card_class`（事件 / 诅咒留空的照旧中性灰）。
	if card == null:
		return Color.WHITE
	var c: Color = UiTheme.class_color(PlayerClass.skin_class(card.id, card.card_class))
	if c.a <= 0.0:
		return Color.WHITE
	return c.lerp(Color.WHITE, CLASS_PAPER_MIX)


static func art_for(id: int, sleeping := false, phase := 0) -> Texture2D:
	# sleeping=true 时优先取沉睡专用图 `<id>_sleep.png`（R182 恶魔鸭沉睡状态）；
	# 沉睡图缺失则回退普通卡图 —— 不空白、不报错。
	# 公用初始卡（8001 木栅栏 / 8002 攻击）按 RunState.player_class 换图；
	# 职业图缺失回退 `<id>.png` 通用图（8001 目前还没有职业变体，走这条回退）；
	# 图鉴等非 run 场景 player_class 为默认值（森林精魄），显示森林版。
	var suffix := ""
	if PlayerClass.is_base_common(id):
		suffix = "_" + String(ART_VARIANT_SUFFIX.get(RunState.player_class, "forest"))
	# R357：**阶段变体图**（多阶段 Boss）—— `phase >= 2` 时优先取 `<id>_p<phase>.png`。
	# 约定：`<id>.png` = 第 1 阶段的图，`<id>_p2.png` / `<id>_p3.png` = 后续阶段的图。
	# 缺图逐级回退（p3 → p2 → 基础图），所以新阶段图没做好时只是「图不变」，不会空白。
	var phase_suffix := ""
	if phase >= 2:
		phase_suffix = "_p%d" % phase
	var key := str(id) + suffix + ("_sleep" if sleeping else "") + phase_suffix
	if not _art_cache.has(key):
		var path := "res://assets/pics/%d.png" % id
		if suffix != "":
			var cp := "res://assets/pics/%d%s.png" % [id, suffix]
			if _pic_exists(cp):
				path = cp
		if sleeping:
			var sp := "res://assets/pics/%d%s_sleep.png" % [id, suffix]
			if _pic_exists(sp):
				path = sp
		if phase >= 2:
			for ph in range(phase, 1, -1):
				var pp := "res://assets/pics/%d%s_p%d.png" % [id, suffix, ph]
				if _pic_exists(pp):
					path = pp
					break
		# R478：未确认卡图 —— 主目录没有、`_pending/` 里有，就先拿来用（卡面带角标）。
		# 只回退基础图 + 职业变体；阶段图（_p2/_p3）和沉睡图不放 pending，避免误判。
		if not _pic_exists(path):
			var pend := PENDING_DIR + "%d%s.png" % [id, suffix]
			if _pic_exists(pend):
				path = pend
		_art_cache[key] = load(path) if _pic_exists(path) else null
	return _art_cache[key]


## R478：未确认卡图的暂存目录。AI 生成、还没人工确认的图放这里，
## 主目录（assets/pics/）缺图时回退读取，卡面左上角打一枚黄色三角 —— 一眼看出「没定稿」。
## 确认动作：python _cardart.py approve <id>（移入主目录，角标自动消失）。
const PENDING_DIR := "res://assets/pics/_pending/"


static func is_pending_art(id: int) -> bool:
	## 当前这张卡用的是不是「未确认图」= 主目录没有 + pending 目录有。
	if _pic_exists("res://assets/pics/%d.png" % id):
		return false
	return _pic_exists(PENDING_DIR + "%d.png" % id)


static func _draw_pending_mark(canvas: CanvasItem, box: Rect2, k: float) -> void:
	## 未确认角标：卡图**右下角**一枚黄色三角。
	## 为什么不放左上角：那里是费用徽章的圆心（压在框线上），三角会被圆盖住一半，
	## 看起来像徽章的一部分。右下角在卡图区内、四枚数值徽章都在卡片底部，不冲突。
	var d: float = maxf(6.0, 8.5 * k)
	var o := box.position + box.size
	canvas.draw_colored_polygon(PackedVector2Array([
			o + Vector2(0, 0), o + Vector2(-d, 0), o + Vector2(0, -d)]),
			Color(0.98, 0.80, 0.25, 0.92))


## R190：导出包（安卓 / Windows 独立版）里图片只有 `.import` + `.ctex`、**没有源文件**，
## 单看 `FileAccess.file_exists` 会全部落空 → 卡图一张都不显示（UiAssets 同款坑，
## 见 ui_assets.gd 顶部注释）。正确判存 = FileAccess or ResourceLoader.exists
## （编辑器里两者都真；导出包里后者靠 .import 重映射为真）。
static func _pic_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


static func fit_rect(src: Vector2, box: Rect2) -> Rect2:
	## 等比缩放放进 box，居中。
	if src == Vector2.ZERO:
		return box
	var s: float = minf(box.size.x / src.x, box.size.y / src.y)
	var sz := src * s
	return Rect2(box.position + (box.size - sz) / 2.0, sz)


static func cover_region(src: Vector2, box: Rect2) -> Rect2:
	## 「铺满」（cover）：按 box 的宽高比，从 src 里裁出一块**等比**区域 ——
	## 配合 `draw_texture_rect_region` 画出来正好填满 box：不拉伸、不留白。
	## 横置卡面（76×63，横向）上的卡图用它铺满整张卡（R122 用户口径）。
	return cover_region_anchored(src, box, 0.5)


static func cover_region_top(src: Vector2, box: Rect2) -> Rect2:
	## 同 `cover_region`，但**纵向从顶边开始裁**（宁可裁脚，不裁头）。
	## R519 用户口径：职业 CG 里角色头顶基本贴着画面上沿，居中裁会把兜帽/发梢削掉
	## —— 屏越宽（20:9、21:9）纵向能留的越少，削得越明显。立绘/插图一律走这个。
	return cover_region_anchored(src, box, 0.0)


static func cover_region_anchored(src: Vector2, box: Rect2, ay: float) -> Rect2:
	## `ay`：纵向裁切的锚点。0.0 = 顶端对齐，0.5 = 居中，1.0 = 底端对齐。
	## 横向永远居中（角色基本在画面中部，左右对称裁最不容易切到主体）。
	if src.x <= 0.0 or src.y <= 0.0 or box.size.x <= 0.0 or box.size.y <= 0.0:
		return Rect2(Vector2.ZERO, src)
	var src_r: float = src.x / src.y
	var box_r: float = box.size.x / box.size.y
	if src_r > box_r:
		# 源更宽 → 左右各裁掉一点
		var cw: float = src.y * box_r
		return Rect2((src.x - cw) / 2.0, 0.0, cw, src.y)
	# 源更高 → 上下裁掉一部分（裁多少由 ay 决定留上还是留下）
	var ch: float = src.x / box_r
	return Rect2(0.0, (src.y - ch) * clampf(ay, 0.0, 1.0), src.x, ch)


# ──────────────────────────────────────────────────────────────────────
# 版式几何（对外暴露：调用方要往卡上叠自己的角标时，必须读这里，
# 否则改了版式那些叠加层就会错位 —— battle_scene 的动态减费就是这么接的）
# ──────────────────────────────────────────────────────────────────────

static func scale_of(rect: Rect2) -> float:
	## 卡片缩放比 k（1.0 = 战场小卡 58×70，1.7 = 手牌，3.7 = 奖励大卡）。
	return rect.size.y / CARD_H_DESIGN


static func ui_scale_of(rect: Rect2) -> float:
	## 徽章 / 装饰的缩放：等于 k 但**封顶**（`CARD_BADGE_SCALE_CAP`）。
	## 大卡上徽章若跟着 k 线性长，会变成几个巨球抢掉卡图的戏。
	return minf(scale_of(rect), UiTheme.CARD_BADGE_SCALE_CAP)


static func badge_radius(rect: Rect2) -> float:
	return UiTheme.CARD_BADGE_R * ui_scale_of(rect)


static func badge_font(rect: Rect2) -> int:
	return maxi(7, roundi(UiTheme.CARD_FS_BADGE * ui_scale_of(rect)))


static func cost_badge_center(rect: Rect2) -> Vector2:
	## 左上费用数值的圆心 = **卡片的左上角**（圆心压在框线上，一半露在框外）。
	## R115 起「力量」的圆心在**左下角**，与这个点同一条竖线 —— 两者左右对齐。
	## battle_scene 的「动态减费」要在同位置重画绿色数字，所以这里对外暴露 ——
	## 它是费用徽章位置的**唯一口**。
	return rect.position


static func enchant_badge_center(rect: Rect2) -> Vector2:
	## **附魔标记的圆心**（R214）= 费用徽章**正下方** —— 用户口径「标记应在卡片费用正下方」。
	## 同一竖线（x 与费用圆心相同 = 卡框左沿），纵向间距与底部那排数值徽章**完全一致**
	## （圆心距 = 2R + `CARD_BADGE_GAP`，默认 gap=0 → 两枚徽章相切），
	## 于是「费用 · 附魔 · 力量」在卡框左侧排成一条**等距竖列**，眼睛只需要记一次间距。
	## ⚠️ 半径一律走 `badge_radius()`（带 `CARD_BADGE_SCALE_CAP` 封顶）——
	##    `_draw_badges()` 里也是这么算的，两处不同步就会错位。
	return cost_badge_center(rect) + Vector2(0.0,
			2.0 * badge_radius(rect) + UiTheme.CARD_BADGE_GAP * ui_scale_of(rect))


static func text_zone_bottom(rect: Rect2) -> float:
	## 文字区下界 = 底部数值的**内半圈**上沿（圆心在卡框上，只侵入卡片一个半径）。
	## 数值不再占用卡片内部空间，所以这一版比初版多了约 1.5R 的文字高度。
	return rect.end.y - badge_radius(rect)


# ──────────────────────────────────────────────────────────────────────

static func draw(canvas: CanvasItem, card: CardData, rect: Rect2, hp: int,
		selected: bool, is_tapped: bool, font: Font, font_bold: Font,
		power_override := -1, on_board := false, sleeping := false,
		name_only := false, phase := 0,
		speed_override := -1, range_override := -1, adventure_frame := false,
		record_seen := true, state_slots: Array = []) -> void:
	## 卡面一律按 rect **完整排版**，与图鉴/战场小卡同一套比例，没有「按可见高度重锚」
	## 之类的特例 —— 手牌卡底沉出窗口下沿时，被挡住的那截就让它挡住
	## （作者口径：卡片是一个整体，排版要与正常状态完全一致，别为了躲裁剪挪数值）。
	##
	## `record_seen`（R642）：画出来 = 玩家见过 → 顺带记进 `ProfileData.seen_cards`。
	## **图鉴自己画卡面时必须传 false**，否则一开图鉴就把 315 张全标成见过。
	if record_seen:
		ProfileData.mark_card_seen(card.id)
	var k := rect.size.y / CARD_H_DESIGN
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var kt: float = minf(k, UiTheme.CARD_TEXT_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	# ① 卡面纸底：素材槽 assets/ui/card_paper.png 优先，缺图回退纯色（R113 起可换皮）
	var paper: Texture2D = UiAssets.card_paper()
	var tint := paper_tint(card)   # R267：职业色只涂在纸底上，卡图本身不动
	if adventure_frame:
		preload("res://scripts/battle_hud_material.gd").draw(canvas, rect)
	elif paper != null:
		canvas.draw_texture_rect(UiAssets.filtered(paper, ceili(maxf(rect.size.x, rect.size.y) * maxf(1.5, canvas.get_viewport_transform().get_scale().x))), rect, false, tint)
	else:
		canvas.draw_rect(rect, tint if tint != Color.WHITE else UiTheme.SURFACE)
	# ② 选中态：**外发光**，不占用任何语义色（缎带是稀有度的通道，见 UI设计规范 §规则 5）
	if selected:
		for gi in 3:
			var glow := UiTheme.SELECT_RING
			glow.a = 0.42 - 0.11 * gi
			canvas.draw_rect(rect.grow(1.0 + gi), glow, false, 1.0)
	# ③ 底部框线（R170 / R193）：**中性深胡桃木色**、只框文字区。
	#    v4 纸底自带 ornate 姓名牌边框，有纸时不再手画框线，避免双重边框；缺图时才用程序框。
	var has_paper := paper != null
	var bw := maxf(1.5, 2.0 * k)
	var frame_top: float = rect.position.y + rect.size.y * UiTheme.CARD_ART_RATIO
	if not has_paper:
		canvas.draw_rect(Rect2(rect.position.x + bw / 2.0, frame_top + bw / 2.0,
				rect.size.x - bw, rect.end.y - frame_top - bw), UiTheme.CARD_FRAME, false, bw)
	# ④ 卡图区（上半）
	_draw_art(canvas, card, rect, k, pad, is_tapped, font_bold, sleeping, phase)
	if adventure_frame:
		preload("res://scripts/battle_hud_material.gd").draw_frame(canvas, rect, true)
		var name_plate := Rect2(rect.position + Vector2(2, rect.size.y * UiTheme.CARD_ART_RATIO), Vector2(rect.size.x - 4, rect.size.y * (1.0 - UiTheme.CARD_ART_RATIO)))
		preload("res://scripts/battle_hud_material.gd").draw(canvas, name_plate)
	# ④b 稀有度缎带（R170）：挂在**右上角**、压在卡图之上。
	#     （旧色块小旗画在卡图**之前**，被开放式卡图整个盖住 —— 等于没画。）
	_draw_rarity_ribbon(canvas, card, rect, k, pad)
	# ④c R592：字段标志（贴卡框右上角，多字段轮播；R592d 起压在缎带上层）
	#     R656：状态槽位（眩晕 / 冰封 / 沉睡 N / 倒数 N / 可发动 / 临时嘲讽）排进同一条队列，
	#     状态在前、字段在后 —— 卡面**不再有文字标记**，全靠这个圆槽说话。
	_draw_affix_badges(canvas, card, rect, k, on_board, -1, state_slots)
	# ⑤ 卡图与文字区的分隔线
	# ⚠️ R153：v2 底图**自带金线分隔**（CARD_ART_RATIO 0.745 处的金条），不再手画灰线。
	# ⚠️ R122：**横置时不画** —— 那时卡图铺满整卡（见 _draw_art），横一道线很突兀。
	var sep_y: float = rect.position.y + rect.size.y * UiTheme.CARD_ART_RATIO
	# ⑥ 文字区（下半）—— 底衬在 `_draw_text_zone` 内部按**文字块的实际高度**铺。
	#    name_only=true → 只画卡名（战斗内卡面口径：效果详情走悬停/点选描述面板）。
	_draw_text_zone(canvas, card, rect, kt, k, pad, sep_y, hp, font, font_bold, on_board, is_tapped, name_only)
	# ⑦ 数值徽章 —— 最后画，压在卡图与文字之上（「额外挂载」的字面意思）
	_draw_badges(canvas, font_bold, card, rect, k, kc, hp, power_override,
			speed_override, range_override)
	# ⑧ 附魔标记（R214）—— 同样压在最上层（它骑在卡图左上角上）
	_draw_enchant_mark(canvas, card, rect, font_bold)
	_draw_combine_mark(canvas, card, rect)                       # R565：组合专属印记
	# ⑨ R592：**卡面不再画成长角标**（用户口径「+力/+生命 直接不在卡面上显示」）。
	#    数值照旧按「比原型高」染色，具体加了多少去详细描述看 ——
	#    `CardDetailOverlay` 的「本局永久成长　力+1 生+6」那一段就是它的新家。


static func draw_no_record(canvas: CanvasItem, card: CardData, rect: Rect2, hp: int,
		selected: bool, font: Font, font_bold: Font) -> void:
	## R642：图鉴专用 —— 与 `draw()` 完全一致，只是**不**记「玩家见过这张卡」。
	## 为什么单独开一个口：GDScript 没有具名参数，要把 `record_seen` 传成 false，
	## 就得把中间那一串带默认值的参数逐个写成 `-1 / false / 0`，调用处读起来像密码。
	draw(canvas, card, rect, hp, selected, false, font, font_bold,
			-1, false, false, false, 0, -1, -1, false, false)


static func draw_locked(canvas: CanvasItem, rect: Rect2, font_bold: Font) -> void:
	## R642：图鉴里「还没见过」的卡位 —— 统一画成一张**通用未解锁图**。
	## 底图直接用现成的卡背（`assets/ui/card_back.png`），按卡面比例**居中裁切**再铺：
	## 卡背是 2:3、卡面是 76:92（≈5:6），直接铺会横向拉宽 24%，一眼就看出被压扁。
	## 上面再压一层暗色 + 「？」+「未解锁」，保证它不会被误读成一张真卡。
	## 换皮：以后有专用未解锁插画，只需让 `UiAssets.card_back()` 这条底图换掉，
	## 裁切 / 压暗 / 文字全部不用动。
	var tex: Texture2D = UiAssets.card_back()
	if tex != null and tex.get_height() > 0:
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var want: float = rect.size.x / maxf(rect.size.y, 1.0)
		var src := Vector2(tw, th)
		if tw / th > want:
			src.x = th * want      # 源图更宽 → 左右各裁一点
		else:
			src.y = tw / want      # 源图更高 → 上下各裁一点（卡背是这一种）
		var off := Vector2((tw - src.x) * 0.5, (th - src.y) * 0.5)
		canvas.draw_texture_rect_region(tex, rect, Rect2(off, src))
	else:
		canvas.draw_rect(rect, UiTheme.SURFACE)
	canvas.draw_rect(rect, Color(0.07, 0.08, 0.11, 0.58))
	canvas.draw_rect(rect, Color(0.72, 0.58, 0.32, 0.85), false,
			maxf(1.0, rect.size.y / CARD_H_DESIGN * 1.6))
	# 「？」—— 卡面中间偏上
	var qs := int(maxf(12.0, rect.size.y * 0.42))
	var q := "？"
	var qw: float = font_bold.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, qs).x
	canvas.draw_string(font_bold,
			Vector2(rect.position.x + (rect.size.x - qw) * 0.5, rect.position.y + rect.size.y * 0.62),
			q, HORIZONTAL_ALIGNMENT_LEFT, -1, qs, Color(0.88, 0.77, 0.53, 0.9))
	# 「未解锁」—— 卡面底部
	var fs := int(maxf(9.0, rect.size.y * 0.115))
	var s := GameI18n.ui("shared", "CARD_FACE_LOCKED", "未解锁")
	var sw: float = font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	canvas.draw_string(font_bold,
			Vector2(rect.position.x + (rect.size.x - sw) * 0.5, rect.end.y - rect.size.y * 0.06),
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.93, 0.89, 0.79, 0.92))


static func draw_pick(canvas: CanvasItem, card: CardData, rect: Rect2,
		font: Font, font_bold: Font, selected := false, record_seen := true) -> void:
	## 选卡场景专用简洁卡面（R191，用户口径「卡面只留卡名，描述点选后再看」）：
	## 纸底 + 卡图 + 稀有度缎带 + 数值徽章 + **只有卡名**的文字区（不画种类行与效果文）。
	## 用于战斗内选卡页 / 卡牌奖励三选一 / 卡组编辑选卡 —— 战场与手牌仍走 `draw()`。
	##
	## `record_seen`（R642）：奖励三选一 / 商店陈列 / 组合候选都是**真给玩家看卡面**，
	## 照常记账；只有图鉴自己要传 false。
	if record_seen:
		ProfileData.mark_card_seen(card.id)
	var k := rect.size.y / CARD_H_DESIGN
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var kt: float = minf(k, UiTheme.CARD_TEXT_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	var paper: Texture2D = UiAssets.card_paper()
	var tint := paper_tint(card)   # R267：职业色只涂在纸底上，卡图本身不动
	if paper != null:
		canvas.draw_texture_rect(UiAssets.filtered(paper, ceili(maxf(rect.size.x, rect.size.y) * maxf(1.5, canvas.get_viewport_transform().get_scale().x))), rect, false, tint)
	else:
		canvas.draw_rect(rect, tint if tint != Color.WHITE else UiTheme.SURFACE)
	if selected:
		for gi in 3:
			var glow := UiTheme.SELECT_RING
			glow.a = 0.42 - 0.11 * gi
			canvas.draw_rect(rect.grow(1.0 + gi), glow, false, 1.0)
	_draw_art(canvas, card, rect, k, pad, false, font_bold, false)
	_draw_rarity_ribbon(canvas, card, rect, k, pad)
	_draw_affix_badges(canvas, card, rect, k, false)   # R592：字段标志
	_draw_name_zone(canvas, card, rect, kt, k, pad, font_bold)   # R193：姓名牌内框 + 居中卡名（只留卡名）
	_draw_badges(canvas, font_bold, card, rect, k, kc, card.health, -1)
	_draw_enchant_mark(canvas, card, rect, font_bold)            # R214：选卡页也要看到附魔标记
	_draw_combine_mark(canvas, card, rect)                       # R565：组合专属印记
	_draw_lock_mark(canvas, card, rect)                          # R351：不可删除的卡带锁
	# R592：选卡页同样不画成长角标（+力/+生命 只在详细描述里）


static func _draw_lock_mark(canvas: CanvasItem, card: CardData, rect: Rect2) -> void:
	## **锁标记**（R351）：`CardData.no_remove` 的卡（月亮 9180 / 硬币 9181 / 罐子 9157）
	## 在选卡页上盖一枚金锁 —— 与 `deck_edit_scene` 提示行「带锁标记的卡不可以从卡组删除」
	## 对上，玩家不用试错就知道哪张点不动。
	##
	## 位置：**卡图区右侧、稀有度缎带正下方**（缎带占到卡高 38%，再往下才是空地）。
	##   ⚠️ 不能放姓名牌里 —— 卡名居中且占满内框宽度，长卡名会直接撞上。
	## 尺寸一律按 `rect` 边长取比例（选卡页 448×403、卡组网格更小，都跟着缩）。
	## 只挂 `draw_pick()`：手牌 / 战场 / 图鉴走 `draw()`，那里不需要这层提示。
	if card == null or not card.no_remove:
		return
	var u: float = minf(rect.size.x, rect.size.y)
	# ⚠️ 尺寸按 `u` 取比例而不是写死像素：卡组网格里一张卡只有 ~160×120，
	#    0.052u 的锁（直径 21px）糊成一团 —— 0.085u 才读得出「锁」。
	var r: float = u * 0.080
	var c := Vector2(rect.end.x - u * 0.150, rect.position.y + rect.size.y * 0.50)
	var gold := Color("f2bb45")
	var ring_w: float = maxf(1.2, u * 0.012)
	# 深色圆盘打底：卡图可能很花，直接压金锁会糊掉
	canvas.draw_circle(c, r, Color(0.09, 0.07, 0.06, 0.80))
	canvas.draw_circle(c, r, gold, false, ring_w)
	# 锁体（实心方块，坐下半）+ 锁梁（上半圆，开口朝下）—— 纯几何，无素材依赖
	var bw: float = r * 0.98          # 锁体宽
	var bh: float = r * 0.70          # 锁体高
	var arch_w: float = maxf(1.6, u * 0.024)
	var body := Rect2(c.x - bw / 2.0, c.y + r * 0.06 - bh / 2.0, bw, bh)
	canvas.draw_arc(Vector2(c.x, body.position.y), bw * 0.30,
			PI, TAU, 16, gold, arch_w)
	canvas.draw_rect(body, gold, true)
	# 锁孔：一个小深色圆点 + 下方短竖线（钥匙孔的读法），让锁体不是一块死金块
	var kh := Vector2(c.x, body.position.y + bh * 0.42)
	canvas.draw_circle(kh, maxf(1.1, r * 0.19), Color(0.09, 0.07, 0.06, 0.88))
	canvas.draw_line(kh, kh + Vector2(0.0, bh * 0.26),
			Color(0.09, 0.07, 0.06, 0.88), maxf(1.1, r * 0.16))


static func _draw_enchant_mark(canvas: CanvasItem, card: CardData, rect: Rect2,
		font_bold: Font) -> void:
	## **附魔标记**（R214）：费用徽章正下方的一枚圆徽，内容是这张卡吃的那一种附魔。
	##
	## 用户口径「带有附魔效果的卡片，应该在任何地方，都显示附魔标记。标记应在卡片费用
	## 正下方，与附魔种类相同」——
	##   · **任何地方**：`draw()`（战场 / 手牌 / 图鉴 / 牌库 / 地图卡组 / 商店）
	##     与 `draw_pick()`（选卡页 / 奖励三选一 / 卡组编辑）都调这一口，
	##     所以标记跟着卡面走，不用每个场景各画一遍。
	##   · **与附魔种类相同**：图标就是商店第二行那件商品的**同一张素材**
	##     （`CardData.ENCHANT_DEFS` 唯一口），描边环再用该附魔的种类色 ——
	##     四种附魔在 18px 的小徽章上靠「图 + 环色」双通道区分，不会认错。
	##   · **费用正下方**：几何见 `enchant_badge_center()`，与底部那排数值徽章等距。
	##
	## ⚠️ 必须垫一层**深色圆盘**：附魔素材是浅色扁平插画（白描边），直接压在本就花哨的
	##    卡图上会糊成一片；深底 + 亮色环让它在任何卡图上都读得出来（R173 的教训：
	##    素材接进绘制后必须出图量像素，别只看代码）。
	## ⚠️ 图标缺失 → 回退「附魔名首字」（费/伤/次/保），不空白也不报错。
	if card == null or not card.has_enchant():
		return
	var r: float = badge_radius(rect)
	var c := enchant_badge_center(rect)
	if r < 3.0:
		return
	var col: Color = CardData.enchant_color(card.enchant)
	# 底圆盘用**该附魔色的深色调**（不是统一黑）：远处也能凭底色区分「蓝=费用 / 橙=伤害 /
	# 紫=次元之力 / 绿=保存」，近处再看图标细节 —— 双通道。
	var disc: Color = col.darkened(0.74)
	disc.a = 0.92
	canvas.draw_circle(c, r, disc)
	canvas.draw_arc(c, r, 0.0, TAU, 28, col, maxf(1.2, r * 0.20), true)
	var icon: Texture2D = UiAssets.enchant_icon(card.enchant)
	if icon != null:
		var ir: float = r * 0.86
		canvas.draw_texture_rect(icon, Rect2(c - Vector2(ir, ir), Vector2(ir, ir) * 2.0), false)
	else:
		var fs: int = maxi(6, roundi(10.0 * ui_scale_of(rect)))
		_draw_center_outlined(canvas, font_bold, fs,
				CardData.enchant_title(card).substr(0, 1), c, col)


static func combine_badge_center(rect: Rect2, enchanted: bool) -> Vector2:
	## R565：组合印记的圆心 = 附魔标记那条竖列的下一位。
	## 这张卡同时带商店附魔时自动让开一格（两张印记不叠）。
	var c := enchant_badge_center(rect)
	if enchanted:
		c.y += 2.0 * badge_radius(rect) + UiTheme.CARD_BADGE_GAP * ui_scale_of(rect)
	return c


static func _draw_combine_mark(canvas: CanvasItem, card: CardData, rect: Rect2) -> void:
	## **组合专属印记**（R565）—— 用户口径「要有组合的专属附魔标记（费用下面那个），
	## 不需要组合这个 buff」。
	##
	## 视觉与附魔标记同一套：深色圆盘 + 亮色环 + 符号，位置也在费用正下方那条竖列
	## （`combine_badge_center`）。区别只在符号：走 `CardInfoBoxes.draw_glyph("combine")`
	## ——两个拼块左右拼接的自绘符号，不依赖素材，也就不会缺图。
	##
	## ⚠️ 它**不是** `enchant`：不写 `ENCHANT_DEFS`、不进随机附魔池、不参与「同一张卡不能
	##    重复附魔」，更不挂 `affixes` —— 所以卡面上不会多出一条「组合」buff条。
	##    （R559 那版就是 `add_affix("组合")`，结果在卡面渲染成了 buff。）
	if card == null or not card.combine_mark:
		return
	var r: float = badge_radius(rect)
	if r < 3.0:
		return
	var c := combine_badge_center(rect, card.has_enchant())
	var col: Color = UiTheme.ACCENT_GOLD
	var disc: Color = col.darkened(0.78)
	disc.a = 0.95
	canvas.draw_circle(c, r, disc)
	canvas.draw_arc(c, r, 0.0, TAU, 28, col, maxf(1.2, r * 0.22), true)
	preload("res://scripts/card_info_boxes.gd").draw_glyph(canvas, c, r * 0.62, "combine", col)


static func _draw_name_zone(canvas: CanvasItem, card: CardData, rect: Rect2, kt: float,
	k: float, pad: float, font_bold: Font, pin_gold := false) -> void:
	## 文字区 = **只有卡名**（R281 起**恒单行**）。
	## 字号 / 是否滚动走 `name_layout()`（宽度 + 高度双约束的唯一口）；
	## 超宽走 `_draw_name_marquee()` 横向滚动。
	## 效果文字**不画在卡面上** —— 详情走悬停/点选的描述面板（选卡底部描述条 / 战斗左栏）。
	var parch_top: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_TOP + pad * 0.25
	var zone_top: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_TOP + pad
	var zone_bottom: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_BOTTOM - pad
	var badge_top: float = 0.0
	if pin_gold:
		# 底部一排数值徽章（力/程/速/生）圆心压在卡框**下边缘**、一半探出卡外 →
		# 卡内自 `rect.end.y - badge_r` 起就是徽章带，卡名绝不能伸进去。
		var badge_r: float = UiTheme.CARD_BADGE_R * minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
		badge_top = rect.end.y - badge_r - pad * 0.5
	var max_h: float = (badge_top - parch_top) if pin_gold else (zone_bottom - zone_top)
	var info := name_layout(_display_name(card), rect, font_bold, max_h)
	var sz: int = int(info["sz"])
	var maxw: float = float(info["maxw"])
	var row_h: float = font_bold.get_height(sz)
	var text_x: float = rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad
	var text_top: float
	if pin_gold:
		text_top = parch_top + maxf(0.0, (badge_top - parch_top - row_h) / 2.0)
		# R208：不铺程序底衬 —— 卡名直接坐在 card_paper 自带的姓名牌羊皮纸上。
		text_top = minf(text_top, badge_top - row_h)   # 放不下就贴徽章带顶，绝不压数字
	else:
		text_top = zone_top + maxf(0.0, (zone_bottom - zone_top - row_h) / 2.0)
	text_top = maxf(text_top, rect.position.y + 1.0)
	var baseline: float = text_top + float(font_bold.get_ascent(sz))
	if bool(info["need_scroll"]):
		_draw_name_marquee(canvas, font_bold, sz, _display_name(card), text_x, baseline, maxw,
			UiTheme.INK_900, float(info["text_w"]))
		return
	canvas.draw_string(font_bold, Vector2(text_x, baseline), _display_name(card),
			HORIZONTAL_ALIGNMENT_CENTER, maxw, sz, UiTheme.INK_900)


static func _draw_art(canvas: CanvasItem, card: CardData, rect: Rect2, k: float, pad: float,
		is_tapped: bool, font_bold: Font, sleeping := false, phase := 0) -> void:
	## 卡图区 = 卡片上半（R114 起）。R165：卡图**开放**——左/右/上直接出血到卡边，
	## 不再有内框；卡框只留在底部（见 `draw()` ③）。
	## sleeping=true → 取沉睡专用图（`<id>_sleep.png`，缺失回退普通卡图）。
	var box := Rect2(rect.position,
			Vector2(rect.size.x, rect.size.y * UiTheme.CARD_ART_RATIO))
	if box.size.x < 6.0 or box.size.y < 6.0:
		return
	var tex := art_for(card.pic_id(), sleeping, phase)
	# R637：取图认 `pic_id()` —— 组合产物 id 归 0，卡图仍要出属性槽那张。
	if tex != null:
		# 覆盖式铺满（cover）：卡图出血到卡边、不留白（R165 开放式卡图）。
		tex = UiAssets.filtered(tex, ceili(maxf(box.size.x, box.size.y) * 1.5))
		canvas.draw_texture_rect_region(tex, box, cover_region(tex.get_size(), box), Color.WHITE)
	else:
		# 无图回退（R165）：卡种/职业色的**淡彩竖向渐变横幅**代替「粗暴纯色块」——
		# 自然、按卡分色（职业优先，中立回落卡种）。
		var cols := banner_cols(card)
		_draw_vgradient(canvas, box, cols[0], cols[1])
		var glyph: Color = cols[1]
		glyph.a = 0.40
		_draw_center(canvas, font_bold, int(minf(box.size.x, box.size.y) * 0.9),
				_display_name(card).substr(0, 1), box.get_center(), glyph)
	# R498：卡图区窄边框（按归属分色）—— 卡图之后、待确认角标之前（角标要压在最上层）。
	# 有图无图都画：无图回退的渐变横幅同样需要一圈边框，否则那一档卡看起来「没做完」。
	_draw_art_frame(canvas, card, box, k)
	# R478：未确认卡图打角标（AI 生成、待人工确认）。
	if tex != null and is_pending_art(card.pic_id()):
		_draw_pending_mark(canvas, box, k)


static func art_frame_kind(card: CardData) -> String:
	## R498：卡图区窄边框的归属键（素材槽 `art_frame_<kind>.png` 的后缀）。
	## 判定顺序写死：**敌人 → 三个职业 → 公用**。
	## ⚠️ 敌人优先：敌人卡也有 `class`（森林精魄 / 机械之心…），一律红框才读得出来。
	## ⚠️ 用 `card.card_class`（卡面原始职业），**不跟** `PlayerClass.skin_class()` ——
	##    公用初始卡要永远保持白框，跟着当前职业变色的话「公用」这一档就永远看不见了。
	if card == null:
		return ""
	if card.is_enemy_card():
		return "enemy"
	match card.card_class:
		"森林精魄":
			return "forest"
		"暗影刺客":
			return "shadow"
		"机械之心":
			return "mech"
	return "common"


static func _draw_art_frame(canvas: CanvasItem, card: CardData, box: Rect2, k: float) -> void:
	## 卡图区的窄边框（R498）：素材整张**拉伸**贴合卡图区（200×160 → box，比例 1.25 恒定，
	## 所以不会变形，也因此**不需要九宫格**）。
	## 缺图回退 = 同色细线框：宽度按 `k` 缩放，视觉厚度接近素材的主环（8/160 ≈ 5%）。
	var kind := art_frame_kind(card)
	if kind == "":
		return
	var tex: Texture2D = UiAssets.art_frame(kind)
	if tex != null:
		canvas.draw_texture_rect(UiAssets.filtered(tex, ceili(maxf(box.size.x, box.size.y) * maxf(1.5, canvas.get_viewport_transform().get_scale().x))), box, false)
		return
	var col := Color("6b7280")
	match kind:
		"forest":
			col = Color("2c5233")
		"shadow":
			col = Color("14121c")
		"mech":
			col = Color("7a5c33")
		"common":
			col = Color("f6f9fc")
		"enemy":
			col = Color("8a1c1c")
	canvas.draw_rect(box.grow(-maxf(0.5, 1.0 * k)), col, false, maxf(1.0, 2.0 * k))


# ------------------------------------------------------------ 字段标志（R592）
## **字段不再走文字**（用户口径 R592：「所有贴在卡上的 buff 都不再用纯文字」）。
## 卡面右上角有一个**圆形槽位**，同一时刻只显示一个字段标志；卡上有多个字段时
## 按 `AFFIX_BADGE_CYCLE_MS` 轮流切换（收尾交叉淡化 `AFFIX_BADGE_FADE_MS`）。
##   · 素材：`assets/ui/affix_<glyph>.png`（`CardData.affix_glyph()` 给名字），
##     缺图回退 `CardInfoBoxes.draw_glyph()` 的矢量符号 + 语义色圆底。
##   · 位置（R592e）：**与费用徽章镜像对称** —— 费用圆心在卡片左上角（`cost_badge_center`），
##     字段标志圆心就在卡片**右上角**（`affix_badge_center`），两枚关于卡面竖直中轴对称。
##     半径也走同一个 `badge_radius()`（= `CARD_BADGE_R × min(k, CARD_BADGE_SCALE_CAP)`），
##     与费用**同尺寸**，圆心同样压在框线上、一半探出卡外。
##     于是玩家的眼睛只要记一对角：左上 = 费用，右上 = 字段。
##     ⚠️ 它必然压在稀有度缎带上（缎带挂在右上角），这是店长明确接受的：
##        「略微遮挡旗子也无所谓」。绘制顺序在缎带之后 → 标志在上层。
##     ⚠️ 试过「底部正中、与数值徽章同一行」：四枚数值徽章圆心全压在卡框线上、
##        彼此相切，中间只剩 2.8k 的缝，放不进可读的标志（要腾位得把徽章砍到 5k）。
##   · 战场卡面（`on_board`）沿用 `affix_on_board()` 过滤：交换 / 幻影上场后不再显示。
## ⚠️ R592e：**没有独立的尺寸常量** —— 直径就是 `2 × badge_radius(rect)`，
## 与费用 / 力量 / 生命那几个数值徽章同一口径（改尺寸只改 `UiTheme.CARD_BADGE_R`）。
const AFFIX_BADGE_CYCLE_MS := 1800     # 单个标志停留时长
const AFFIX_BADGE_FADE_MS := 240       # 收尾交叉淡化时长


static func affix_badge_queue(card: CardData, on_board := false) -> Array[String]:
	## 这张卡**要轮流显示**的字段（中文名，按 `affixes` 顺序）。两层过滤：
	##   · `CardData.affix_badge_on_card()` 为 false 的字段**卡面一律不出图标**
	##     （R592d 起没有字段用它 —— 交换已按店长口径恢复显示）；
	##   · 战场卡面再滤掉「上场之后已无作用」的（幻影），与旧文字行同一口径。
	var out: Array[String] = []
	if card == null:
		return out
	for a: String in card.affixes:
		if not CardData.affix_badge_on_card(a):
			continue
		if on_board and not CardData.affix_on_board(a):
			continue
		out.append(a)
	return out


static func affix_badge_center(rect: Rect2) -> Vector2:
	## **字段标志的圆心**（R592e）= 卡片的**右上角**。
	## 与 `cost_badge_center()`（左上角）关于卡面竖直中轴对称 —— 店长口径
	## 「放到和费用对应的位置」：左上读费用、右上读字段，视线只用记住一对角。
	## 圆心压在框线上（一半露在卡外），与费用徽章完全一样的手感。
	return Vector2(rect.end.x, rect.position.y)


static func affix_badge_rect(card: CardData, rect: Rect2, on_board := false) -> Rect2:
	## **圆形槽位的唯一口**（绘制与回归共用，别各算一遍）。
	## 没有字段 → 空 Rect2（`size == Vector2.ZERO`）。
	## R592e：圆心 = `affix_badge_center()`（卡框右上角），半径 = `badge_radius()`
	## —— 与费用徽章**同尺寸、同「挂在框上」的位置关系**，允许压住稀有度缎带。
	if card == null or affix_badge_queue(card, on_board).is_empty():
		return Rect2()
	var r: float = badge_radius(rect)
	var c := affix_badge_center(rect)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


static func affix_badge_state(card: CardData, on_board: bool, now_ms: int) -> Dictionary:
	## 字段轮播状态：`{count, index, next, fade}`。
	## `fade` = 0 全然是 `index`，= 1 全然是 `next`（`next == -1` 表示没有下一张）。
	## 只有一张时不轮播（fade 恒 0）；多张按环形推进 —— 到末尾自然接回第 0 张。
	## ⚠️ R656 起算法搬进 `badge_slot_state()`（状态与字段共用一条队列），这里只做薄包装
	##    —— 回归断言的旧入口与旧语义一个字都没变。
	return badge_slot_state(affix_badge_queue(card, on_board).size(), now_ms)


static func affix_badge_text(card: CardData, on_board: bool, now_ms: int) -> String:
	## 此刻**正在显示**的字段名（测试与悬停提示共用；不进绘制路径）。
	var q := affix_badge_queue(card, on_board)
	if q.is_empty():
		return ""
	var st := affix_badge_state(card, on_board, now_ms)
	return q[int(st["index"])]


# ------------------------------------------------------------ 状态槽位（R656）
## 店长口径 R656：**卡面不再出现任何文字标记**。原来那六块文字底板
## （嘲讽 / 冰封 / 眩晕 / 沉睡 N / 倒数 N / 可发动 F，画在 `battle_scene._draw_state_badge`）
## 全部取缔 —— 状态改成**图标**，排进右上角那个圆槽，与字段图标共用同一条轮播队列。
##   · 顺序：**状态在前、字段在后**。「下回合不能行动」比「有疾行」紧急，轮播时先露它。
##   · 数据形状 `{glyph, label, count, affix}`：
##       - `affix = true` → 有素材就贴 `assets/ui/affix_<glyph>.png`（缺图走矢量回退）；
##       - `count > 0`   → 圆徽**右下角**贴数字角标（沉睡还剩几下 / 倒数还剩几回合）。
##         ⚠️ 数字不算「文字标记」：那是决策信息，去掉后玩家得点开详情才知道
##            「现在打它值不值」（R76 就有这个口径）。
##   · `label` 只给悬停提示与回归用，**不上卡面**。

static func badge_slots(card: CardData, on_board: bool, states: Array = []) -> Array[Dictionary]:
	## **槽位队列的唯一口** = 调用方给的状态 + 卡面自带的字段。
	if card == null:
		return []
	var out: Array[Dictionary] = []
	for sv: Variant in states:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = sv
		var g := String(sd.get("glyph", ""))
		if g == "":
			continue
		out.append({"glyph": g, "label": String(sd.get("label", "")),
				"count": int(sd.get("count", 0)), "affix": false})
	for a: String in affix_badge_queue(card, on_board):
		out.append({"glyph": CardData.affix_glyph(a), "label": a, "count": 0, "affix": true})
	return out


static func badge_slot_state(n: int, now_ms: int) -> Dictionary:
	## 轮播的**唯一实现**（`affix_badge_state()` 只是它的薄包装，节拍完全同一套）。
	## 返回 `{count, index, next, fade}`：`fade = 1` 表示整张已经是 `next`。
	if n <= 0:
		return {"count": 0, "index": 0, "next": -1, "fade": 0.0}
	if n == 1:
		return {"count": 1, "index": 0, "next": -1, "fade": 0.0}
	var cycle := AFFIX_BADGE_CYCLE_MS
	var t: int = now_ms % (cycle * n)
	var idx: int = int(t / cycle)
	var phase: int = t % cycle
	var fade := 0.0
	var nxt := -1
	if phase > cycle - AFFIX_BADGE_FADE_MS:
		fade = float(phase - (cycle - AFFIX_BADGE_FADE_MS)) / float(AFFIX_BADGE_FADE_MS)
		nxt = (idx + 1) % n
	return {"count": n, "index": idx, "next": nxt, "fade": clampf(fade, 0.0, 1.0)}


static func badge_slot_rect(has_any: bool, rect: Rect2) -> Rect2:
	## 圆槽**唯一口**（与 `affix_badge_rect()` 同一圆心半径，只是不关心队列来源）。
	if not has_any:
		return Rect2()
	var r: float = badge_radius(rect)
	var c := affix_badge_center(rect)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


static func _state_style(glyph: String) -> Array:
	## 状态图标的语义色（底 / 线）：沿用被取缔的那套文字底板配色，玩家不用重学。
	match glyph:
		"stun":
			return [Color(0.24, 0.16, 0.02), Color(1.0, 0.85, 0.36)]
		"frozen":
			return [Color(0.04, 0.16, 0.30), Color(0.90, 0.98, 1.0)]
		"sleep":
			return [Color(0.13, 0.07, 0.24), Color(0.93, 0.86, 1.0)]
		"fuse":
			return [Color(0.28, 0.09, 0.03), Color(1.0, 0.93, 0.86)]
		"activate":
			return [Color(0.08, 0.20, 0.06), Color(0.94, 1.0, 0.82)]
		"taunt":
			return [Color(0.20, 0.11, 0.02), Color(1.0, 0.84, 0.40)]
		_:
			return [Color(0.17, 0.16, 0.19), Color(0.94, 0.94, 0.96)]



static func _draw_affix_badges(canvas: CanvasItem, card: CardData, rect: Rect2,
		k: float, on_board: bool, now_ms := -1, states: Array = []) -> void:
	## 右上角圆形槽位（R592d：压在稀有度缎带上层）：先画下一张（淡入），
	## 再画当前张（淡出），交叉过渡不闪。
	## `now_ms` 可注入（截图 / 回归固定时刻用）；-1 = 读系统时钟。
	## `states`（R656）：战场状态槽位（`battle_scene._state_slots()` 给），空 = 只有字段。
	if card == null:
		return
	var slots := badge_slots(card, on_board, states)
	if slots.is_empty():
		return
	var box := badge_slot_rect(true, rect)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var st := badge_slot_state(slots.size(),
			now_ms if now_ms >= 0 else Time.get_ticks_msec())
	var fade: float = float(st["fade"])
	var nxt: int = int(st["next"])
	# 描边宽度跟徽章口径走（尺寸本身已由 `badge_slot_rect()` 决定，这里只管线宽）
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	if nxt >= 0 and fade > 0.0:
		_draw_one_badge(canvas, slots[nxt], box, kc, fade)
	_draw_one_badge(canvas, slots[int(st["index"])], box, kc, 1.0 - fade)


static func _draw_one_badge(canvas: CanvasItem, e: Dictionary, box: Rect2,
		k: float, alpha: float) -> void:
	## 单个槽位：素材优先 → 矢量回退 →（有 count 时）右下角数字角标。
	if alpha <= 0.01:
		return
	var glyph := String(e.get("glyph", ""))
	var label := String(e.get("label", ""))
	var is_affix: bool = bool(e.get("affix", false))
	var tex: Texture2D = UiAssets.affix_badge(glyph) if is_affix else null
	if tex != null:
		canvas.draw_texture_rect(tex, box, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		# 回退：语义色圆底 + 矢量符号（素材缺图时照常可玩，只是没那么精致）
		var cols: Array = CardData.affix_colors(label) if is_affix else _state_style(glyph)
		var bg: Color = cols[0]
		var fg: Color = cols[1]
		bg.a *= alpha
		fg.a *= alpha
		var c := box.get_center()
		canvas.draw_circle(c, box.size.y * 0.5, bg)
		canvas.draw_arc(c, box.size.y * 0.46, 0.0, TAU, 28,
				Color(fg.r, fg.g, fg.b, 0.9 * alpha), maxf(1.0, 1.2 * k))
		preload("res://scripts/card_info_boxes.gd").draw_glyph(
				canvas, c, box.size.y * 0.30, glyph, fg)
	var cnt := int(e.get("count", 0))
	if cnt > 0:
		_draw_count_pip(canvas, box, k, cnt, alpha)


static func _draw_count_pip(canvas: CanvasItem, box: Rect2, k: float,
		n: int, alpha: float) -> void:
	## 数字角标：圆徽**右下角**贴一枚小圆（半压在徽章边缘上），里面是剩余次数。
	## 为什么要它：沉睡 / 倒数都是「还剩几下」，纯图标只能告诉玩家「有这个状态」，
	## 说不出「现在打它值不值」—— 只有数字能。（R76 的老口径，文字底板取缔后由它接手。）
	## 图上写 `9+` 不再扩宽：真要知道确切数字去左侧信息栏 / 悬停，卡面只保证「快到了」。
	## ⚠️ R656 首版半径 0.32×槽位、圆心内缩 0.55 —— 出图后它把沙漏整个盖住了
	##    （槽位才 40px，角标直径 25px）。现在半径 0.24、圆心贴到角上，只咬掉槽位右下角。
	var pr := maxf(4.5, box.size.y * 0.24)
	var pc := Vector2(box.end.x - pr * 0.18, box.end.y - pr * 0.18)
	canvas.draw_circle(pc, pr, Color(0.07, 0.05, 0.03, 0.94 * alpha))
	canvas.draw_arc(pc, pr, 0.0, TAU, 18,
			Color(1.0, 0.97, 0.86, 0.90 * alpha), maxf(1.0, 0.9 * k))
	var f: FontFile = UiTheme.font_bold()
	var fs := maxi(8, roundi(pr * 1.45))
	var txt := str(n) if n < 10 else "9+"
	var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	canvas.draw_string(f, pc + Vector2(-tw * 0.5, float(fs) * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.98, 0.92, alpha))


static func _draw_one_affix_badge(canvas: CanvasItem, name: String, box: Rect2,
		k: float, alpha: float) -> void:
	## R656：旧入口保留（只画字段），内部走 `_draw_one_badge()` 的同一条绘制路径。
	_draw_one_badge(canvas, {"glyph": CardData.affix_glyph(name), "label": name,
			"count": 0, "affix": true}, box, k, alpha)


static func _draw_rarity_ribbon(canvas: CanvasItem, card: CardData, rect: Rect2,
		k: float, pad: float, h_override := 0.0) -> void:
	## 稀有度缎带（R170）：挂在卡面**右上角**的锦旗 —— 稀有度的**主通道**。
	## 素材 `assets/ui/ribbon_<0..5>.png`（透明底、燕尾下垂，下标同 RARITY_COLORS）；
	## 缺图回退**同形状的程序缎带**（杆 + 布条 + 燕尾，色取 `rarity_color()`）。
	## ⚠️ 必须画在卡图**之后**：开放式卡图铺满上半，先画会被整个盖住（旧小旗就是这么没的）。
	## ⚠️ 尺寸（R173）：旗高 27k ≈ 卡高的 39% —— R170 第一版只有 13k，细长燕尾被压成
	##    一条 6px 细线，肉眼观感 = 「没应用素材」；27k 后金绣/燕尾在各种卡尺寸下都可辨认。
	## ⚠️ R643：**款式只能由 `card.rarity` 决定**，调用方不许自己挑素材。
	##    奖励三选一曾写死「史诗→紫缎带 / 其它→金缎带」，于是稀有 / 初始 / 怪物 / 事件
	##    全挂金缎带，跟卡下方的稀有度铭牌对不上（用户实测「搭配不上」）。
	##    `h_override > 0` 只换高度（奖励页卡大，要跟它自己的尺寸口径），不换款式。
	var rh: float = 27.0 * k
	if h_override > 0.0:
		rh = h_override
	var ribbon: Texture2D = UiAssets.rarity_ribbon(card.rarity)
	if ribbon != null:
		var rw: float = rh * ribbon.get_width() / maxf(1.0, ribbon.get_height())
		var rx: float = rect.end.x - pad - rw
		var ry: float = rect.position.y - 1.2 * k   # 横杆骑在卡顶边（微探出 = 「挂」在卡上）
		canvas.draw_texture_rect(ribbon, Rect2(rx, ry, rw, rh), false)
		return
	_draw_ribbon_procedural(canvas, card, rect, k, pad, rh)


static func _draw_ribbon_procedural(canvas: CanvasItem, card: CardData, rect: Rect2,
		k: float, pad: float, rh: float) -> void:
	## 无素材时的程序缎带（R643）：**形状照素材**（顶部卷轴杆 + 下垂布条 + 燕尾缺口），
	## 颜色取 `rarity_color()` —— 缺的是图，不是「这一档不该是缎带」。
	## 旧版回退是三角小旗：挂在满排燕尾缎带里一眼就看得出「这张没配图」
	## （诅咒 9149 / 9154 / 9157 / 9185 就是这样，rarity 6 没素材）。
	var col: Color = card.rarity_color()
	var rw: float = rh * 0.30                 # 布条宽 ≈ 素材 56/192（其余几档也在 0.29~0.40）
	var bar_h: float = maxf(2.0, rh * 0.045)
	var rx: float = rect.end.x - pad - rw
	var ry: float = rect.position.y - 1.2 * k
	# ① 卷轴杆：横跨布条、两端各探出一点
	var bar := Rect2(rx - rw * 0.06, ry, rw * 1.12, bar_h)
	canvas.draw_rect(bar, col.lightened(0.35))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar_h * 0.45)), col.lightened(0.62))
	# ② 布条：顶边齐杆下，底边做燕尾（中间抬到 84% 高）
	var top: float = ry + bar_h
	var bot: float = ry + rh
	var notch: float = bot - rh * 0.16
	var cloth := PackedVector2Array([
			Vector2(rx, top), Vector2(rx + rw, top),
			Vector2(rx + rw, bot), Vector2(rx + rw * 0.5, notch),
			Vector2(rx, bot)])
	canvas.draw_colored_polygon(cloth, col)
	# ③ 两条暗边 + 一条亮褶：平涂也要看得出是「布」
	var edge_w: float = maxf(1.0, rw * 0.07)
	canvas.draw_line(Vector2(rx + edge_w * 0.5, top), Vector2(rx + edge_w * 0.5, bot),
			col.darkened(0.4), edge_w)
	canvas.draw_line(Vector2(rx + rw - edge_w * 0.5, top), Vector2(rx + rw - edge_w * 0.5, bot),
			col.darkened(0.4), edge_w)
	canvas.draw_line(Vector2(rx + rw * 0.42, top + bar_h), Vector2(rx + rw * 0.42, notch),
			col.lightened(0.28), maxf(1.0, rw * 0.10))


static func banner_cols(card: CardData) -> Array:
	## 卡面横幅色 = [上端, 下端]：职业色优先（中立回落卡种色），向白混合成淡彩。
	## R277：**无图回退横幅**也按卡的**归属**上色 —— 189 张卡还没有卡图，横幅就是它们的
	##    卡面，颜色不跟归属走的话「敌人红 / 公用灰」在这些卡上根本看不见
	##    （原来敌人卡取卡种色、公用卡取卡种色，一张盟友卡永远是绿的）。
	# R328：与 paper_tint 同一条口径（公用初始卡跟当前职业），两处不能各写一份。
	var c: Color = UiTheme.class_color(PlayerClass.skin_class(card.id, card.card_class))
	if c.a <= 0.01:
		c = UiTheme.kind_color(card.kind)
	var w := Color(1, 1, 1)
	return [c.lerp(w, UiTheme.KIND_BANNER_TOP), c.lerp(w, UiTheme.KIND_BANNER_BOT)]


static func _draw_vgradient(canvas: CanvasItem, rect: Rect2, top: Color, bot: Color) -> void:
	## 竖向渐变填充（无图回退横幅）。逐条水平带插值 —— 无素材依赖、headless 安全。
	var steps := maxi(2, int(rect.size.y / 3.0))
	var sh := rect.size.y / float(steps)
	for i in steps:
		var t := float(i) / float(steps - 1)
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + i * sh, rect.size.x, sh + 1.0),
				top.lerp(bot, t), true)


static func text_zone_layout(card: CardData, rect: Rect2, font: Font, font_bold: Font,
		pad: float) -> Dictionary:
	## 卡面文字区（卡名 → 种类 → 效果文）的**唯一排版口**（R631）。
	## 绘制 `_draw_text_zone` 与体检探针 `tools/probe_r631_textfit.gd` 共用这一份 ——
	## 两边各算一套的亏已经吃过：`fit_text_lines` 按 `行数 × 行高 ≤ 可用高` 判（多算半行），
	## 绘制又按「末行墨迹底」重算一遍能画几行，于是 fit 说 4 行放得下、绘制只肯画 3 行，
	## 第 4 行被补成「…」（用户口径「激光巨炮的描述超过了格子」）。
	##
	## 返回字段：`ok` / `top` / `bottom` / `maxw` / `name_sz` / `ninfo` / `base_name` /
	## `meta_sz` / `base_meta` / `has_meta` / `eff_text` / `eff_sz` / `eff_lines` /
	## `line_h` / `eff_base0` / `eff_n` / `eff_truncated`。
	var out := {"ok": false, "eff_truncated": false, "eff_n": 0, "eff_lines": []}
	var top: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_TOP + pad
	var bottom: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_BOTTOM - pad
	bottom = minf(bottom, text_zone_bottom(rect))
	if bottom - top < 6.0:
		return out
	var kt: float = minf(scale_of(rect), UiTheme.CARD_TEXT_SCALE_CAP)
	var sz: int = maxi(7, roundi(UiTheme.CARD_FS_TEXT * kt))
	var maxw: float = rect.size.x * (UiTheme.CARD_NAMEPLATE_X1 - UiTheme.CARD_NAMEPLATE_X0) - pad * 2.0
	var row_h: float = maxf(font.get_height(sz), font_bold.get_height(sz))
	var desc: float = float(font.get_descent(sz))
	var ninfo := name_layout(_display_name(card), rect, font_bold, bottom - top)
	var nsz: int = int(ninfo["sz"])
	var base_name: float = minf(top + float(nsz) * 0.88, bottom - float(nsz) * 0.22)
	var base_meta: float = base_name + row_h                 # 种类行基线
	var has_meta: bool = base_meta + desc <= bottom
	var eff_base0: float = base_meta + row_h                 # 效果首行基线
	var eff: String = CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
	var eff_sz: int = sz
	var eff_lines: Array = []
	var line_h: float = sz * 1.16
	var eff_n: int = 0
	if eff != "":
		# R569：**超框缩字号**；R631：① 缩到 6px（原来 7px + 只降 5 档，长文案必截断）；
		# ② `last_line_descent = true` → 判据改成「末行墨迹底」，与下面算 eff_n 的公式**同一套**。
		var avail_h: float = bottom - eff_base0
		var fit := fit_text_lines(font, eff, maxw, avail_h, sz, maxi(6, sz - 8), 99, true)
		eff_sz = int(fit["fs"])
		eff_lines = fit["lines"]
		line_h = float(fit["line_h"])
		if avail_h > 0.0:
			var dh: float = float(font.get_descent(eff_sz))
			eff_n = maxi(0, int(floor((avail_h - dh) / line_h)) + 1)
		eff_n = mini(eff_lines.size(), eff_n)
	return {
		"ok": true, "top": top, "bottom": bottom, "maxw": maxw,
		"name_sz": nsz, "ninfo": ninfo, "base_name": base_name,
		"meta_sz": sz, "base_meta": base_meta, "has_meta": has_meta,
		"eff_text": eff, "eff_sz": eff_sz, "eff_lines": eff_lines,
		"line_h": line_h, "eff_base0": eff_base0, "eff_n": eff_n,
		"eff_truncated": eff_n < eff_lines.size(),
	}


static func _draw_text_zone(canvas: CanvasItem, card: CardData, rect: Rect2, kt: float,
		k: float, pad: float, sep_y: float, hp: int, font: Font, font_bold: Font,
		on_board: bool, is_tapped := false, name_only := false) -> void:
	## 文字区（下半）：**卡名 → 种类 · 字段 → 效果文字**，按这个优先级往下排，排不下的整块省略。
	##
	## ⚠️ 「种类」与「字段」**合并成一行**（`盟友 · 迅捷`）—— 分成两行的话，
	##    58×70 / 98×119 这类尺寸上光是这两行就把文字区吃光，效果文字永远轮不到。
	## ⚠️ 效果文字**只在排得下完整一行时**才画 —— 小卡上排「半行字 + 省略号」比不排
	##    更难看，而且玩家根本读不到信息。
	##
	## ⚠️ R164 版式重写（用户口径「文字和卡面的布局对应不上，白底上描边的字难以辨认」）：
	##   ① **所有行共用一个基线基准**：卡名基线 = `top + ascent`，下面每行依次 +`row_h`。
	##      旧版卡名经 `_draw_center`（内部 **+0.36 字号**）下移，而「种类」直接 `draw_string`
	##      不下移 —— 两条基线只差 `row_h - 0.36×字号`，大卡上卡名与种类**必然叠字**
	##      （奖励三选一 216×260 实测：字糊成一片），效果首行也一起挤上来。
	##   ② **先算「画到哪一行」，再画字**：文字块整块落在姓名牌内框里，上不盖分隔金条、
	##      下不吃底部数值徽章 —— 文字与卡面因此对得上。
	##   ③ 文字**一律不描边**，也**不铺底衬**（R208）：可读性靠 card_paper 姓名牌那块
	##      羊皮纸；贴一块程序画的长方形反而像贴纸（用户口径）。
	# name_only（战斗内卡面口径）：只画居中卡名，不画种类·字段与效果文 ——
	# 效果详情由悬停/点选的描述面板提供（战斗左栏信息 / 选卡界面底部描述条）。
	if name_only:
		_draw_name_zone(canvas, card, rect, kt, k, pad, font_bold, true)   # 战斗内：贴金条上移，避开底部徽章
		return
	# R631：排版全部交给 `text_zone_layout()` —— 这里只负责「照着画」，
	# 不再自己算第二套字号 / 行数（两套判据就是「描述超过格子」的根因）。
	var L := text_zone_layout(card, rect, font, font_bold, pad)
	if not bool(L["ok"]):
		return
	var maxw: float = float(L["maxw"])
	var cx: float = rect.position.x + rect.size.x * (UiTheme.CARD_NAMEPLATE_X0 + UiTheme.CARD_NAMEPLATE_X1) / 2.0
	var sz: int = int(L["meta_sz"])
	var kind_col: Color = UiTheme.kind_color(card.kind)
	var meta_a: String = card.kind
	# R592：**字段改走右上角标志**（`_draw_affix_badges`），这一行只剩卡种。
	# 字段名不再出现在文字里 —— 用户口径「所有贴在卡上的 buff 都不再用纯文字」。
	# `card.affix_line()` / `field_affix_line()` 保留：它们是数据层口径
	# （悬停浮层 / 战场徽标 / 测试仍在用），只是卡面不再画。
	var affix_txt: String = ""
	var meta_b: String = (" · " + affix_txt) if affix_txt != "" else ""
	var nsz: int = int(L["name_sz"])
	var ninfo: Dictionary = L["ninfo"]
	var base_name: float = float(L["base_name"])
	var base_meta: float = float(L["base_meta"])
	# ── 画字（**不描边**）───────────────────────────────────────────────
	# R203：卡名横幅（R165 的 banner 渐变条）已去掉 —— 用户口径「卡名后面垫着的那条
	# 绿色长方形直接去掉，卡名直接放在上面就好」；卡名直接画在羊皮卷/木板底衬上。
	# R281：卡名恒单行（宽度自适应 → 超宽横向滚动），不再折行；超宽时也不省略。
	if bool(ninfo["need_scroll"]):
		_draw_name_marquee(canvas, font_bold, nsz, _display_name(card),
			rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad,
			base_name, float(ninfo["maxw"]), UiTheme.INK_900, float(ninfo["text_w"]))
	else:
		_draw_center(canvas, font_bold, nsz, _display_name(card),
			Vector2(cx, base_name - nsz * 0.36), UiTheme.INK_900)
	if bool(L["has_meta"]):
		var wa: float = font.get_string_size(meta_a, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var wb: float = font.get_string_size(meta_b, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		# ⚠️⚠️ 这里踩过一个**让整个游戏未响应**的坑，改这一行前务必读完：
		#   起初写的是 `meta_b = meta_b.substr(0, meta_b.length() - 1) + "…"` ——
		#   去掉最后一个字符再补一个 `…`，**长度恒定不变**；而且末位一旦是 `…`，
		#   下一轮会得到**完全相同的字符串**（末位被换成 `…`，再砍一位又补回 `…`）。
		#   于是只要「种类 + 长字段」一开始就超宽，这个循环**永远退不出来**。
		#   它在 `_draw()` 里 → 整帧不返回 → 游戏直接未响应。图鉴会画全部卡
		#   （里面有带字段的），所以必中、必卡死，表现为「一打开就卡住」。
		#   两条保险：① 每次砍 **2** 个字符（长度严格递减）；② 再加一个硬上限兜底
		#   —— 绘制代码里的循环**绝不允许**只依赖「条件终将不成立」来退出。
		var meta_guard := 0
		while meta_b != "" and wa + wb > maxw and meta_b.length() > 2 and meta_guard < 64:
			meta_b = meta_b.substr(0, meta_b.length() - 2) + "…"
			wb = font.get_string_size(meta_b, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			meta_guard += 1
		var mx: float = cx - (wa + wb) / 2.0
		canvas.draw_string(font, Vector2(mx, base_meta), meta_a,
				HORIZONTAL_ALIGNMENT_LEFT, -1, sz, kind_col)
		if meta_b != "":
			canvas.draw_string(font, Vector2(mx + wa, base_meta), meta_b,
					HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiTheme.STAT_POWER)
	# R631：效果文整行**不传 width** —— `draw_string` 的 width 会把超出部分直接裁掉，
	# 贴边的那半个词（幻影斗篷的「力量 -1」）会凭空消失。宽度由折行保证，这里只管画。
	var eff_lines: Array = L["eff_lines"]
	var eff_n: int = int(L["eff_n"])
	var eff_sz: int = int(L["eff_sz"])
	var line_h: float = float(L["line_h"])
	var eff_base0: float = float(L["eff_base0"])
	for i in eff_n:
		var t: String = str(eff_lines[i])
		if i == eff_n - 1 and eff_lines.size() > eff_n:
			t = _ellipsize(font, t + "…", maxw, eff_sz)
		canvas.draw_string(font, Vector2(rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad,
				eff_base0 + line_h * i), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, eff_sz, UiTheme.INK_600)


static func _draw_badges(canvas: CanvasItem, font_bold: Font, card: CardData, rect: Rect2,
		k: float, kc: float, hp: int, power_override: int,
		speed_override := -1, range_override := -1) -> void:
	## 数值「额外挂载」。位置是**固定槽位**，与卡的种类无关 ——
	## 玩家的眼睛只需要记一次坐标：
	##   ① 费用 = 卡框左上角 · ② 力量 = 卡框左下角（与 ① 同一条竖线）
	##   ③ 攻击距离 = ② 右侧 · ④ 移动距离 = ⑤ 左侧 · ⑤ 生命 = 卡框右下角
	## ⚠️ 于是 ② 与 ⑤ **分别向左右探出卡框**（R115 用户口径）—— 容器必须让出
	##    `UiTheme.CARD_BLEED`，少让一点这两张就会骑到邻卡身上。
	# R387（用户口径「启示者 2 阶段减 1 速度的显示正常吗？」）：程 / 速 与力量同一口径 ——
	# 战场单位传 `effective_range()` / `effective_speed()`，徽章写**真正生效的数**，
	# 并按卡库原型染色（2 → 1 = 红）。手牌 / 图鉴 / 选卡页不传，保持卡面粉数值。
	var r: float = UiTheme.CARD_BADGE_R * kc
	var gap: float = UiTheme.CARD_BADGE_GAP * kc
	var fs: int = maxi(7, roundi(UiTheme.CARD_FS_BADGE * kc))
	# ── ① 左上角：费用（水晶）—— 圆心压在卡框左上角上 ──
	# X 费卡（流星雨 9083）：费用不是定值 → 徽章上直接画「X」
	# R373：**不能打出**的诅咒（麻痹 9185）把费用位打成「×」——
	# 比写 0 更清楚：玩家一眼知道「这不是 0 费能白嫖的牌，是根本打不出去」。
	var cost_txt := "X" if card.x_cost else str(card.cost)
	if card.unplayable:
		cost_txt = "×"
	draw_badge(canvas, font_bold, cost_badge_center(rect), r, fs, "cost",
			cost_txt, UiTheme.BADGE_COST)
	# 技能 / 效果卡没有攻防数值，只有费用
	var is_unit: bool = card.kind == "盟友"
	if not is_unit and card.kind != "工事":
		return
	# ── 底部一排：圆心落在卡片**下边缘**上（一半挂在卡外）──
	# 最外两张的圆心就压在**卡的左右框线**上 → 整排比卡宽左右各多一个半径。
	var bar_y: float = rect.end.y
	var step: float = 2.0 * r + gap
	var power_x: float = rect.position.x      # ② 与 ① 同一条竖线（卡框左沿）
	var range_x: float = power_x + step       # ③
	var health_x: float = rect.end.x          # ⑤ 与 ① 左右反向（卡框右沿）
	var speed_x: float = health_x - step      # ④
	# ── ② 力量（剑） + ③ 攻击距离（弓）──
	# ── R301：四项数值相对**卡库原型**的染色 ──
	# 力 / 程 / 速：单一维度（高 = 绿 / 低 = 红 / 一样 = 白）。
	# 生命：**四态**（受伤红 / 高于原本绿 / 等于原本白 / 低于原本黄）—— 见 `_health_col()`。
	# 手卡 / 场上 / 弃牌区 / 图鉴全部走这里，调用方不用管（也不用各自判涨跌）。
	var bv := _base_vals(card)
	# R325：难度档位给的攻 / 血**不算「变强」** —— 算进基准，卡面保持白字
	#（用户口径「因难度选择而增加的，依然显示白色，视为没有增加过」）。
	# ⚠️ 只加在本地副本上：`_base_vals()` 的字典是**按 id 缓存**的，改它会污染同 id 的
	#    所有卡（手牌里那张没有难度加成，也会跟着变成「本来就这么高」）。
	var base_power: Variant = bv.get("power")
	if base_power != null:
		base_power = int(base_power) + card.diff_power
	var base_health: Variant = bv.get("health")
	if base_health != null:
		base_health = int(base_health) + card.diff_health
	var shown_power: int = power_override if power_override >= 0 else card.power
	# R467：**X 费单位**（传说卡「枭熊」9213）—— 力 / 生都要等落地才有值，卡面写 X / 9X，
	# 否则手牌里永远是「0 攻 0 血」，读起来像张废卡。
	# ⚠️ 9X 的倍数与 `GameEngine.OWLBEAR_HP_PER_X` 是同一个数（那边改，这里也要改）。
	var x_unit := card.x_cost and card.kind == "盟友"
	draw_badge(canvas, font_bold, Vector2(power_x, bar_y), r, fs, "power",
			"X" if x_unit else str(shown_power), UiTheme.BADGE_POWER,
			UiTheme.BADGE_VALUE if x_unit else _delta_col(shown_power, base_power))
	var shown_range: int = badge_shown(card.attack_range, range_override)
	draw_badge(canvas, font_bold, Vector2(range_x, bar_y), r, fs, "range",
			str(shown_range), UiTheme.BADGE_RANGE,
			_delta_col(shown_range, bv.get("range")))
	# ── ④ 移动距离（鞋）+ ⑤ 生命（血）──
	# ⚠️ 阅读方向必须与左半排一致（力 程 … 速 生）：跨过中间空档后仍是「先读到的在左」。
	# 先前按「离卡角最近的是第一个」做成镜像（力 程 速 生 → 生 速），出图一看就读反了 ——
	# 两组之间「先读到的那个」忽左忽右，比单纯难看更糟：会读错数值。
	# 工事不会移动 → 不画鞋，生命直接占最外侧那张（贴右框线）。
	if is_unit:
		var shown_speed: int = badge_shown(card.move_speed, speed_override)
		draw_badge(canvas, font_bold, Vector2(speed_x, bar_y), r, fs, "speed",
				str(shown_speed), UiTheme.BADGE_SPEED,
				_delta_col(shown_speed, bv.get("speed")))
	draw_badge(canvas, font_bold, Vector2(health_x, bar_y), r, fs, "health",
			"9X" if x_unit else str(hp), UiTheme.BADGE_HEALTH,
			UiTheme.BADGE_VALUE if x_unit else _health_col(card, hp, base_health))


static func badge_shown(cur: int, override: int) -> int:
	## 数值徽章的**显示值**（R387）：override >= 0 → 用它，否则用卡面粉数值。
	## 力量早已走 `power_override`；这里把程 / 速 补成同一口径 ——
	## 「显示值 == 实际生效值」是卡面的硬约束，染色也跟着显示值算。
	## 抽成静态口是为了回归能直接断言，不必先起一个 CanvasItem 去画。
	return override if override >= 0 else cur


static func _base_repo() -> CardRepo:
	## 卡库单例（懒加载）：`CardRepo.load_json()` 每次都会读盘，卡面绘制不能那么干。
	if _repo_cache == null:
		_repo_cache = CardRepo.load_json()
	return _repo_cache


static func _base_vals(card: CardData) -> Dictionary:
	## 这张卡的**卡库原型**四项数值（{power, health, range, speed}）。
	## 找不到（动态生成的衍生物 / 卡库没有的 id）→ 空字典 = 一律按「没变」处理（不染色）。
	if card == null:
		return {}
	# R637：染色基准认 `pic_id()` —— 产物 id 归 0，但它的身材来自属性槽那张，基准还是它。
	if _base_cache.has(card.pic_id()):
		return _base_cache[card.pic_id()]
	var d := {}
	var repo := _base_repo()
	var proto: CardData = repo.get_card(card.pic_id()) if repo != null else null
	if proto != null:
		d = {"power": proto.power, "health": proto.health,
				"range": proto.attack_range, "speed": proto.move_speed}
	_base_cache[card.pic_id()] = d
	return d


static func _delta_col(cur: int, base: Variant) -> Color:
	## 当前值 vs 卡库原型：高了绿、低了红、一样就保持白色（默认）。
	## `base == null`（原型查不到）→ 白字，绝不给一个来路不明的红/绿。
	if base == null:
		return UiTheme.BADGE_VALUE
	var b := int(base)
	if cur > b:
		return UiTheme.BADGE_UP
	if cur < b:
		return UiTheme.BADGE_DOWN
	return UiTheme.BADGE_VALUE

static func _health_col(card: CardData, cur_hp: int, base: Variant) -> Color:
	## 生命徽章的**四态**染色（R301，用户口径）。生命不能只按「比原本高/低」一个维度：
	## 「最大生命被削」和「当前受伤」是两件事，用同一套红绿会互相掩盖。
	##   ① 当前生命 < 最大生命（受过伤）  → **红**（受伤，优先级最高，压过涨跌）
	##   ② 满血 + 最大生命 > 原本          → **绿**（被加强）
	##   ③ 满血 + 最大生命 == 原本         → **白**（正常）
	##   ④ 满血 + 最大生命 < 原本          → **黄**（上限被削但没掉血：警示，不是损失）
	## ⚠️ `cur_hp` 与 `card.health` 都取**显示值**：战场传进来的是 `_show_hp()`（含尚未
	##    演出的伤害）→ 命中动画期间数字还没掉、颜色也还没变红，与数字严格同步。
	## ⚠️ 找不到原型（动态衍生物）→ 只判受伤、不判涨跌：没有基准就不该给出绿/黄。
	if base == null:
		return UiTheme.BADGE_HURT if cur_hp < card.health else UiTheme.BADGE_VALUE
	if cur_hp < card.health:
		return UiTheme.BADGE_HURT
	var b := int(base)
	if card.health > b:
		return UiTheme.BADGE_UP
	if card.health < b:
		return UiTheme.BADGE_WARN
	return UiTheme.BADGE_VALUE


static func _rel_lum(c: Color) -> float:
	## WCAG 相对亮度（对比度计算的中间量）。逐通道 sRGB 线性化后加权。
	var r: float = c.r / 12.92 if c.r <= 0.03928 else pow((c.r + 0.055) / 1.055, 2.4)
	var g: float = c.g / 12.92 if c.g <= 0.03928 else pow((c.g + 0.055) / 1.055, 2.4)
	var b: float = c.b / 12.92 if c.b <= 0.03928 else pow((c.b + 0.055) / 1.055, 2.4)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


static func _contrast(a: Color, b: Color) -> float:
	var la := _rel_lum(a)
	var lb := _rel_lum(b)
	if la < lb:
		var t := la
		la = lb
		lb = t
	return (la + 0.05) / (lb + 0.05)


static func _legible(col: Color, bg: Color, min_ratio := 3.0) -> Color:
	## R301：**缺图标**时数字压在语义色圆盘上，做一层对比度保底。
	## 典型冲突：生命圆盘本身就是亮红 `#c1121f`，「受伤红」压上去只有 2.0:1 —— 红字糊在
	## 红盘里，玩家根本读不出数字（用户明确指出这一点）。
	## 做法：保住色相、只往白里提，直到对比度达标（最多 8 档，8 档还不够就干脆用白）。
	## 有图标时**不走这里** —— 图标（酒滴画稿）本身是深底，原色已经够亮。
	if _contrast(col, bg) >= min_ratio:
		return col
	var c := col
	for _i in 8:
		c = c.lerp(Color.WHITE, 0.18)
		if _contrast(c, bg) >= min_ratio:
			return c
	return Color.WHITE

static func draw_badge(canvas: CanvasItem, font_bold: Font, center: Vector2, r: float, fs: int,
		key: String, value: String, disc: Color,
		value_col := UiTheme.BADGE_VALUE) -> void:
	## 单个数值挂件：**图标为底、数字压在图标上**。
	##
	## ⚠️ R122 起对外公开：battle_scene 的「动态减费」把费用槽重画成绿色数字时
	##    必须走这里（`disc` = 缺图标时的回退色，`value_col` = 数字颜色）。
	##    自己 draw_circle 会盖掉水晶图标 —— 那正是 R115 之后「降费看不见宝石」的原因。
	##
	## R115 用户口径：「并不需要严格的圆盘，直接用图标 + 数字就可以」——
	## 有图标时**不再垫那层深色圆盘**：图标素材本身就是一枚圆形徽记，再垫一层
	## 只是白占一圈面积（也就没法把图标画大了）。
	## ⚠️ 但**缺图标时仍然回退成语义色圆盘**：零素材下若只剩一个白色数字，
	##    在浅色卡面上会直接看不见 —— 信息不能丢。
	##
	## 数字按宽度自适应缩号：三位数（如鸭之暗面的 150 血）在 58px 小卡的图标上
	## 必然顶出去，缩到刚好放得下为止；缩到 6px 仍是极限就让它略微出格
	## ⚠️ R117：`CARD_FS_BADGE` 提到 12 之后，**两位数**（力量 1~30、生命 30~50 常见）
	##   在 20px 的战场徽章上正好卡在阈值内（sz=13 →「30」量宽 17 ≤ r×1.75 ≈ 17.5），
	##   不会再被悄悄缩小；三位数（如 150 血）仍会缩到 9px，属预期。
	## （宁可略宽也不缩成看不出来的小点）。
	var icon: Texture2D = UiAssets.filtered(UiAssets.badge_icon(key), ceili(r * 2.0 * maxf(1.5, canvas.get_viewport_transform().get_scale().x)))
	if icon != null:
		canvas.draw_texture_rect(icon, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		canvas.draw_circle(center, r, disc)
		canvas.draw_arc(center, r, 0.0, TAU, 20, disc.darkened(0.34),
				maxf(1.0, r * 0.16), true)
		# R301：没有图标素材时，数字是**直接压在语义色圆盘**上的。
		# 生命圆盘 = 亮红 #c1121f，而「受伤红」数字也是红 → 对比度只有 2:1，糊成一片。
		# 这里把数字往白里提到「至少 3:1」，保色相、只改亮度；有图标时不触发。
		value_col = _legible(value_col, disc)
	var sz: int = fs
	while sz > 6 and font_bold.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x 			> r * 1.75:
		sz -= 1
	# **数字一律描边**（不只是有图标时）：
	#   · 有图标：图标是花哨插画，不描边压不住；
	#   · 无图标：语义色圆盘只有 2R 直径，两位/三位数必然会溢出圆盘边缘
	#     （鸭之暗面 150 血、铁壁卫兵 30 血），溢出后白字落在白卡面上＝看不见。
	# 描边让「数字出格」从缺陷降级成可接受的排版。
	_draw_center_outlined(canvas, font_bold, sz, value, center, value_col)


static func stats_line(card: CardData, hp := -1) -> String:
	## 详情面板用的一行数值描述（hp<0 时用卡面生命）。
	var shown := hp if hp >= 0 else card.health
	match card.kind:
		"盟友":
			return GameI18n.ui("shared", "CARD_FACE_ALLY_STATS", "力量 %d   生命 %d   射程 %d   速度 %d") % [
				card.power, shown, card.attack_range, card.move_speed]
		"工事":
			return GameI18n.ui("shared", "CARD_FACE_FORT_STATS", "力量 %d   生命 %d   射程 %d") % [card.power, shown, card.attack_range]
		"技能":
			return GameI18n.ui("shared", "CARD_FACE_SKILL_STATS", "直接使用")
		"效果":
			return GameI18n.ui("shared", "CARD_FACE_EFFECT_STATS", "在效果区持续生效")
	return ""


static func growth_text(card: CardData) -> String:
	## R393b：这张卡「本局永久成长」的**紧凑标记**（`力+1` / `力+3 生+6` / `伤+6`）。
	## 没有成长 → 空串。力 / 生 / 伤 各一段，只列非零项。
	## ⚠️ 只认 `CardData` 上烤好的 `growth_*`（由 `RunState.card_with_mod()` 写在副本上），
	##    **不查 `RunState.card_growth`** —— 否则图鉴 / 奖励三选一里同 id 的卡
	##    会显示别处的成长，一张从没上过场的卡也会带角标。
	if card == null:
		return ""
	var parts: Array[String] = []
	if card.growth_power > 0:
		parts.append(GameI18n.ui("shared", "CARD_FACE_GROWTH_POWER", "力+%d") % card.growth_power)
	if card.growth_health > 0:
		parts.append(GameI18n.ui("shared", "CARD_FACE_GROWTH_HEALTH", "生+%d") % card.growth_health)
	if card.growth_damage > 0:
		parts.append(GameI18n.ui("shared", "CARD_FACE_GROWTH_DAMAGE", "伤+%d") % card.growth_damage)
	return " ".join(parts)


static func growth_mark_font(rect: Rect2, card: CardData = null, font_bold: Font = null) -> int:
	## 成长角标字号：跟 `ui_scale_of()` 走（有封顶），再把「装不下就缩」兜一层。
	## 牌库面板一张卡只有 76×92，`力+3 生+6` 是七段宽 —— 固定字号必然顶出卡框。
	var fs: int = maxi(7, roundi(9.5 * ui_scale_of(rect)))
	if card != null and font_bold != null:
		var maxw: float = maxf(24.0, rect.size.x - 6.0)
		var txt := growth_text(card)
		while fs > 7 and font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs).x > maxw:
			fs -= 1
	return fs


static func growth_mark_rect(card: CardData, rect: Rect2, font_bold: Font) -> Rect2:
	## 成长角标的**位置与尺寸唯一口**（绘制与回归都读它，别各算一遍）。
	## 位置：卡图区**左下角、贴着底边**，左沿只内缩 2px ——
	##   · 不向左出血（左侧那条「费用 / 附魔 / 力量」竖列已经占满）；
	##   · 不压卡名（姓名牌从 `CARD_ART_RATIO` 往下才出现）；
	##   · 与右下角的锁标记（`draw_pick` 才画）不同侧，不会撞。
	## 没有成长 → 空 Rect2（`size == Vector2.ZERO`）。
	## ⚠️ **战场小卡（58×70）不画**：角标最窄也要 `力+1` 三个字符，在 58px 宽的
	##    卡上会横跨整张卡图、把美术彻底盖掉；而那张卡的数字本来就因为成长变绿了，
	##    信息没丢。手牌（~119）/ 牌库（92）/ 卡组编辑（~200）/ 奖励大卡全部照画。
	if rect.size.y < GROWTH_MARK_MIN_H:
		return Rect2()
	var txt := growth_text(card)
	if txt == "" or rect.size.x <= 8.0 or rect.size.y <= 8.0:
		return Rect2()
	var fs := growth_mark_font(rect, card, font_bold)
	var tw: float = font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var padx: float = maxf(2.0, roundf(fs * 0.34))
	var h: float = font_bold.get_height(fs) + maxf(2.0, roundf(fs * 0.26))
	var art_bot: float = rect.position.y + rect.size.y * UiTheme.CARD_ART_RATIO
	var y: float = art_bot - h - maxf(1.0, rect.size.y * 0.015)
	var x: float = rect.position.x + 2.0
	# 兜底：任何情况下都不许顶出卡框右沿（宁可压窄，也不骑到邻卡身上）
	var maxw2: float = rect.end.x - 2.0 - x
	return Rect2(x, y, minf(tw + padx * 2.0, maxw2), h)


static func _draw_growth_mark(canvas: CanvasItem, card: CardData, rect: Rect2,
		font_bold: Font) -> void:
	## **本局成长角标**（R393b，用户口径「本局成长的需要在卡组界面卡面可显示」）。
	## 一枚深底 + 绿字的小扁牌，压在卡图区左下角：`力+1` / `力+3 生+6` / `伤+6`。
	## 读法直接对齐底部数值徽章的染色（`BADGE_UP` 绿 = 比卡库原型强）——
	## 数字为什么是绿的，角标把原因写出来了。
	## ⚠️ 走 `draw()` 与 `draw_pick()` 两口 → 战场 / 手牌 / 图鉴 / 牌库 / 地图卡组 /
	##    选卡页 / 卡组编辑**全都有**，不用每个场景各画一遍。
	if card == null:
		return
	var box := growth_mark_rect(card, rect, font_bold)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var fs := growth_mark_font(rect, card, font_bold)
	var col: Color = UiTheme.BADGE_UP
	var bg := Color(0.07, 0.12, 0.07, 0.86)
	canvas.draw_rect(box, bg)
	canvas.draw_rect(box, Color(col.r, col.g, col.b, 0.85), false,
			maxf(1.0, roundf(rect.size.y / 92.0)))
	# 文字左右各留 padx，与 `growth_mark_rect()` 的算法同源
	var padx: float = maxf(2.0, roundf(fs * 0.34))
	var baseline: float = box.position.y + (box.size.y + font_bold.get_ascent(fs)
			- font_bold.get_descent(fs)) * 0.5
	canvas.draw_string(font_bold, Vector2(box.position.x + padx, baseline),
			growth_text(card), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - padx * 2.0, fs, col)


static func wrap_text(font: Font, text: String, max_w: float, size: int) -> Array[String]:
	## 折行**唯一口** = `TextWrap.wrap_plain`（R292）。
	## 名字保留是因为全工程（卡面 / 选卡页 / 卡组编辑 / 道具页 / 地图）都在调它 ——
	## 换实现只改这一行，几十处调用点不用跟着动。
	## 规则：行首不落「，）」」这类收尾标点、行尾不留开引号、`「卡名」` 不拆、`+2/12/HP`
	## 不从中间断、折行处不吃空格、超宽单元退化成逐字硬切。
	return TextWrap.wrap_plain(font, text, max_w, size)


static func fit_text_lines(font: Font, text: String, max_w: float, max_h: float,
		fs_max: int, fs_min: int, max_lines: int = 99,
		last_line_descent := false) -> Dictionary:
	## R569：**超框就缩字号**（用户口径「文字应该增加自适应大小，超框需要缩小」）。
	## 从 `fs_max` 往下逐级试，取第一个「折行数 ≤ max_lines 且整块行高 ≤ max_h」的字号；
	## 一路缩到 `fs_min` 仍放不下时返回 `fs_min` 的结果 —— **截断由调用方决定**，
	## 这里不悄悄丢字（悄悄丢掉的那部分，玩家永远不知道自己漏了什么）。
	## 返回 {"fs": int, "lines": Array[String], "line_h": float}。
	##
	## ⚠️ 行高用字体真实 `get_height`，不按字号估：雅黑 9px 行高 13，按 1.16 倍估成 10
	##    会让两行墨迹叠在一起（R115 出图实测）。
	## ⚠️ 循环**严格递减**（`sz -= 1`），绝不依赖「条件终将不成立」退出 —— 绘制代码里
	##    这类循环一旦条件写错就是整帧不返回，表现为游戏未响应（R164 踩过）。
	if text.strip_edges() == "":
		var none: Array[String] = []
		return {"fs": fs_max, "lines": none, "line_h": float(fs_max)}
	var sz: int = maxi(fs_min, fs_max)
	while sz > fs_min:
		var probe := wrap_text(font, text, max_w, sz)
		var lh: float = maxf(font.get_height(sz), float(sz))
		# R631：`last_line_descent = true` → 按「末行墨迹底」判（(n-1)×行高 + 下行留白）。
		# 绘制方算「能画几行」用的就是这个式子；两边必须同一套，否则末行会被白砍一刀。
		var need: float = probe.size() * lh
		if last_line_descent and not probe.is_empty():
			need = (probe.size() - 1) * lh + float(font.get_descent(sz))
		if probe.size() <= max_lines and need <= max_h:
			return {"fs": sz, "lines": probe, "line_h": lh}
		sz -= 1
	var lines := wrap_text(font, text, max_w, fs_min)
	return {"fs": fs_min, "lines": lines, "line_h": maxf(font.get_height(fs_min), float(fs_min))}


static func ellipsize(font: Font, text: String, max_w: float, size: int) -> String:
	## 公开口（R631）：道具提示 / 详情面板的正文也要「超宽补 …」——
	## 各处别再自己写一份裁剪循环（写歪了就是死循环 + 整帧不返回）。
	return _ellipsize(font, text, max_w, size)


static func _ellipsize(font: Font, text: String, max_w: float, size: int) -> String:
	## 超宽就截断并补「…」；**没超宽时原样返回**（别给短文本平白加省略号）。
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return text
	var t := text
	while t.length() > 1 and font.get_string_size(t + "…",
			HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		t = t.substr(0, t.length() - 1)
	return t + "…"


static func _draw_center(canvas: CanvasItem, font: Font, size: int, text: String,
		center: Vector2, col: Color) -> void:
	# width=-1 时 draw_string 的居中参数不生效（文字从 pos 向右排），
	# 必须给定显式宽度并以 center 为中点。
	var w := maxf(size * text.length() * 1.2, 40.0)
	canvas.draw_string(font, center + Vector2(-w / 2.0, size * 0.36), text,
			HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


static func _draw_center_outlined(canvas: CanvasItem, font: Font, size: int, text: String,
		center: Vector2, col: Color) -> void:
	## 有图标素材时数字压在图上，而图标可能是花哨的插画 → 先描一圈深色再填字，
	## 保证**任何素材**上数字都能读（素材是玩家往后自己换的，不能假设它够素）。
	## 描边宽度：R114 出图实测 0.18 在 14px 的小卡徽章上太粗（白字+粗边会把 14px 圆盘占满，
	## 图标只剩边角），收到 0.13 —— 白卡面上仍然可读，但给图标让出一点面积。
	var o: float = maxf(0.7, size * 0.13)
	for d: Vector2 in [Vector2(-o, 0), Vector2(o, 0), Vector2(0, -o), Vector2(0, o)]:
		_draw_center(canvas, font, size, text, center + d, UiTheme.BADGE_OUTLINE)
	_draw_center(canvas, font, size, text, center, col)


# ------------------------------------------------------------ 字段索引浮层（R444）
#
# **为什么要单独一版**：卡牌奖励三选一（`draw_pick`）与商店第一行（R203 起）的卡面
# **只留卡名** ——「次元 / 嘲讽 / 超负荷」这几个字根本没有地方写，玩家只看得见字段的
# 名字，看不见它什么意思（用户口径 R444：「这两个界面看不到字段解释」）。
# 于是把「字段名：解释」做成小浮窗，贴在**这张卡的左右两侧**，明确允许压住邻卡：
# 三选一的卡间距只有 44px、商店第一行只有 32px，浮窗本来就没有空位可躲。
#
# 归属靠一条**指向卡边的小三角**表达 —— 浮窗压着邻卡时，没有箭头就会认错它属于谁。

## 浮窗宽度（解释在这个宽度里折行）。
const AFFIX_INDEX_W := 172.0
## 浮窗内侧边与卡边的水平间距。
const AFFIX_INDEX_GAP := 10.0
## 同一列里两块浮窗的竖直间距。
const AFFIX_INDEX_VGAP := 6.0
const AFFIX_INDEX_PAD := 8.0
const AFFIX_INDEX_TITLE_FS := 11
const AFFIX_INDEX_BODY_FS := 10
const AFFIX_INDEX_LINE_H := 13.0


# ------------------------------------------------------------ 关联关键字（R632）

const KEYWORD_FS := 13
const KEYWORD_LINE_H := 17.0


static func keyword_names(card: CardData) -> Array[String]:
	## R632：卡牌奖励页要展示的「关联关键字」= 特性 + 字段 + 正文里查得到的机制词条。
	## 与 `kind` 同名的特性（「工事」「场地」…）不列 —— 详情盒上一行「种类 · 费用 · 稀有度」
	## 已经写了同一件事，重复一次只会把这一行挤爆。
	var out: Array[String] = []
	if card == null:
		return out
	for t in card.traits:
		var tn := str(t)
		if tn == card.kind or out.has(tn):
			continue
		out.append(tn)
	for a in card.affixes:
		var an := str(a)
		if not out.has(an):
			out.append(an)
	for k in card.mech_keywords():
		if not out.has(k):
			out.append(k)
	return out


static func keyword_lines(font: Font, card: CardData, max_w: float) -> Array[String]:
	## 把「关键字：A · B · C」按**词**折行 —— 绝不把一个名字切成两半。
	## ⚠️ 不能直接用 `wrap_text()`：它是整串折行，9222 实测把「超负荷」拆成「超」/「负荷」。
	## 行首不落「 · 」。单个词自己就超宽时（现库最长「仅玩家可放置」≈78px，不会发生）
	## 这一行会溢出框，调用方靠 `max_w` 的绘制宽度兜不住 —— 真出现再加硬切。
	var out: Array[String] = []
	var names := keyword_names(card)
	if names.is_empty():
		return out
	var prefix := GameI18n.ui("shared", "CARD_FACE_KEYWORDS", "关键字：%s") % ""
	var cur := prefix
	for i in names.size():
		var unit: String = names[i] if cur == prefix else " · " + names[i]
		var probe := cur + unit
		if cur != prefix and font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1,
				KEYWORD_FS).x > max_w:
			out.append(cur)
			cur = names[i]
		else:
			cur = probe
	out.append(cur)
	return out


static func keyword_line_count(font: Font, card: CardData, max_w: float,
		max_lines := 2) -> int:
	## 关键字会占几行 —— 给调用方算详情盒高度（量高与画字共用 `keyword_lines`）。
	return mini(keyword_lines(font, card, max_w).size(), max_lines)


static func draw_keyword_line(canvas: CanvasItem, font: Font, card: CardData,
		x: float, y: float, max_w: float, max_lines := 2, max_y := -1.0,
		ink := Color("333333")) -> int:
	## 画「关键字：…」这一块。返回实际画出的行数（0 = 这张卡没有关键字）。
	## * 超过 `max_lines` → 最后一行以「…」收尾。**完整解释不靠这一行**：
	##   把鼠标压到卡面上，`draw_affix_index()` 会在卡两侧弹出每个可解释词的说明，
	##   所以这里只负责「看得见有哪些关键字」，装不下也不会丢信息。
	## * `max_y > 0` = 可用底线：再画一行就压到盒底时**不画** —— 宁可少一行也不溢出。
	var lines := keyword_lines(font, card, max_w)
	if lines.is_empty():
		return 0
	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
		var last: String = lines[max_lines - 1]
		lines[max_lines - 1] = last.substr(0, maxi(0, last.length() - 1)) + "…"
	var drawn := 0
	for i in lines.size():
		if max_y > 0.0 and y + float(i) * KEYWORD_LINE_H > max_y:
			break
		canvas.draw_string(font, Vector2(x, y + float(i) * KEYWORD_LINE_H), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, max_w, KEYWORD_FS, ink)
		drawn += 1
	return drawn


static func affix_index_items(card: CardData, font: Font, box_w := AFFIX_INDEX_W) -> Array:
	## 每个字段一条浮窗的内容与高度。绘制与测高共用这一口（与 `wrap_text` 同一折行器，
	## 不会出现「量高一套、画字另一套」的字戳出框）。
	var out: Array = []
	if card == null:
		return out
	var body_w: float = box_w - AFFIX_INDEX_PAD * 2.0
	# R614：字段 + **机制词条**（「组合」这类：不是 affixes、没有状态可挂，但正文里出现、
	# 玩家同样要能查到解释）。两者共用同一块浮窗，所以先并成一条名字流再画。
	var names: Array[String] = []
	for a: String in card.affixes:
		names.append(a)
	# R632：特性里**有解释的**也进浮窗（改版后「死亡」既是敌人卡的特性、也是字段，
	# 奖励页的关键字行把它写出来了，玩家就得能查到它是什么意思）。
	# 纯专名（「聚能炮击」「月亮」）没有定义 → 不进浮窗，免得弹出一串只有标题的空框。
	for t in card.traits:
		var tn := str(t)
		if names.has(tn) or CardData.word_def(tn).is_empty():
			continue
		names.append(tn)
	for kw: String in card.mech_keywords():
		if not names.has(kw):
			names.append(kw)
	for a: String in names:
		var desc := CardData.affix_desc(a)
		var lines: Array[String] = []
		if desc != "":
			lines = wrap_text(font, desc, body_w, AFFIX_INDEX_BODY_FS)
		var h: float = AFFIX_INDEX_PAD * 2.0 + 18.0 + float(lines.size()) * AFFIX_INDEX_LINE_H
		out.append({"affix": a, "label": CardData.affix_label(a), "lines": lines, "h": h})
	return out


static func affix_index_rects(card: CardData, card_rect: Rect2, font: Font,
		box_w := AFFIX_INDEX_W, bounds := Rect2()) -> Array:
	## 算出每块浮窗的位置（不画）。返回 [{rect, item, side}]，side = 1 右 / -1 左。
	## 排布：**单字段一律靠右**（商店最左那张卡左边只剩 32px，靠左必然出屏）；
	##       两个以上按「右 → 左 → 右 → 左」交替，左右各自成一列、列内垂直居中。
	## `bounds` 非空时把每块的 x 夹回屏内（最左 / 最右那张卡不会把解释画到屏幕外）。
	var out: Array = []
	var items := affix_index_items(card, font, box_w)
	if items.is_empty():
		return out
	var right_col: Array = []
	var left_col: Array = []
	for i in items.size():
		if i % 2 == 0:
			right_col.append(items[i])
		else:
			left_col.append(items[i])
	for two in 2:
		var col: Array = right_col if two == 0 else left_col
		if col.is_empty():
			continue
		var side := 1 if two == 0 else -1
		var total := 0.0
		for it: Dictionary in col:
			total += float(it["h"])
		total += AFFIX_INDEX_VGAP * float(maxi(0, col.size() - 1))
		var y: float = card_rect.position.y + (card_rect.size.y - total) / 2.0
		if y < card_rect.position.y:
			y = card_rect.position.y     # 字段比卡还高 → 从卡顶往下排（宁可压住卡下方）
		for it: Dictionary in col:
			var x: float = card_rect.end.x + AFFIX_INDEX_GAP
			if side < 0:
				x = card_rect.position.x - AFFIX_INDEX_GAP - box_w
			if bounds.size.x > 0.0:
				x = clampf(x, bounds.position.x + 2.0,
						maxf(bounds.position.x + 2.0, bounds.end.x - box_w - 2.0))
			out.append({"rect": Rect2(x, y, box_w, float(it["h"])), "item": it, "side": side})
			y += float(it["h"]) + AFFIX_INDEX_VGAP
	return out


static func draw_affix_index(canvas: CanvasItem, card: CardData, card_rect: Rect2,
		font: Font, font_bold: Font, box_w := AFFIX_INDEX_W,
		bounds := Rect2()) -> void:
	## 画字段索引浮窗。**必须在这张卡画完之后调**（它要压住卡与邻卡）。
	## 没有字段 → 什么都不画（绝大多数卡是这种，调用方不用自己判）。
	for r: Dictionary in affix_index_rects(card, card_rect, font, box_w, bounds):
		_draw_affix_index_box(canvas, r["rect"], r["item"], int(r["side"]), font, font_bold)


static func _draw_affix_index_box(canvas: CanvasItem, rect: Rect2, item: Dictionary,
		side: int, font: Font, font_bold: Font) -> void:
	var a := str(item.get("affix", ""))
	var ac := CardData.affix_colors(a)
	var accent: Color = ac[1]
	# 深底 + 字段色描边：两张页面底色一深（商店）一浅（羊皮卷）—— 深底在两边都读得清，
	# 也正好与战斗内那套「字段解释框」的印象对齐。
	canvas.draw_rect(rect, Color(0.06, 0.065, 0.08, 0.94), true)
	canvas.draw_rect(rect, accent, false, 1.4)
	# 指向卡边的小三角（浮窗压着邻卡时靠它认归属）
	var tip_x: float = rect.position.x - 6.0
	var base_x: float = rect.position.x
	if side < 0:
		tip_x = rect.end.x + 6.0
		base_x = rect.end.x
	var my: float = rect.position.y + 16.0
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(tip_x, my), Vector2(base_x, my - 5.0), Vector2(base_x, my + 5.0)]), accent)
	var x: float = rect.position.x + AFFIX_INDEX_PAD
	var w: float = rect.size.x - AFFIX_INDEX_PAD * 2.0
	canvas.draw_string(font_bold, Vector2(x, rect.position.y + AFFIX_INDEX_PAD + 11.0),
			str(item.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, w,
			AFFIX_INDEX_TITLE_FS, accent)
	var ly: float = rect.position.y + AFFIX_INDEX_PAD + 28.0
	for t: String in item.get("lines", []):
		canvas.draw_string(font, Vector2(x, ly), t, HORIZONTAL_ALIGNMENT_LEFT, w,
				AFFIX_INDEX_BODY_FS, Color("e8e3d6"))
		ly += AFFIX_INDEX_LINE_H
