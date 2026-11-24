# -*- coding: utf-8 -*-
"""R777 彩虹诗（9269）引擎落地 —— game_engine.gd 是 CRLF，锚点带 \\r\\n。

⚠️ 并行线（R776 激励乐章 9267 / 管风琴 9268）正在改同一个文件，所以本脚本的
锚点**全部避开**它的五处修改点（CALL_COST_GAP 常量行 / fetch_skill emit /
CALL_ID match 分支 / _gale_tick 序列 / _attack_gain_energy 行）：
  ① 常量区 → 锚定 R745 野性图腾那行（R776 不碰）
  ② 新函数 → 锚定 _roll_recruit_cards 定义行（R776 不碰）
  ③ match 分支 → 锚定招募分支（R776 插在 CALL_ID 之前，互不重叠）
这样两边谁先跑都不会把对方的锚点吃掉。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENG = os.path.join(ROOT, "scripts", "game_engine.gd")


def read(p):
    return io.open(p, "rb").read().decode("utf-8")


def write(p, s):
    io.open(p, "wb").write(s.encode("utf-8"))


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    return text.replace(old, new)


src = read(ENG)
assert src.count("\r\n") > 0 and "\n" not in src.replace("\r\n", ""), "game_engine.gd 不是纯 CRLF"
assert "RAINBOW_ID" not in src, "RAINBOW_ID 已存在，别重复插入"

# ── ① 常量 ────────────────────────────────────────────────────────────────
old = "const CALL_ENERGY:= 1     # 本局每回合费用 +1\r\n"
new = (
    "const CALL_ENERGY:= 1     # 本局每回合费用 +1\r\n"
    "# R777 彩虹诗（9269，吟游诗人 2 费稀有技能）：\r\n"
    "#   随机 **3 个不同**的其他职业，各摇一张「盟友或技能卡」加入手卡，\r\n"
    "#   这些卡**本局**（= 本场战斗内）费用各 -1。\r\n"
    "# ⚠️ 减费走 `state.hand_cost_delta`（手卡内减费唯一口径），**不是** `hand_free` ——\r\n"
    "#    后者是「归 0」，这里要的是「-N 且可叠」（同一天手里两张彩虹诗就是 -2）。\r\n"
    "const RAINBOW_ID:= 9269\r\n"
    "const RAINBOW_CLASSES:= 3   # 摇几个不同职业\r\n"
    "const RAINBOW_CUT:= 1       # 每张费用本局 -1\r\n"
)
src = sub(src, old, new, "常量区")

# ── ② 随机源函数（挂在 _roll_recruit_cards 之前，同族）─────────────────────
old = "func _roll_recruit_cards() -> Array:\r\n"
new = (
    "func _roll_rainbow_cards() -> Array:\r\n"
    "\t## R777 彩虹诗（9269）：**随机 3 个不同**的其他职业，各摇一张「盟友或技能卡」。\r\n"
    "\t## * 候选职业 = `PlayerClass.ids()` 去掉玩家当前职业 —— 隐藏职业（吟游诗人）\r\n"
    "\t##   天然不在 `ids()` 里，所以它那几张永远不会被非吟游诗人摇到（R761 的规矩）；\r\n"
    "\t## * 挑职业走 Fisher-Yates 前缀，随机源是引擎 `rng` → 同种子同结果、回放可复现；\r\n"
    "\t## * 每个职业的池子走 `reward_pool_for(cls)`（剧情锁 / 本局禁卡 / event_only 一并生效），\r\n"
    "\t##   再按 `card_class == cls` 精确定位本职业卡 —— 通用卡（class 留空）不算「其他职业」；\r\n"
    "\t## * 池空 → 退回该职业的全部卡（与招募 9264 / 森林的朋友们 9183 同一条退路）；\r\n"
    "\t##   再空就少给一张，不拿别职业的卡凑数（凑了就破坏「不同职业」这条保证）。\r\n"
    "\t## 返回**独立副本**：减费表以卡对象为键，绝不能拿卡库共享实例（R281 的教训）。\r\n"
    "\tvar repo := CardRepo.load_json()\r\n"
    "\tvar classes: Array[String] = []\r\n"
    "\tfor cls: String in PlayerClass.ids():\r\n"
    "\t\tif cls == RunState.player_class:\r\n"
    "\t\t\tcontinue\r\n"
    "\t\tclasses.append(cls)\r\n"
    "\tvar want := mini(RAINBOW_CLASSES, classes.size())\r\n"
    "\tfor i in want:\r\n"
    "\t\tvar j := i + int(rng.randi() % (classes.size() - i))\r\n"
    "\t\tvar tmp: String = classes[i]\r\n"
    "\t\tclasses[i] = classes[j]\r\n"
    "\t\tclasses[j] = tmp\r\n"
    "\tvar out: Array = []\r\n"
    "\tfor k in want:\r\n"
    "\t\tvar cls2: String = classes[k]\r\n"
    "\t\tvar pool: Array[CardData] = []\r\n"
    "\t\tfor c: CardData in repo.reward_pool_for(cls2):\r\n"
    "\t\t\tif c.card_class == cls2 and (c.kind == \"盟友\" or c.kind == \"技能\"):\r\n"
    "\t\t\t\tpool.append(c)\r\n"
    "\t\tif pool.is_empty():\r\n"
    "\t\t\tfor c2: CardData in repo.player_cards():\r\n"
    "\t\t\t\tif c2.card_class == cls2 and (c2.kind == \"盟友\" or c2.kind == \"技能\"):\r\n"
    "\t\t\t\t\tpool.append(c2)\r\n"
    "\t\tif pool.is_empty():\r\n"
    "\t\t\tcontinue\r\n"
    "\t\tout.append(_new_own_card(pool[rng.randi() % pool.size()]))\r\n"
    "\treturn out\r\n"
    "\r\n"
    "\r\n"
    "func _roll_recruit_cards() -> Array:\r\n"
)
src = sub(src, old, new, "_roll_rainbow_cards")

# ── ③ match 分支（插在招募分支之前，与 R776 的 CALL_ID 分支不重叠）────────
old = "\t\tRECRUIT_ID:\r\n"
new = (
    "\t\tRAINBOW_ID:\r\n"
    "\t\t\t# 彩虹诗（9269，R777，吟游诗人 2 费稀有技能）：\r\n"
    "\t\t\t#   随机 3 个不同其他职业，各摇一张「盟友或技能卡」入手，其费用本局 -1。\r\n"
    "\t\t\t# * 「本局 -1」= `state.hand_cost_delta`：表挂在 FieldState 上，一场战斗一个 →\r\n"
    "\t\t\t#   跨回合有效，换层 / 新战斗自然复位（与「呼唤」用 hand_free 只是口径不同）；\r\n"
    "\t\t\t# * 手牌满 → `_grant_to_hand` 通用口径（进弃牌区，不蒸发）：那张按原价躺在弃牌堆，\r\n"
    "\t\t\t#   `cost_of` 的 `hand.has()` 判据自然不生效，抽回手里才 -1 —— 不必特判；\r\n"
    "\t\t\t# * 摇不满 3 张（其他职业池被剧情锁 / 禁卡清空）→ 有几张给几张。\r\n"
    "\t\t\tvar rb_list := _roll_rainbow_cards()\r\n"
    "\t\t\tif rb_list.is_empty():\r\n"
    "\t\t\t\t_log(\"彩虹诗：卡池里摇不出其他职业的盟友或技能卡\")\r\n"
    "\t\t\t\treturn \"卡池里没有可借的卡，效果落空\"\r\n"
    "\t\t\tvar rb_names: Array[String] = []\r\n"
    "\t\t\tvar rb_landed := 0\r\n"
    "\t\t\tfor rb_c: CardData in rb_list:\r\n"
    "\t\t\t\tvar rb_got := _grant_to_hand(rb_c, \"彩虹诗\")\r\n"
    "\t\t\t\tstate.hand_cost_delta[rb_c] = int(state.hand_cost_delta.get(rb_c, 0)) + RAINBOW_CUT\r\n"
    "\t\t\t\trb_names.append(rb_c.card_name)\r\n"
    "\t\t\t\tif rb_got:\r\n"
    "\t\t\t\t\trb_landed += 1\r\n"
    "\t\t\t_log(\"彩虹诗：%d 张%s（%s），各费用本局 -%d\" % [\r\n"
    "\t\t\t\t\trb_landed, \"加入手卡\" if rb_landed == rb_list.size() else \"入手 / 弃牌区\",\r\n"
    "\t\t\t\t\t\"、\".join(rb_names), RAINBOW_CUT])\r\n"
    "\t\t\taction.emit(\"rainbow\", {\"cards\": rb_list, \"landed\": rb_landed,\r\n"
    "\t\t\t\t\t\"cut\": RAINBOW_CUT})\r\n"
    "\t\t\tif rb_landed == 0:\r\n"
    "\t\t\t\treturn \"手牌已满，%d 张改投弃牌区\" % rb_list.size()\r\n"
    "\t\t\treturn \"%d 张加入手卡，其费用本局 -%d\" % [rb_list.size(), RAINBOW_CUT]\r\n"
    "\t\tRECRUIT_ID:\r\n"
)
src = sub(src, old, new, "match 分支")

write(ENG, src)
print("[ok] game_engine.gd 已写入 9269")

# ── 写后复核：我的改动在，且没吃掉并行线的行 ──────────────────────────────
chk = read(ENG)
assert "RAINBOW_ID:= 9269" in chk and "func _roll_rainbow_cards()" in chk
assert chk.count("\t\tRAINBOW_ID:\r\n") == 1
assert "func _roll_recruit_cards() -> Array:" in chk
print("[ok] 复核通过（RAINBOW_ID / _roll_rainbow_cards / 招募分支均在）")
