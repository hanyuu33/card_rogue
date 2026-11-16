# -*- coding: utf-8 -*-
"""R773 二次修正（test_engine.gd，CRLF）：
  ① R226 玩家技能卡 104 → 105（新增呼唤）
  ② R346 期望值统计补「隐藏职业不算」（与 reward_pool 对齐 —— 以前隐藏卡都是 rarity 3
     才蒙对，R773 呼唤是 rarity 0，蒙不过去了）
  ③ R773 判据断言改口径：判据读**玩家当前职业**，不是在库里给呼唤定性
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TE = os.path.join(ROOT, "scripts", "test_engine.gd")
s = io.open(TE, "rb").read().decode("utf-8")


def sub(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s：命中 %d 次" % (tag, n)
    s = s.replace(old, new)


# ── ① R226 ────────────────────────────────────────────────────────────────
sub("check(r226_skills == 104 and r226_dmg == 42 and r226_leak.is_empty(),",
    "check(r226_skills == 105 and r226_dmg == 42 and r226_leak.is_empty(),",
    "R226 技能卡数")

# ── ② R346 ────────────────────────────────────────────────────────────────
sub('\t\tif c0.rarity <= 2 and not c0.traits.has("测试") and not c0.event_only and not (\r\n',
    '\t\t# R773：隐藏职业卡（吟游诗人）也**不进**随机池 —— 以前它们都是 rarity 3 天然被上面\r\n'
    '\t\t# 那道稀有条槛挡住，R773 呼唤 9266 是 rarity 0，这里必须显式对齐 `reward_pool()`。\r\n'
    '\t\t# ⚠️ 条件用括号包住换行，GDScript 不认行尾反斜杠续行。\r\n'
    '\t\tif (c0.rarity <= 2 and not c0.traits.has("测试") and not c0.event_only\r\n'
    '\t\t\t\tand not PlayerClass.is_hidden_class(c0.card_class)\r\n'
    '\t\t\t\tand not (c0.locked and not ProfileData.is_card_unlocked(c0.id))):\r\n',
    "R346 期望统计")

# ── ③ R773 判据断言 ───────────────────────────────────────────────────────
sub('\tcheck(not r773_probe._other_class_card(r773_call),\r\n'
    '\t\t\t"R773 判据：呼唤自己不算「其他职业卡」（有归属 + 不是自己）")\r\n',
    '\t# 判据读的是**玩家当前职业**，不是在库里给呼唤定性 —— 所以两种身份都要验。\r\n'
    '\t# （_random_call_ally 也靠它排除「自己家」的卡，这里顺带把测试前提钉死。）\r\n'
    '\tRunState.player_class = PlayerClass.BARD\r\n'
    '\tcheck(not r773_probe._other_class_card(r773_call),\r\n'
    '\t\t\t"R773 判据：吟游诗人自己手里，呼唤不算「其他职业卡」")\r\n'
    '\tRunState.player_class = PlayerClass.DRUID\r\n'
    '\tcheck(r773_probe._other_class_card(r773_call),\r\n'
    '\t\t\t"R773 判据：换成森林精魄，呼唤就是「其他职业卡」（判据读当前职业）")\r\n'
    '\tRunState.player_class = PlayerClass.BARD\r\n',
    "R773 判据")

# ── ④ R773 收尾：player_class 也要还原 ──────────────────────────────────
sub('\tvar r773_sv_active: bool = RunState.run_active\r\n'
    '\tRunState.run_active = false   # 测试里打的牌不许写进玩家成就统计\r\n',
    '\tvar r773_sv_active: bool = RunState.run_active\r\n'
    '\tvar r773_sv_class: String = RunState.player_class\r\n'
    '\tRunState.run_active = false   # 测试里打的牌不许写进玩家成就统计\r\n'
    '\t# 本卡的真实场景只有一种：玩家是吟游诗人（隐藏职业）。`_other_class_card()` 读的就是\r\n'
    '\t# `RunState.player_class`，所以整段测试都钉在这个身份上，否则测出来的不是真实行为。\r\n'
    '\tRunState.player_class = PlayerClass.BARD\r\n',
    "R773 前提")

sub('\tRunState.relics = r773_sv_relics\r\n'
    '\tRunState.spent_relics = r773_sv_spent\r\n'
    '\tRunState.run_active = r773_sv_active\r\n',
    '\tRunState.relics = r773_sv_relics\r\n'
    '\tRunState.spent_relics = r773_sv_spent\r\n'
    '\tRunState.run_active = r773_sv_active\r\n'
    '\tRunState.player_class = r773_sv_class\r\n',
    "R773 收尾")

# 早退分支也要还原 player_class
sub('\tif r773_call == null:\r\n'
    '\t\tRunState.relics = r773_sv_relics\r\n'
    '\t\tRunState.spent_relics = r773_sv_spent\r\n'
    '\t\tRunState.run_active = r773_sv_active\r\n'
    '\t\treturn\r\n',
    '\tif r773_call == null:\r\n'
    '\t\tRunState.relics = r773_sv_relics\r\n'
    '\t\tRunState.spent_relics = r773_sv_spent\r\n'
    '\t\tRunState.run_active = r773_sv_active\r\n'
    '\t\tRunState.player_class = r773_sv_class\r\n'
    '\t\treturn\r\n',
    "R773 早退")

assert s.count("\r\n") > 0 and "\n" not in s.replace("\r\n", "")
io.open(TE, "wb").write(s.encode("utf-8"))
print("[ok] test_engine.gd 二次修正完成")
