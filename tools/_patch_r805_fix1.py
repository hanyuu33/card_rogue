# -*- coding: utf-8 -*-
"""R805 修计数断言：engine 6 处 / reward 1 处 / content probe 4 处。

全部是「我漏改的条数」和「我写歪的源码锚点」，无逻辑改动。
行尾：test_engine.gd / test_reward.gd = CRLF；_probe_content_override.gd = LF。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fix(rel, eol, pairs):
    path = os.path.join(ROOT, rel)
    raw = io.open(path, "rb").read()
    s = raw.decode("utf-8")
    for old, new, cnt in pairs:
        o = old.replace("\n", eol)
        n = new.replace("\n", eol)
        c = s.count(o)
        if c != cnt:
            print("FAIL %s : count=%d expect=%d\n  anchor=%r" % (rel, c, cnt, old[:100]))
            sys.exit(1)
        s = s.replace(o, n)
    io.open(path, "wb").write(s.encode("utf-8"))
    print("OK   %s" % rel)


E = "\r\n"

# ---------------------------------------------------------------- test_engine
fix("scripts/test_engine.gd", E, [
    # 1) 图鉴分组：玩家 258 → 259
    ('check(grp_player.size() == 258 and grp_enemy.size() == 78,',
     'check(grp_player.size() == 259 and grp_enemy.size() == 78,', 1),

    # 2) 角色归属：class 留空 28 → 29（两处判定 + 两处说明）
    ('\t\t\tand int(dr_cls_count.get("", 0)) == 28,',
     '\t\t\tand int(dr_cls_count.get("", 0)) == 29,', 1),
    ('\tcheck(int(dr_cls_count.get("", 0)) == 28,',
     '\tcheck(int(dr_cls_count.get("", 0)) == 29,', 1),
    ('公用 28（R794 +巧克力工厂 9271 class 留空；',
     '公用 29（R805 公用 +1：诅咒娃娃 9276；R794 +巧克力工厂 9271 class 留空；', 1),
    ('R756 代偿 9252 + R766 懊悔 9265（实际 %d）',
     'R756 代偿 9252 + R766 懊悔 9265 + R805 诅咒娃娃 9276（实际 %d）', 1),

    # 3) 两处「R632 公用计数」注释（内容完全相同的两段 → 一起替换）
    ('；R794 巧克力工厂 9271 → 28。',
     '；R794 巧克力工厂 9271 → 28；R805 诅咒娃娃 9276 → 29。', 2),

    # 4) R45 角色归属同款 28 → 29
    ('check(int(r45_cls_count.get("", 0)) == 28,',
     'check(int(r45_cls_count.get("", 0)) == 29,', 1),
    ('+ R766 懊悔 9265（%d 张）',
     '+ R766 懊悔 9265 + R805 诅咒娃娃 9276（%d 张）', 1),

    # 5) R793/R794 白名单锚点：R805 在 choco 之后追加了 haunted_house
    ('\t\t\tand r793_es.contains("or _is_choco_factory():"),',
     '\t\t\tand r793_es.contains("or _is_choco_factory() or _is_haunted_house():"),', 1),

    # 6) 我自己写歪的那条：整份源码里注释就带 _present_win_panel，
    #    改成对探索函数体做正面断言（直连 _reward_panel.open()、不调胜利面板）
    ('\tcheck_src(not ("_present_win_panel" in r805_src),\n'
     '\t\t\t"R805 事件：奖励页直连 —— 事件页根本不碰战斗胜利面板（没有「战斗胜利」那一屏）")',
     '\tcheck_src(r805_body.contains("_reward_panel.open()")\n'
     '\t\t\tand not r805_body.contains("_present_win_panel("),\n'
     '\t\t\t"R805 事件：奖励页直连 —— 探索函数直接开奖励面板，不经过战斗胜利那一屏")', 1),
])

# ---------------------------------------------------------------- test_reward
fix("scripts/test_reward.gd", E, [
    ('check(all.size() == 336, "卡牌库 336 张（R800 +2：',
     'check(all.size() == 337, "卡牌库 337 张（R805 +1：诅咒娃娃 9276（0 费诅咒 · 不可打出 · 保存 · 回合结束 -3）；R800 +2：', 1),
])

# ---------------------------------------------------------------- content probe
fix("tools/_probe_content_override.gd", "\n", [
    ('##   1. 没有覆盖目录时，读到的就是 pck 基线（336 张卡，卡名不变）；',
     '##   1. 没有覆盖目录时，读到的就是 pck 基线（337 张卡，卡名不变）；', 1),
    ('##   2. 放一份改过卡名的 cards.json → 覆盖生效，数量仍为 336（整份替换，不是合并）；',
     '##   2. 放一份改过卡名的 cards.json → 覆盖生效，数量仍为 337（整份替换，不是合并）；', 1),
    ('\t_check("基线卡牌 336 张", base_count == 336, str(base_count))',
     '\t_check("基线卡牌 337 张", base_count == 337, str(base_count))', 1),
    ('\t_check("覆盖后仍是 336 张", ov.all_cards().size() == 336, str(ov.all_cards().size()))',
     '\t_check("覆盖后仍是 337 张", ov.all_cards().size() == 337, str(ov.all_cards().size()))', 1),
    ('\t_check("坏 JSON 回落基线", broken.all_cards().size() == 336 and broken.get_card(CARD_ID).card_name == base_name,',
     '\t_check("坏 JSON 回落基线", broken.all_cards().size() == 337 and broken.get_card(CARD_ID).card_name == base_name,', 1),
    ('\t_check("空结构回落基线", empty.all_cards().size() == 336, str(empty.all_cards().size()))',
     '\t_check("空结构回落基线", empty.all_cards().size() == 337, str(empty.all_cards().size()))', 1),
])

print("DONE")
