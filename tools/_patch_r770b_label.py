## R770b：说明类飘字改成胶囊徽标（battle_scene.gd + test_engine.gd 的断言同步）。
## 两个文件都是 CRLF —— 只用本脚本做 exact-replace。
P = "scripts/battle_scene.gd"
Q = "scripts/test_engine.gd"

d = open(P, "rb").read().decode("utf-8")

# ① 变量：加一个 1px 细边用的 StyleBoxFlat
old_var = (
    '## R770：伤害数字底板（只有拖卡预览用）。每帧 new 一个 StyleBoxFlat 太浪费 →\r\n'
    '## 复用同一实例，只改颜色 / 圆角。\r\n'
    'var _dmg_plate_box: StyleBoxFlat = null\r\n'
)
new_var = (
    '## R770：伤害数字底板（只有拖卡预览用）。每帧 new 一个 StyleBoxFlat 太浪费 →\r\n'
    '## 复用同一实例，只改颜色 / 圆角。\r\n'
    'var _dmg_plate_box: StyleBoxFlat = null\r\n'
    '## R770b：说明类飘字（胶囊徽标）的 1px 色相细边。同样复用实例。\r\n'
    'var _dmg_edge_box: StyleBoxFlat = null\r\n'
)
assert d.count(old_var) == 1, "var anchor=%d" % d.count(old_var)
d = d.replace(old_var, new_var)

# ② 飘字说明分支：换成徽标画法
old_call = (
    '\t\tif not is_num:\r\n'
    '\t\t\t# R770：说明类飘字（法术名 / 「接下 5」/「冰封」）保持 R140 的带底条样式 ——\r\n'
    '\t\t\t# 它们要**读**，不是要感受分量；换成大字反而挤掉信息。\r\n'
    '\t\t\tvar alpha := 1.0 - t * t\r\n'
    '\t\t\tvar size := int(f.get("size", 15))\r\n'
    '\t\t\tcol.a = alpha\r\n'
    '\t\t\t_draw_string_box_center(_font_bold, size, txt,\r\n'
    '\t\t\t\t\tbase_pos + Vector2(0, -30.0 * t), col,\r\n'
    '\t\t\t\t\tColor(TEXT_BG.r, TEXT_BG.g, TEXT_BG.b, TEXT_BG.a * alpha))\r\n'
    '\t\t\tcontinue\r\n'
)
new_call = (
    '\t\tif not is_num:\r\n'
    '\t\t\t# R770b：说明类飘字（法术名 / 「接下 5」/「冰封」）从「便利贴方块」换成\r\n'
    '\t\t\t# **胶囊徽标** —— 它们要**读**，所以不进数字那套弹性弹字；但样式得跟\r\n'
    '\t\t\t# 数字同代，不然同屏一个贴纸一个大字。\r\n'
    '\t\t\tvar alpha := 1.0 - t * t\r\n'
    '\t\t\t_paint_status_label(_font_bold, base_pos + Vector2(0, -30.0 * t), txt,\r\n'
    '\t\t\t\t\tcol, alpha, int(f.get("size", 15)))\r\n'
    '\t\t\tcontinue\r\n'
)
assert d.count(old_call) == 1, "call anchor=%d" % d.count(old_call)
d = d.replace(old_call, new_call)

