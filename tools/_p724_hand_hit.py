# -*- coding: utf-8 -*-
"""R724：手牌点击命中判定与绘制几何对齐（修「点手牌点到后排单位」）。

用法：python tools/_p724_hand_hit.py [--check-only]
"""
import sys

CHECK_ONLY = "--check-only" in sys.argv
ROOT = ""


def patch(path, old, new, tag):
    full = ROOT + path
    data = open(full, "rb").read()
    o = old.replace("\n", "\r\n").encode("utf-8")
    n = new.replace("\n", "\r\n").encode("utf-8")
    c = data.count(o)
    assert c == 1, "%s: 锚点命中 %d 次（应为 1）" % (tag, c)
    if not CHECK_ONLY:
        open(full, "wb").write(data.replace(o, n))
    print("OK  %s" % tag)


B = "scripts/battle_scene.gd"
S = "scripts/test_smoke.gd"

# ---------------------------------------------------------------- A：命中几何
old_a = (
    "func _hand_hit(i: int, pos: Vector2) -> bool:\n"
    "\t## 精确命中：把鼠标点**反向旋转**回卡牌本地坐标再判矩形。\n"
    "\t## （卡是转着画的，直接拿轴对齐矩形判会在两端错位；这里用同一条 _hand_angle。）\n"
    "\t## 注意：悬停抬手只影响绘制、不进 _hand_rect，所以不会出现「抬起→不再命中→闪」。\n"
    "\tvar pivot := _hand_pivot(i)\n"
    "\tvar local := pivot + (pos - pivot).rotated(-_hand_angle(i))\n"
    "\treturn Rect2(_hand_rect(i).position, Vector2(HAND_CARD_W, HAND_CARD_H)).has_point(local)\n"
)
new_a = (
    "func _hand_hit(i: int, pos: Vector2) -> bool:\n"
    "\t## **静态**命中（不含悬停抬手 / 选中放大）—— 只给悬停判定用（`_on_hover`）。\n"
    "\t## 精确：把鼠标点**反向旋转**回卡牌本地坐标再判矩形。\n"
    "\t## （卡是转着画的，直接拿轴对齐矩形判会在两端错位；这里用同一条 _hand_angle。）\n"
    "\t## 注意：悬停抬手只影响绘制、不进 _hand_rect，所以不会出现「抬起→不再命中→闪」。\n"
    "\t## ⚠️ R724：点击 / 拖拽**不要**走这条，用 `_hand_hit_painted`（按画出来的几何判）。\n"
    "\treturn _hand_hit_geom(i, pos, 0.0, false)\n"
    "\n\n"
    "func _hand_hit_painted(i: int, pos: Vector2) -> bool:\n"
    "\t## R724：按**画出来的**那张卡判命中 —— 含悬停抬手（HAND_FAN_HOVER_LIFT）、选中放大\n"
    "\t## （HAND_SELECT_SCALE）与回合归属位移（_hand_turn_dy），与 `_draw_hand_card` 同一套几何。\n"
    "\t## 旧版只按未放大的轴对齐矩形判（R416 原话「不挪命中矩形」），于是「看到的卡面」比\n"
    "\t## 「能点中的卡面」大一圈：选中 1.3 倍 + 悬停再抬 28 → 卡顶探进棋盘可视窗几十像素，\n"
    "\t## 玩家点在自己手牌上，结算出来的却是**自己后排滚下来的单位**（用户报告）。\n"
    "\t## 悬停仍走静态版 `_hand_hit`：那里若把抬手算进来，就成了\n"
    "\t##   「抬起 → 点不在卡上 → 落下 → 又命中」的闪。\n"
    "\tvar lift := HAND_FAN_HOVER_LIFT if i == _hover_hand else 0.0\n"
    "\treturn _hand_hit_geom(i, pos, lift, _is_hand_selected(i))\n"
    "\n\n"
    "func _hand_hit_geom(i: int, pos: Vector2, lift: float, selected: bool) -> bool:\n"
    "\t## 命中判定的**唯一几何口**：与 `_draw_hand_card` 的行序逐行对齐\n"
    "\t## （_hand_rect → 减 lift → 加 _hand_turn_dy → 绕卡底中心旋转 + 缩放）。\n"
    "\t## 那边以后再加偏移（除 `_shake_card` 那种纯视觉抖动），这里必须同改。\n"
    "\tvar r := _hand_rect(i)\n"
    "\tr.position.y -= lift\n"
    "\tr.position.y += _hand_turn_dy\n"
    "\tvar pivot := Vector2(r.position.x + HAND_CARD_W / 2.0, r.position.y + HAND_CARD_H)\n"
    "\tvar scl := HAND_SELECT_SCALE if selected else 1.0\n"
    "\tvar local := pivot + ((pos - pivot).rotated(-_hand_angle(i))) / scl\n"
    "\treturn r.has_point(local)\n"
)
patch(B, old_a, new_a, "A _hand_hit 拆静态 / 绘制几何")

