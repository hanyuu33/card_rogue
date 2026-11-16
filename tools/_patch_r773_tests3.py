# -*- coding: utf-8 -*-
"""R773 三补：test_engine.gd（CRLF）加一条「en / ja 真有译文」的断言。

R702 / R718 都踩过「中文原文改了、cards_en 忘同步 → 非中文环境静默掉回中文」，
所以新卡的译文也要在显示层验一次。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TE = os.path.join(ROOT, "scripts", "test_engine.gd")
s = io.open(TE, "rb").read().decode("utf-8")

old = (
    '\tcheck(r773_e2.state.energy == 3 and r773_e2._battle_energy_bonus == 1,\r\n'
    '\t\t\t"R773 空池：效果落空但费用照给（2 → %d）" % r773_e2.state.energy)\r\n'
    '\r\n'
    '\t# 收尾还原\r\n'
)
new = (
    '\tcheck(r773_e2.state.energy == 3 and r773_e2._battle_energy_bonus == 1,\r\n'
    '\t\t\t"R773 空池：效果落空但费用照给（2 → %d）" % r773_e2.state.energy)\r\n'
    '\r\n'
    '\t# ⑨ 三语：en / ja 都要真有译文（R702 / R718 都踩过「改了中文忘同步 → 静默掉回中文」）。\r\n'
    '\t# 判据读显示层输出（`CardText.naturalize_card`），不是查 json 里有没有这个键。\r\n'
    '\tvar r773_lang_bak: String = GameSettings.language\r\n'
    '\tGameSettings.language = "en"\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tvar r773_en: String = CardText.naturalize_card(r773_call)\r\n'
    '\tGameSettings.language = "ja"\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tvar r773_ja: String = CardText.naturalize_card(r773_call)\r\n'
    '\tGameSettings.language = r773_lang_bak\r\n'
    '\tGameI18n.reset_cache()\r\n'
    '\tcheck(r773_en.find("Call") >= 0 and r773_en.find("Energy") >= 0\r\n'
    '\t\t\tand r773_en.find("呼唤") < 0,\r\n'
    '\t\t\t"R773 译文：en 下卡名与效果都是英文（%s）" % r773_en.replace("\\n", " ").left(40))\r\n'
    '\tcheck(r773_ja.find("呼び声") >= 0 and r773_ja.find("戦闘") >= 0\r\n'
    '\t\t\tand r773_ja.find("呼唤") < 0,\r\n'
    '\t\t\t"R773 译文：ja 下卡名与效果都是日文（%s）" % r773_ja.replace("\\n", " ").left(40))\r\n'
    '\r\n'
    '\t# 收尾还原\r\n'
)
n = s.count(old)
assert n == 1, "锚点命中 %d 次" % n
s = s.replace(old, new)
assert s.count("\r\n") > 0 and "\n" not in s.replace("\r\n", "")
io.open(TE, "wb").write(s.encode("utf-8"))
print("[ok] 三语断言已插入")
