## R839：大蒜 7017 —— 图标兜底 + 战场「不可使用格」绘制 + 拖放提示
## 用法：python tools/_patch_r839_ui.py
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep(path, old, new, tag):
    d = read(path)
    crlf = "\r\n" in d
    norm = d.replace("\r\n", "\n")
    o, n = old.replace("\r\n", "\n"), new.replace("\r\n", "\n")
    cnt = norm.count(o)
    if cnt == 0 and n in norm:
        print("skip %-36s（已应用）" % tag)
        return
    assert cnt == 1, "%s 锚点命中 %d 次（要求 1）" % (tag, cnt)
    out = norm.replace(o, n)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    print("ok  %-38s (%s)" % (tag, "CRLF" if crlf else "LF"))


# ============================ trap_art.gd ============================
TA = "scripts/trap_art.gd"

rep(TA, '''		7016: return Color(0.86, 0.32, 0.28)   # 爆炸蘑菇 · 蘑菇红''',
    '''		7016: return Color(0.86, 0.32, 0.28)   # 爆炸蘑菇 · 蘑菇红
		# R839 大蒜 7017 —— 蒜苗青（不用蒜白：蒜白在米色格底上几乎看不见）。
		7017: return Color(0.76, 0.82, 0.52)''', "trap_art: color_of 7017")

rep(TA, '''		7016: _mushroom(ci, c, s, ink)''',
    '''		7016: _mushroom(ci, c, s, ink)
		7017: _garlic(ci, c, s, ink)''', "trap_art: draw 分支")

rep(TA, '''static func _bomb(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:''',
    '''static func _garlic(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R839 大蒜 7017：蒜头剪影 —— 上尖下圆的身子 + 顶端短茎 + 两条竖纹（分瓣暗示）。
	## 与 `_mushroom` / `_puffer` 同一路数：单色剪影，44px 下靠**轮廓**认形状
	## （斑点 / 高光那个尺寸全糊掉）。有 png 时整段不走。
	var w := maxf(1.2, s * 0.024)
	var body := c + Vector2(0, s * 0.06)
	var rx := s * 0.25
	var ry := s * 0.26
	var pts := PackedVector2Array()
	var steps := 24
	for k in steps:
		var a := TAU * float(k) / float(steps)
		# sin(a) < 0 = 屏幕上方：上半收窄拉长 = 蒜头那个尖
		var px := rx
		var py := ry
		if sin(a) < 0.0:
			px = rx * 0.74
			py = ry * 1.24
		pts.append(body + Vector2(cos(a) * px, sin(a) * py))
	ci.draw_colored_polygon(pts, col)
	# 顶端短茎（斜一点点，正上方太像「洋葱」）
	var tip := body + Vector2(0, -ry * 1.24)
	ci.draw_line(tip, tip + Vector2(s * 0.04, -s * 0.09), col, w, true)
	# 两条竖纹：同色系更深一档，画成两段折线（蒜瓣分瓣的暗示）
	var dark := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, col.a)
	for sx: float in [-1.0, 1.0]:
		var top := body + Vector2(sx * s * 0.02, -ry * 1.10)
		var mid := body + Vector2(sx * s * 0.12, 0.0)
		var bot := body + Vector2(sx * s * 0.05, ry * 0.92)
		ci.draw_line(top, mid, dark, w, true)
		ci.draw_line(mid, bot, dark, w, true)


static func _bomb(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:''',
    "trap_art: _garlic()")

# ============================ battle_scene.gd ============================
BS = "scripts/battle_scene.gd"

# ① 绘制接入
rep(BS, '''	if not engine.state.trap_fields.is_empty():
		_draw_trap_markers()      # R663：已布置的陷阱（非卡牌场地，独立一张表）''',
    '''	if not engine.state.trap_fields.is_empty():
		_draw_trap_markers()      # R663：已布置的陷阱（非卡牌场地，独立一张表）
	if not engine.state.sealed_cells.is_empty():
		_draw_seal_markers()      # R839：大蒜封住的格子（不可使用）''', "battle: _draw_grid 接入")

# ② 逐帧重绘判据（封锁格带呼吸描边）
rep(BS, '''	if engine != null and not engine.state.trap_fields.is_empty():
		return true   # R663：陷阱格带呼吸描边，得逐帧重绘''',
    '''	if engine != null and not engine.state.trap_fields.is_empty():
		return true   # R663：陷阱格带呼吸描边，得逐帧重绘
	if engine != null and not engine.state.sealed_cells.is_empty():
		return true   # R839：大蒜封锁格同样带呼吸描边''', "battle: pulsing 判据")