# ③ 新增 _dmg_edge / _paint_status_label（紧跟 _dmg_plate 之后）
old_plate_end = (
    '\t_dmg_plate_box.bg_color = col\r\n'
    '\t_dmg_plate_box.set_corner_radius_all(rad)\r\n'
    '\tdraw_style_box(_dmg_plate_box, rect)\r\n'
)
new_plate_end = (
    '\t_dmg_plate_box.bg_color = col\r\n'
    '\t_dmg_plate_box.set_corner_radius_all(rad)\r\n'
    '\tdraw_style_box(_dmg_plate_box, rect)\r\n'
    '\r\n'
    '\r\n'
    'func _dmg_edge(rect: Rect2, col: Color, rad: int) -> void:\r\n'
    '\t## R770b：1px 色相细边（透明底 + 一圈 border）。Capsule 的圆角直接给 rad\r\n'
    '\t## （= 高的一半），StyleBoxFlat 会自动夹到合法范围。\r\n'
    '\tif _dmg_edge_box == null:\r\n'
    '\t\t_dmg_edge_box = StyleBoxFlat.new()\r\n'
    '\t\t_dmg_edge_box.anti_aliasing = true\r\n'
    '\t\t_dmg_edge_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)\r\n'
    '\t\t_dmg_edge_box.set_border_width_all(1)\r\n'
    '\t_dmg_edge_box.border_color = col\r\n'
    '\t_dmg_edge_box.set_corner_radius_all(rad)\r\n'
    '\tdraw_style_box(_dmg_edge_box, rect)\r\n'
    '\r\n'
    '\r\n'
    'func _paint_status_label(font: Font, center: Vector2, text: String, tint: Color,\r\n'
    '\t\talpha: float, px: int) -> void:\r\n'
    '\t## R770b：说明类飘字的**唯一画法**（胶囊徽标）。`center` 是屏幕空间的中心。\r\n'
    '\t## 五层：落地阴影 → 深底 → 上半弧面高光 → 1px 色相细边 → 描边文字。\r\n'
    '\t## ⚠️ 与 `_paint_dmg_number()` 一样**不改变换**；几何与配色全部取 `DmgNumber`。\r\n'
    '\tif px < 7:\r\n'
    '\t\tpx = 7\r\n'
    '\tvar met := DmgNumber.label_metrics(px)\r\n'
    '\tvar pad_x := float(met["pad_x"])\r\n'
    '\tvar pad_y := float(met["pad_y"])\r\n'
    '\tvar sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)\r\n'
    '\tvar h := font.get_height(px)\r\n'
    '\tvar rect := Rect2(center.x - sz.x * 0.5 - pad_x, center.y - h * 0.5 - pad_y,\r\n'
    '\t\t\tsz.x + pad_x * 2.0, h + pad_y * 2.0)\r\n'
    '\tvar rad := int(round(rect.size.y * 0.5))\r\n'
    '\tvar edge := DmgNumber.label_edge(tint)\r\n'
    '\t# ① 落地阴影：往下错 2px，让胶囊「贴」在木板上而不是浮着\r\n'
    '\t_dmg_plate(Rect2(rect.position + Vector2(0.0, 2.0), rect.size),\r\n'
    '\t\t\tColor(0.0, 0.0, 0.0, DmgNumber.LABEL_SHADOW_ALPHA * alpha), rad)\r\n'
    '\t# ② 主体深底\r\n'
    '\t_dmg_plate(rect, Color(0.055, 0.045, 0.038, DmgNumber.LABEL_PLATE_ALPHA * alpha), rad)\r\n'
    '\t# ③ 上半弧面高光：圆管的上沿受光，做出立体；半径夹一次，别超过自身半高\r\n'
    '\tvar arc := Rect2(rect.position + Vector2(0.0, 1.0),\r\n'
    '\t\t\tVector2(rect.size.x, rect.size.y * 0.46))\r\n'
    '\t_dmg_plate(arc, Color(1.0, 1.0, 1.0, DmgNumber.LABEL_ARC_ALPHA * alpha),\r\n'
    '\t\t\tmini(rad, int(arc.size.y * 0.5)))\r\n'
    '\t# ④ 一圈色相细边\r\n'
    '\t_dmg_edge(rect, Color(edge.r, edge.g, edge.b, DmgNumber.LABEL_EDGE_ALPHA * alpha), rad)\r\n'
    '\t# ⑤ 字：先深描边再填 —— 底色已经压住底图，描边只为让笔画立起来\r\n'
    '\tvar ink := DmgNumber.label_ink(tint)\r\n'
    '\tvar pos := Vector2(center.x - sz.x * 0.5, center.y + float(px) * 0.36)\r\n'
    '\tdraw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,\r\n'
    '\t\t\tint(met["outline"]), Color(0.04, 0.03, 0.025, 0.85 * alpha))\r\n'
    '\tdraw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,\r\n'
    '\t\t\tColor(ink.r, ink.g, ink.b, alpha))\r\n'
)
assert d.count(old_plate_end) == 1, "plate anchor=%d" % d.count(old_plate_end)
d = d.replace(old_plate_end, new_plate_end)

