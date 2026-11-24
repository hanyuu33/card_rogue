# -*- coding: utf-8 -*-
"""R780b 第三步：力场改为画在**卡面之前**，并把薄金罩从矩形改成六边形。

两个问题（都在 8x 实拍里看清了）：
1. 力场原来画在 `_draw_card_face()` **之后** → 六边形的斜边正好压在右上角
   那个圆槽徽标上，把「免伤」图标切成两半。
2. 薄金罩是**矩形**，跟六边形不同形，卡角处会露出一个直角金块 ——
   两个形状互相打脸，「隔着玻璃」的感觉就没了。

改法：整段挪到 `_draw_card_face()` 之前，罩子改成同参数的六边形填充。
画在卡面之下以后，罩子的中心被卡面盖住，只剩卡框与六边形之间那圈
**金色薄雾**——正好是「卡片浮在一层光里」的读法，也不会碰任何卡面元素。
"""
import io
import sys

P = "E:/work/card_rogue/scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()

# ---------- 1) 调用点：从 `if p.first_hit_shield:` 之前搬到 `_draw_card_face(` 之前 ----------
CALL = "\r\n".join([
    "\tif engine.damage_cap_left(p) == 0:",
    "\t\t# R780b 赫尔墨斯 9140 / 量产型赫尔墨斯 9188：本回合 20 点伤害额度已经吃满，",
    "\t\t# 接下来谁打它都进不去。这是**看卡面看不出来**的隐藏状态 ——",
    "\t\t# 卡面只写「每回合最多受到 20 点伤害」，不写「这一刻已经满了」，",
    "\t\t# 而玩家恰恰要靠这个决定「还要不要继续砸它」。",
    "\t\t# 图标由 `_state_slots()` 送进右上角圆槽，环与薄金罩在这里画。",
    "\t\t_draw_damage_cap_aura(center, w, h)",
])
if s.count(CALL) != 1:
    sys.exit("调用段计数 %d" % s.count(CALL))
s = s.replace(CALL + "\r\n", "", 1)          # 连换行一起去掉，避免留空行

ANCHOR = "\t_draw_card_face(p.card, Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),"
if s.count(ANCHOR) != 1:
    sys.exit("card_face 锚点计数 %d" % s.count(ANCHOR))

NEW_CALL = "\r\n".join([
    "\tif engine.damage_cap_left(p) == 0:",
    "\t\t# R780b 赫尔墨斯 9140 / 量产型赫尔墨斯 9188：本回合 20 点伤害额度吃满，",
    "\t\t# 接下来谁打它都进不去。这是**看卡面看不出来**的隐藏状态 ——",
    "\t\t# 卡面只写「每回合最多受到 20 点伤害」，不写「这一刻已经满了」，",
    "\t\t# 而玩家恰恰要靠这个决定「还要不要继续砸它」。",
    "\t\t# ⚠️ 必须画在 `_draw_card_face()` **之前**：",
    "\t\t#    ① 六边形斜边正好经过右上角圆槽，画在后面会把「免伤」图标切两半；",
    "\t\t#    ② 画在下面时罩心被卡面盖住，只剩卡框外那圈金色薄雾 = 「浮在光里」。",
    "\t\t_draw_damage_cap_aura(center, w, h)",
    "",
])
s = s.replace(ANCHOR, NEW_CALL + ANCHOR, 1)

# ---------- 2) 罩子：矩形 → 同参数六边形 ----------
OLD_WASH = "\r\n".join([
    "\t# 整张卡压一层极薄的金：读作「隔着玻璃罩」，但绝不能糊掉卡图（7%→13%）",
    "\tdraw_rect(Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)),",
    "\t\t\tColor(dc_col.r, dc_col.g, dc_col.b, 0.07 + dc_pulse * 0.06), true)",
])
if s.count(OLD_WASH) != 1:
    sys.exit("矩形罩段计数 %d" % s.count(OLD_WASH))

NEW_WASH = "\r\n".join([
    "\t# 罩子与光环**同形**（六边形填充）：卡面会盖住中心，只剩卡框外那圈金色薄雾。",
    "\t# 矩形罩会在卡角露出直角金块，和六边形互相打脸（R780b 实拍）。",
    "\tvar wash := PackedVector2Array()",
    "\tfor i in 6:",
    "\t\tvar wa: float = -PI * 0.5 + TAU * float(i) / 6.0",
    "\t\twash.append(center + Vector2(cos(wa) * (w * 0.5 + 12.0), sin(wa) * (h * 0.5 + 12.0)))",
    "\tdraw_colored_polygon(wash, Color(dc_col.r, dc_col.g, dc_col.b, 0.10 + dc_pulse * 0.07))",
])
s = s.replace(OLD_WASH, NEW_WASH, 1)

# ---------- 回读 ----------
if s.count("_draw_damage_cap_aura(center, w, h)") != 1:
    sys.exit("回读失败：调用计数异常")
if "draw_colored_polygon(wash" not in s:
    sys.exit("回读失败：六边形罩未写入")
if "Color(dc_col.r, dc_col.g, dc_col.b, 0.07 + dc_pulse * 0.06), true)" in s:
    sys.exit("回读失败：矩形罩仍在")
i_call = s.find("_draw_damage_cap_aura(center, w, h)")
i_face = s.find("_draw_card_face(p.card, Rect2(center")
if not (0 < i_call < i_face):
    sys.exit("回读失败：调用点顺序不对（call=%d face=%d）" % (i_call, i_face))

io.open(P, "w", encoding="utf-8", newline="").write(s)
b = io.open(P, "rb").read()
print("AURA_REORDER ok  CRLF=%d bareLF=%d  call@%d face@%d"
      % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n"), i_call, i_face))
