# -*- coding: utf-8 -*-
"""R816：把 mod 套挂进 _verify.py 的 SUITES（content 之后、smoke 之前）。"""
import sys

p = '_verify.py'
b = open(p, 'rb').read()
crlf = b.count(b'\r\n')
nl = '\r\n' if crlf > 0 else '\n'

# 1) 文件头：九套 → 十套
old_doc = ('"""九套回归一键跑（2026-10-01 重建；R663 增补 assemble / mana / traps；'
           'R667 增补 trapinput；R789 增补 content）。')
new_doc = ('"""十套回归一键跑（2026-10-01 重建；R663 增补 assemble / mana / traps；'
           'R667 增补 trapinput；R789 增补 content；R816 增补 mod）。')
od = old_doc.encode('utf-8')
assert b.count(od) == 1, ('doc', b.count(od))
b = b.replace(od, new_doc.encode('utf-8'))

# 2) 用法行
old_usage = '逐套跑 assemble / mana / engine / reward / bgm / traps / trapinput / content / smoke，统计 ✓/✗，'
new_usage = '逐套跑 assemble / mana / engine / reward / bgm / traps / trapinput / content / mod / smoke，统计 ✓/✗，'
ou = old_usage.encode('utf-8')
assert b.count(ou) == 1, ('usage', b.count(ou))
b = b.replace(ou, new_usage.encode('utf-8'))

# 3) SUITES：content 之后、smoke 之前插入
anchor = ('    ("smoke", ["--headless", "--path", ROOT, "--script", '
          '"res://scripts/test_smoke.gd"], "_s.txt"),')
a = anchor.encode('utf-8')
assert b.count(a) == 1, ('anchor', b.count(a))
block = (
    '    # R816：mod 层（多目录增量合并 / 只写部分字段的深合并 / priority 仲裁 /\n'
    '    #       坏清单与坏 JSON 只伤自己 / 素材覆盖与压制 / 编辑器默认不扫）。\n'
    '    # 与 content 套是两条链：那条测官方热更的「整份替换」，这条测 mod 的「增量合并」。\n'
    '    ("mod", ["--headless", "--path", ROOT, "--script", "res://tools/_probe_mod_loader.gd"], "_mod.txt"),'
)
b = b.replace(a, block.replace('\n', nl).encode('utf-8') + nl.encode('utf-8') + a)

open(p, 'wb').write(b)
print('ok crlf=%d' % crlf)
sys.exit(0)
