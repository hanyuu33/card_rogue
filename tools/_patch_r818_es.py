# -*- coding: utf-8 -*-
"""R818：l10n 新增 6 条设置文案 → 补西语骨架 + 同步条数断言。"""
import sys

# 1) i18n/l10n_es.json 插入 6 条
p = 'i18n/l10n_es.json'
b = open(p, 'rb').read()
nl = b'\r\n' if b.count(b'\r\n') > 0 else b'\n'
anchor = '  "settings.tab_run": "Partida",'.encode('utf-8')
assert b.count(anchor) == 1, ('anchor', b.count(anchor))
block = (
    '  "settings.tab_mod": "Mods",\n'
    '  "settings.mod_empty": "No hay mods instalados",\n'
    '  "settings.mod_hint": "Los mods que suscribas en el Workshop aparecerán aquí",\n'
    '  "settings.mod_footer": "Los mods desactivados quedan fuera del contenido",\n'
    '  "settings.mod_next_run": "Partida en curso: se aplicará en la siguiente",\n'
    '  "settings.mod_problems": "%s mod(s) no se pudieron cargar",'
).replace('\n', nl.decode())
b = b.replace(anchor, anchor + nl + block.encode('utf-8'))
open(p, 'wb').write(b)

# 2) validate_spanish.py 的条数断言 67 → 73
q = 'i18n/validate_spanish.py'
t = open(q, 'rb').read()
oid = 'check(len(L10N_ES) == 67, "l10n 骨架共 67 条")'.encode('utf-8')
nid = 'check(len(L10N_ES) == 73, "l10n 骨架共 73 条")'.encode('utf-8')
assert t.count(oid) == 1, ('count-assert', t.count(oid))
t = t.replace(oid, nid)
open(q, 'wb').write(t)

print('ok')
sys.exit(0)
