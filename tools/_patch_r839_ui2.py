## R839：大蒜 7017 —— 战场标记可读性（图标放大去底框 + 数字不压边）
## 依据：第一版截图里 34px 的 `TrapArt.draw`（自带深色底框）在暗格上像一块石头，
## 认不出是蒜；「3」用 `_draw_string_box_center` 带深底条，压住格子右上边框。
## 用法：python tools/_patch_r839_ui2.py
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
        print("skip %-38s（已应用）" % tag)
        return
    assert cnt == 1, "%s 锚点命中 %d 次（要求 1）" % (tag, cnt)
    out = norm.replace(o, n)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    print("ok  %-40s (%s)" % (tag, "CRLF" if crlf else "LF"))


# ===================== trap_art.gd：抽出 _glyph + draw_glyph =====================
TA = "scripts/trap_art.gd"

rep(TA, '''	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	match id:
		7001: _bomb(ci, c, s, ink)''', '''	_glyph(ci, rect, id, ink)


static func draw_glyph(ci: CanvasItem, rect: Rect2, id: int) -> void:
	## R839：**只画图案、不画底框**的入口 —— 给「这一格已经有自己的底色」的场合用。
	## 目前唯一用户是战场上的大蒜封锁格：那里底板已经是暗格 + 对角封条，
	## 再叠一个 34px 的深色底框就成了三块黑压一起（实测截图里像块石头，认不出是蒜）。
	## 颜色直接取 `color_of(id)`（亮色剪影）—— 深色底板上才看得见。
	var tex: Texture2D = UiAssets.trap_icon(id)
	if tex != null:
		ci.draw_texture_rect(tex, rect, false, Color.WHITE)
		return
	_glyph(ci, rect, id, color_of(id))


static func _glyph(ci: CanvasItem, rect: Rect2, id: int, ink: Color) -> void:
	## 图案本体（不含底板 / 外框）—— `draw()` 与 `draw_glyph()` 共用同一份，
	## 保证「工具栏里的样子」和「战场上的样子」永远是同一个形状。
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	match id:
		7001: _bomb(ci, c, s, ink)''', "trap_art: 抽 _glyph + draw_glyph")

# ===================== battle_scene.gd：放大 + 去底框 + 数字换位置 =====================
BS = "scripts/battle_scene.gd"

rep(BS, '''		draw_rect(r.grow(-3.0), Color(0.26, 0.24, 0.33, 0.40), true)
		draw_rect(r.grow(-3.0), Color(0.74, 0.72, 0.84, 0.45 + 0.35 * pulse), false, 2.0)''',
    '''		draw_rect(r.grow(-3.0), Color(0.24, 0.22, 0.31, 0.56), true)
		draw_rect(r.grow(-3.0), Color(0.78, 0.76, 0.88, 0.55 + 0.35 * pulse), false, 2.5)''',
    "battle: 封锁底更实")

rep(BS, '''		var pad := 9.0
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
				Vector2(r.end.x - 13.0, r.position.y + 13.0), Color("ece7f8"))''',
    '''		var pad := 9.0
		var seal_col := Color(0.84, 0.82, 0.92, 0.50 + 0.20 * pulse)
		draw_line(r.position + Vector2(pad, pad), r.end - Vector2(pad, pad), seal_col, 3.0)
		draw_line(Vector2(r.end.x - pad, r.position.y + pad),
				Vector2(r.position.x + pad, r.end.y - pad), seal_col, 3.0)
		# 中央蒜图标：**只画图案、不画底框**（暗格上再叠一个深色方块就认不出是蒜了），
		# 尺寸按格子走（0.5 格宽）—— 固定 34px 在 128px 的格子里太小。
		var gs := CELL_W * 0.50
		TrapArt.draw_glyph(self, Rect2(r.get_center() - Vector2(gs * 0.5, gs * 0.5),
				Vector2(gs, gs)), 7017)
		# 右上角剩余我方回合数（「3」= 还能封 3 个我方回合）。不带底条 ——
		# 底条会压住格子右上边框，而这一格本身已经是深色底，白字 + 描边就够读。
		_draw_string_center(_font_bold, UI_FS_CAPTION, str(left),
				Vector2(r.end.x - 18.0, r.position.y + 18.0), Color("f4efff"))''',
    "battle: 图标放大 + 数字无底")
