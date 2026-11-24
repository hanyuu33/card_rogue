# -*- coding: utf-8 -*-
"""R836b：时针动画的观感修正（素材对齐 + 指针比例）。

① 轴座对齐：素材里轴座相对纹理中心偏 (+6, +9)（512 空间，程序测出来的质心），
   直接按纹理中心旋转 → 指针与轴座差 3~4px，静止帧能看出来。
   现在绘制时整张表盘反向平移这点偏移，让**轴座落在绘制中心**，指针从轴座出发。
② 指针比例：用户要的是「**时针**」，原来的 0.34d 细长针读作分针 →
   收短到 0.29d、加粗一档，末端加一个小菱形（时针的经典形状）。
③ 抖动幅度 0.055 → 0.085 rad（约 3° → 5°）——「坏掉的钟」那两下现在看得见了。

⚠️ battle_scene.gd 是 CRLF。
"""
ROOT = "E:/work/card_rogue/"


def rd(rel):
    return open(ROOT + rel, "rb").read()


def wr(rel, b):
    open(ROOT + rel, "wb").write(b)


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8")


def rep(b, old, new, tag):
    assert b.count(old) == 1, "[%s] 命中 %d 次" % (tag, b.count(old))
    return b.replace(old, new)


BS = "scripts/battle_scene.gd"
bs = rd(BS)

# ① 常量：轴座偏移
bs = rep(bs, crlf(
    "const CLOCK_FX_MS := 1150\n"
    "const CLOCK_FX_D := 240.0       # 表盘直径（棋盘坐标，随棋盘缩放）\n"),
    crlf(
    "const CLOCK_FX_MS := 1150\n"
    "const CLOCK_FX_D := 240.0       # 表盘直径（棋盘坐标，随棋盘缩放）\n"
    "## 素材里轴座相对纹理中心偏 (+6, +9)（512 空间，程序测的质心）——\n"
    "## 绘制时整张表盘反向平移这点偏移，指针从**轴座**出发而不是从几何中心出发。\n"
    "const CLOCK_FACE_PIVOT := Vector2(6.0, 9.0) / 512.0\n"),
    "bs.pivot")

# ② 表盘绘制：按轴座对齐
bs = rep(bs, crlf(
    "\tvar tex := UiAssets.clock_face()\n"
    "\tif tex != null:\n"
    "\t\tdraw_texture_rect(tex, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false,\n"
    "\t\t\t\tColor(1.0, 1.0, 1.0, a))\n"
    "\telse:\n"
    "\t\t_draw_clock_face_fallback(c, d, a)\n"),
    crlf(
    "\tvar tex := UiAssets.clock_face()\n"
    "\tif tex != null:\n"
    "\t\tvar fc := c - CLOCK_FACE_PIVOT * d      # 轴座落在 c：整张表盘反向平移\n"
    "\t\tdraw_texture_rect(tex, Rect2(fc - Vector2(d, d) * 0.5, Vector2(d, d)), false,\n"
    "\t\t\t\tColor(1.0, 1.0, 1.0, a))\n"
    "\telse:\n"
    "\t\t_draw_clock_face_fallback(c, d, a)\n"),
    "bs.face")

# ③ 指针：短粗（时针）+ 末端菱形 + 抖动加大
bs = rep(bs, crlf(
    "\tvar ang := -PI * 0.5 + TAU * (1.0 - pow(1.0 - spin, 2.2))\n"
    "\tif spin >= 1.0:\n"
    "\t\tvar jt := clampf((t - 0.74) / 0.26, 0.0, 1.0)\n"
    "\t\tang += sin(jt * 34.0) * 0.055 * (1.0 - jt)\n"
    "\tvar dir := Vector2(cos(ang), sin(ang))\n"
    "\tvar tip := c + dir * (d * 0.34)\n"
    "\tvar tail := c - dir * (d * 0.09)\n"
    "\t# 先深褐描边再压金芯 —— 与卡面同一套「细黑描边 + 平涂」\n"
    "\tdraw_line(tail, tip, Color(0.16, 0.13, 0.09, a), maxf(1.0, 6.0 * s), true)\n"
    "\tdraw_line(c - dir * (d * 0.06), tip - dir * 1.5, Color(0.85, 0.66, 0.25, a),\n"
    "\t\t\tmaxf(1.0, 3.2 * s), true)\n"),
    crlf(
    "\tvar ang := -PI * 0.5 + TAU * (1.0 - pow(1.0 - spin, 2.2))\n"
    "\tif spin >= 1.0:\n"
    "\t\tvar jt := clampf((t - 0.74) / 0.26, 0.0, 1.0)\n"
    "\t\tang += sin(jt * 34.0) * 0.085 * (1.0 - jt)\n"
    "\tvar dir := Vector2(cos(ang), sin(ang))\n"
    "\t# 时针比例（用户口径「时针」）：短而粗，长度落在刻度内圈之内，不压刻度\n"
    "\tvar tip := c + dir * (d * 0.29)\n"
    "\tvar tail := c - dir * (d * 0.08)\n"
    "\tvar hb := Color(0.16, 0.13, 0.09, a)\n"
    "\tvar hg := Color(0.85, 0.66, 0.25, a)\n"
    "\t# 先深褐描边再压金芯 —— 与卡面同一套「细黑描边 + 平涂」\n"
    "\tdraw_line(tail, tip, hb, maxf(1.0, 8.0 * s), true)\n"
    "\tdraw_line(c - dir * (d * 0.05), tip - dir * 1.5, hg, maxf(1.0, 4.6 * s), true)\n"
    "\t# 针尖小菱形（时针的读法，也遮住金芯的圆头）\n"
    "\tvar side := Vector2(-dir.y, dir.x)\n"
    "\tdraw_colored_polygon(PackedVector2Array([\n"
    "\t\t\ttip + dir * (4.6 * s), tip + side * (3.4 * s),\n"
    "\t\t\ttip - dir * (3.2 * s), tip - side * (3.4 * s)]), hb)\n"),
    "bs.hand")

wr(BS, bs)
print("R836b 补丁完成：battle_scene 轴座对齐 + 时针比例")
