# -*- coding: utf-8 -*-
"""R773 呼唤（9266）引擎落地 —— game_engine.gd / field_state.gd 都是 CRLF，锚点带 \\r\\n。

五处：
  ① 常量区 CALL_ID / CALL_ENERGY / CALL_COST_GAP
  ② 字段 `_battle_energy_bonus`（本场战斗内每回合费用加成）
  ③ `max_energy()` 分母算上它（否则费用条显示 5/5、实际能用 6 点）
  ④ `_begin_turn` 发费时叠加它
  ⑤ `use_spell` 的 match 加 CALL_ID 分支 + `_random_call_ally()` 随机源
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENG = os.path.join(ROOT, "scripts", "game_engine.gd")
FS = os.path.join(ROOT, "scripts", "field_state.gd")


def read(p):
    return io.open(p, "rb").read().decode("utf-8")


def write(p, s):
    io.open(p, "wb").write(s.encode("utf-8"))


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    return text.replace(old, new)


src = read(ENG)
assert src.count("\r\n") > 0 and "\n" not in src.replace("\r\n", "")

# ── ① 常量 ────────────────────────────────────────────────────────────────
old = "const RECRUIT_ID:= 9264\r\n# R745 野性图腾"
new = (
    "const RECRUIT_ID:= 9264\r\n"
    "# R773 呼唤（9266，吟游诗人 0 费普通技能）：\r\n"
    "#   ① **本场战斗内每回合费用 +1**（记在 `_battle_energy_bonus`，打出几张叠几层）——\r\n"
    "#      不是「这一回合多出来的」（那样下回合重置就没了，与卡面「本局」不符）；\r\n"
    "#   ② 一张随机**其他职业盟友**加入手卡：卡面费用恰好比本卡高 1（本卡 0 费 → 1 费），\r\n"
    "#      且它**本场战斗内**费用为 0（复用 `state.hand_free`：判据是「此刻还在手牌里」，\r\n"
    "#      离手自动恢复原价，不必在那十来个离手口逐个清标记）。\r\n"
    "const CALL_ID:= 9266\r\n"
    "const CALL_ENERGY:= 1     # 本局每回合费用 +1\r\n"
    "const CALL_COST_GAP:= 1   # 找的盟友 = 本卡费用 +1\r\n"
    "# R745 野性图腾"
)
src = sub(src, old, new, "常量区")

# ── ② 字段 ────────────────────────────────────────────────────────────────
old = "var _recruit_cards: Array = []\r\n"
new = (
    "var _recruit_cards: Array = []\r\n"
    "## R773 呼唤（9266）：**本场战斗内每回合费用 +N**（打出几张叠几层）。\r\n"
    "## ⚠️ 与「应急电源 9170」那种 `state.energy +=` 不是一回事 —— 那是「这一回合多出来的」，\r\n"
    "##    回合结束重置就没了；卡面写的是「本局」，所以必须记在这里，由 `_begin_turn` 发费时\r\n"
    "##    叠加、`max_energy()` 算进分母。每个新 GameEngine = 一场新战斗 → 自然复位。\r\n"
    "var _battle_energy_bonus:= 0\r\n"
)
src = sub(src, old, new, "字段")

# ── ③ max_energy ──────────────────────────────────────────────────────────
old = "\treturn FieldState.ENERGY_PER_TURN + permanent_energy_bonus()\r\n"
new = (
    "\t# R773 呼唤：本场战斗内每回合 +N 也是「每回合都给」→ 必须进分母\r\n"
    "\t# （不进的话费用条显示 5/5，实际却能用 6 点）。\r\n"
    "\treturn FieldState.ENERGY_PER_TURN + permanent_energy_bonus() + _battle_energy_bonus\r\n"
)
src = sub(src, old, new, "max_energy")

# ── ④ _begin_turn 发费 ────────────────────────────────────────────────────
old = (
    "\t\t# R767：我方每回合费用统一走 RunState.energy_per_turn()\r\n"
    "\t\t# （每日修饰的「灵光 +1 / 滞涩 −1」就叠在它里面，标准局等于常量）\r\n"
    "\t\tstate.energy = RunState.energy_per_turn()\r\n"
)
new = (
    "\t\t# R767：我方每回合费用统一走 RunState.energy_per_turn()\r\n"
    "\t\t# （每日修饰的「灵光 +1 / 滞涩 −1」就叠在它里面，标准局等于常量）\r\n"
    "\t\t# R773 呼唤：本场战斗内攒下的 +N 在这里叠加 —— 与 `max_energy()` 同一口径，\r\n"
    "\t\t# 显示 = 判定 = 实发（卡面写的是「本局」，不能只加当回合）。\r\n"
    "\t\tstate.energy = RunState.energy_per_turn() + _battle_energy_bonus\r\n"
    "\t\tif _battle_energy_bonus > 0:\r\n"
    "\t\t\t_log(\"呼唤：本局每回合费用 +%d（本回合发费 %d）\" % [_battle_energy_bonus, state.energy])\r\n"
)
src = sub(src, old, new, "_begin_turn")

# ── ⑤ 随机源 + match 分支 ─────────────────────────────────────────────────
old = "func _roll_recruit_cards() -> Array:\r\n"
new = (
    "func _random_call_ally(base: CardData) -> CardData:\r\n"
    "\t## R773 呼唤（9266）：费用**恰好**比 `base` 高 `CALL_COST_GAP` 的随机**其他职业盟友**。\r\n"
    "\t## * 池子走 `reward_pool()`（默认已筛掉隐藏职业卡）→ 过 `_other_class_card()`，\r\n"
    "\t##   与猴爪 / 懊悔的「其他职业」判据同一个口（公用卡 class 留空，不算）；\r\n"
    "\t## * `base.cost` 读**卡面费用**，不是 `cost_of()` —— 减费 / 免费不该改变\r\n"
    "\t##   「比这张卡费用高 1」这条判据；\r\n"
    "\t## * 随机源走引擎 `rng` → 同种子同结果、回放可复现（与招募 / 森林的朋友们同口径）。\r\n"
    "\tvar want: int = base.cost + CALL_COST_GAP\r\n"
    "\tvar repo := CardRepo.load_json()\r\n"
    "\tvar pool: Array[CardData] = []\r\n"
    "\tfor c: CardData in repo.reward_pool():\r\n"
    "\t\tif c.kind == \"盟友\" and c.cost == want and _other_class_card(c):\r\n"
    "\t\t\tpool.append(c)\r\n"
    "\tif pool.is_empty():\r\n"
    "\t\treturn null\r\n"
    "\treturn pool[rng.randi() % pool.size()]\r\n"
    "\r\n"
    "\r\n"
    "func _roll_recruit_cards() -> Array:\r\n"
)
src = sub(src, old, new, "_random_call_ally")

old = "\t\tRECRUIT_ID:\r\n"
new = (
    "\t\tCALL_ID:\r\n"
    "\t\t\t# 呼唤（9266，R773，吟游诗人 0 费普通技能）：\r\n"
    "\t\t\t#   ① 本场战斗内每回合费用 +1（`_battle_energy_bonus` 累加，叠几张算几层）；\r\n"
    "\t\t\t#   ② 一张随机**其他职业盟友**进手卡：卡面费用恰好比本卡高 1，且它**本场**费用为 0。\r\n"
    "\t\t\t# * 加费这里**额外**给一份当回合的 `state.energy +=`：上限虽然涨了，但本回合的费用\r\n"
    "\t\t\t#   早在 `_begin_turn` 就发完了 —— 不给的话玩家打出这张 0 费卡反而「什么也没多出来」。\r\n"
    "\t\t\t# * 归零走 `state.hand_free`（判据带 `state.hand.has(card)`）→ 离手自动恢复原价。\r\n"
    "\t\t\t# * 手牌满 → `_grant_to_hand` 通用口径（进弃牌区，不蒸发）；那张没进手，\r\n"
    "\t\t\t#   `hand_free` 也无处生效，不必特判。\r\n"
    "\t\t\t_battle_energy_bonus += CALL_ENERGY\r\n"
    "\t\t\tstate.energy += CALL_ENERGY\r\n"
    "\t\t\tvar cl_c := _random_call_ally(card)\r\n"
    "\t\t\tif cl_c == null:\r\n"
    "\t\t\t\t_log(\"呼唤：卡池里没有费用 %d 的其他职业盟友\" % (card.cost + CALL_COST_GAP))\r\n"
    "\t\t\t\treturn \"费用 +%d；卡池里没有可呼唤的盟友\" % CALL_ENERGY\r\n"
    "\t\t\tvar cl_copy := _new_own_card(cl_c)\r\n"
    "\t\t\tcl_copy.affixes = (cl_c.affixes as Array).duplicate()\r\n"
    "\t\t\tvar cl_got := _grant_to_hand(cl_copy, \"呼唤\")\r\n"
    "\t\t\tif cl_got:\r\n"
    "\t\t\t\tstate.hand_free[cl_copy] = true\r\n"
    "\t\t\t_log(\"呼唤：费用 +%d（本局每回合累计 +%d）；%s「%s」（%d 费 → 本局 0 费）\" % [\r\n"
    "\t\t\t\t\tCALL_ENERGY, _battle_energy_bonus,\r\n"
    "\t\t\t\t\t\"手卡加入\" if cl_got else \"手牌已满 → 进弃牌区\",\r\n"
    "\t\t\t\t\tcl_copy.card_name, cl_c.cost])\r\n"
    "\t\t\taction.emit(\"call\", {\"card\": cl_copy, \"to_hand\": cl_got,\r\n"
    "\t\t\t\t\t\"energy\": _battle_energy_bonus})\r\n"
    "\t\t\tif not cl_got:\r\n"
    "\t\t\t\treturn \"费用 +%d；手牌已满，「%s」进弃牌区\" % [CALL_ENERGY, cl_copy.card_name]\r\n"
    "\t\t\treturn \"费用 +%d；「%s」加入手卡，其费用本局为 0\" % [CALL_ENERGY, cl_copy.card_name]\r\n"
    "\t\tRECRUIT_ID:\r\n"
)
src = sub(src, old, new, "match 分支")

write(ENG, src)
print("[ok] game_engine.gd 已写入")

# ── field_state.gd：hand_free 的第二位用户 ────────────────────────────────
fs = read(FS)
old = "## CardData -> true：**在手牌里期间**费用为 0（无限装甲 8038 供能的改造牌）。"
new = (
    "## CardData -> true：**在手牌里期间**费用为 0。\r\n"
    "## 现有用户：无限装甲 8038 供能的改造牌、R773 呼唤 9266「那张盟友本局费用为 0」。"
)
fs = sub(fs, old, new, "hand_free 注释")
write(FS, fs)
print("[ok] field_state.gd 已写入")
