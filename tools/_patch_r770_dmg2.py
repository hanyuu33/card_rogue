# -*- coding: utf-8 -*-
"""R770 二次补丁：判据拆成 is_number_text() 之后，同步 test_engine 的断言。

首版用的是「amount_of_text() < 0 = 不是数字」，结果把**所有负数伤害**都甩回
说明分支（实机截图里 -18 / -42 还是深色方块底）。现在形状与数值分开判，
断言也要跟着改成 is_number_text()。
"""
import sys

P = 'scripts/test_engine.gd'

OLD = '''	check(DmgNumber.amount_of_text("-12") == -12, "R770 判据：-12 是伤害数字")
	check(DmgNumber.amount_of_text("+7") == 7, "R770 判据：+7 是治疗数字")
	check(DmgNumber.amount_of_text("接下 5") < 0, "R770 判据：说明文字不当数字画")
	check(DmgNumber.amount_of_text("-3 暴击") < 0, "R770 判据：带后缀的不当纯数字")
	check(DmgNumber.amount_of_text("冰封") < 0, "R770 判据：纯中文不当数字画")'''

NEW = '''	check(DmgNumber.is_number_text("-12") and DmgNumber.amount_of_text("-12") == -12,
			"R770 判据：-12 是伤害数字（负号是**数值**，不是「不是数字」）")
	check(DmgNumber.is_number_text("+7") and DmgNumber.amount_of_text("+7") == 7,
			"R770 判据：+7 是治疗数字")
	check(not DmgNumber.is_number_text("接下 5"), "R770 判据：说明文字不当数字画")
	check(not DmgNumber.is_number_text("-3 暴击"), "R770 判据：带后缀的不当纯数字")
	check(not DmgNumber.is_number_text("冰封"), "R770 判据：纯中文不当数字画")
	check(not DmgNumber.is_number_text("-0"), "R770 判据：-0 不算数字（没有这种伤害）")'''

raw = open(P, 'rb').read()
text = raw.decode('utf-8')
old_crlf = OLD.replace('\n', '\r\n')
new_crlf = NEW.replace('\n', '\r\n')
if text.count(old_crlf) != 1:
    sys.exit('[patch] 旧断言命中 %d 次（应为 1），停止' % text.count(old_crlf))
text = text.replace(old_crlf, new_crlf)
open(P, 'wb').write(text.encode('utf-8'))
print('[patch] R770 判据断言已换成 is_number_text()，共 6 条')
