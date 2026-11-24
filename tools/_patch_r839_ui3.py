## R839：大蒜 7017 —— 蒜头图案改成「三瓣 + 尖」（第二版截图里单椭圆像水滴/叶子）
## 用法：python tools/_patch_r839_ui3.py
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


TA = "scripts/trap_art.gd"

OLD = '''static func _garlic(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
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
		ci.draw_line(mid, bot, dark, w, true)'''

NEW = '''static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	## 椭圆填充（CanvasItem 只有 draw_circle，缩不成椭圆）——
	## 大蒜的三片瓣都靠它画，别为此引一张贴图。
	var pts := PackedVector2Array()
	var steps := 20
	for k in steps:
		var a := TAU * float(k) / float(steps)
		pts.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func _garlic(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R839 大蒜 7017：**三瓣 + 尖**的蒜头剪影。
	## ⚠️ 单个椭圆 + 竖纹（第一版）在 60~64px 下读成「水滴 / 叶子」——
	## 认蒜头靠的是**分瓣轮廓**：中间一瓣最高最宽、两侧各一瓣略低，顶上一个尖。
	## 与 `_mushroom` / `_puffer` 同一路数：单色剪影，靠形状认东西。
	var w := maxf(1.3, s * 0.022)
	var body := c + Vector2(0, s * 0.11)
	var dark := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, col.a)
	# 三瓣：中瓣盖住两侧的内半边 → 合起来是一个圆底、两条浅沟的蒜头
	_ellipse(ci, body + Vector2(-s * 0.145, s * 0.045), s * 0.115, s * 0.185, col)
	_ellipse(ci, body + Vector2(s * 0.145, s * 0.045), s * 0.115, s * 0.185, col)
	_ellipse(ci, body, s * 0.165, s * 0.225, col)
	# 顶端尖：从两肩收到一个点（蒜苗断口），比圆顶更像蒜
	ci.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - s * 0.115, body.y - s * 0.135),
			Vector2(c.x + s * 0.115, body.y - s * 0.135),
			Vector2(c.x, body.y - s * 0.375)]), col)
	# 分瓣沟：两道竖线落在瓣与瓣的接缝上（同色系深一档）
	for sx: float in [-0.132, 0.132]:
		ci.draw_line(Vector2(c.x + sx * s, body.y - s * 0.105),
				Vector2(c.x + sx * s * 1.02, body.y + s * 0.205), dark, w, true)
	# 底部一道浅横沟（蒜头「坐」在案板上的那条线）
	ci.draw_line(Vector2(c.x - s * 0.13, body.y + s * 0.19),
			Vector2(c.x + s * 0.13, body.y + s * 0.19), dark, w * 0.8, true)'''

rep(TA, OLD, NEW, "trap_art: 蒜头三瓣版")

# 数字往格内再收一点（第一版 y+18 时上沿顶到格边）
BS = "scripts/battle_scene.gd"
rep(BS, '''		_draw_string_center(_font_bold, UI_FS_CAPTION, str(left),
				Vector2(r.end.x - 18.0, r.position.y + 18.0), Color("f4efff"))''',
    '''		_draw_string_center(_font_bold, UI_FS_CAPTION, str(left),
				Vector2(r.end.x - 21.0, r.position.y + 23.0), Color("f4efff"))''',
    "battle: 数字内收")
