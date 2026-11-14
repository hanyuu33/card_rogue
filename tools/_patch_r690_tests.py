# -*- coding: utf-8 -*-
"""R690 测试与文档补丁。

- test_engine.gd：生命循环 1→2 费断言；水元素改为抓漩涡的用例；漩涡 3→0 费断言。
- test_assemble.gd：水元素下半首动作 add_effect_from_deck → add_card。
- assemble_rules.gd：注释跟进（动作本身保留）。
- 拼装可用半句名单.md：水元素三处文案同步。

用法：python tools/_patch_r690_tests.py [--write]
"""
import sys

WRITE = "--write" in sys.argv


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    crlf, lf = raw.count("\r\n"), raw.count("\n")
    assert crlf == lf or crlf == 0, "%s 行尾混杂（CRLF %d / LF %d）" % (path, crlf, lf)
    return (raw.replace("\r\n", "\n"), ("\r\n" if crlf else "\n"))


def save(path, txt, eol):
    open(path, "wb").write(txt.replace("\n", eol).encode("utf-8"))
    b = open(path, "rb").read()
    print("  %s → CRLF %d / LF %d" % (path, b.count(b"\r\n"), b.count(b"\n")))


# ── test_engine.gd ────────────────────────────────────────────────────────
te, te_eol = load("scripts/test_engine.gd")
out = te


def rep(old, new, tag, cnt=1):
    global out
    c = out.count(old)
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    out = out.replace(old, new)


rep('	# ---- R227 → R689：生命循环（9150，森林精魄 · **1 费史诗效果卡**）----',
    '	# ---- R227 → R689 → R690：生命循环（9150，森林精魄 · **2 费史诗效果卡**）----',
    "生命循环注释")

rep('			and lc_c.cost == 1 and lc_c.rarity == 2 and lc_c.card_class == "森林精魄"',
    '			and lc_c.cost == 2 and lc_c.rarity == 2 and lc_c.card_class == "森林精魄"',
    "生命循环费用")

rep('''	dm_e.state.deck = [repo.get_card(9062)]      # 使魔之夜：3 费效果卡

	dm_e.state.hand = [repo.get_card(9068)]

	dm_e.state.energy = 9

	dm_e.play_from_hand(0, Vector2i(4, 1))

	check(dm_e.state.deck.is_empty() and dm_e.state.hand.size() == 1

			and dm_e.state.hand[0].id == 9062,

			"水元素：上场时从卡组将一张效果卡加入手卡")

	check(dm_e.cost_of(dm_e.state.hand[0]) == 1,

			"水元素：取到的那张效果卡费用 -2（3 → 1）")''',
    '''	dm_e.state.deck = [repo.get_card(9062)]      # 使魔之夜：3 费效果卡（R690 起一张不动）

	dm_e.state.hand = [repo.get_card(9068)]

	dm_e.state.energy = 9

	dm_e.play_from_hand(0, Vector2i(4, 1))

	check(dm_e.state.deck.size() == 1 and dm_e.state.deck[0].id == 9062

			and dm_e.state.hand.size() == 1 and dm_e.state.hand[0].id == 9186,

			"R690 水元素：上场时把一张「漩涡」加入手卡（卡组一张不动）")

	check(dm_e.cost_of(dm_e.state.hand[0]) == 0,

			"R690 漩涡：0 费（拿到手就能直接摆）")

	check(dm_e.state.hand[0].own_copy,

			"R690 漩涡：发的是独立副本，改它串不到卡库")''',
    "水元素用例")

rep('''	check(r381_v != null and r381_v.kind == "场地" and r381_v.cost == 3''',
    '''	check(r381_v != null and r381_v.kind == "场地" and r381_v.cost == 0''',
    "漩涡费用")

rep('"R381 漩涡 9186：3 费持续场地（森林精魄），漩涡伤害 15，已无「涡旋」trait"',
    '"R381 / R690 漩涡 9186：0 费持续场地（森林精魄，R690 由 3 费下调、水元素是获得渠道），漩涡伤害 15，已无「涡旋」trait"',
    "漩涡断言文案")

# ── test_assemble.gd ──────────────────────────────────────────────────────
ta, ta_eol = load("scripts/test_assemble.gd")
rep_te = out  # 保留 test_engine 的结果，单独处理 test_assemble
out_ta = ta


def rep2(old, new, tag, cnt=1):
    global out_ta
    c = out_ta.count(old)
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    out_ta = out_ta.replace(old, new)


rep2('		9068: ["use", "add_effect_from_deck", 1],',
     '		9068: ["use", "add_card", 9186],',
     "拼装 9068 行")

# ── assemble_rules.gd 注释 ────────────────────────────────────────────────
ar, ar_eol = load("scripts/assemble_rules.gd")
out_ar = ar


def rep3(old, new, tag, cnt=1):
    global out_ar
    c = out_ar.count(old)
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    out_ar = out_ar.replace(old, new)


rep3('''	# R589：水元素 9068「从卡组将一张效果卡加入手卡，费用减少 N」。''',
     '''	# R589：「从卡组将一张效果卡加入手卡，费用减少 N」。R690 起水元素改用 add_card
	# （抓漩涡），这条动作暂无卡使用，但仍是合法素材。''',
     "rules 校验注释")

rep3('''		# 水元素 9068：「使用时，从卡组将一张效果卡加入手卡，费用减少 2」''',
     '''		# 「从卡组将 N 张效果卡加入手卡，费用减少 X」（R690 起暂无卡使用）''',
     "rules 文案注释")

# ── 拼装可用半句名单.md ───────────────────────────────────────────────────
md, md_eol = load("拼装可用半句名单.md")
out_md = md


def rep4(old, new, tag, cnt=1):
    global out_md
    c = out_md.count(old)
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    out_md = out_md.replace(old, new)


rep4('| 9068 | 水元素 | 使用时：从卡组将一张效果卡加入手卡，费用减少2。 | 待扩展动作/条件 |',
     '| 9068 | 水元素 | 使用时：将一张「漩涡」加入手卡。 | 基础片段可表达（add_card） |',
     "名单 上半句")

rep4('| 9068 | 水元素 | 从卡组将一张效果卡加入手卡，费用减少2。 |',
     '| 9068 | 水元素 | 将一张「漩涡」加入手卡。 |',
     "名单 下半句")

rep4('自己场上每有一张效果卡，这张卡费用 -1。使用时，从卡组将一张效果卡加入手卡，费用减少 2。',
     '自己场上每有一张效果卡，这张卡费用 -1。使用时，将一张「漩涡」加入手卡。',
     "名单 详情段")

if WRITE:
    save("scripts/test_engine.gd", out, te_eol)
    save("scripts/test_assemble.gd", out_ta, ta_eol)
    save("scripts/assemble_rules.gd", out_ar, ar_eol)
    save("拼装可用半句名单.md", out_md, md_eol)
else:
    print("干跑通过（未写入）")
