#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：reward / content 两套里的卡数 334 → 336。"""
import io

# ---------- scripts/test_reward.gd（CRLF） ----------
P = "scripts/test_reward.gd"
d = open(P, "rb").read().decode("utf-8")
pairs = [
    ('check(all.size() == 334, "卡牌库 334 张（R799 +2：连斩 9272',
     'check(all.size() == 336, "卡牌库 336 张（R800 +2：余音 9274（吟游诗人 · X 费稀有技能）/'
     ' 音符 9275（0 费技能 · 次元 · event_only 内部卡）；R799 +2：连斩 9272'),
]
for old, new in pairs:
    assert d.count(old) == 1, "reward count=%d" % d.count(old)
    d = d.replace(old, new)
open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "test_reward 行尾混了"

# ---------- tools/_probe_content_override.gd（CRLF） ----------
P = "tools/_probe_content_override.gd"
d = open(P, "rb").read().decode("utf-8")
pairs = [
    ("##   1. 没有覆盖目录时，读到的就是 pck 基线（334 张卡，卡名不变）；",
     "##   1. 没有覆盖目录时，读到的就是 pck 基线（336 张卡，卡名不变）；"),
    ("##   2. 放一份改过卡名的 cards.json → 覆盖生效，数量仍为 334（整份替换，不是合并）；",
     "##   2. 放一份改过卡名的 cards.json → 覆盖生效，数量仍为 336（整份替换，不是合并）；"),
    ('_check("基线卡牌 334 张", base_count == 334, str(base_count))',
     '_check("基线卡牌 336 张", base_count == 336, str(base_count))'),
    ('_check("覆盖后仍是 334 张", ov.all_cards().size() == 334, str(ov.all_cards().size()))',
     '_check("覆盖后仍是 336 张", ov.all_cards().size() == 336, str(ov.all_cards().size()))'),
    ("broken.all_cards().size() == 334 and broken.get_card(CARD_ID).card_name == base_name,",
     "broken.all_cards().size() == 336 and broken.get_card(CARD_ID).card_name == base_name,"),
    ('_check("空结构回落基线", empty.all_cards().size() == 334, str(empty.all_cards().size()))',
     '_check("空结构回落基线", empty.all_cards().size() == 336, str(empty.all_cards().size()))'),
]
for old, new in pairs:
    assert d.count(old) == 1, "content count=%d for %r" % (d.count(old), old[:40])
    d = d.replace(old, new)
open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "probe 行尾混了"
assert b"334" not in b, "还有漏改的 334"
print("reward / content 计数已同步到 336")
