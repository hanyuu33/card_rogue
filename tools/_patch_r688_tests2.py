# -*- coding: utf-8 -*-
"""R688 二次修测试：镜像可叠加语义、文案断言、填充卡换名。保留 CRLF。"""
import sys

P = "E:/work/card_rogue/scripts/test_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
assert raw.count("\r\n") == raw.count("\n")
src = raw.replace("\r\n", "\n")
edits = []


def rep(old, new, tag, cnt=1):
    edits.append((old, new, tag, cnt))


# ① 镜像：副本名（填充卡已由迅捷换成自愈）
rep('			and mir_e2.state.hand[0].card_name == "迅捷",',
    '			and mir_e2.state.hand[0].card_name == "自愈",', "mir_name1")
rep('			and mir_e3.state.hand[0].card_name == "迅捷",',
    '			and mir_e3.state.hand[0].card_name == "自愈",', "mir_name2")
rep('			and mir_e4.state.hand[0].card_name == "迅捷",',
    '			and mir_e4.state.hand[0].card_name == "自愈",', "mir_name3", 2)

# ② 镜像 2 张：由「不可叠加」改为「可叠加（每次使用只复制 1 份，但前 X 次都触发）」
rep('''	# 不可叠加：效果区 2 张镜像 → 第一次使用仍只加 1 份、只抽 1 张，第 2 次使用也不触发
''',
    '''	# R688 可叠加：效果区 2 张镜像 → 每次使用**只复制 1 份**（不会一次叠两份），但前 2 次都触发
''',
    "mir_e4_cmt")

rep('''			"镜像：不可叠加 → 效果区 2 张，第一次使用也只加 1 份、只抽 1 张")''',
    '''			"镜像（R688 可叠加）：2 张时每次使用仍只复制 1 份、只抽 1 张（不按张数乘）")''',
    "mir_e4_lbl1")

rep('''	check(mir_e4.state.deck.size() == 2 and mir_e4.state.hand.is_empty(),

			"镜像：不可叠加 → 同回合第 2 次使用不触发（既不复制也不抽卡）")''',
    '''	check(mir_e4.state.deck.size() == 2 and mir_e4.state.hand.size() == 1
			and mir_e4.state.hand[0].card_name == "自愈",

			"镜像（R688 可叠加）：2 张 → 同回合第 2 次使用**仍然触发**（再复制 1 份 + 抽 1 张）")''',
    "mir_e4_lbl2")

# ③ 智慧喷涌：抽到的是填充效果卡（已换自愈 9065）
rep('	check(wis_drawn.id == 9002 and wis_drawn.is_effect(),\n\n			"智慧喷涌：抽到的正是那张效果卡「迅捷」")',
    '	check(wis_drawn.id == 9065 and wis_drawn.is_effect(),\n\n			"智慧喷涌：抽到的正是那张效果卡「自愈」")',
    "wis1")
rep('			"智慧喷涌：这张迅捷费用 2 → 1（实际 %d）" % wis_e.cost_of(wis_drawn))',
    '			"智慧喷涌：这张自愈费用 2 → 1（实际 %d）" % wis_e.cost_of(wis_drawn))',
    "wis2")
rep('	# 已在效果区 → 再打效果牌（迅捷 2 费）：扣费后回 1',
    '	# 已在效果区 → 再打效果牌（自愈 2 费）：扣费后回 1', "wis_cmt")
rep('			"小精灵：下一张效果卡费用 -2（迅捷 2 → 0）")',
    '			"小精灵：下一张效果卡费用 -2（自愈 2 → 0）")', "pix1")
rep('			"小精灵：跨过回合后第一张效果卡仍然 -2（迅捷 2 → 0）")',
    '			"小精灵：跨过回合后第一张效果卡仍然 -2（自愈 2 → 0）")', "pix2")

# ④ 猫头鹰：从卡组抽出的效果卡 id
rep('	check(ow_e.state.hand.size() == 1 and ow_e.state.hand[0].id == 9002',
    '	check(ow_e.state.hand.size() == 1 and ow_e.state.hand[0].id == 9065', "owl")

# ⑤ R617 野兽之心：文案改 X 表述
rep('''	check(beast.effect_text.contains("可叠加"),
			"R617：野兽之心卡面写明「可叠加」")''',
    '''	check(beast.effect_text.contains("X 为本卡在效果区的张数"),
			"R617/R688：野兽之心卡面用 X 表述叠加（X = 效果区张数）")''',
    "beast")

# ⑥ R222 新生 / R327 送葬：文案同步成 X 表述
rep('		and r222_card.effect_text == "回合开始时，选一张手卡消失，随机将一张卡牌加入你的手卡。",',
    '		and r222_card.effect_text == "回合开始时，选 X 张手卡消失，随机将 X 张卡牌加入你的手卡。"'
    '\n\t\t\t\t+ "X 为本卡在效果区的张数。",',
    "r222")
rep('''	check(r327_card.effect_text == "场上每有一个单位被破坏，抽 1 张卡。",

			"R327 送葬文案：「场上每有一个单位被破坏，抽 1 张卡。」（实际「%s」）"''',
    '''	check(r327_card.effect_text == "场上每有一个单位被破坏，抽 1 张卡。效果区多张本卡不可叠加。",

			"R327 送葬文案：「场上每有一个单位被破坏，抽 1 张卡。」+「不可叠加」（实际「%s」）"''',
    "r327")

out = src
for old, new, tag, cnt in edits:
    c = out.count(old)
    if c != cnt:
        raise SystemExit("[%s] 命中 %d 次（预期 %d）" % (tag, c, cnt))
    out = out.replace(old, new)

if "--write" in sys.argv:
    open(P, "wb").write(out.replace("\n", "\r\n").encode("utf-8"))
    b = open(P, "rb").read()
    print("已写入 CRLF %d / LF %d" % (b.count(b"\r\n"), b.count(b"\n")))
else:
    print("dry-run：%d 处锚点全部命中" % len(edits))
