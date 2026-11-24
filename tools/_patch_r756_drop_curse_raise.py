# -*- coding: utf-8 -*-
"""R756: 删掉 _migrate_card_state 里对已删除字段 state.curse_raise 的迁移。"""
import io, sys

P = "scripts/game_engine.gd"
OLD = "\t_move_key(state.curse_raise, old_card, new_card)\r\n"

with io.open(P, "r", encoding="utf-8", newline="") as f:
    s = f.read()

print("anchor repr:", repr(OLD))
print("count:", s.count(OLD))
assert s.count(OLD) == 1, "anchor not unique"

s2 = s.replace(OLD, "")
with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s2)

print("removed. len", len(s), "->", len(s2))
