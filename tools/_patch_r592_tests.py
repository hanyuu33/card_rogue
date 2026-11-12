# -*- coding: utf-8 -*-
"""R592 测试补丁：给「组合入口卡统一带次元」补数据锁 + 行为锁。

· test_assemble.gd 是 **LF**；test_engine.gd 是 **CRLF** —— 两边分别按自己的行尾拼。
· 判据写成**文本级 + 字段级**两条锁，不只钉这七张 id：
  以后新增任何「组合一张卡」的卡漏了次元，回归会红。
"""
import io
import sys

CHECK_ONLY = '--check-only' in sys.argv


def patch_assemble():
    p = 'scripts/test_assemble.gd'
    t = io.open(p, encoding='utf-8', newline='').read()

    call_old = '\t_test_r589_materials()\n'
    if t.count(call_old) != 1:
        print('[FAIL] test_assemble 调用锚点 %d 次' % t.count(call_old))
        return None
    t = t.replace(call_old, call_old + '\t_test_r592_combo_dimension()\n', 1)

    func = '''
func _test_r592_combo_dimension() -> void:
	## R592：所有「组合一张卡」的入口卡统一带「次元」（用后 / 离场即消失，不进弃牌区）。
	## 判据 = **能打开组合页的卡**，也就是 `_open_combo()` 的全部调用点：
	##   · 传授系 8084 / 8085 / 8086（TEACH_IDS）
	##   · 黑暗嵌合 9191 / 技术结合 9193（技能卡自带入口）
	##   · 宝石兽 9246（death）/ 拼装工厂 9247（turn_start）
	## 9144 随心组装是手牌变形（不产出新卡、不开组合页），不在判据内。
	var repo := CardRepo.load_json()
	var rows := {
		8084: "打出后消失", 8085: "打出后消失", 8086: "打出后消失",
		9191: "打出后消失", 9193: "打出后消失",
		9246: "离场即消失", 9247: "离场即消失",
	}
	for cid: int in rows:
		var c: CardData = repo.get_card(cid)
		check(c.has_affix("次元"),
				"R592：%d %s 必须带「次元」" % [cid, c.card_name])
		var tail: String = "字段「次元」：%s，不进弃牌区。" % str(rows[cid])
		check(c.effect_text.ends_with(tail),
				"R592：%d %s 卡面末句应为「%s」（实际「%s」）"
				% [cid, c.card_name, tail, c.effect_text])
	# 判据锁（文本级）：认的是「卡面在说自己会组合」，不是 id 清单 ——
	# 以后新增「组合一张卡」的卡忘了加次元，这条直接红。
	for c2: CardData in repo.all_cards():
		if c2.effect_text.contains("组合一张卡") or c2.effect_text.contains("组合一张盟友"):
			check(c2.has_affix("次元"),
					"R592：%s %d 文案是「组合一张卡」却没带次元"
					% [c2.card_name, c2.id])
	# 判据锁（字段级）：自带组合扳机的卡（宝石兽 / 拼装工厂）走的是这条。
	for c3: CardData in repo.all_cards():
		if c3.combo_trigger != "":
			check(c3.has_affix("次元"),
					"R592：combo_trigger=%s 的 %d %s 漏了次元"
					% [c3.combo_trigger, c3.id, c3.card_name])
'''
    body = t.rstrip('\n') + '\n' + func
    return body


def patch_engine():
    p = 'scripts/test_engine.gd'
    t = io.open(p, encoding='utf-8', newline='').read()

    call_old = '\t_test_r589()\r\n'
    if t.count(call_old) != 1:
        print('[FAIL] test_engine 调用锚点 %d 次' % t.count(call_old))
        return None
    t = t.replace(call_old, call_old + '\t_test_r592()\r\n', 1)

    func_lines = [
        'func _test_r592() -> void:',
        '\t## R592：「组合一张卡」的入口卡全带「次元」—— 打出 / 离场后进消耗区，不进弃牌区。',
        '\t## 数据与文案断言在 test_assemble._test_r592_combo_dimension()，这里只验**行为**。',
        '\tvar repo := CardRepo.load_json()',
        '\t# ① 传授卡 8084：打完照常打开组合页，但本体进消耗区',
        '\tvar r592_a := _new_engine([], 20, 20)',
        '\tr592_a.state.hand.clear()',
        '\tr592_a.state.hand.append(CardData.from_dict(repo.get_card(8084).to_dict()))',
        '\tr592_a.use_spell(0, null, true)',
        '\tcheck(r592_a.assemble_combo_pending, "R592：传授 8084 打出照常打开组合页")',
        '\tcheck(r592_a.state.void_count == 1 and r592_a.state.discard.is_empty(),',
        '\t\t\t"R592：传授 8084 打出后进消耗区（void %d / 弃牌 %d）"',
        '\t\t\t% [r592_a.state.void_count, r592_a.state.discard.size()])',
        '\tr592_a.assemble_combo_cancel()',
        '\t# ② 宝石兽 9246：死亡触发组合 + 本体离场即消失',
        '\tvar r592_b := _new_engine([], 20, 20)',
        '\tr592_b.state.hand.clear()',
        '\tr592_b.state.place(CardData.from_dict(repo.get_card(9246).to_dict()),',
        '\t\t\tVector2i(3, 0), GameEngine.SIDE_SELF)',
        '\tr592_b._destroy(Vector2i(3, 0))',
        '\tcheck(r592_b.assemble_combo_pending, "R592：宝石兽 9246 死亡 → 组合页打开")',
        '\tcheck(r592_b.state.discard.is_empty(),',
        '\t\t\t"R592：宝石兽离场即消失，不进弃牌区（弃牌 %d）"',
        '\t\t\t% r592_b.state.discard.size())',
        '\tr592_b.assemble_combo_cancel()',
    ]
    body = t.rstrip('\r\n') + '\r\n\r\n' + '\r\n'.join(func_lines) + '\r\n'
    return body


def main():
    a = patch_assemble()
    b = patch_engine()
    if a is None or b is None:
        return 1
    # 行尾自检
    if (a.count('\n') - a.count('\r\n')) != a.count('\n'):
        print('[FAIL] test_assemble 混进 CRLF')
        return 1
    if (b.count('\n') - b.count('\r\n')) != 0:
        print('[FAIL] test_engine 混进裸 LF：%d' % (b.count('\n') - b.count('\r\n')))
        return 1
    print('test_assemble：调用 + 函数已就位（LF）')
    print('test_engine  ：调用 + 函数已就位（CRLF）')
    if CHECK_ONLY:
        print('--check-only：未写盘')
        return 0
    io.open('scripts/test_assemble.gd', 'w', encoding='utf-8', newline='').write(a)
    io.open('scripts/test_engine.gd', 'w', encoding='utf-8', newline='').write(b)
    print('已写入两个测试文件')
    return 0


if __name__ == '__main__':
    sys.exit(main())
