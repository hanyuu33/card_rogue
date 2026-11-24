# -*- coding: utf-8 -*-
# R774c：纯状态词飘字 i18n —— 非中文语言用英文艺术字（StatusBadge.word_of 切换）。
# battle_scene.gd 是 CRLF，用 newline="" 读写保持行尾不变。
import io

p = "scripts/battle_scene.gd"
with io.open(p, "r", encoding="utf-8", newline="") as f:
    s = f.read()

repls = [
    ('"text": "冰封"',
     '"text": StatusBadge.word_of(StatusBadge.GLYPH_ICE)'),
    ('"text": "眩晕", "col": Color("8a6d1f")',
     '"text": StatusBadge.word_of(StatusBadge.GLYPH_STAR), "col": Color("8a6d1f")'),
    ('"text": "治疗 +%d" % int(data.get("amount", 0))',
     '"text": "%s +%d" % [StatusBadge.word_of(StatusBadge.GLYPH_HEAL), int(data.get("amount", 0))]'),
    ('"text": "力量 -%d" % fp_debuff',
     '"text": "%s -%d" % [StatusBadge.word_of(StatusBadge.GLYPH_SWORD), fp_debuff]'),
    ('"text": "力量 +%d" % GameEngine.EMERGENCY_CALL_ATK',
     '"text": "%s +%d" % [StatusBadge.word_of(StatusBadge.GLYPH_SWORD), GameEngine.EMERGENCY_CALL_ATK]'),
]

for old, new in repls:
    n = s.count(old)
    assert n == 1, "anchor not unique (count=%d): %r" % (n, old)
    s = s.replace(old, new)

with io.open(p, "w", encoding="utf-8", newline="") as f:
    f.write(s)

print("OK patched battle_scene.gd (%d replacements)" % len(repls))
