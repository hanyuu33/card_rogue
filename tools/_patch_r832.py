# -*- coding: utf-8 -*-
"""R832：缺陷时钟（6084）角标不显示计数 —— 补角标取数口。

根因：计数活在引擎（`GameEngine._clock_plays`，每场复位），
而角标唯一取数口 `RunState.relic_badge_text()` 里没有 6084 这一支 → 恒返回 ""。
修法（照 `relic_display_name(id, plays)` 的既有先例）：加第二参把引擎值递进来，
界面不自己反算数字。

⚠️ 行尾：game_engine / battle_scene / test_engine 是 CRLF，run_state 是 LF。
    一律按**字节**替换，块内换行用 CRLF 常量，免得整篇被转成 LF。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def read_bytes(rel):
    with open(ROOT + rel, "rb") as f:
        return f.read()


def write_bytes(rel, data):
    with open(ROOT + rel, "wb") as f:
        f.write(data)


def rep(data, old, new, tag):
    assert data.count(old) == 1, "[%s] 锚点命中 %d 次" % (tag, data.count(old))
    return data.replace(old, new)


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8")


# ───────────────────────── ① game_engine.gd ─────────────────────────
GE = "scripts/game_engine.gd"
ge = read_bytes(GE)

old_ge = crlf(
    "func _clock_maybe_switch() -> void:\n"
    "\t## R810 缺陷时钟（6084）：本场第 DEFECT_CLOCK_AT 张牌打完 → 结束当前回合、\n"
)
new_ge = crlf(
    "func defect_clock_left() -> int:\n"
    "\t## R832：缺陷时钟（6084）**本场还要再打几张牌**才触发 —— 角标唯一的取数口。\n"
    "\t## 计数 `_clock_plays` 只活在引擎里：每个新 GameEngine = 一场新战斗，天然复位，\n"
    "\t## 所以读档续战之后角标与实际触发同源（RunState 不另存一份，免得两套账）。\n"
    "\t## ⚠️ 触发之后 `_clock_plays` 还会继续涨（`_note_card_played` 只对 `==` 置待办）→\n"
    "\t##    夹到 0：本场已经白赚过一回合，「0」＝本场没戏，下一场重新数。\n"
    "\treturn maxi(0, DEFECT_CLOCK_AT - mini(_clock_plays, DEFECT_CLOCK_AT))\n"
    "\n"
    "\n"
    "func _clock_maybe_switch() -> void:\n"
    "\t## R810 缺陷时钟（6084）：本场第 DEFECT_CLOCK_AT 张牌打完 → 结束当前回合、\n"
)
ge = rep(ge, old_ge, new_ge, "ge.defect_clock_left")
write_bytes(GE, ge)

# ───────────────────────── ② run_state.gd（LF）─────────────────────────
RS = "scripts/run_state.gd"
rs = read_bytes(RS)

old_const = (
    "const CRESCENT_EARING_ID := 6081\n"
    "const CRESCENT_EVERY := 3\n"
    "static var crescent_battles := 0\n"
).encode("utf-8")
new_const = (
    "const CRESCENT_EARING_ID := 6081\n"
    "const CRESCENT_EVERY := 3\n"
    "static var crescent_battles := 0\n"
    "\n"
    "## R832 缺陷时钟（6084，传奇档）：每场战斗打出第 12 张牌 → 结束当前回合并跳过敌方回合。\n"
    "## ⚠️ 计数**只活在战斗引擎里**（`GameEngine._clock_plays`）—— 这里不另存一份，\n"
    "##    否则读档续战之后「角标」与「实际触发」会变成两套账。\n"
    "##    角标由战斗界面把 `engine.defect_clock_left()` 当参数递进来（见 `relic_badge_text`）。\n"
    "const DEFECT_CLOCK_BADGE_ID := 6084\n"
).encode("utf-8")
rs = rep(rs, old_const, new_const, "rs.const")

old_sig = "static func relic_badge_text(id: int) -> String:\n".encode("utf-8")
new_sig = (
    "static func relic_badge_text(id: int, clock_left := -1) -> String:\n"
).encode("utf-8")
rs = rep(rs, old_sig, new_sig, "rs.sig")

old_doc = (
    "\t##   * 其余道具 → 没有可数的东西。\n"
).encode("utf-8")
new_doc = (
    "\t##   * 缺陷时钟（6084，R832）→ 本场**还差几张牌**触发。它的计数在引擎里，\n"
    "\t##     由战斗界面当第二参 `clock_left` 递进来；没有战斗上下文（图鉴 / 商店 / 奖励页）\n"
    "\t##     时是默认的 -1 → 不画。本场已触发过 → 「0」照画（跟火柴同口径：得让玩家\n"
    "\t##     看见这一场已经用光了）。\n"
    "\t##   * 其余道具 → 没有可数的东西。\n"
).encode("utf-8")
rs = rep(rs, old_doc, new_doc, "rs.doc")

old_branch = (
    "\t\tBASIN_RELIC_ID:\n"
    "\t\t\treturn str(basin_charge) if basin_charge > 0 else \"\"\n"
    "\treturn \"\"\n"
).encode("utf-8")
new_branch = (
    "\t\tBASIN_RELIC_ID:\n"
    "\t\t\treturn str(basin_charge) if basin_charge > 0 else \"\"\n"
    "\t\tDEFECT_CLOCK_BADGE_ID:\n"
    "\t\t\treturn str(clock_left) if clock_left >= 0 else \"\"\n"
    "\treturn \"\"\n"
).encode("utf-8")
rs = rep(rs, old_branch, new_branch, "rs.branch")
write_bytes(RS, rs)

# ───────────────────────── ③ battle_scene.gd（CRLF）─────────────────────────
BS = "scripts/battle_scene.gd"
bs = read_bytes(BS)

old_bs = crlf(
    "\t## 样式跟着 UI 的暖金描边走：深底 + 1px 金边 + 浅米字，压在弧与蓝边之上。\n"
    "\tvar txt := RunState.relic_badge_text(id)\n"
)
new_bs = crlf(
    "\t## 样式跟着 UI 的暖金描边走：深底 + 1px 金边 + 浅米字，压在弧与蓝边之上。\n"
    "\t# R832：缺陷时钟的计数在**引擎**里（本场已打出张数）—— 这里把引擎值递进去，\n"
    "\t# 界面不自己拿 `_clock_plays` 反算。其余道具不读这个参数，照旧只认 RunState。\n"
    "\tvar txt := RunState.relic_badge_text(id, engine.defect_clock_left())\n"
)
bs = rep(bs, old_bs, new_bs, "bs.badge")
write_bytes(BS, bs)

# ───────────────────────── ④ test_engine.gd（CRLF）─────────────────────────
TE = "scripts/test_engine.gd"
te = read_bytes(TE)

# ④a 旧守卫串要跟着签名走
te = rep(te,
         crlf("\tcheck_src(r809_src.contains(\"RunState.relic_badge_text(id)\"),\n"),
         crlf("\tcheck_src(r809_src.contains(\"RunState.relic_badge_text(id, engine.defect_clock_left())\"),\n"),
         "te.guard809")

# ④b 注册
te = rep(te, crlf("\t_test_r830()\n\n\tprint(\"== 结果：\""),
         crlf("\t_test_r830()\n\t_test_r832()\n\n\tprint(\"== 结果：\""),
         "te.register")

# ④c 新增测试函数（放在 _test_r830 定义之前）
TEST = crlf(
    "func _test_r832() -> void:\n"
    "\t## R832：缺陷时钟（6084）**角标不显示计数**（用户实测）。\n"
    "\t## 根因不是画不出来，是取数口没这一支：它的计数是「本场已打出张数」，\n"
    "\t## 活在引擎 `_clock_plays` 里，而 `RunState.relic_badge_text()` 只认 RunState 的静态状态。\n"
    "\t## 现在第二参 `clock_left` 由 `battle_scene._draw_relic_badge()` 把\n"
    "\t## `engine.defect_clock_left()` 递进来 —— 与 `relic_display_name(id, plays)` 同一套先例。\n"
    "\tvar r832_sv_relics := RunState.relics\n"
    "\tvar r832_sv_spent := RunState.spent_relics\n"
    "\tvar r832_cards := CardRepo.load_json()\n"
    "\tRunState.relics = [6084]\n"
    "\tRunState.spent_relics = []\n"
    "\n"
    "\t# ① 没有战斗上下文（图鉴 / 商店 / 奖励页）→ 不画（默认参 -1）\n"
    "\tcheck(RunState.relic_badge_text(6084) == \"\",\n"
    "\t\t\t\"R832 缺陷时钟：非战斗界面不画角标（实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084))\n"
    "\n"
    "\t# ② 战斗开场 → 还差 12 张\n"
    "\tvar r832_e := _new_engine([], 40, 40)\n"
    "\t_begin(r832_e)\n"
    "\tcheck(r832_e.defect_clock_left() == 12,\n"
    "\t\t\t\"R832 缺陷时钟：开场还差 12 张（实际 %d）\" % r832_e.defect_clock_left())\n"
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"12\",\n"
    "\t\t\t\"R832 角标：开场画「12」（实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084, r832_e.defect_clock_left()))\n"
    "\n"
    "\t# ③ 真打一张 → 11（走真实出牌口，验「引擎计数 → 角标」这条链是活的）\n"
    "\tr832_e.state.energy = 30\n"
    "\tr832_e.state.hand.clear()\n"
    "\tr832_e.state.hand.append(CardData.from_dict(r832_cards.get_card(8006).to_dict()))\n"
    "\tr832_e.play_from_hand(0, Vector2i(4, 1))\n"
    "\tcheck(r832_e.defect_clock_left() == 11,\n"
    "\t\t\t\"R832 缺陷时钟：打 1 张后还差 11 张（实际 %d）\" % r832_e.defect_clock_left())\n"
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"11\",\n"
    "\t\t\t\"R832 角标：打 1 张后画「11」（实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084, r832_e.defect_clock_left()))\n"
    "\n"
    "\t# ④ 第 12 张 → 触发（换回合），角标「0」＝本场用光\n"
    "\tr832_e.state.energy = 30\n"
    "\tr832_e.state.hand.clear()\n"
    "\tr832_e.state.hand.append(CardData.from_dict(r832_cards.get_card(8006).to_dict()))\n"
    "\tr832_e._clock_plays = 11\n"
    "\tvar r832_t0: int = r832_e.turn_number\n"
    "\tr832_e.play_from_hand(0, Vector2i(4, 0))\n"
    "\tcheck(r832_e.turn_number == r832_t0 + 1 and r832_e.opp_turns == 0,\n"
    "\t\t\t\"R832 缺陷时钟：第 12 张照旧跳过敌方回合（回合 %d → %d，opp_turns %d）\"\n"
    "\t\t\t\t% [r832_t0, r832_e.turn_number, r832_e.opp_turns])\n"
    "\tcheck(r832_e.defect_clock_left() == 0,\n"
    "\t\t\t\"R832 缺陷时钟：触发后还差 0 张（实际 %d）\" % r832_e.defect_clock_left())\n"
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"0\",\n"
    "\t\t\t\"R832 角标：触发后画「0」（本场用光）\")\n"
    "\n"
    "\t# ⑤ 再打几张也不会变负数（`_clock_plays` 会继续涨，取数口必须夹住）\n"
    "\tr832_e.state.energy = 30\n"
    "\tr832_e.state.hand.clear()\n"
    "\tr832_e.state.hand.append(CardData.from_dict(r832_cards.get_card(8006).to_dict()))\n"
    "\tr832_e.play_from_hand(0, Vector2i(4, 2))\n"
    "\tcheck(r832_e.defect_clock_left() == 0,\n"
    "\t\t\t\"R832 缺陷时钟：第 13 张后仍为 0，不出负数（实际 %d）\" % r832_e.defect_clock_left())\n"
    "\n"
    "\t# ⑥ 下一场（新引擎）→ 回到 12（每场复位是设计口径，不是漏清）\n"
    "\tvar r832_e2 := _new_engine([], 40, 40)\n"
    "\t_begin(r832_e2)\n"
    "\tcheck(r832_e2.defect_clock_left() == 12,\n"
    "\t\t\t\"R832 缺陷时钟：下一场重新数到 12（实际 %d）\" % r832_e2.defect_clock_left())\n"
    "\n"
    "\t# ⑦ 没这件道具 → 不画（传了引擎值也不画）\n"
    "\tRunState.relics = []\n"
    "\tcheck(RunState.relic_badge_text(6084, 7) == \"\",\n"
    "\t\t\t\"R832 角标：没持有缺陷时钟时不画（实际「%s」）\" % RunState.relic_badge_text(6084, 7))\n"
    "\n"
    "\t# ⑧ 源码守卫：绘制口必须把引擎计数递进唯一取数口，不许界面自己算\n"
    "\tvar r832_bs_src := FileAccess.get_file_as_string(\"res://scripts/battle_scene.gd\")\n"
    "\tcheck_src(r832_bs_src.contains(\"RunState.relic_badge_text(id, engine.defect_clock_left())\"),\n"
    "\t\t\t\"R832 守卫：角标绘制口把 `engine.defect_clock_left()` 递进取数口\")\n"
    "\n"
    "\tRunState.relics = r832_sv_relics\n"
    "\tRunState.spent_relics = r832_sv_spent\n"
    "\n"
    "\n"
)

old_fn = crlf("func _test_r830() -> void:\n")
te = rep(te, old_fn, TEST + old_fn, "te.func")
write_bytes(TE, te)

print("R832 补丁完成：game_engine / run_state / battle_scene / test_engine")
