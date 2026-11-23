# -*- coding: utf-8 -*-
"""R831：两处文案规范化。

① 「保存」字段说明去掉「（保留到下一回合）」
② 「蓄势」9156 文案统一为「手牌的此卡本局伤害 +3」（去掉「（战斗内不重置）」与
   静态文案里的「本局累计」两种旧写法，cards.json / zh_canonical / 三语 / 运行时同口）
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def patch(path, pairs):
    p = ROOT + path
    s = io.open(p, encoding="utf-8", newline="").read()
    for old, new, expect in pairs:
        n = s.count(old)
        if n != expect:
            print("!! %s: count=%d expect=%d for %r" % (path, n, expect, old[:60]))
            sys.exit(1)
        s = s.replace(old, new)
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print("ok %s" % path)


# ① 保存字段说明
patch("scripts/card_data.gd", [(
    u'"回合结束时，手牌里的这张卡不会丢弃（保留到下一回合）。"',
    u'"回合结束时，手牌里的这张卡不会丢弃。"',
    1,
)])

# ② 蓄势：运行时文案 + 注释
OLD_RT = u'\treturn "造成 %d 点伤害。回合结束时，每有 1 点未使用的费用，手卡的此卡伤害 +3（战斗内不重置）。" % v'
NEW_RT = u'\treturn "造成 %d 点伤害。回合结束时，每有 1 点未使用的费用，手牌的此卡本局伤害 +3。" % v'
patch("scripts/game_engine.gd", [
    (OLD_RT, NEW_RT, 1),
    (u"# 回合结束时每剩 1 点费用 → 手卡里这张 +CHARGE_UP_PER_ENERGY 伤害（战斗内不重置）。",
     u"# 回合结束时每剩 1 点费用 → 手卡里这张 +CHARGE_UP_PER_ENERGY 伤害（本局累计）。", 1),
])

# ② 静态文案（cards.json CRLF / zh_canonical LF，只换内文）
OLD_ZH = u"造成 0 点伤害。回合结束时，每有 1 点未使用的费用，手卡的此卡伤害 +3，本局累计。"
NEW_ZH = u"造成 0 点伤害。回合结束时，每有 1 点未使用的费用，手牌的此卡本局伤害 +3。"
patch("cards.json", [(OLD_ZH, NEW_ZH, 1)])
patch("i18n/zh_canonical.json", [(OLD_ZH, NEW_ZH, 1)])

# ② 三语
patch("i18n/cards_en.json", [(
    u"Deal 0 damage. At the end of the turn, for each point of unspent Cost, this card in your Hand gains +3 damage; this bonus accumulates for the rest of this battle.",
    u"Deal 0 damage. At the end of the turn, for each point of unspent Cost, this card in your Hand gains +3 damage for this battle.",
    1,
)])
patch("i18n/cards_ja.json", [(
    u"0ダメージを与える。ターン終了時、未使用のコスト1につき、手札にあるこのカードのダメージ+3。この上昇はこの戦闘中累積する。",
    u"0ダメージを与える。ターン終了時、未使用のコスト1につき、手札にあるこのカードはこの戦闘中ダメージ+3。",
    1,
)])
patch("i18n/cards_es.json", [(
    u"Inflige 0 de daño. Al final del turno, por cada 1 punto de Coste sin gastar, esta carta de la mano obtiene +3 de daño; esta bonificación se acumula durante esta batalla.",
    u"Inflige 0 de daño. Al final del turno, por cada 1 punto de Coste sin gastar, esta carta de la mano obtiene +3 de daño durante esta batalla.",
    1,
)])

# ② 测试：静态 + 运行时都锁新措辞
ANCHOR = (u'\tcheck(r232_cu != null and r232_cu.card_name == "蓄势" and r232_cu.is_spell()\r\n')
patch("scripts/test_engine.gd", [(
    ANCHOR,
    u'\tcheck(r232_cu != null and r232_cu.effect_text.contains("手牌的此卡本局伤害 +3"),\r\n\r\n'
    u'\t\t\t"R831 蓄势：cards.json 文案统一为「手牌的此卡本局伤害 +3」（%s）" % (r232_cu.effect_text if r232_cu else ""))\r\n\r\n'
    + ANCHOR,
    1,
)])
patch("scripts/test_engine.gd", [(
    u'\t\t\t"R232 蓄势：卡面文案同步显示当前伤害（%s）" % (r232_g1.effect_text if r232_g1 else ""))\r\n',
    u'\t\t\t"R232 蓄势：卡面文案同步显示当前伤害（%s）" % (r232_g1.effect_text if r232_g1 else ""))\r\n\r\n'
    u'\tcheck(r232_g1 != null and r232_g1.effect_text.contains("手牌的此卡本局伤害 +3")\r\n\r\n'
    u'\t\t\tand not r232_g1.effect_text.contains("战斗内不重置"),\r\n\r\n'
    u'\t\t\t"R831 蓄势：运行时文案用「手牌的此卡本局伤害 +3」、不再出现「战斗内不重置」（%s）" % (r232_g1.effect_text if r232_g1 else ""))\r\n',
    1,
)])

print("== all patched ==")