open(P, "wb").write(d.encode("utf-8"))
raw = open(P, "rb").read()
print("battle_scene ok  CRLF=%d  LF-only=%d" % (raw.count(b"\r\n"), raw.count(b"\n") - raw.count(b"\r\n")))

# ④ 断言：源码守卫换成新口，并补徽标几何 / 配色断言
t = open(Q, "rb").read().decode("utf-8")
old_chk = (
    '\tcheck_src(r770_bs.find("_draw_string_box_center(_font_bold, size, txt,") >= 0,\r\n'
    '\t\t\t"R770 源码：说明类飘字仍走带底条样式（不能全换成大字）")\r\n'
)
new_chk = (
    '\t# R770b：说明类飘字改走胶囊徽标 —— 守卫换成新口，且**必须是徽标口**，\r\n'
    '\t# 不许顺手把它塞进数字的弹字（说明文字要读，不需要「分量」）。\r\n'
    '\tcheck_src(r770_bs.find("_paint_status_label(_font_bold") >= 0\r\n'
    '\t\t\tand r770_bs.find("_dmg_edge(rect,") >= 0,\r\n'
    '\t\t\t"R770b 源码：说明类飘字走 _paint_status_label（胶囊徽标），不再垫直角方块")\r\n'
    '\t# 徽标几何：留白随字号长，且上下小于左右（长条胶囊，不是正方形贴纸）\r\n'
    '\tvar r770_lm := DmgNumber.label_metrics(20)\r\n'
    '\tcheck(int(r770_lm["pad_x"]) > int(r770_lm["pad_y"]),\r\n'
    '\t\t\t"R770b 徽标：左右留白 > 上下留白（横向长条）")\r\n'
    '\tcheck(int(r770_lm["pad_y"]) * 2 + 20 < 40,\r\n'
    '\t\t\t"R770b 徽标：胶囊总高要压得住，别把飘字撑成大块")\r\n'
    '\tcheck(int(r770_lm["outline"]) >= 2, "R770b 徽标：描边至少 2px（笔画才立得住）")\r\n'
    '\t# 字面比细边亮、且两者都留色相：冰封的冷色不能被洗成灰白\r\n'
    '\tvar r770_ink := DmgNumber.label_ink(Color("8ad4f0"))\r\n'
    '\tvar r770_edg := DmgNumber.label_edge(Color("8ad4f0"))\r\n'
    '\tcheck(r770_ink.v > 0.95 and r770_edg.v < 0.7,\r\n'
    '\t\t\t"R770b 徽标：字面接近全亮、细边明显更暗（边比字亮会抢视线）")\r\n'
    '\tcheck(absf(r770_ink.h - Color("8ad4f0").h) < 0.03,\r\n'
    '\t\t\t"R770b 徽标：字面保留色相（冰封仍是冷色）")\r\n'
)
assert t.count(old_chk) == 1, "check anchor=%d" % t.count(old_chk)
t = t.replace(old_chk, new_chk)
open(Q, "wb").write(t.encode("utf-8"))
raw2 = open(Q, "rb").read()
print("test_engine ok  CRLF=%d  LF-only=%d" % (raw2.count(b"\r\n"), raw2.count(b"\n") - raw2.count(b"\r\n")))