# ---------------------------------------------------------------- B：索引口
old_b = (
    "\tfor i in range(engine.state.hand.size() - 1, -1, -1):\n"
    "\t\tif _hand_hit(i, pos):\n"
    "\t\t\treturn i\n"
    "\treturn -1\n"
)
new_b = (
    "\t## R724：用**绘制几何**版 —— 点到的必须是眼睛看到的那张卡。\n"
    "\tfor i in range(engine.state.hand.size() - 1, -1, -1):\n"
    "\t\tif _hand_hit_painted(i, pos):\n"
    "\t\t\treturn i\n"
    "\treturn -1\n"
)
patch(B, old_b, new_b, "B _hand_index_at 换绘制几何")

# ---------------------------------------------------------------- C：_on_left_click 签名
old_c = (
    "func _on_left_click(pos: Vector2) -> void:\n"
    "\t# R288：玩家一动手就交还镜头"
)
new_c = (
    "func _on_left_click(pos: Vector2, hand_hint := -1) -> void:\n"
    "\t## hand_hint：R724 —— 按下那一刻命中的手牌下标（没有则 -1）。只有 `_gui_input`\n"
    "\t## 的松手分支会传；其余入口（没拖动的棋盘 / 左栏轻点）走默认值，行为不变。\n"
    "\t# R288：玩家一动手就交还镜头"
)
patch(B, old_c, new_c, "C _on_left_click 接受 hand_hint")

# ---------------------------------------------------------------- D：手牌分支吃 hint
old_d = (
    "\t# 手牌：必须和悬停/拖拽用同一套判定（卡是转着画的、还会互相重叠），\n"
    "\t# 否则会出现「悬停显示 A、点下去选中 B」。\n"
    "\tvar hi := _hand_index_at(pos)\n"
    "\tif hi >= 0:\n"
)
new_d = (
    "\t# 手牌：必须和**画出来的**几何用同一套判定（卡是转着画的、还会互相重叠、选中还会放大），\n"
    "\t# 否则会出现「悬停显示 A、点下去选中 B」，或者更糟：点在卡上却选中了背后棋盘上的单位。\n"
    "\tvar hi := _hand_index_at(pos)\n"
    "\tif hi < 0 and hand_hint >= 0 and hand_hint < engine.state.hand.size():\n"
    "\t\t# R724：按下时点在卡上，松手前悬停状态变了（抬手消失 → 命中区缩回去）——\n"
    "\t\t# 仍按按下时那张结算，别把这一下漏给棋盘。\n"
    "\t\thi = hand_hint\n"
    "\tif hi >= 0:\n"
)
patch(B, old_d, new_d, "D 手牌分支接受按下时下标")

# ---------------------------------------------------------------- E：松手传下标
old_e = (
    "\t\t\telif _press_idx >= 0:\n"
    "\t\t\t\t_on_left_click(event.position)\n"
)
new_e = (
    "\t\t\telif _press_idx >= 0:\n"
    "\t\t\t\t# R724：把按下时命中的那张带过去 —— 松手前悬停若被清掉，重算会算不到\n"
    "\t\t\t\t# （命中区随抬手缩回），这一下就又漏给棋盘了。\n"
    "\t\t\t\t_on_left_click(event.position, _press_idx)\n"
)
patch(B, old_e, new_e, "E 松手分支传 _press_idx")

# ---------------------------------------------------------------- F：绘制注释同步
old_f = (
    "\t# R416：选中（点击 / 拖拽）的手牌整张放大 —— 绕卡底中心缩放，向上 / 两侧长出，\n"
    "\t# 不挪命中矩形（命中仍按 _hand_rect 原尺寸，见 _hand_hit）。\n"
)
new_f = (
    "\t# R416：选中（点击 / 拖拽）的手牌整张放大 —— 绕卡底中心缩放，向上 / 两侧长出。\n"
    "\t# R724：命中判定**跟着放大 / 跟着抬手**（`_hand_hit_painted` → `_hand_hit_geom`）——\n"
    "\t# 以前这里「不挪命中矩形」，玩家点放大后的卡面上缘就会漏给棋盘（= 选中背后后排单位）。\n"
)
patch(B, old_f, new_f, "F 绘制处注释同步")

