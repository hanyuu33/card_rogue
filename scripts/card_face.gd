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

# R185：8002「攻击」卡图按当前职业切换（森林精魄=爪击 / 暗影刺客=匕首刺 / 机械之心=浮游炮）。
const ATTACK_ART_ID := 8002
const ATTACK_ART_SUFFIX := {"森林精魄": "forest", "暗影刺客": "shadow", "机械之心": "mech"}


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
	if card == null:
		return Color.WHITE
	var c: Color = UiTheme.class_color(card.card_class)
	if c.a <= 0.0:
		return Color.WHITE
	return c.lerp(Color.WHITE, CLASS_PAPER_MIX)


static func art_for(id: int, sleeping := false) -> Texture2D:
	# sleeping=true 时优先取沉睡专用图 `<id>_sleep.png`（R182 恶魔鸭沉睡状态）；
	# 沉睡图缺失则回退普通卡图 —— 不空白、不报错。
	# 8002「攻击」按 RunState.player_class 换图；职业图缺失回退 `8002.png` 通用图；
	# 图鉴等非 run 场景 player_class 为默认值（森林精魄），显示爪击版。
	var suffix := ""
	if id == ATTACK_ART_ID:
		suffix = "_" + String(ATTACK_ART_SUFFIX.get(RunState.player_class, "forest"))
	var key := str(id) + suffix + ("_sleep" if sleeping else "")
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
		_art_cache[key] = load(path) if _pic_exists(path) else null
	return _art_cache[key]


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
	if src.x <= 0.0 or src.y <= 0.0 or box.size.x <= 0.0 or box.size.y <= 0.0:
		return Rect2(Vector2.ZERO, src)
	var src_r: float = src.x / src.y
	var box_r: float = box.size.x / box.size.y
	if src_r > box_r:
		# 源更宽 → 左右各裁掉一点
		var cw: float = src.y * box_r
		return Rect2((src.x - cw) / 2.0, 0.0, cw, src.y)
	# 源更高 → 上下各裁掉一点
	var ch: float = src.x / box_r
	return Rect2(0.0, (src.y - ch) / 2.0, src.x, ch)


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
		name_only := false) -> void:
	## 卡面一律按 rect **完整排版**，与图鉴/战场小卡同一套比例，没有「按可见高度重锚」
	## 之类的特例 —— 手牌卡底沉出窗口下沿时，被挡住的那截就让它挡住
	## （作者口径：卡片是一个整体，排版要与正常状态完全一致，别为了躲裁剪挪数值）。
	var k := rect.size.y / CARD_H_DESIGN
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var kt: float = minf(k, UiTheme.CARD_TEXT_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	# ① 卡面纸底：素材槽 assets/ui/card_paper.png 优先，缺图回退纯色（R113 起可换皮）
	var paper: Texture2D = UiAssets.card_paper()
	var tint := paper_tint(card)   # R267：职业色只涂在纸底上，卡图本身不动
	if paper != null:
		canvas.draw_texture_rect(paper, rect, false, tint)
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
	_draw_art(canvas, card, rect, k, pad, is_tapped, font_bold, sleeping)
	# ④b 稀有度缎带（R170）：挂在**右上角**、压在卡图之上。
	#     （旧色块小旗画在卡图**之前**，被开放式卡图整个盖住 —— 等于没画。）
	_draw_rarity_ribbon(canvas, card, rect, k, pad)
	# ⑤ 卡图与文字区的分隔线
	# ⚠️ R153：v2 底图**自带金线分隔**（CARD_ART_RATIO 0.745 处的金条），不再手画灰线。
	# ⚠️ R122：**横置时不画** —— 那时卡图铺满整卡（见 _draw_art），横一道线很突兀。
	var sep_y: float = rect.position.y + rect.size.y * UiTheme.CARD_ART_RATIO
	# ⑥ 文字区（下半）—— 底衬在 `_draw_text_zone` 内部按**文字块的实际高度**铺。
	#    name_only=true → 只画卡名（战斗内卡面口径：效果详情走悬停/点选描述面板）。
	_draw_text_zone(canvas, card, rect, kt, k, pad, sep_y, hp, font, font_bold, on_board, is_tapped, name_only)
	# ⑦ 数值徽章 —— 最后画，压在卡图与文字之上（「额外挂载」的字面意思）
	_draw_badges(canvas, font_bold, card, rect, k, kc, hp, power_override)
	# ⑧ 附魔标记（R214）—— 同样压在最上层（它骑在卡图左上角上）
	_draw_enchant_mark(canvas, card, rect, font_bold)


static func draw_pick(canvas: CanvasItem, card: CardData, rect: Rect2,
		font: Font, font_bold: Font, selected := false) -> void:
	## 选卡场景专用简洁卡面（R191，用户口径「卡面只留卡名，描述点选后再看」）：
	## 纸底 + 卡图 + 稀有度缎带 + 数值徽章 + **只有卡名**的文字区（不画种类行与效果文）。
	## 用于战斗内选卡页 / 卡牌奖励三选一 / 卡组编辑选卡 —— 战场与手牌仍走 `draw()`。
	var k := rect.size.y / CARD_H_DESIGN
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var kt: float = minf(k, UiTheme.CARD_TEXT_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	var paper: Texture2D = UiAssets.card_paper()
	var tint := paper_tint(card)   # R267：职业色只涂在纸底上，卡图本身不动
	if paper != null:
		canvas.draw_texture_rect(paper, rect, false, tint)
	else:
		canvas.draw_rect(rect, tint if tint != Color.WHITE else UiTheme.SURFACE)
	if selected:
		for gi in 3:
			var glow := UiTheme.SELECT_RING
			glow.a = 0.42 - 0.11 * gi
			canvas.draw_rect(rect.grow(1.0 + gi), glow, false, 1.0)
	_draw_art(canvas, card, rect, k, pad, false, font_bold, false)
	_draw_rarity_ribbon(canvas, card, rect, k, pad)
	_draw_name_zone(canvas, card, rect, kt, k, pad, font_bold)   # R193：姓名牌内框 + 居中卡名（只留卡名）
	_draw_badges(canvas, font_bold, card, rect, k, kc, card.health, -1)
	_draw_enchant_mark(canvas, card, rect, font_bold)            # R214：选卡页也要看到附魔标记


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
				CardData.enchant_name(card.enchant).substr(0, 1), c, col)


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
	var info := name_layout(card.card_name, rect, font_bold, max_h)
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
		_draw_name_marquee(canvas, font_bold, sz, card.card_name, text_x, baseline, maxw,
			UiTheme.INK_900, float(info["text_w"]))
		return
	canvas.draw_string(font_bold, Vector2(text_x, baseline), card.card_name,
			HORIZONTAL_ALIGNMENT_CENTER, maxw, sz, UiTheme.INK_900)


static func _draw_art(canvas: CanvasItem, card: CardData, rect: Rect2, k: float, pad: float,
		is_tapped: bool, font_bold: Font, sleeping := false) -> void:
	## 卡图区 = 卡片上半（R114 起）。R165：卡图**开放**——左/右/上直接出血到卡边，
	## 不再有内框；卡框只留在底部（见 `draw()` ③）。
	## sleeping=true → 取沉睡专用图（`<id>_sleep.png`，缺失回退普通卡图）。
	var box := Rect2(rect.position,
			Vector2(rect.size.x, rect.size.y * UiTheme.CARD_ART_RATIO))
	if box.size.x < 6.0 or box.size.y < 6.0:
		return
	var tex := art_for(card.id, sleeping)
	if tex != null:
		# 覆盖式铺满（cover）：卡图出血到卡边、不留白（R165 开放式卡图）。
		canvas.draw_texture_rect_region(tex, box, cover_region(tex.get_size(), box), Color.WHITE)
	else:
		# 无图回退（R165）：卡种/职业色的**淡彩竖向渐变横幅**代替「粗暴纯色块」——
		# 自然、按卡分色（职业优先，中立回落卡种）。
		var cols := banner_cols(card)
		_draw_vgradient(canvas, box, cols[0], cols[1])
		var glyph: Color = cols[1]
		glyph.a = 0.40
		_draw_center(canvas, font_bold, int(minf(box.size.x, box.size.y) * 0.9),
				card.card_name.substr(0, 1), box.get_center(), glyph)


static func _draw_rarity_ribbon(canvas: CanvasItem, card: CardData, rect: Rect2,
		k: float, pad: float) -> void:
	## 稀有度缎带（R170）：挂在卡面**右上角**的锦旗 —— 稀有度的**主通道**。
	## 素材 `assets/ui/ribbon_<0..5>.png`（透明底、燕尾下垂，下标同 RARITY_COLORS）；
	## 缺图回退程序小旗（同色多边形）—— 不空白也不报错。
	## ⚠️ 必须画在卡图**之后**：开放式卡图铺满上半，先画会被整个盖住（旧小旗就是这么没的）。
	## ⚠️ 尺寸（R173）：旗高 27k ≈ 卡高的 39% —— R170 第一版只有 13k，细长燕尾被压成
	##    一条 6px 细线，肉眼观感 = 「没应用素材」；27k 后金绣/燕尾在各种卡尺寸下都可辨认。
	var ribbon: Texture2D = UiAssets.rarity_ribbon(card.rarity)
	if ribbon != null:
		var rh: float = 27.0 * k
		var rw: float = rh * ribbon.get_width() / maxf(1.0, ribbon.get_height())
		var rx: float = rect.end.x - pad - rw
		var ry: float = rect.position.y - 1.2 * k   # 横杆骑在卡顶边（微探出 = 「挂」在卡上）
		canvas.draw_texture_rect(ribbon, Rect2(rx, ry, rw, rh), false)
		return
	# 回退：程序小旗（形状与旧版一致，但画在卡图之后，不再被盖）
	var rar_col: Color = card.rarity_color()
	var flag_w: float = 9.0 * k
	var flag_h: float = 22.0 * k
	var fx: float = rect.end.x - pad - flag_w
	var fy: float = rect.position.y + pad
	var flag := PackedVector2Array([
			Vector2(fx, fy), Vector2(fx + flag_w, fy),
			Vector2(fx + flag_w, fy + flag_h),
			Vector2(fx + flag_w / 2.0, fy + flag_h * 0.72),
			Vector2(fx, fy + flag_h)])
	canvas.draw_colored_polygon(flag, rar_col)


static func banner_cols(card: CardData) -> Array:
	## 卡面横幅色 = [上端, 下端]：职业色优先（中立回落卡种色），向白混合成淡彩。
	## R277：**无图回退横幅**也按卡的**归属**上色 —— 189 张卡还没有卡图，横幅就是它们的
	##    卡面，颜色不跟归属走的话「敌人红 / 公用灰」在这些卡上根本看不见
	##    （原来敌人卡取卡种色、公用卡取卡种色，一张盟友卡永远是绿的）。
	var c: Color = UiTheme.class_color(card.card_class)
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


static func _draw_text_zone(canvas: CanvasItem, card: CardData, rect: Rect2, kt: float,
		k: float, pad: float, sep_y: float, hp: int, font: Font, font_bold: Font,
		on_board: bool, is_tapped := false, name_only := false) -> void:
	## 文字区（下半）：**卡名 → 种类 · 字段 → 效果文字**，按这个优先级往下排，
	## 排不下的整块省略。
	##
	## ⚠️ 「种类」与「字段」**合并成一行**（`盟友 · 迅捷`）—— 分成两行的话，
	## 58×70 / 98×119 这类尺寸上光是这两行就把文字区吃光，效果文字永远轮不到。
	## ⚠️ 效果文字**只在排得下完整一行时**才画 —— 小卡上排「半行字 + 省略号」比不排
	## 更难看，而且玩家根本读不到信息。
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
	var bottom: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_BOTTOM - pad  # 姓名牌内框下沿
	var top: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_TOP + pad       # 姓名牌内框上沿
	if bottom - top < 6.0:
		return
	var sz: int = maxi(7, roundi(UiTheme.CARD_FS_TEXT * kt))
	var cx: float = rect.position.x + rect.size.x * (UiTheme.CARD_NAMEPLATE_X0 + UiTheme.CARD_NAMEPLATE_X1) / 2.0
	var maxw: float = rect.size.x * (UiTheme.CARD_NAMEPLATE_X1 - UiTheme.CARD_NAMEPLATE_X0) - pad * 2.0
	var kind_col: Color = UiTheme.kind_color(card.kind)
	# ⚠️ 行距必须用**字体真实行高**（`get_height`），不能按字号估：
	#   雅黑 9px 的行高是 13（ascent 10 + descent 3），而旧写法 `sz * 1.12 = 10.08 < 13`
	#   → 两行墨迹必然叠（R115 出图实测：手牌上「木栅栏 / 工事」糊成一片）。
	var row_h: float = maxf(font.get_height(sz), font_bold.get_height(sz))
	var asc: float = float(font.get_ascent(sz))
	var asc_b: float = float(font_bold.get_ascent(sz))
	var desc: float = float(font.get_descent(sz))
	var meta_a: String = card.kind
	# R118：战场卡面（`on_board`）只写**上场之后仍然有用**的字段 —— 交换 / 幻影是
	# 「打出那一刻」的规则，卡一落到格子上就再无作用，继续写在这里只会误导玩家。
	# ⚠️ 判空不能用 `card.affixes.is_empty()`：过滤之后**可能整段为空**（只剩种类的卡）。
	var affix_txt: String = card.field_affix_line() if on_board else card.affix_line()
	var meta_b: String = (" · " + affix_txt) if affix_txt != "" else ""
	var eff: String = CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
	var line_h: float = sz * 1.16
	# ── 第一遍：只算基线，不画 ──────────────────────────────────────────
	var base_name: float = top + asc_b                       # 卡名基线
	var base_meta: float = base_name + row_h                 # 种类 · 字段基线
	var has_meta: bool = base_meta + desc <= bottom
	var eff_base0: float = base_meta + row_h                 # 效果首行基线
	var eff_n: int = 0
	var eff_lines: Array = []
	if eff != "":
		eff_n = int(floor((bottom - desc - eff_base0) / line_h)) + 1
		if eff_n > 0:
			eff_lines = wrap_text(font, eff, maxw, sz)
			eff_n = mini(eff_lines.size(), eff_n)
	# R208：**不再铺底衬**（用户口径「卡牌文字背后那个淡黄色长方形不需要，只留卡名
	# 文字和底背景图」）—— 文字直接坐在 card_paper 自带的姓名牌羊皮纸上。
	# ── 第二遍：画字（**不描边**）───────────────────────────────────────
	# R203：卡名横幅（R165 的 banner 渐变条）已去掉 —— 用户口径「卡名后面垫着的那条
	# 绿色长方形直接去掉，卡名直接放在上面就好」；卡名直接画在羊皮卷/木板底衬上。
	# R281：卡名恒单行（宽度自适应 → 超宽横向滚动），不再折行；超宽时也不省略。
	var ninfo := name_layout(card.card_name, rect, font_bold)
	var nsz: int = int(ninfo["sz"])
	if bool(ninfo["need_scroll"]):
		_draw_name_marquee(canvas, font_bold, nsz, card.card_name,
			rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad,
			base_name, float(ninfo["maxw"]), UiTheme.INK_900, float(ninfo["text_w"]))
	else:
		_draw_center(canvas, font_bold, nsz, card.card_name,
			Vector2(cx, base_name - nsz * 0.36), UiTheme.INK_900)
	if has_meta:
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
	for i in eff_n:
		var t: String = eff_lines[i]
		if i == eff_n - 1 and eff_lines.size() > eff_n:
			t = _ellipsize(font, t + "…", maxw, sz)
		canvas.draw_string(font, Vector2(rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad,
				eff_base0 + line_h * i), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiTheme.INK_600)


static func _draw_badges(canvas: CanvasItem, font_bold: Font, card: CardData, rect: Rect2,
		k: float, kc: float, hp: int, power_override: int) -> void:
	## 数值「额外挂载」。位置是**固定槽位**，与卡的种类无关 ——
	## 玩家的眼睛只需要记一次坐标：
	##   ① 费用 = 卡框左上角 · ② 力量 = 卡框左下角（与 ① 同一条竖线）
	##   ③ 攻击距离 = ② 右侧 · ④ 移动距离 = ⑤ 左侧 · ⑤ 生命 = 卡框右下角
	## ⚠️ 于是 ② 与 ⑤ **分别向左右探出卡框**（R115 用户口径）—— 容器必须让出
	##    `UiTheme.CARD_BLEED`，少让一点这两张就会骑到邻卡身上。
	var r: float = UiTheme.CARD_BADGE_R * kc
	var gap: float = UiTheme.CARD_BADGE_GAP * kc
	var fs: int = maxi(7, roundi(UiTheme.CARD_FS_BADGE * kc))
	# ── ① 左上角：费用（水晶）—— 圆心压在卡框左上角上 ──
	# X 费卡（流星雨 9083）：费用不是定值 → 徽章上直接画「X」
	draw_badge(canvas, font_bold, cost_badge_center(rect), r, fs, "cost",
			"X" if card.x_cost else str(card.cost), UiTheme.BADGE_COST)
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
	var shown_power: int = power_override if power_override >= 0 else card.power
	draw_badge(canvas, font_bold, Vector2(power_x, bar_y), r, fs, "power",
			str(shown_power), UiTheme.BADGE_POWER,
			_delta_col(shown_power, bv.get("power")))
	draw_badge(canvas, font_bold, Vector2(range_x, bar_y), r, fs, "range",
			str(card.attack_range), UiTheme.BADGE_RANGE,
			_delta_col(card.attack_range, bv.get("range")))
	# ── ④ 移动距离（鞋）+ ⑤ 生命（血）──
	# ⚠️ 阅读方向必须与左半排一致（力 程 … 速 生）：跨过中间空档后仍是「先读到的在左」。
	# 先前按「离卡角最近的是第一个」做成镜像（力 程 速 生 → 生 速），出图一看就读反了 ——
	# 两组之间「先读到的那个」忽左忽右，比单纯难看更糟：会读错数值。
	# 工事不会移动 → 不画鞋，生命直接占最外侧那张（贴右框线）。
	if is_unit:
		draw_badge(canvas, font_bold, Vector2(speed_x, bar_y), r, fs, "speed",
				str(card.move_speed), UiTheme.BADGE_SPEED,
				_delta_col(card.move_speed, bv.get("speed")))
	draw_badge(canvas, font_bold, Vector2(health_x, bar_y), r, fs, "health",
			str(hp), UiTheme.BADGE_HEALTH,
			_health_col(card, hp, bv.get("health")))


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
	if _base_cache.has(card.id):
		return _base_cache[card.id]
	var d := {}
	var repo := _base_repo()
	var proto: CardData = repo.get_card(card.id) if repo != null else null
	if proto != null:
		d = {"power": proto.power, "health": proto.health,
				"range": proto.attack_range, "speed": proto.move_speed}
	_base_cache[card.id] = d
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
	var icon: Texture2D = UiAssets.badge_icon(key)
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
			return "力量 %d   生命 %d   射程 %d   速度 %d" % [
				card.power, shown, card.attack_range, card.move_speed]
		"工事":
			return "力量 %d   生命 %d   射程 %d" % [card.power, shown, card.attack_range]
		"技能":
			return "直接使用"
		"效果":
			return "在效果区持续生效"
	return ""


static func wrap_text(font: Font, text: String, max_w: float, size: int) -> Array[String]:
	## 折行**唯一口** = `TextWrap.wrap_plain`（R292）。
	## 名字保留是因为全工程（卡面 / 选卡页 / 卡组编辑 / 道具页 / 地图）都在调它 ——
	## 换实现只改这一行，几十处调用点不用跟着动。
	## 规则：行首不落「，）」」这类收尾标点、行尾不留开引号、`「卡名」` 不拆、`+2/12/HP`
	## 不从中间断、折行处不吃空格、超宽单元退化成逐字硬切。
	return TextWrap.wrap_plain(font, text, max_w, size)


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
