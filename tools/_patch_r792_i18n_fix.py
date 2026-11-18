# -*- coding: utf-8 -*-
"""R792 修正：en/ja/es 的 relics 字典是三行收尾，改用「classes 之前」插入。"""
import io
import sys

ROOT = 'E:/work/card_rogue/'

ADD = {
    'i18n/noncard_en.json': [
        ('6070', 'Plate Armor', 'The first Ally you play each combat gains +6 Health (does not stack), but its Move Speed becomes 1.'),
        ('6071', 'Pawn', 'The first Ally you play each combat can act twice (does not stack).'),
        ('6072', 'Wall Brick', 'Your Structures have +4 Health (persistent; does not stack).'),
    ],
    'i18n/noncard_ja.json': [
        ('6070', '板金鎧', '各戦闘で最初に使う味方は生命+6（重複しない）を得るが、移動速度が1になる。'),
        ('6071', 'ポーン', '各戦闘で最初に使う味方は2回行動できる（重複しない）。'),
        ('6072', '壁のレンガ', '自分の構造物カードの生命+4（継続し、重複しない）。'),
    ],
    'i18n/noncard_es.json': [
        ('6070', 'Armadura de Placas', 'El primer Aliado que juegas en cada combate obtiene +6 de Vida (no se acumula), pero su Velocidad de Movimiento pasa a ser 1.'),
        ('6071', 'Peón', 'El primer Aliado que juegas en cada combate puede actuar dos veces (no se acumula).'),
        ('6072', 'Ladrillo', 'Tus Estructuras tienen +4 de Vida (efecto persistente; no se acumula).'),
    ],
}

for fname, rows in ADD.items():
    p = ROOT + fname
    s = io.open(p, encoding='utf-8', newline='').read()
    old = '    }\n  },\n  "classes": {'
    if s.count(old) != 1:
        print('FAIL %s 收尾锚点命中 %d 次' % (fname, s.count(old)))
        sys.exit(1)
    extra = ',\n' + ',\n'.join(
        '    "%s": {"name": "%s", "desc": "%s"}' % (i, n, d) for i, n, d in rows)
    s = s.replace(old, '    }' + extra + '\n  },\n  "classes": {')
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK   %s' % fname)
