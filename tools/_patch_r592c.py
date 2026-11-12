# -*- coding: utf-8 -*-
"""R592 测试补丁（卡面标志化）。

· 改掉 R393b 的旧源码锁（`_draw_growth_mark` 调用数 2 → **0**）：
  卡面不再画成长角标，+力/+生命 只在详细描述里；
· 新增 `_test_r592b()`：槽位几何（正方形 / 卡内 / 让开缎带）+ 轮播时序 +
  战场过滤 + 源码锁（文字行不再写字段、两口都挂标志、详细描述仍写成长）。
"""
import io
import sys

CHECK_ONLY = '--check-only' in sys.argv
P = 'scripts/test_engine.gd'
CR = '\r\n'

FUNC = [
    'func _test_r592b() -> void:',
    '\t## R592b：字段标志化 —— 卡面右上角**圆形槽位** + 多字段轮播；文字行不再写字段；',
    '\t## 卡面不再画成长角标（+力/+生命 只在 `CardDetailOverlay` 的「本局永久成长」段）。',
    '\tvar repo := CardRepo.load_json()',
    '\tvar base: CardData = repo.get_card(8003)',
    '\tvar box_rect := Rect2(100.0, 50.0, 232.0, 280.0)',
    '\tvar k: float = box_rect.size.y / CardFace.CARD_H_DESIGN',
    '\tvar kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)',
    '',
    '\t# ① 无字段 → 不占槽位',
    '\tvar none_c := CardData.from_dict(base.to_dict())',
    '\tnone_c.affixes = []',
    '\tcheck(CardFace.affix_badge_rect(none_c, box_rect).size == Vector2.ZERO,',
    '\t\t\t"R592b：无字段的卡不占右上角槽位")',
    '',
    '\t# ② 有字段 → 正方形槽位、整个在卡内、右沿让开稀有度缎带',
    '\tvar two_c := CardData.from_dict(base.to_dict())',
    '\ttwo_c.affixes = ["疾行", "嘲讽"]',
    '\tvar slot := CardFace.affix_badge_rect(two_c, box_rect)',
    '\tcheck(is_equal_approx(slot.size.x, slot.size.y)',
    '\t\t\tand is_equal_approx(slot.size.x, CardFace.AFFIX_BADGE_D * kc),',
    '\t\t\t"R592b：槽位是正方形且按徽章口径缩放（实际 %s）" % str(slot.size))',
    '\tcheck(slot.position.x >= box_rect.position.x and slot.end.x <= box_rect.end.x',
    '\t\t\tand slot.position.y >= box_rect.position.y and slot.end.y <= box_rect.end.y,',
    '\t\t\t"R592b：槽位整个在卡框内（实际 %s）" % str(slot))',
    '\tvar ribbon_left: float = box_rect.end.x - UiTheme.CARD_PAD * k - (27.0 * k * 0.32 + 1.0 * k)',
    '\tcheck(slot.end.x <= ribbon_left + 0.01,',
    '\t\t\t"R592b：槽位右沿不越过缎带左沿（槽右 %.2f / 缎带左 %.2f）"',
    '\t\t\t% [slot.end.x, ribbon_left])',
    '',
    '\t# ③ 战场卡面滤掉「上场后无作用」的字段（交换 / 幻影），手牌不滤',
    '\tvar board_c := CardData.from_dict(base.to_dict())',
    '\tboard_c.affixes = ["交换", "嘲讽"]',
    '\tvar on_hand := CardFace.affix_badge_queue(board_c, false)',
    '\tvar on_board_q := CardFace.affix_badge_queue(board_c, true)',
    '\tcheck(on_hand.size() == 2 and on_board_q.size() == 1 and on_board_q[0] == "嘲讽",',
    '\t\t\t"R592b：战场槽位滤掉交换（手牌 %d / 战场 %d）"',
    '\t\t\t% [on_hand.size(), on_board_q.size()])',
    '',
    '\t# ④ 轮播：三字段 1.8s 一张，末尾环形接回第 0 张',
    '\tvar three_c := CardData.from_dict(base.to_dict())',
    '\tthree_c.affixes = ["疾行", "嘲讽", "护盾"]',
    '\tvar cycle := CardFace.AFFIX_BADGE_CYCLE_MS',
    '\tvar seq: Array[int] = []',
    '\tfor i in 4:',
    '\t\tseq.append(int(CardFace.affix_badge_state(three_c, false, i * cycle)["index"]))',
    '\tcheck(seq == [0, 1, 2, 0],',
    '\t\t\t"R592b：三字段按 %dms 轮播并环形回到第一张（实际 %s）" % [cycle, str(seq)])',
    '\t# 单字段不轮播',
    '\tvar one_c := CardData.from_dict(base.to_dict())',
    '\tone_c.affixes = ["次元"]',
    '\tvar one_st := CardFace.affix_badge_state(one_c, false, 12345)',
    '\tcheck(int(one_st["count"]) == 1 and int(one_st["next"]) == -1',
    '\t\t\tand is_zero_approx(float(one_st["fade"])),',
    '\t\t\t"R592b：单字段不轮播（fade 恒 0）")',
    '\t# 收尾阶段 next 指向下一张（交叉淡化）',
    '\tvar fade_st := CardFace.affix_badge_state(three_c, false, cycle - 1)',
    '\tcheck(int(fade_st["next"]) == 1,',
    '\t\t\t"R592b：切换前 next 指向下一张（实际 %s）" % str(fade_st))',
    '',
    '\t# ⑤ 源码锁：文字行不再写字段、两口都挂标志、卡面不再画成长角标',
    '\tvar cfs := FileAccess.get_file_as_string("res://scripts/card_face.gd")',
    '\tcheck(cfs.contains(\'var affix_txt: String = ""\'),',
    '\t\t\t"R592b：文字区不再把字段名拼进「种类 · 字段」那行")',
    '\tcheck(cfs.count("_draw_growth_mark(canvas, card, rect, font_bold)") == 0,',
    '\t\t\t"R592b：卡面不再画成长角标（+力/+生命 只在详细描述）")',
    '\tcheck(cfs.contains("_draw_affix_badges(canvas, card, rect, k, on_board)")',
    '\t\t\tand cfs.contains("_draw_affix_badges(canvas, card, rect, k, false)"),',
    '\t\t\t"R592b：draw() 与 draw_pick() 两口都画字段标志")',
    '\t# ⑥ 详细描述仍然是「+力/+生命」的唯一展示位',
    '\tvar det := FileAccess.get_file_as_string("res://scripts/card_detail_overlay.gd")',
    '\tcheck(det.contains("CardFace.growth_text(_card)"),',
    '\t\t\t"R592b：详细描述仍显示本局永久成长")',
    '\t# ⑦ 每个字段都有 glyph 名（标志文件名 = affix_<glyph>.png）',
    '\tfor a: String in CardData.AFFIX_DEFS.keys():',
    '\t\tcheck(CardData.affix_glyph(a) != "",',
    '\t\t\t\t"R592b：字段 %s 必须有 glyph（标志素材按它取名）" % a)',
]


