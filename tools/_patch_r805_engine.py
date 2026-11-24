# -*- coding: utf-8 -*-
"""R805：game_engine.gd 加「诅咒娃娃」9276 的两条机制。保持 CRLF。

① 回合结束：它还在手牌 → 你受 3 点伤害（走 `_damage_player()` 唯一口）
② 回合开始：它若在弃牌区 → 从弃牌区回到手牌（`_grant_to_hand()` 唯一口，手牌满就留在弃牌区）
"""
import io

P = "E:/work/card_rogue/scripts/game_engine.gd"
d = open(P, "rb").read().decode("utf-8")
crlf0 = d.count("\r\n")
assert "\r\n" in d and d.count("\n") == crlf0, "文件不是纯 CRLF"


def rep(old, new, cnt=1):
    global d
    old_c = old.replace("\n", "\r\n")
    new_c = new.replace("\n", "\r\n")
    assert d.count(old_c) == cnt, "锚点命中 %d 次（应 %d）：%r" % (d.count(old_c), cnt, old[:70])
    d = d.replace(old_c, new_c)


# ① 常量
rep(
    "const PARALYSIS_CARD_ID:= 9185\n",
    "const PARALYSIS_CARD_ID:= 9185\n"
    "# R805 诅咒「诅咒娃娃」（9276）：事件「诡异洋房 · 探索」的代价。\n"
    "#   带「保存」→ 回合结束不弃、常驻手牌；每回合结束**你受 3 点伤害**；\n"
    "#   回合开始时它若在弃牌区 → 自己爬回手牌（丢出去也甩不掉）。\n"
    "const CURSE_DOLL_ID:= 9276\n"
    "const CURSE_DOLL_DMG:= 3\n"
)

# ② 两个函数，插在 _paralysis_tick 之前
rep(
    "func _paralysis_tick() -> void :\n",
    'func _curse_doll_tick() -> void :\n'
    "\t## R805 诅咒娃娃（9276）：「回合结束时，你受到 3 点伤害」。\n"
    "\t## 判据只有一个 —— **它此刻在手牌里**（带「保存」所以通常一直在）。同名多张各算一次。\n"
    "\t## 走 `_damage_player()` 唯一口：lucky7 免疫 / 鸭嘴减伤 / 不锈钢盆 / 死亡判定\n"
    "\t## 全部照旧生效，所以在它上面再叠一层减伤只会让道具白拿。\n"
    "\t## ⚠️ 必须排在 `discard_hand()` 之前：手牌先被弃掉这张就永远不在手上，效果白挂。\n"
    "\tif over:\n"
    "\t\treturn\n"
    "\tvar count := 0\n"
    "\tfor c: CardData in state.hand:\n"
    "\t\tif c != null and c.id == CURSE_DOLL_ID:\n"
    "\t\t\tcount += 1\n"
    "\tif count == 0:\n"
    "\t\treturn\n"
    "\tvar dmg := CURSE_DOLL_DMG * count\n"
    "\t_damage_player(SIDE_SELF, dmg, \"诅咒娃娃\")\n"
    "\t_log(\"诅咒娃娃：回合结束，你受到 %d 点伤害（剩余 %d）\" % [dmg, state.hp_self])\n"
    "\taction.emit(\"curse_doll\", {\"count\": count, \"dmg\": dmg, \"hp\": state.hp_self})\n"
    "\n"
    "\n"
    "func _curse_doll_return() -> void :\n"
    "\t## R805 诅咒娃娃（9276）：「回合开始时，若这张卡在弃牌区，从弃牌区加入你的手牌」。\n"
    "\t## 这一条才是它甩不掉的原因 —— 玩家把它丢进弃牌区只能躲开**那一次**扣血，\n"
    "\t## 下个我方回合开始它自己就爬回来了。\n"
    "\t## 进手走 `_grant_to_hand()` 唯一口：手牌满时它会**被放回弃牌区**（不消失），\n"
    "\t## 下个回合继续尝试 —— 别在这里自己 append 到 hand，那会突破 HAND_LIMIT。\n"
    "\t## ⚠️ 就地 `remove_at` 摘牌，不整体重建 discard 数组：别的模块可能持有它的引用。\n"
    "\tvar back := 0\n"
    "\tvar i := state.discard.size() - 1\n"
    "\twhile i >= 0:\n"
    "\t\tvar c: CardData = state.discard[i]\n"
    "\t\tif c != null and c.id == CURSE_DOLL_ID:\n"
    "\t\t\tstate.discard.remove_at(i)\n"
    "\t\t\tif _grant_to_hand(c, \"诅咒娃娃\"):\n"
    "\t\t\t\tback += 1\n"
    "\t\ti -= 1\n"
    "\tif back > 0:\n"
    "\t\t_log(\"诅咒娃娃：回合开始，从弃牌区回到手牌（%d 张）\" % back)\n"
    "\n"
    "\n"
    "func _paralysis_tick() -> void :\n"
)

# ③ end_turn 里的调用（罐子 / 麻痹旁边，同一位置纪律）
rep(
    "\t\t_jar_tick()\n"
    "\t\t_paralysis_tick()   # R373 麻痹：回合结束仍在手卡 → 消失（排在弃手牌之前）\n",
    "\t\t_jar_tick()\n"
    "\t\t_paralysis_tick()   # R373 麻痹：回合结束仍在手卡 → 消失（排在弃手牌之前）\n"
    "\t\t_curse_doll_tick()  # R805 诅咒娃娃：回合结束仍在手卡 → 你受 3 伤（同样排弃手牌之前）\n"
)

# ④ _begin_turn 里的调用（我方回合开始，排在鸭蛋孵化之前 —— 那时手牌还没动）
rep(
    "\t\t# R692（店长口径「鸭蛋改为（我方）回合开始时若存活」）：孵化从**回合结束**搬到\n"
    "\t\t# **我方回合开始**。排在 `state.reset_units()` 之前 → 刚孵出的宠物鸭这一回合就能行动。\n"
    "\t\t_egg_hatch_tick()\n",
    "\t\t_curse_doll_return()    # R805 诅咒娃娃：回合开始若在弃牌区 → 回手（先于抽牌）\n"
    "\t\t# R692（店长口径「鸭蛋改为（我方）回合开始时若存活」）：孵化从**回合结束**搬到\n"
    "\t\t# **我方回合开始**。排在 `state.reset_units()` 之前 → 刚孵出的宠物鸭这一回合就能行动。\n"
    "\t\t_egg_hatch_tick()\n"
)

crlf1 = d.count("\r\n")
io.open(P, "wb").write(d.encode("utf-8"))
print("ok crlf %d -> %d (+%d)" % (crlf0, crlf1, crlf1 - crlf0))
