# -*- coding: utf-8 -*-
"""R692 反转五条「卡面必须写次元后果」的旧锁（R239 / R240 / R410×2 / R411）。

用法：python tools/_patch_r692_legacy.py [--write]
"""
import sys

P = "E:/work/card_rogue/scripts/test_engine.gd"
WRITE = "--write" in sys.argv
CR = "\r\n"
crlf = lambda *ls: CR.join(ls)

s = open(P, "rb").read().decode("utf-8")
assert s.count(CR) == s.count("\n")
edits = []

# ── ① R239 破绽 ─────────────────────────────────────────────
old = crlf(
    '\tcheck(r239_curse.has_affix(GameEngine.AFFIX_DIMENSION)',
    '',
    '\t\t\tand r239_curse.effect_text.contains("消失")',
    '',
    '\t\t\tand r239_curse.is_curse() and r239_curse.cost == 2,',
    '',
    '\t\t\t"R239 破绽：带「次元」字段（打出后消失），文案写明；仍是 2 费诅咒")',
)
new = crlf(
    '\tcheck(r239_curse.has_affix(GameEngine.AFFIX_DIMENSION)',
    '',
    '\t\t\tand not r239_curse.effect_text.contains("字段")',
    '',
    '\t\t\tand r239_curse.effect_text.contains("本场对战不再出现")',
    '',
    '\t\t\tand r239_curse.is_curse() and r239_curse.cost == 2,',
    '',
    '\t\t\t"R239/R692 破绽：次元由字段承载，只留「本场对战不再出现」这半句；仍是 2 费诅咒")',
)
edits.append(("R239", old, new))

# ── ② R240 破绽 ─────────────────────────────────────────────
old = crlf(
    '\tcheck(r240_curse.effect_text.contains("字段")',
    '',
    '\t\t\tand r240_curse.effect_text.contains("次元")',
    '',
    '\t\t\tand r240_curse.effect_text.contains("消失")',
    '',
    '\t\t\tand r240_curse.has_affix(GameEngine.AFFIX_DIMENSION),',
    '',
    '\t\t\t"R240 破绽：卡面注释了「字段：次元」的效果（%s）" % r240_curse.effect_text)',
)
new = crlf(
    '\tcheck(not r240_curse.effect_text.contains("字段")',
    '',
    '\t\t\tand not r240_curse.effect_text.contains("次元")',
    '',
    '\t\t\tand r240_curse.effect_text.contains("本场对战不再出现")',
    '',
    '\t\t\tand r240_curse.has_affix(GameEngine.AFFIX_DIMENSION),',
    '',
    '\t\t\t"R240/R692 破绽：正文不再复述次元说明，字段仍在（%s）" % r240_curse.effect_text)',
)
edits.append(("R240", old, new))

# ── ③④ R410 报废 / 集束炮台 ─────────────────────────────────
old = crlf(
    '\tcheck(r410_scrap != null and r410_scrap.effect_text.find("次元") >= 0',
    '',
    '\t\t\tand r410_scrap.effect_text.find("不进弃牌区") >= 0,',
    '',
    '\t\t\t"R410 报废卡面写明「次元：打出后消失，不进弃牌区」")',
    '',
    '\tcheck(r410_turret != null and r410_turret.effect_text.find("次元") >= 0',
    '',
    '\t\t\tand r410_turret.effect_text.find("离场即消失") >= 0,',
    '',
    '\t\t\t"R410 集束炮台卡面写明「次元：离场即消失，不进弃牌区」")',
)
new = crlf(
    '\tcheck(r410_scrap != null and r410_scrap.effect_text.find("次元") < 0',
    '',
    '\t\t\tand r410_scrap.effect_text.find("不进弃牌区") < 0',
    '',
    '\t\t\tand r410_scrap.has_affix(GameEngine.AFFIX_DIMENSION),',
    '',
    '\t\t\t"R410/R692 报废：卡面不再复述次元，后果由字段承载")',
    '',
    '\tcheck(r410_turret != null and r410_turret.effect_text.find("次元") < 0',
    '',
    '\t\t\tand r410_turret.effect_text.find("离场即消失") < 0',
    '',
    '\t\t\tand r410_turret.has_affix(GameEngine.AFFIX_DIMENSION),',
    '',
    '\t\t\t"R410/R692 集束炮台：卡面不再复述次元，后果由字段承载")',
)
edits.append(("R410", old, new))

# ── ⑤ R411 全库守卫：从「必须写」反转为「不许写」 ────────────
old = crlf(
    '\t\tvar r411_t: String = r411_c.effect_text',
    '',
    '\t\tif r411_t.find("字段「次元」") < 0:',
    '',
    '\t\t\tr411_missing.append("%s(%d)" % [r411_c.card_name, r411_c.id])',
    '',
    '\t\t\tcontinue',
    '',
    '\t\tvar r411_need: String = "打出后消失" if (r411_c.is_spell() or r411_c.is_curse()) \\',
    '',
    '\t\t\t\telse "离场即消失"',
    '',
    '\t\tif r411_t.find(r411_need) < 0:',
    '',
    '\t\t\tr411_wrong.append("%s(%d)" % [r411_c.card_name, r411_c.id])',
    '',
    '\t\tif r411_t.find("（") >= 0:',
    '',
    '\t\t\tr411_paren.append("%s(%d)" % [r411_c.card_name, r411_c.id])',
)
new = crlf(
    '\t\tvar r411_t: String = r411_c.effect_text',
    '',
    '\t\t# R692（店长口径「多余的字段描述文本删除」）：从「必须写」反转为「不许写」。',
    '',
    '\t\t# 「次元」由字段本身承载（卡面 glyph + 悬停解释），正文再复述一遍就是冗余。',
    '',
    '\t\tif r411_t.find("字段「次元」") >= 0 or r411_t.find("次元：") >= 0:',
    '',
    '\t\t\tr411_missing.append("%s(%d)" % [r411_c.card_name, r411_c.id])',
    '',
    '\t\tif r411_t.find("次元：") >= 0 or r411_t.find("次元:") >= 0:',
    '',
    '\t\t\tr411_wrong.append("%s(%d)" % [r411_c.card_name, r411_c.id])',
    '',
    '\t\tif r411_t.find("（") >= 0:',
    '',
    '\t\t\tr411_paren.append("%s(%d)" % [r411_c.card_name, r411_c.id])',
)
edits.append(("R411 loop", old, new))

old_msg = crlf(
    '\t\t\t"R411 每张次元卡都写明后果（漏写：%s）" % ", ".join(r411_missing))',
)
new_msg = crlf(
    '\t\t\t"R692 每张次元卡正文都不再复述字段说明（残留：%s）" % ", ".join(r411_missing))',
)
edits.append(("R411 missing msg", old_msg, new_msg))

old_msg2 = crlf(
    '\t\t\t"R411 次元句式按卡种分对（技能/诅咒=打出后消失，盟友/工事=离场即消失；写错：%s）"',
)
new_msg2 = crlf(
    '\t\t\t"R692 次元正文不再出现「次元：…」句式（残留：%s）"',
)
edits.append(("R411 wrong msg", old_msg2, new_msg2))

for tag, o, n in edits:
    c = s.count(o)
    assert c == 1, "[%s] 锚点命中 %d 次" % (tag, c)
    s = s.replace(o, n)
    print("  ok  %s" % tag)

if WRITE:
    open(P, "wb").write(s.encode("utf-8"))
    b = open(P, "rb").read()
    print("CRLF %d / LF %d" % (b.count(b"\r\n"), b.count(b"\n")))
    print("WROTE")
else:
    print("DRY-RUN")
