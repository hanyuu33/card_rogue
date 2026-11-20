# -*- coding: utf-8 -*-
"""R833：把组合动作文案 / 测试判据统一到新术语（手牌 / 抽牌库 / 弃牌区 / 生命）。

背景：cards.json 的卡面中文已按 zh_canonical 统一（R833），组合动作的 note
（assemble_rules.effect_text）与保真判据（test_assemble._fx_in_text）、
若干卡面文案断言（test_engine）还写着旧词，必须同步，否则玩家看到的
「组合产物卡面」和母卡对不上。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def patch(rel, pairs):
    p = ROOT + rel
    s = io.open(p, encoding="utf-8", newline="").read()
    for old, new, expect in pairs:
        n = s.count(old)
        if n != expect:
            print("!! %s count=%d expect=%d  %r" % (rel, n, expect, old[:60]))
            sys.exit(1)
        s = s.replace(old, new)
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print("ok %s（%d 处）" % (rel, len(pairs)))


# ── ① 组合动作 note ───────────────────────────────────────────────
patch("scripts/assemble_rules.gd", [
    ('return "从卡组把%d张「%s」加入手卡" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]',
     'return "从抽牌库把%d张「%s」加入手牌" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]', 1),
    ('return "将%d张「%s」加入你的手卡" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]',
     'return "将%d张「%s」加入你的手牌" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]', 1),
    ('return "从卡组将%d张效果卡加入手卡，费用减少 %d" % [',
     'return "从抽牌库将%d张效果卡加入手牌，费用减少 %d" % [', 1),
    ('return "手卡中所有技能牌本回合费用 -%d" % n',
     'return "手牌中所有技能牌本回合费用 -%d" % n', 1),
    ('return "手卡每有一张费用为 0 的技能卡，这张卡获得 +%d 生命" % n',
     'return "手牌每有一张费用为 0 的技能卡，这张卡获得 +%d 生命" % n', 1),
    ('return "从抽牌库将一张费用最低的盟友加入手卡"',
     'return "从抽牌库将一张费用最低的盟友加入手牌"', 1),
    ('return "选择弃牌堆中一张盟友回到手卡"',
     'return "选择弃牌区中一张盟友回到手牌"', 1),
    ('return "清除你的抽牌堆、手卡、弃牌区中的所有诅咒；每清除 1 张，对随机一个敌人造成 %d 点伤害" % n',
     'return "清除你的抽牌库、手牌、弃牌区中的所有诅咒；每清除 1 张，对随机一个敌人造成 %d 点伤害" % n', 1),
    ('var ae_src := "从卡组" if str(fx.get("from", "")) == "deck" else ""',
     'var ae_src := "从抽牌库" if str(fx.get("from", "")) == "deck" else ""', 1),
    ('return "%s随机将%d张效果卡加入你的手卡" % [ae_src, maxi(1, n)]',
     'return "%s随机将%d张效果卡加入你的手牌" % [ae_src, maxi(1, n)]', 1),
    ('return "手卡中的盟友获得改造：生命 +%d" % n',
     'return "手牌中的盟友获得改造：生命 +%d" % n', 1),
    ('return "本回合手卡中所有卡费用 +%d" % n',
     'return "本回合手牌中所有卡费用 +%d" % n', 1),
    ('return "回复 X 点生命值，X 为自己剩余费用（每 1 点剩余费用回复 %d 点生命，不超过生命上限）" % n',
     'return "回复 X 点生命，X 为自己剩余费用（每 1 点剩余费用回复 %d 点生命，不超过生命上限）" % n', 1),
    ('return "从卡组随机抽取一张技能牌，该卡本回合费用 -%d" % n',
     'return "从抽牌库随机抽取一张技能牌，该卡本回合费用 -%d" % n', 1),
    ('return "若包含这张卡本回合打出的卡达到 3 张，从卡组将一张随机技能卡加入手卡"',
     'return "若包含这张卡本回合打出的卡达到 3 张，从抽牌库将一张随机技能卡加入手牌"', 1),
    ('return "从卡组将一张随机技能卡加入手卡"',
     'return "从抽牌库将一张随机技能卡加入手牌"', 1),
])

# ── ② 保真判据：先归一化，再按新术语比对 ───────────────────────────
patch("scripts/test_assemble.gd", [
    ('\tvar n := int(fx.get("value", 0))\n\tmatch str(fx.type):',
     '\tvar n := int(fx.get("value", 0))\n'
     '\t# R833：卡面已统一术语，判据先归一化再比对（旧写法也不会误判）。\n'
     '\ttext = text.replace("手卡", "手牌").replace("弃牌堆", "弃牌区")\n'
     '\ttext = text.replace("抽牌堆", "抽牌库").replace("生命值", "生命")\n'
     '\tmatch str(fx.type):', 1),
    ('and (text.contains("加入你的手牌") or text.contains("加入手卡"))',
     'and (text.contains("加入你的手牌") or text.contains("加入手牌"))', 1),
    ('\t\t\t\treturn ac_ok and text.contains("从卡组")',
     '\t\t\t\treturn ac_ok and (text.contains("从抽牌库") or text.contains("从卡组"))', 1),
    ('return text.contains("从卡组") and text.contains("效果卡加入手卡") \\',
     'return (text.contains("从抽牌库") or text.contains("从卡组")) and text.contains("效果卡加入手牌") \\', 1),
    ('return text.contains("费用最低的盟友") and text.contains("加入手卡")',
     'return text.contains("费用最低的盟友") and text.contains("加入手牌")', 1),
    ('return text.contains("弃牌堆") and text.contains("盟友回到手卡")',
     'return text.contains("弃牌区") and text.contains("盟友回到手牌")', 1),
    ('"R585：保真判据认「从卡组」与「加入抽牌库」，错来源不放过"',
     '"R585：保真判据认「从抽牌库」与「加入抽牌库」，错来源不放过"', 1),
    ('and r585_built.effect_text == "入场时，将2张「聚能炮击」加入抽牌库。每次被改造时：从卡组把1张「聚能炮击」加入手卡"',
     'and r585_built.effect_text == "入场时，将2张「聚能炮击」加入抽牌库。每次被改造时：从抽牌库把1张「聚能炮击」加入手牌"', 1),
    ('check(fox_prod.effect_text.find("从卡组随机抽取") < 0,',
     'check(fox_prod.effect_text.find("从抽牌库随机抽取") < 0,', 1),
    ('== "清除你的抽牌堆、手卡、弃牌区中的所有诅咒；每清除 1 张，对随机一个敌人造成 2 点伤害"',
     '== "清除你的抽牌库、手牌、弃牌区中的所有诅咒；每清除 1 张，对随机一个敌人造成 2 点伤害"', 1),
    ('check(cat != null and cat.effect_text.begins_with("使用时"), "R775：影子猫描述改为「使用时」")',
     'check(cat != null and cat.effect_text.begins_with("打出时"), "R775：影子猫描述改为「打出时」")', 1),
])

# ── ③ 卡面文案断言（engine 套） ───────────────────────────────────
patch("scripts/test_engine.gd", [
    ('and kiln_c.effect_text.contains("所有陶瓷鸭+1血量"),',
     'and kiln_c.effect_text.contains("所有陶瓷鸭+1生命"),', 1),
    ('"R259：鸭子窑卡面写明 <3 只照旧、>=3 只只召唤 1 只且全体 +1 血量")',
     '"R259：鸭子窑卡面写明 <3 只照旧、>=3 只只召唤 1 只且全体 +1 生命")', 1),
    ('and r223_fatigue.effect_text == "打出无效果。在手卡时，所有技能卡费用 +1。",',
     'and r223_fatigue.effect_text == "打出无效果。在手牌时，所有技能卡费用 +1。",', 1),
    ('and r245_pot.desc.contains("2 件奖励道具") and r245_pot.desc.contains("罐子"),',
     'and r245_pot.desc.contains("2 件互不重复的奖励道具") and r245_pot.desc.contains("罐子"),', 1),
    ('check(r313_wf.desc.contains("第五张") and r313_wf.desc.contains("4"),',
     'check(r313_wf.desc.contains("第 5 张") and r313_wf.desc.contains("4"),', 1),
    ('and r313_rune.desc.contains("冰封"),',
     'and r313_rune.desc.contains("不能行动"),', 1),
    ('check(r314_repo.get_relic(6044).desc.contains("不")\n\n\t\t\tand r314_repo.get_relic(6044).desc.contains("手牌"),',
     'check(r314_repo.get_relic(6044).desc.contains("免除")\n\n\t\t\tand r314_repo.get_relic(6044).desc.contains("手牌"),', 1),
    ('check(r405_repo.get_card(8076).effect_text.contains("手卡")',
     'check(r405_repo.get_card(8076).effect_text.contains("手牌")', 1),
    ('"R523 卡面：改装者只写「手卡中的盟友」（不再提场上）")',
     '"R523 卡面：改装者只写「手牌中的盟友」（不再提场上）")', 1),
    ('and r406_c.effect_text.contains("随机使手卡一张盟友或工事消失")',
     'and r406_c.effect_text.contains("随机使手牌一张盟友或工事消失")', 1),
    ('and str(r586_rel.desc).contains("对满血的敌人伤害加倍")',
     'and str(r586_rel.desc).contains("满血敌方单位造成的伤害加倍")', 1),
])

print("== all patched ==")
