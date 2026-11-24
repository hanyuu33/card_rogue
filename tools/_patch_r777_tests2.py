# -*- coding: utf-8 -*-
"""R777 测试修正两处：
  ① 满手断言 —— 打出本卡腾出 1 位，第 1 张会补进手牌（不是 3 张全进弃牌区）；
  ② 译文断言 —— `naturalize_card` **只返回效果正文**，卡名不在里面（既有 R773 的
     检查也只查效果关键词）。卡名另走 `GameI18n.card_name`，这里分开验。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TE = os.path.join(ROOT, "scripts", "test_engine.gd")
s = io.open(TE, "rb").read().decode("utf-8")


def sub(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    s = s.replace(old, new)


# ── ① 满手 ────────────────────────────────────────────────────────────────
sub('\tcheck(r777_e2.state.hand.size() == r777_hand_full_n - 1\r\n'
    '\t\t\tand r777_e2.state.discard.size() == r777_discard_before + 3,\r\n'
    '\t\t\t"R777 满手：3 张进弃牌区、手牌只少了打出的那张（%d→%d / 弃 %d→%d）"',
    '\t# 手牌满 → 打出本卡先腾出 1 位 → 第 1 张补进手牌、其余 2 张进弃牌区；\r\n'
    '\t# 弃牌区 +3 = 溢出的 2 张 + 打出的本卡本身（技能卡打出进弃牌区）。\r\n'
    '\tcheck(r777_e2.state.hand.size() == r777_hand_full_n\r\n'
    '\t\t\tand r777_e2.state.discard.size() == r777_discard_before + 3,\r\n'
    '\t\t\t"R777 满手：腾出的 1 位补进 1 张、另 2 张进弃牌区（手 %d→%d / 弃 %d→%d）"',
    "满手断言")

# ── ② 译文：先取卡名，再验效果正文 ────────────────────────────────────────
sub('\tGameSettings.language = "en"\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tvar r777_en: String = CardText.naturalize_card(r777_card)\r\n'
    '\tGameSettings.language = "ja"\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tvar r777_ja: String = CardText.naturalize_card(r777_card)\r\n',
    '\t# ⚠️ `naturalize_card` 只出**效果正文**，卡名不在里面（R773 的检查同样只查效果）——\r\n'
    '\t#   卡名另走 `GameI18n.card_name`，两样都验才叫「三语齐了」。\r\n'
    '\tGameSettings.language = "en"\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tvar r777_en_name: String = GameI18n.card_name(9269, r777_card.card_name)\r\n'
    '\tvar r777_en: String = CardText.naturalize_card(r777_card)\r\n'
    '\tGameSettings.language = "ja"\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tvar r777_ja_name: String = GameI18n.card_name(9269, r777_card.card_name)\r\n'
    '\tvar r777_ja: String = CardText.naturalize_card(r777_card)\r\n',
    "译文取值")

sub('\tcheck(r777_en.find("Rainbow") >= 0 and r777_en.find("Ally") >= 0\r\n'
    '\t\t\tand r777_en.find("费用") < 0 and r777_en.find("盟友") < 0,\r\n'
    '\t\t\t"R777 译文：en 下卡名与效果都是英文（%s）" % r777_en.replace("\\n", " ").left(40))\r\n'
    '\tcheck(r777_ja.find("虹の詩") >= 0 and r777_ja.find("味方") >= 0\r\n'
    '\t\t\tand r777_ja.find("费用") < 0 and r777_ja.find("盟友") < 0,\r\n'
    '\t\t\t"R777 译文：ja 下卡名与效果都是日文（%s）" % r777_ja.replace("\\n", " ").left(40))\r\n',
    '\tcheck(r777_en_name == "Rainbow Verse",\r\n'
    '\t\t\t"R777 译文：en 卡名走 i18n（%s）" % r777_en_name)\r\n'
    '\tcheck(r777_en.find("Ally") >= 0 and r777_en.find("Skill") >= 0\r\n'
    '\t\t\tand r777_en.find("费用") < 0 and r777_en.find("盟友") < 0,\r\n'
    '\t\t\t"R777 译文：en 下效果正文是英文（%s）" % r777_en.replace("\\n", " ").left(40))\r\n'
    '\tcheck(r777_ja_name == "虹の詩",\r\n'
    '\t\t\t"R777 译文：ja 卡名走 i18n（%s）" % r777_ja_name)\r\n'
    '\tcheck(r777_ja.find("味方") >= 0 and r777_ja.find("スキル") >= 0\r\n'
    '\t\t\tand r777_ja.find("费用") < 0 and r777_ja.find("盟友") < 0,\r\n'
    '\t\t\t"R777 译文：ja 下效果正文是日文（%s）" % r777_ja.replace("\\n", " ").left(40))\r\n',
    "译文断言")

assert "\n" not in s.replace("\r\n", "")
io.open(TE, "wb").write(s.encode("utf-8"))
print("[ok] test_engine.gd 已修正满手 / 译文断言")
