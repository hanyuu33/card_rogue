# -*- coding: utf-8 -*-
"""R832b：缺陷时钟计数封顶 —— 触发后**真的不再计数**，而不是靠 `==` 去重。

用户追问「触发一次之后是不是能正常地不再计数」。实测（tools/_probe_r832_clock.gd）：
  turn 只在第 12 张跳一次 ✓ / opp_turns 恒 0 ✓ / 角标恒 0 ✓
  但 `_clock_plays` 12→13→…→25 一直在涨 —— 行为正确靠的是 `== DEFECT_CLOCK_AT`。
风险：谁把 `==` 改成 `>=`（很自然的「更稳妥」改法），就会每打一张都换回合，
      把「一场一次」变成「无限回合」。封顶后两种写法都安全，语义也对：
      这一场已经白赚过一次，再数没有意义。

⚠️ 行尾：两个文件都是 CRLF。
"""
ROOT = "E:/work/card_rogue/"


def rd(rel):
    return open(ROOT + rel, "rb").read()


def wr(rel, b):
    open(ROOT + rel, "wb").write(b)


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8")


def rep(b, old, new, tag):
    assert b.count(old) == 1, "[%s] 命中 %d 次" % (tag, b.count(old))
    return b.replace(old, new)


# ── ① 计数封顶 ──
GE = "scripts/game_engine.gd"
ge = rd(GE)
old = crlf(
    "\tif side == SIDE_SELF and played != null and self_relics.has(DEFECT_CLOCK_ID):\n"
    "\t\t_clock_plays += 1\n"
    "\t\tif _clock_plays == DEFECT_CLOCK_AT:\n"
)
new = crlf(
    "\tif side == SIDE_SELF and played != null and self_relics.has(DEFECT_CLOCK_ID):\n"
    "\t\t# R832：计数**到 DEFECT_CLOCK_AT 就停** —— 这一场已经白赚过一次，再数没有意义。\n"
    "\t\t# ⚠️ 原先是无条件 `+= 1`、只靠 `== 12` 去重：谁把判据改成 `>=`（很自然的「更稳妥」\n"
    "\t\t#    改法）就会变成**每打一张都换回合**，一场战斗里玩家能无限白赚。封顶后两种写法都安全。\n"
    "\t\tif _clock_plays < DEFECT_CLOCK_AT:\n"
    "\t\t\t_clock_plays += 1\n"
    "\t\t\tif _clock_plays == DEFECT_CLOCK_AT:\n"
)
ge = rep(ge, old, new, "ge.count")

# 置待办 / 日志那两行要跟着多缩进一层
old2 = crlf(
    "\t\t\tif _clock_plays == DEFECT_CLOCK_AT:\n"
    "\t\t\t_clock_pending = true\n"
    "\t\t\t_log(\"缺陷时钟：本场已打出第 %d 张牌，本卡结算完后结束回合\" % DEFECT_CLOCK_AT)\n"
)
new2 = crlf(
    "\t\t\tif _clock_plays == DEFECT_CLOCK_AT:\n"
    "\t\t\t\t_clock_pending = true\n"
    "\t\t\t\t_log(\"缺陷时钟：本场已打出第 %d 张牌，本卡结算完后结束回合\" % DEFECT_CLOCK_AT)\n"
)
ge = rep(ge, old2, new2, "ge.indent")

# ── ② 取数口注释：封顶之后 mini 变成双保险 ──
old3 = crlf(
    "\t## ⚠️ 触发之后 `_clock_plays` 还会继续涨（`_note_card_played` 只对 `==` 置待办）→\n"
    "\t##    夹到 0：本场已经白赚过一回合，「0」＝本场没戏，下一场重新数。\n"
)
new3 = crlf(
    "\t## R832：`_clock_plays` 到 DEFECT_CLOCK_AT 就封顶（见 `_note_card_played`），\n"
    "\t##    这里的 `mini` 只是防别的路径写脏 —— 双保险，不是主判据。\n"
    "\t##    本场已经白赚过一回合，角标恒「0」＝本场用光了，下一场重新数。\n"
)
ge = rep(ge, old3, new3, "ge.left")
wr(GE, ge)

# ── ③ 测试：把「第 13 张仍为 0」升级成「计数封顶 + 再压 6 次一步不动」 ──
TE = "scripts/test_engine.gd"
te = rd(TE)
old4 = crlf(
    "\t# ⑤ 再打几张也不会变负数（`_clock_plays` 会继续涨，取数口必须夹住）\n"
    "\tr832_e.state.energy = 30\n"
    "\tr832_e.state.hand.clear()\n"
    "\tr832_e.state.hand.append(CardData.from_dict(r832_cards.get_card(8006).to_dict()))\n"
    "\tr832_e.play_from_hand(0, Vector2i(4, 2))\n"
    "\tcheck(r832_e.defect_clock_left() == 0,\n"
    "\t\t\t\"R832 缺陷时钟：第 13 张后仍为 0，不出负数（实际 %d）\" % r832_e.defect_clock_left())\n"
)
new4 = crlf(
    "\t# ⑤ 触发之后**计数就停住**（R832b，用户追问「是不是不再计数」）：\n"
    "\t#    原先只是靠 `== 12` 去重，`_clock_plays` 会一路涨到 25 —— 谁把判据改成 `>=`\n"
    "\t#    就会每张都换回合。现在封顶在 12，两种写法都安全。\n"
    "\tr832_e.state.energy = 30\n"
    "\tr832_e.state.hand.clear()\n"
    "\tr832_e.state.hand.append(CardData.from_dict(r832_cards.get_card(8006).to_dict()))\n"
    "\tr832_e.play_from_hand(0, Vector2i(4, 2))\n"
    "\tcheck(r832_e._clock_plays == 12,\n"
    "\t\t\t\"R832 缺陷时钟：触发后计数封顶在 12，不再累加（实际 %d）\" % r832_e._clock_plays)\n"
    "\tcheck(r832_e.defect_clock_left() == 0,\n"
    "\t\t\t\"R832 缺陷时钟：第 13 张后仍为 0，不出负数（实际 %d）\" % r832_e.defect_clock_left())\n"
    "\t# ⑤b 再往唯一计数口直压 6 次（相当于本场第 14~19 张）：一步都不动、回合一次都不跳\n"
    "\tvar r832_t1: int = r832_e.turn_number\n"
    "\tvar r832_card := CardData.from_dict(r832_cards.get_card(8006).to_dict())\n"
    "\tfor i in 6:\n"
    "\t\tr832_e._note_card_played(GameEngine.SIDE_SELF, r832_card)\n"
    "\t\tr832_e._clock_maybe_switch()\n"
    "\tcheck(r832_e._clock_plays == 12,\n"
    "\t\t\t\"R832 缺陷时钟：再打 6 张，计数仍是 12（实际 %d）\" % r832_e._clock_plays)\n"
    "\tcheck(r832_e.turn_number == r832_t1 and r832_e.opp_turns == 0,\n"
    "\t\t\t\"R832 缺陷时钟：再打 6 张一次都不换回合（turn %d / opp %d）\"\n"
    "\t\t\t\t% [r832_e.turn_number, r832_e.opp_turns])\n"
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"0\",\n"
    "\t\t\t\"R832 角标：再打 6 张仍画「0」\")\n"
)
te = rep(te, old4, new4, "te.⑤")
wr(TE, te)

print("R832b 补丁完成")
