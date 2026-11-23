#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：接入「余音」9274（X 费塞 X 张音符）与「音符」9275（0 费 +2 费 + 抽 2 · 次元）。

三处：
  ① 常量区（BARRAGE 之后）加 ENCORE_ID / NOTE_ID / NOTE_ENERGY / NOTE_DRAW；
  ② `_barrage()` 之后加 `_encore()` 与 `_note()`；
  ③ 技能 match 里挂 ENCORE_ID / NOTE_ID 两个分支。

X 一律走 `_x_spell_value`（use_spell / remote_spell 都在 _pay 之前抓），
钻头 6077 的「X ≥ 6 翻倍」自动同源生效 —— 与 9272 / 9273 一模一样。
两张卡都不造成伤害 → 不登记 SPELL_BASE_DMG / SPELL_DYNAMIC_IDS / spell_now（左栏不该画伤害行）。
"""
P = "scripts/game_engine.gd"
d = open(P, "rb").read().decode("utf-8")


def rep(old, new, tag):
    assert d.count(old) == 1, "[%s] count=%d" % (tag, d.count(old))
    return d.replace(old, new)


# ---------- ① 常量 ----------
CONST_OLD = (
    "# ── 炮火就位（9273 技能，R799，机械之心史诗）：X 费；X 张聚能炮击进抽牌库 + 全体 3 伤 × X 次 ──\r\n"
    "const BARRAGE_ID:= 9273\r\n"
    "const BARRAGE_DMG:= 3\r\n"
)
CONST_NEW = CONST_OLD + (
    "\r\n"
    "# ── 余音（9274 技能，R800，吟游诗人稀有）：X 费；X 张「音符」进抽牌库 ──\r\n"
    "# 音符（9275）是**内部卡**（`event_only`，不进任何获得池）：0 费，「+2 费 + 抽 2 张」，带「次元」。\r\n"
    "# 「次元」在这里不是装饰：没有它，音符打完进弃牌区 → 被洗回牌库 → 又是 +2 费 + 抽 2 张，\r\n"
    "# 一张余音就能把牌库变成永动机。用后进消耗区（`_spell_card_gone` 只认字段）才安全。\r\n"
    "const ENCORE_ID:= 9274\r\n"
    "const NOTE_ID:= 9275\r\n"
    "const NOTE_ENERGY:= 2\r\n"
    "const NOTE_DRAW:= 2\r\n"
)
d = rep(CONST_OLD, CONST_NEW, "const")

# ---------- ② 两个结算函数（接在 _barrage 之后） ----------
# _barrage 的结尾 = 它最后一行 return + 空行 + 下一个 func。
import re

m = re.search(r"\nfunc _barrage\(side: String, card: CardData\) -> String:\r\n(.*?)\r\n\r\n\r\nfunc ", d, re.S)
assert m, "_barrage 定位失败"
tail = d[m.end() - len("func "):]  # 从 `func ` 开始的下一个函数头
FUNCS = (
    "func _encore(side: String, card: CardData) -> String:\r\n"
    "\t## 余音（9274，R800，吟游诗人稀有技能）：X 费 → 将 X 张「音符」(9275) 加入**抽牌库**。\r\n"
    "\t## X 走 `_x_spell_value`（`use_spell` 在 `_pay` 之前抓取）→ 钻头 6077 的「X ≥ 6 翻倍」\r\n"
    "\t## 与连斩 9272 / 炮火就位 9273 同源，改一处三张一起变。\r\n"
    "\t## 音符是 `event_only` 的内部卡：只活在抽牌库里，不进图鉴获得池 / 奖励池 / 商店。\r\n"
    "\t## 造卡与「聚能炮击」完全一致（`CardData.from_dict(proto.to_dict())` → traits 另拷一份），\r\n"
    "\t## 顺手发 `deck_added`，界面靠它播塞牌动画。\r\n"
    "\tvar n:= maxi(0, _x_spell_value)\r\n"
    "\tif n <= 0:\r\n"
    "\t\t_log(\"余音：X = 0（没有费用），一张音符都没塞进去\")\r\n"
    "\t\treturn \"余音：X = 0，没有音符加入抽牌库\"\r\n"
    "\tif side != SIDE_SELF:\r\n"
    "\t\t# 敌方没有真实牌库（只有抽象计数 opp_deck_count）→ 只推进计数，与「镜像」同口径。\r\n"
    "\t\tstate.opp_deck_count += n\r\n"
    "\t\t_log(\"余音（敌方）：敌方牌库 +%d 张\" % n)\r\n"
    "\t\treturn \"将 %d 张「音符」加入抽牌库\" % n\r\n"
    "\tvar repo:= CardRepo.load_json()\r\n"
    "\tvar proto: CardData = repo.get_card(NOTE_ID) if repo != null else null\r\n"
    "\tif proto == null:\r\n"
    "\t\t_log(\"余音：卡库缺少「音符」(9275)，加卡部分落空\")\r\n"
    "\t\treturn \"余音：卡库缺少「音符」\"\r\n"
    "\tvar added:= 0\r\n"
    "\tfor _i in n:\r\n"
    "\t\tvar c:= CardData.from_dict(proto.to_dict())\r\n"
    "\t\tc.traits = (c.traits as Array).duplicate()\r\n"
    "\t\tstate.deck.append(c)\r\n"
    "\t\taction.emit(\"deck_added\", {\"card\": c, \"side\": side})\r\n"
    "\t\tadded += 1\r\n"
    "\t_log(\"余音：抽牌库 +%d 张「音符」（牌库 %d 张）\" % [added, state.deck.size()])\r\n"
    "\treturn \"将 %d 张「音符」加入抽牌库\" % added\r\n"
    "\r\n"
    "\r\n"
    "func _note(side: String) -> String:\r\n"
    "\t## 音符（9275，R800，吟游诗人内部卡 · 0 费技能 · 次元）：获得 2 点费用，抽 2 张卡。\r\n"
    "\t## * 加费直接 `state.energy +=`（与应急电源 9170 / 拆解 8049 同口径：\r\n"
    "\t##   不污染 `self_energy_spent`，当回合允许超额）。\r\n"
    "\t## * 抽卡只走 `_draw_many` 唯一口：手牌满会 burn 进弃牌区并广播 `hand_full`。\r\n"
    "\t## * 带「次元」→ 用后进**消耗区**（本场最多用一次）。这不是装饰：若进弃牌区，\r\n"
    "\t##   音符会被洗回牌库，形成「+2 费 + 抽 2 张」的无限循环。\r\n"
    "\tif side != SIDE_SELF:\r\n"
    "\t\tstate.opp_energy += NOTE_ENERGY\r\n"
    "\t\t_log(\"音符（敌方）：+%d 费\" % NOTE_ENERGY)\r\n"
    "\t\treturn \"获得 %d 点费用\" % NOTE_ENERGY\r\n"
    "\tstate.energy += NOTE_ENERGY\r\n"
    "\tvar n:= _draw_many(NOTE_DRAW)\r\n"
    "\t_log(\"音符：+%d 费，抽 %d 张\" % [NOTE_ENERGY, n])\r\n"
    "\treturn \"获得 %d 点费用，抽 %d 张卡\" % [NOTE_ENERGY, n]\r\n"
    "\r\n"
    "\r\n"
)
d = d[: m.end() - len("func ")] + FUNCS + tail

# ---------- ③ match 分支 ----------
BR_OLD = (
    "\t\tBARRAGE_ID:\r\n"
    "\t\t\treturn _barrage(side, card)\r\n"
)
BR_NEW = BR_OLD + (
    "\t\tENCORE_ID:\r\n"
    "\t\t\treturn _encore(side, card)\r\n"
    "\t\tNOTE_ID:\r\n"
    "\t\t\treturn _note(side)\r\n"
)
d = rep(BR_OLD, BR_NEW, "match")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "行尾被改成 LF 了"
print("game_engine.gd ok: CRLF %d" % b.count(b"\r\n"))