def main():
    t = io.open(P, encoding='utf-8', newline='').read()
    ok = True

    # ① 改 R393b 旧锁
    old_lock = ('\tcheck_src(r393b_cfs.count("_draw_growth_mark(canvas, card, rect, font_bold)") == 2,' + CR +
                '\t\t\t"R393b 源码：draw() 与 draw_pick() 两口都挂成长角标")' + CR)
    new_lock = ('\t# R592b 起卡面不画成长角标（店长口径「+力/+生命 直接不在卡面上显示」）——' + CR +
                '\t# 函数与 `growth_mark_rect` 留着（它有几何断言），只是没人再调用。' + CR +
                '\tcheck_src(r393b_cfs.count("_draw_growth_mark(canvas, card, rect, font_bold)") == 0,' + CR +
                '\t\t\t"R393b/R592b 源码：卡面两口都不再挂成长角标"' + CR)
    if t.count(old_lock) != 1:
        print('[FAIL] R393b 旧锁锚点 %d 次' % t.count(old_lock))
        ok = False
    else:
        t = t.replace(old_lock, new_lock, 1)

    # ② 调用
    call_old = '\t_test_r592()' + CR
    if t.count(call_old) != 1:
        print('[FAIL] _test_r592 调用锚点 %d 次' % t.count(call_old))
        ok = False
    else:
        t = t.replace(call_old, call_old + '\t_test_r592b()' + CR, 1)

    if not ok:
        print('补丁未写入')
        return 1

    body = t.rstrip('\r\n') + CR + CR + CR.join(FUNC) + CR
    if (body.count('\n') - body.count('\r\n')) != 0:
        print('[FAIL] 混进裸 LF：%d' % (body.count('\n') - body.count('\r\n')))
        return 1
    print('test_engine：R393b 旧锁已改 0；_test_r592b() 已追加（CRLF 干净）')
    if CHECK_ONLY:
        print('--check-only：未写盘')
        return 0
    io.open(P, 'w', encoding='utf-8', newline='').write(body)
    print('已写入')
    return 0


if __name__ == '__main__':
    sys.exit(main())
