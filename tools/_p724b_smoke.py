# -*- coding: utf-8 -*-
"""R724b：把 smoke 守卫改成「中间那张 + 旧几何漏点数」判据（首版取最右一张，够不到棋盘列）。"""
import sys

CHECK_ONLY = "--check-only" in sys.argv
P = "scripts/test_smoke.gd"

old = (
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

new = (
    "\t# 取**中间**那张：满手时两端的卡横向已经探出棋盘列（x > 776），够不到格子。\n"
    "\tvar keep_sel: Variant = scene.selection\n"
    "\tvar keep_hover: int = scene._hover_hand\n"
    "\tvar mid: int = n / 2\n"
    "\tvar checked := 0\n"
    "\tvar bad_paint := 0\n"
    "\tvar leak_pts := 0\n"
    "\tfor mode: Dictionary in [{\"sel\": true, \"hover\": true}, {\"sel\": true, \"hover\": false},\n"
    "\t\t\t{\"sel\": false, \"hover\": true}]:\n"
    "\t\tvar want_sel: bool = bool(mode[\"sel\"])\n"
    "\t\tvar want_hover: bool = bool(mode[\"hover\"])\n"
    "\t\tscene.selection = [\"hand\", mid] if want_sel else null\n"
    "\t\tscene._hover_hand = mid if want_hover else -1\n"
    "\t\tvar pr: Rect2 = scene._hand_rect(mid)\n"
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
    "\t\t\t\tvar q: Vector2 = pv + ((base - pv) * psc).rotated(scene._hand_angle(mid))\n"
    "\t\t\t\tchecked += 1\n"
    "\t\t\t\tif not scene._hand_hit_painted(mid, q):\n"
    "\t\t\t\t\tbad_paint += 1\n"
    "\t\t\t\t# 同一个点在**旧几何**（不放大 / 不抬手；仍含选中的 28 抬起，那是 _hand_rect 自带的）\n"
    "\t\t\t\t# 下算不出手牌，而它又压在棋盘格上 → 正是用户报告的那一下「点手牌选中后排」。\n"
    "\t\t\t\tif not scene._hand_hit_geom(mid, q, 0.0, false) and scene._cell_at(q) != null:\n"
    "\t\t\t\t\tleak_pts += 1\n"
    "\tscene.selection = keep_sel\n"
    "\tscene._hover_hand = keep_hover\n"
    "\tif bad_paint > 0:\n"
    "\t\t_smoke_fail(\"扇形手牌：绘制几何里有 %d/%d 个点算不出这张牌（放大 / 抬手没进命中判定）\"\n"
    "\t\t\t\t% [bad_paint, checked])\n"
    "\telif leak_pts <= 0:\n"
    "\t\t_smoke_fail(\"扇形手牌：R724 用例没踩到旧的漏点（前提不成立，别当通过）\")\n"
    "\telse:\n"
    "\t\tprint(\"SMOKE OK 手牌命中几何：绘制几何 %d 点全部命中，其中 %d 点是旧逻辑会漏给棋盘的\"\n"
    "\t\t\t\t% [checked, leak_pts])\n"
)

data = open(P, "rb").read()
o = old.replace("\n", "\r\n").encode("utf-8")
n2 = new.replace("\n", "\r\n").encode("utf-8")
c = data.count(o)
assert c == 1, "锚点命中 %d 次（应为 1）" % c
if not CHECK_ONLY:
    open(P, "wb").write(data.replace(o, n2))
print("OK  smoke 守卫改中间那张 / 旧几何漏点数" + ("（仅检查）" if CHECK_ONLY else ""))
