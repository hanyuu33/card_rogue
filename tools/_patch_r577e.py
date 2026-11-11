# -*- coding: utf-8 -*-
"""R577e：道具图标高亮（判定口扩展 + 图标本体提亮 + 三层判据 + 演示口）。

可重跑：每个 apply 用「终态标记」判 SKIP，锚点用 exact-replace 且 assert count==1。
目标四个脚本全是 CRLF；本文件里的 GDScript 片段一律按 LF 写，apply 时统一转 CRLF。
用法：python tools/_patch_r577e.py [--check-only]
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK_ONLY = "--check-only" in sys.argv


def apply(rel, old, new, tag, marker):
    p = os.path.join(ROOT, rel)
    b = io.open(p, "rb").read()
    o = old.replace("\n", "\r\n").encode("utf-8")
    n = new.replace("\n", "\r\n").encode("utf-8")
    m = marker.encode("utf-8")
    done = m in b
    if CHECK_ONLY:
        assert done, "%s：check-only 但终态标记不在" % tag
        assert b.count(n) >= 1, "%s：check-only 但新片段不完整" % tag
        print("CHECK OK", tag)
        return
    if done:
        print("SKIP", tag)
        return
    cnt = b.count(o)
    assert cnt == 1, "%s：锚点命中 %d 次（应为 1）" % (tag, cnt)
    b = b.replace(o, n, 1)
    io.open(p, "wb").write(b)
    got = io.open(p, "rb").read()
    assert m in got and got.count(n) == 1, "%s：写入后自检失败" % tag
    print("APPLY OK", tag)


GE = "scripts/game_engine.gd"
BS = "scripts/battle_scene.gd"
TE = "scripts/test_engine.gd"
SM = "scripts/test_smoke.gd"

# ---------------------------------------------------------------- 1. 判定口注释
GE_HEAD_OLD = '''func relic_highlight(id: int) -> bool:
\t## R314（用户口径）：道具栏**高亮**的唯一判定口 —— 「这一刻会不会真的落到触发点上」。
\t## 界面（`battle_scene._draw_relic_bar`）只负责画亮边，判据全在这里，好在回归里逐条钉。
\t##
\t## 口径：
\t##   * **临近触发 / 正在生效** → 亮（风妖精差一张牌、鸭翼/勇气徽章在生效回合、lucky 7 生效轮）；
\t##   * **一直被动生效**的 → **不亮**（鸭嘴/鸭之眼/快速符文/水晶骰子/不锈钢盆 …）。
\t##     它们没有「这一刻」可言，常亮等于没有信息量（用户明确排除这类）。
\t##   * 未持有 → 不亮。
\tif not self_relics.has(id):
'''
GE_HEAD_NEW = '''func relic_highlight(id: int) -> bool:
\t## R314 / R577e（用户口径）：道具栏**图标高亮**的唯一判定口 ——
\t## 「这一刻会不会真的落到触发点上 / 本回合是否正在生效」。
\t## 界面（`battle_scene._draw_relic_bar`）只负责画亮，判据全在这里，好在回归里逐条钉。
\t##
\t## 口径：
\t##   * **临近触发 / 正在生效** → 亮（风妖精差一张牌、鸭翼/勇气徽章在生效回合、
\t##     lucky 7 生效轮、咒缚还没用掉的首张减费、荒野形态本场还没挨打 …）；
\t##   * **一直被动生效**的 → **不亮**（鸭嘴/鸭之眼/快速符文/储物箱/不锈钢盆 …）。
\t##     它们没有「这一刻」可言，常亮等于没有信息量（用户明确排除这类）。
\t##   * 未持有 → 不亮。
\t## R577e：把「将要在下一次生效 / 本回合生效」这批补齐，只判已有状态位，
\t##   不新增随机数消耗、不改结算；界面高亮与数据判据共用这一份口径。
\tif not self_relics.has(id):
'''

# ---------------------------------------------------------------- 2. 判定口分支
GE_MATCH_OLD = '''\t\tSTATUE_RELIC_ID:
\t\t\t# 雕像：每 10 张牌回 1 费用 → 差 1 张就满的时候亮
\t\t\treturn RunState.statue_charge % 10 == 9
\treturn false
'''
GE_MATCH_NEW = '''\t\tSTATUE_RELIC_ID:
\t\t\t# 雕像：每 10 张牌回 1 费用 → 差 1 张就满的时候亮
\t\t\treturn RunState.statue_charge % 10 == 9
\t\t# ---- R577e：补齐「将要在下一次生效 / 本回合生效」的道具 ----
\t\t6010:   # 鸭之低语：每回合开始随机一种本回合强化
\t\t\treturn current_side == SIDE_SELF
\t\t6012:   # 一袋米抗几楼：本回合第一次我方受伤将触发
\t\t\treturn not _rice_used
\t\tEARRING_RELIC_ID:   # 鸭语耳环：首回合自动出牌（每回合 +1 费用属常驻，不算）
\t\t\treturn turn_number == 1
\t\tICECREAM_RELIC_ID:  # 冰淇淋与汽水：第 1 回合额外费用 / 抽牌
\t\t\treturn turn_number == 1
\t\tWILD_FORM_RELIC_ID:   # 荒野形态：本场第一次被攻击时减伤 + 反伤
\t\t\treturn not state.wild_form_used
\t\tSTEEL_STAMP_RELIC_ID: # 思想钢印：本场第一个被破坏的我方单位回手
\t\t\treturn not _steel_stamp_used
\t\tTHORN_RING_RELIC_ID:  # 荆棘指环：本回合第一次受伤抽 2
\t\t\treturn _thorn_ring_turn != turn_number
\t\tDICE_RELIC_ID:        # 水晶骰子：前 X 回合每回合 +1 费用（有期限，非常驻）
\t\t\treturn dice_energy_turns > 0 and turn_number <= dice_energy_turns
\t\tKNIGHT_SWORD_RELIC_ID: # 骑士剑：本场第一次击杀敌人后全体强化
\t\t\treturn not _knight_sword_fired
\t\tPIPE_RELIC_ID:        # 烟斗：点着时下一场战斗首回合生效（将要在下一次生效）
\t\t\treturn RunState.pipe_ready
\t\tCURSE_BIND_RELIC_ID:  # 咒缚：本场第一张卡 -3 费（额度还没用掉）
\t\t\treturn state.curse_free
\t\tTHREE_BOTS_RELIC_ID:  # 三个机器人：差一个盟友被破坏就抽牌
\t\t\treturn _three_bots_destroyed == THREE_BOTS_NEED - 1
\treturn false
'''

# ---------------------------------------------------------------- 3. 界面分发口
BS_LIT_OLD = '''func _relic_bar_lit() -> bool:
\t## R314：道具栏里**有没有亮着的徽章**（有 → 需要逐帧呼吸重绘，见 `_process`）。
\t## 判据全部在 `GameEngine.relic_highlight()`；这里只做「是否至少有一个」。
\tif engine == null:
\t\treturn false
\tfor rid: int in engine.self_relics:
\t\tif engine.relic_highlight(rid):
\t\t\treturn true
\treturn false
'''
BS_LIT_NEW = '''func _relic_bar_lit() -> bool:
\t## R314：道具栏里**有没有亮着的图标**（有 → 需要逐帧呼吸重绘，见 `_process`）。
\t## R577e：改成遍历绘制用的那份 ids（`_relic_bar_ids()`），与格位 / 图标同源，
\t## 避免 RunState.relics 与 engine.self_relics 不一致时「画亮了却不呼吸」。
\tvar ids := _relic_bar_ids()
\tfor i in ids.size():
\t\tif _relic_icon_lit(i):
\t\t\treturn true
\treturn false


func _relic_icon_lit(i: int) -> bool:
\t## R577e 界面分发唯一口：这一格该不该亮。判据全在 `GameEngine.relic_highlight()`，
\t## 界面只补一条「已耗尽（画灰）的不亮」。
\tif engine == null:
\t\treturn false
\tvar ids := _relic_bar_ids()
\tif i < 0 or i >= ids.size():
\t\treturn false
\tif RunState.is_relic_spent(int(ids[i])):
\t\treturn false
\treturn engine.relic_highlight(int(ids[i]))


func _relic_lit_phase() -> float:
\t## 呼吸相位（0..1）：柔光 / 图标提亮 / 外环共用同一相位，别各跳各的。
\treturn 0.5 + 0.5 * sin(float(_now()) / 220.0)


func _relic_icon_modulate(i: int) -> Color:
\t## R577e：**图标本体**的着色 —— 亮着的提亮成青白，灰掉的压灰，其余原色。
\t## 这是「道具图标高亮」的界面分发口（test_smoke 直接调它验，不靠截图猜）。
\tvar ids := _relic_bar_ids()
\tif i < 0 or i >= ids.size():
\t\treturn Color.WHITE
\tif RunState.is_relic_spent(int(ids[i])):
\t\treturn Color(0.52, 0.52, 0.55, 0.85)
\tif _relic_icon_lit(i):
\t\tvar ph := _relic_lit_phase()
\t\treturn Color(1.10 + 0.14 * ph, 1.22 + 0.16 * ph, 1.34 + 0.16 * ph, 1.0)
\treturn Color.WHITE
'''

# ---------------------------------------------------------------- 4. 绘制段
BS_DRAW_OLD = '''\t\t# R577c（店长口径）：去掉每件道具的横条底 / 边框 / 来源色块，图标本身就是格子。
\t\t# R314 呼吸高亮改走「图标外一圈青白光环」，不再依赖矩形外框。
\t\tif engine.relic_highlight(ids[i]):
\t\t\tvar lit_ph := 0.5 + 0.5 * sin(float(_now()) / 220.0)
\t\t\tvar lit_col := Color(0.56, 0.92, 1.0)
\t\t\tvar cc := rect.get_center()
\t\t\tdraw_circle(cc, rect.size.x * 0.66,
\t\t\t\t\tColor(lit_col.r, lit_col.g, lit_col.b, 0.18 + 0.20 * lit_ph))
\t\t\tdraw_arc(cc, rect.size.x * 0.63, 0.0, TAU, 40,
\t\t\t\t\tColor(lit_col.r, lit_col.g, lit_col.b, 0.72 + 0.24 * lit_ph), 2.2, true)
\t\t# R577b 的唯一取图口不变；缺图才回退到 R309 那套文字（导出包照常可玩）。
\t\tvar tex := UiAssets.relic_icon(int(ids[i]))
\t\tif tex == null:
\t\t\tdraw_rect(rect, Color("d9d7cf") if rspent else scol.lerp(Color.WHITE, 0.62), true)
\t\t\t# R309：**不描边**（outline = -1）—— 8~10 号字上 2px 描边会把笔画糊掉，
\t\t\t# 「雕像（3）」这种带括号的名字尤其看不清。
\t\t\t# R343：传奇道具名走**暗金**（底是来源色向白混 62% 的浅实色 → 亮金会糊），
\t\t\t# 普通道具仍是原来的深棕。判据在 `RelicData.name_color()`，这里不写特例。
\t\t\tvar label := RunState.relic_display_name(ids[i], engine.state.self_card_plays)
\t\t\tvar label_size := 13
\t\t\twhile label_size > 9 and _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > rect.size.x - 18:
\t\t\t\tlabel_size -= 1
\t\t\t_draw_string_center(_font_bold, label_size,
\t\t\t\t\tlabel,
\t\t\t\t\tVector2(rect.position.x + 12.0 + (rect.size.x - 12.0) / 2,
\t\t\t\t\t\t\trect.position.y + rect.size.y * 0.5 + 4.0),
\t\t\t\t\tColor("9a9488") if rspent else rel.name_color(Color("4a3c14")), -1)
\t\telse:
\t\t\tdraw_texture_rect(tex, rect, false,
\t\t\t\t\tColor(0.52, 0.52, 0.55, 0.85) if rspent else Color.WHITE)
'''
BS_DRAW_NEW = '''\t\t# R577c（店长口径）：去掉每件道具的横条底 / 边框 / 来源色块，图标本身就是格子。
\t\t# R577e：高亮 = **图标本体提亮** + 外圈青白呼吸环；环画在图标之后才看得全，
\t\t# 底层柔光用 fx_glow 贴图（R577c 不要框，硬边圆盘不再画）。
\t\tvar lit577e := _relic_icon_lit(i)
\t\tif lit577e and _fx_glow_tex != null:
\t\t\tdraw_texture_rect(_fx_glow_tex, rect.grow(13.0), false,
\t\t\t\t\tColor(0.56, 0.92, 1.0, 0.30 + 0.22 * _relic_lit_phase()))
\t\t# R577b 的唯一取图口不变；缺图才回退到 R309 那套文字（导出包照常可玩）。
\t\tvar tex := UiAssets.relic_icon(int(ids[i]))
\t\tif tex == null:
\t\t\tdraw_rect(rect, Color("d9d7cf") if rspent else scol.lerp(Color.WHITE, 0.62), true)
\t\t\t# R309：**不描边**（outline = -1）—— 8~10 号字上 2px 描边会把笔画糊掉，
\t\t\t# 「雕像（3）」这种带括号的名字尤其看不清。
\t\t\t# R343：传奇道具名走**暗金**（底是来源色向白混 62% 的浅实色 → 亮金会糊），
\t\t\t# 普通道具仍是原来的深棕。判据在 `RelicData.name_color()`，这里不写特例。
\t\t\tvar label := RunState.relic_display_name(ids[i], engine.state.self_card_plays)
\t\t\tvar label_size := 13
\t\t\twhile label_size > 9 and _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > rect.size.x - 18:
\t\t\t\tlabel_size -= 1
\t\t\t_draw_string_center(_font_bold, label_size,
\t\t\t\t\tlabel,
\t\t\t\t\tVector2(rect.position.x + 12.0 + (rect.size.x - 12.0) / 2,
\t\t\t\t\t\t\trect.position.y + rect.size.y * 0.5 + 4.0),
\t\t\t\t\tColor("9a9488") if rspent else rel.name_color(Color("4a3c14")), -1)
\t\telse:
\t\t\tdraw_texture_rect(tex, rect, false, _relic_icon_modulate(i))
\t\t# R577e 顶环：画在图标**之后**，完整压在图标外沿上（旧版画在前面被 44x44 吃掉）。
\t\tif lit577e:
\t\t\tvar lit_ph := _relic_lit_phase()
\t\t\tvar lit_col := Color(0.56, 0.92, 1.0)
\t\t\tvar cc := rect.get_center()
\t\t\tdraw_arc(cc, rect.size.x * 0.66, 0.0, TAU, 40,
\t\t\t\t\tColor(lit_col.r, lit_col.g, lit_col.b, 0.72 + 0.24 * lit_ph), 2.2, true)
'''

# ---------------------------------------------------------------- 5. 演示口
BS_DEMO_OLD = '''\t\tstatus_text = "R577d：%d 件道具按行平均分配" % r577d_n
\t\tqueue_redraw()
\tif "--r352harp" in args and engine != null:
'''
BS_DEMO_NEW = '''\t\tstatus_text = "R577d：%d 件道具按行平均分配" % r577d_n
\t\tqueue_redraw()
\tif "--relichl" in args and engine != null:
\t\t# R577e 出图：亮的（下一次 / 本回合生效）与不亮的（常驻被动）同屏对比。
\t\t# 用法：`battle.tscn -- --screenshot --relichl --shotframe 600`
\t\tvar hl_ids: Array[int] = [6042, 6012, 6022, 6037, 6058, 6060,
\t\t\t\t6006, 6044, 6041, 6009, 6043, 6052]
\t\tRunState.relics = hl_ids
\t\tengine.self_relics = hl_ids.duplicate()
\t\tengine.turn_number = 3
\t\tengine.state.self_card_plays = 4      # 6042 风妖精：下一张就是第 5 张
\t\tengine._three_bots_destroyed = 2      # 6060 三个机器人：差一个
\t\tengine.state.curse_free = true        # 6058 咒缚：第一张卡还没打
\t\tengine._rice_used = false             # 6012 一袋米：本回合还没受过伤
\t\tengine.state.wild_form_used = false   # 6022 荒野形态：本场还没触发
\t\tengine._thorn_ring_turn = -1          # 6037 荆棘指环：本回合还没触发
\t\tstatus_text = "R577e：亮 = 下一次/本回合生效；不亮 = 一直在被动生效"
\t\tqueue_redraw()
\tif "--r352harp" in args and engine != null:
'''

# ---------------------------------------------------------------- 6. 数据层判据
TE_OLD = '''\tcheck(not r314_hl.relic_highlight(9999), "R314 高亮：未持有的道具不会亮")

\t# ================= R339：续档不重复计数 / 一层只打一次 Boss =================
'''
TE_NEW = '''\tcheck(not r314_hl.relic_highlight(9999), "R314 高亮：未持有的道具不会亮")

\t# ============ R577e：图标高亮判定扩到「下一次 / 本回合生效」 ============
\tvar r577e_hl := _new_engine([], 20, 20)
\tr577e_hl.self_relics = [6010, 6012, 6015, 6016, 6022, 6036, 6037,
\t\t\t6040, 6053, 6055, 6058, 6060, 6006, 6044]
\tr577e_hl.turn_number = 1
\tr577e_hl.current_side = GameEngine.SIDE_SELF
\tr577e_hl._rice_used = false
\tr577e_hl.state.wild_form_used = false
\tr577e_hl._steel_stamp_used = false
\tr577e_hl._thorn_ring_turn = -1
\tr577e_hl.dice_energy_turns = 3
\tr577e_hl._knight_sword_fired = false
\tr577e_hl.state.curse_free = true
\tr577e_hl._three_bots_destroyed = GameEngine.THREE_BOTS_NEED - 1
\tvar r577e_pipe_saved: bool = RunState.pipe_ready
\tRunState.pipe_ready = true
\tvar r577e_on: Array[int] = [6010, 6012, 6015, 6016, 6022, 6036, 6037,
\t\t\t6040, 6053, 6055, 6058, 6060]
\tvar r577e_bad := ""
\tfor r577e_id: int in r577e_on:
\t\tif not r577e_hl.relic_highlight(r577e_id):
\t\t\tr577e_bad += " %d" % r577e_id
\tcheck(r577e_bad == "",
\t\t\t"R577e 数据：12 件「下一次/本回合生效」道具全该亮（漏:%s）" % r577e_bad)
\t# 把「差一步」的条件逐条翻掉 → 同一件道具必须灭
\tr577e_hl.turn_number = 5
\tcheck(not r577e_hl.relic_highlight(6015) and not r577e_hl.relic_highlight(6016),
\t\t\t"R577e 数据：鸭语耳环 / 冰淇淋过了首回合就灭")
\tr577e_hl._rice_used = true
\tcheck(not r577e_hl.relic_highlight(6012), "R577e 数据：一袋米本回合触发过就灭")
\tr577e_hl.state.wild_form_used = true
\tcheck(not r577e_hl.relic_highlight(6022), "R577e 数据：荒野形态本场触发过就灭")
\tr577e_hl._steel_stamp_used = true
\tcheck(not r577e_hl.relic_highlight(6036), "R577e 数据：思想钢印救过一次就灭")
\tr577e_hl._thorn_ring_turn = r577e_hl.turn_number
\tcheck(not r577e_hl.relic_highlight(6037), "R577e 数据：荆棘指环本回合抽过就灭")
\tr577e_hl.dice_energy_turns = 0
\tcheck(not r577e_hl.relic_highlight(6040), "R577e 数据：水晶骰子没骰出回合数就不亮")
\tr577e_hl._knight_sword_fired = true
\tcheck(not r577e_hl.relic_highlight(6053), "R577e 数据：骑士剑击杀过就灭")
\tRunState.pipe_ready = false
\tcheck(not r577e_hl.relic_highlight(6055), "R577e 数据：烟斗熄灭后不亮")
\tr577e_hl.state.curse_free = false
\tcheck(not r577e_hl.relic_highlight(6058), "R577e 数据：咒缚额度用掉就灭")
\tr577e_hl._three_bots_destroyed = 0
\tcheck(not r577e_hl.relic_highlight(6060), "R577e 数据：三个机器人差两个时不亮")
\tr577e_hl.current_side = GameEngine.SIDE_OPPONENT
\tcheck(not r577e_hl.relic_highlight(6010), "R577e 数据：敌方回合鸭之低语不亮")
\tRunState.pipe_ready = r577e_pipe_saved
\tcheck(not r577e_hl.relic_highlight(6006) and not r577e_hl.relic_highlight(6044),
\t\t\t"R577e 数据：常驻被动（鸭嘴 / 储物箱）仍然不亮")
\t# 源码锁：判定口 / 界面分发 / 绘制顺序
\tvar r577e_ge := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
\tvar r577e_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
\tcheck_src(r577e_ge.contains("func relic_highlight(")
\t\t\tand r577e_ge.contains("RunState.pipe_ready")
\t\t\tand r577e_ge.contains("state.curse_free"),
\t\t\t"R577e 源码：高亮唯一判定口覆盖下一次 / 本回合生效")
\tcheck_src(r577e_bs.contains("func _relic_icon_modulate(")
\t\t\tand r577e_bs.contains("func _relic_icon_lit("),
\t\t\t"R577e 源码：图标本体提亮与亮/灭判定各有唯一界面分发口")
\tvar r577e_p_icon := r577e_bs.find("draw_texture_rect(tex, rect, false, _relic_icon_modulate(i))")
\tvar r577e_p_ring := r577e_bs.find("R577e 顶环")
\tcheck_src(r577e_p_icon > 0 and r577e_p_ring > r577e_p_icon,
\t\t\t"R577e 源码：外环画在图标之后（不会被 44x44 贴图吃掉）")

\t# ================= R339：续档不重复计数 / 一层只打一次 Boss =================
'''

# ---------------------------------------------------------------- 7. 界面分发判据
SM_OLD = '''\tif int(wf.get("dur", 0)) <= 0 or int(wf.get("start", 0)) <= 0:
\t\t_smoke_fail("R314 风妖精：飘字必须带时间维度（start=%s dur=%s）"
\t\t\t\t% [str(wf.get("start")), str(wf.get("dur"))])


func _check_discard_view(scene: Variant) -> void:
'''
SM_NEW = '''\tif int(wf.get("dur", 0)) <= 0 or int(wf.get("start", 0)) <= 0:
\t\t_smoke_fail("R314 风妖精：飘字必须带时间维度（start=%s dur=%s）"
\t\t\t\t% [str(wf.get("start")), str(wf.get("dur"))])
\t# R577e 界面分发：**图标本体**要跟着高亮，不只是外面套一圈环。
\tRunState.relics = []
\tvar r577e_ids: Array[int] = [6042, 6006]
\tscene.engine.self_relics = r577e_ids
\tscene.engine.state.self_card_plays = 4
\tif not scene._relic_icon_lit(0) or scene._relic_icon_lit(1):
\t\t_smoke_fail("R577e 界面分发：风妖精该亮、鸭嘴不该亮")
\t\treturn
\tvar r577e_lit_col: Variant = scene._relic_icon_modulate(0)
\tif r577e_lit_col.r <= 1.0 or r577e_lit_col.b <= 1.0:
\t\t_smoke_fail("R577e 界面分发：亮着的图标本体没提亮（%s）" % str(r577e_lit_col))
\t\treturn
\tif scene._relic_icon_modulate(1) != Color.WHITE:
\t\t_smoke_fail("R577e 界面分发：不亮的图标应保持原色")
\t\treturn
\tif not scene._relic_bar_lit():
\t\t_smoke_fail("R577e 界面分发：有亮图标时呼吸重绘没接上")
\t\treturn


func _check_discard_view(scene: Variant) -> void:
'''

# ---------------------------------------------------------------- 8. 适配 R314 老断言
SM_R314_OLD = '''
\tvar r314_ids: Array[int] = [6042, 6045, 6007, 6006, 6044]
\tscene.engine.self_relics = r314_ids
\tscene.engine.state.self_card_plays = 4
'''
SM_R314_NEW = '''
\tvar r314_ids: Array[int] = [6042, 6045, 6007, 6006, 6044]
\tRunState.relics = r314_ids   # R577e：绘制用的 ids 与引擎同源（_relic_bar_lit 走绘制那份）
\tscene.engine.self_relics = r314_ids
\tscene.engine.state.self_card_plays = 4
'''


def main():
    apply(GE, GE_HEAD_OLD, GE_HEAD_NEW, "GE 注释", "R577e：把「将要在下一次生效")
    apply(GE, GE_MATCH_OLD, GE_MATCH_NEW, "GE 判定分支", "PIPE_RELIC_ID:        # 烟斗")
    apply(BS, BS_LIT_OLD, BS_LIT_NEW, "BS 界面分发口", "func _relic_icon_modulate(")
    apply(BS, BS_DRAW_OLD, BS_DRAW_NEW, "BS 绘制段", "R577e 顶环")
    apply(BS, BS_DEMO_OLD, BS_DEMO_NEW, "BS 演示口", 'if "--relichl" in args')
    apply(TE, TE_OLD, TE_NEW, "TE 数据层 + 源码锁", "R577e 数据：12 件")
    apply(SM, SM_OLD, SM_NEW, "SM 界面分发", "R577e 界面分发")
    apply(SM, SM_R314_OLD, SM_R314_NEW, "SM 适配 R314", "R577e：绘制用的 ids 与引擎同源")
    print("R577e PATCH", "CHECK-ONLY OK" if CHECK_ONLY else "DONE")


if __name__ == "__main__":
    main()