# ③ 绘制函数（贴在 _draw_trap_markers 之后）
rep(BS, '''func _draw_field_markers() -> void:''', '''func _draw_seal_markers() -> void:
	## R839 大蒜 7017：被封住的格子 = **「这一格不可使用」**。
	## 画法与场上另外三套标记刻意分开，别让玩家读混：
	##   * 陷阱 = 小图标 + 呼吸方框（「埋着东西，踩了会炸」）；
	##   * 场地 = 45° 斜纹 + 名字角标（「这格挂着效果」）；
	##   * 空袭 = 红色准星（「这格被点名了」）；
	##   * **封锁 = 满格暗底 + 两道对角封条 + 中央蒜图标 + 右上角剩余回合数**
	##     （「这格被封死了，谁都别想用」）。
	## 判据只读 `engine.state.sealed_cells`（引擎是唯一数据源）；回合数也直接读表 ——
	## 界面**绝不**自己按「放下时记几」倒推，两套账必然分叉。
	var t := float(_now()) / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	for cell: Vector2i in engine.state.sealed_cells:
		var left := int(engine.state.sealed_cells[cell])
		if left <= 0:
			continue
		var r := _cell_rect(cell)
		draw_rect(r.grow(-3.0), Color(0.26, 0.24, 0.33, 0.40), true)
		draw_rect(r.grow(-3.0), Color(0.74, 0.72, 0.84, 0.45 + 0.35 * pulse), false, 2.0)
		# 两道对角封条（不是斜纹：斜纹是场地卡的语汇）
		var pad := 9.0
		var seal_col := Color(0.82, 0.80, 0.90, 0.42 + 0.18 * pulse)
		draw_line(r.position + Vector2(pad, pad), r.end - Vector2(pad, pad), seal_col, 2.0)
		draw_line(Vector2(r.end.x - pad, r.position.y + pad),
				Vector2(r.position.x + pad, r.end.y - pad), seal_col, 2.0)
		# 中央蒜图标（与工具栏 / 商店 / 奖励页同一个 `TrapArt.draw` 口）
		var s := 34.0
		TrapArt.draw(self, Rect2(r.get_center() - Vector2(s * 0.5, s * 0.5),
				Vector2(s, s)), 7017, false)
		# 右上角剩余我方回合数（「3」= 还能封 3 个我方回合）
		_draw_string_box_center(_font_bold, UI_FS_MICRO, str(left),
				Vector2(r.end.x - 13.0, r.position.y + 13.0), Color("ece7f8"))


func _draw_field_markers() -> void:''', "battle: _draw_seal_markers")

# ④ 放置成功后的提示（大蒜不是「敌人踩到就会触发」）
rep(BS, '''	RunState.consume_trap(slot)   # 放置那一刻才从栏位移除（R663 口径）
	var nm := td.trap_name if td != null else "工具"
	_say("已布置「%s」，敌人踩到就会触发" % nm)''',
    '''	RunState.consume_trap(slot)   # 放置那一刻才从栏位移除（R663 口径）
	var nm := td.trap_name if td != null else "工具"
	# R839 大蒜：封锁型不是「等人踩」，提示语必须换口径（照抄会骗玩家「踩了会触发」）。
	if td != null and td.block_turns > 0:
		_say("已封住这一格：「%s」生效期间任何单位都无法进入或经过" % nm)
	else:
		_say("已布置「%s」，敌人踩到就会触发" % nm)''', "battle: 放置提示")

# ⑤ 高亮过滤：手牌落点 / 场地落点都不给封锁格亮绿
rep(BS, '''			if not GameEngine.hand_place_allowed(c, GameEngine.SIDE_SELF):
				continue
			if not engine.state.board.has(c):''',
    '''			if not GameEngine.hand_place_allowed(c, GameEngine.SIDE_SELF):
				continue
			if engine.cell_sealed(c):
				continue          # R839 大蒜：封锁格「不可使用」，别亮成绿格
			if not engine.state.board.has(c):''', "battle: 手牌落点过滤")

rep(BS, '''			if GameEngine.field_place_allowed(c, aim):
				out.append(c)''',
    '''			# R839 大蒜：`field_place_allowed()` 是 static（拿不到 state），
			# 封锁格由引擎的 `cell_sealed()` 这一刀挡 —— 高亮与真实可放必须一致。
			if GameEngine.field_place_allowed(c, aim) and not engine.cell_sealed(c):
				out.append(c)''', "battle: 场地落点过滤")