# ---------------------------------------------------------------- G：smoke 守卫
old_g = (
    "\t\tmsg += \" / 倾角 左 %.1f° 右 %.1f° / 横向 %.0f~%.0f（不越界）\" % [\n"
    "\t\t\t\tleft_deg, right_deg, el.x, er.y]\n"
    "\t\tprint(msg)\n"
)
new_g = (
    "\t\tmsg += \" / 倾角 左 %.1f° 右 %.1f° / 横向 %.0f~%.0f（不越界）\" % [\n"
    "\t\t\t\tleft_deg, right_deg, el.x, er.y]\n"
    "\t\tprint(msg)\n"
    "\t# R724：**画出来的**卡面必须整张都点得中 —— 选中放大（1.3）与悬停抬手（28）都会让卡顶\n"
    "\t# 探进棋盘可视窗（最多几十像素），命中判定必须跟着放大、跟着抬；否则那段像素漏给棋盘，\n"
    "\t# 玩家点自己的手牌却选中了背后滚下来的后排单位（用户报告）。\n"
    "\tvar keep_sel: Variant = scene.selection\n"
    "\tvar keep_hover: int = scene._hover_hand\n"
    "\tvar bad_paint := 0\n"
    "\tvar overlap_pts := 0\n"
    "\tfor mode: Dictionary in [{\"sel\": true, \"hover\": true}, {\"sel\": true, \"hover\": false},\n"
    "\t\t\t{\"sel\": false, \"hover\": true}]:\n"
    "\t\tvar want_sel: bool = bool(mode[\"sel\"])\n"
    "\t\tvar want_hover: bool = bool(mode[\"hover\"])\n"
    "\t\tscene.selection = [\"hand\", n - 1] if want_sel else null\n"
    "\t\tscene._hover_hand = n - 1 if want_hover else -1\n"
    "\t\tvar pr: Rect2 = scene._hand_rect(n - 1)\n"
    "\t\tpr.position.y -= scene.HAND_FAN_HOVER_LIFT if want_hover else 0.0\n"
    "\t\tpr.position.y += scene._hand_turn_dy\n"
    "\t\tvar psc: float = scene.HAND_SELECT_SCALE if want_sel else 1.0\n"
    "\t\tvar pv := Vector2(pr.position.x + pr.size.x / 2.0, pr.position.y + pr.size.y)\n"
    "\t\tfor ku in 5:\n"
    "\t\t\tfor kv in 5:\n"
    "\t\t\t\tvar u := 0.08 + 0.21 * float(ku)   # 0.08 .. 0.92，避开边缘像素误差\n"
    "\t\t\t\tvar v := 0.08 + 0.21 * float(kv)\n"
    "\t\t\t\tvar base := Vector2(pr.position.x + pr.size.x * u,\n"
    "\t\t\t\t\t\tpr.position.y + pr.size.y * v)\n"
    "\t\t\t\tvar q: Vector2 = pv + ((base - pv) * psc).rotated(scene._hand_angle(n - 1))\n"
    "\t\t\t\tif not scene._hand_hit_painted(n - 1, q):\n"
    "\t\t\t\t\tbad_paint += 1\n"
    "\t\t\t\t# 顺带确认这个用例真的踩到了「手牌压住棋盘」的重叠带，不是空转通过。\n"
    "\t\t\t\tif q.y < scene.GRID_Y + scene.GRID_H and scene._cell_at(q) != null:\n"
    "\t\t\t\t\toverlap_pts += 1\n"
    "\tscene.selection = keep_sel\n"
    "\tscene._hover_hand = keep_hover\n"
    "\tif bad_paint > 0:\n"
    "\t\t_smoke_fail(\"扇形手牌：绘制几何里有 %d 个点算不出这张牌（放大 / 抬手没进命中判定）\"\n"
    "\t\t\t\t% bad_paint)\n"
    "\tif overlap_pts <= 0:\n"
    "\t\t_smoke_fail(\"扇形手牌：R724 用例没踩到手牌压住棋盘的重叠带（前提不成立，别当通过）\")\n"
)
patch(S, old_g, new_g, "G smoke 加绘制几何守卫")

print("DONE" + ("（仅检查）" if CHECK_ONLY else ""))
