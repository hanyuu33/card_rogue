# -*- coding: utf-8 -*-
"""R818：设置页从 4 页签变 5 页签 —— 把 test_smoke 里写死的地方一起翻面。

⚠️ test_smoke.gd 是 CRLF，必须按原行尾追加，不能整篇转 LF。
"""
import sys

p = 'scripts/test_smoke.gd'
b = open(p, 'rb').read()
crlf = b.count(b'\r\n')
nl = '\r\n' if crlf > 0 else '\n'


def rep(old, new, tag):
    global b
    o = old.encode('utf-8')
    n = new.encode('utf-8')
    assert b.count(o) == 1, (tag, b.count(o))
    b = b.replace(o, n)


rep('## R660c：设置页按类分页 —— 四个页签各摊自己的项；语言列表 / 种子输入框',
    '## R660c/R818：设置页按类分页 —— 五个页签各摊自己的项；语言列表 / 种子输入框',
    'comment')

rep('\tif scene.TABS.size() != 4:',
    '\tif scene.TABS.size() != 5:', 'tabs-count')

rep('"R660c 设置页：页签应有 4 个，实际 %d"',
    '"R660c/R818 设置页：页签应有 5 个，实际 %d"', 'msg')

rep('\tif tabs.size() == 4:', '\tif tabs.size() == 5:', 'geom-if')

rep('bar_ok = absf((tabs[3].end.x - tabs[0].position.x) - scene.ROW_W) < 0.5',
    'bar_ok = absf((tabs[4].end.x - tabs[0].position.x) - scene.ROW_W) < 0.5', 'last-tab')

rep('\telif tabs.size() != 4 or tabs[0].size.x < 60.0:',
    '\telif tabs.size() != 5 or tabs[0].size.x < 52.0:', 'geom-guard')

rep('print("SMOKE OK R660c 设置页：4 页签各摊自己的项 · 列表/输入框按页显隐")',
    'print("SMOKE OK R660c 设置页：5 页签各摊自己的项 · 列表/输入框按页显隐")', 'ok-print')

# 模组页：切过去拿一次 _rows()，确认它没有设置行
old_run = '\tscene._set_tab(scene.TAB_RUN)\n\tvar seed_vis: bool ='
new_run = ('\tscene._set_tab(scene.TAB_MOD)\n'
           '\tvar mod_rows: Array = scene._rows()\n'
           '\tscene._set_tab(scene.TAB_RUN)\n'
           '\tvar seed_vis: bool =')
rep(old_run.replace('\n', nl), new_run.replace('\n', nl), 'insert-mod')

old_chain = ('\telif not seed_vis:\n'
             '\t\t_smoke_fail("R660c 设置页：对局页没把种子输入框显示出来")')
new_chain = (old_chain + '\n'
             '\telif not mod_rows.is_empty():\n'
             '\t\t_smoke_fail("R818 设置页：模组页不该有设置行")')
rep(old_chain.replace('\n', nl), new_chain.replace('\n', nl), 'chain')

open(p, 'wb').write(b)
print('ok crlf=%d' % crlf)
sys.exit(0)
