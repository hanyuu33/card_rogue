# -*- coding: utf-8 -*-
"""R757 遥测 第二轮 battle_scene 接入（CRLF）。

1) 战斗奖励入队时把「这场是什么战斗」传下去 —— 第一轮里 `src` 全落成 demo，
   因为结算时 `pending_node` 已经空了。
2) 去掉 `ehp0` / `ehp1`：敌方总血在两个字段在胜/负时都等于满值（单位血是各自独立的），
   拿它算「打掉了多少」会一直显示 0 损伤。我方承伤 `dmg_in` 才是可信的那个。
"""
import io

P = "scripts/battle_scene.gd"


def load(p):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    return (s.replace("\r\n", "\n") if crlf else s), crlf


def save(p, s, crlf):
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag, times=1):
    n = s.count(old)
    assert n == times, "%s: count=%d（期望 %d）" % (tag, n, times)
    print("  ok  %s" % tag)
    return s.replace(old, new)


s, crlf = load(P)

OLD1 = "RunState.queue_battle_card_rewards(RunState.reward_type)"
NEW1 = ("RunState.queue_battle_card_rewards(RunState.reward_type, engine.battle_kind)")
s = rep(s, OLD1, NEW1, "battle: 奖励来源")

OLD2 = (
    "\t\t\t\"ehp0\": engine.state.max_hp_opponent,\n"
    "\t\t\t\"ehp1\": engine.state.hp_opponent,\n"
    "\t\t\t\"dmg_in\": engine.state.self_hp_damage_taken,\n"
    "\t\t\t\"out\": \"win\" if win else \"lose\",\n"
)
NEW2 = (
    "\t\t\t\"dmg_in\": engine.state.self_hp_damage_taken,\n"
    "\t\t\t\"out\": \"win\" if win else \"lose\",\n"
)
s = rep(s, OLD2, NEW2, "battle: 结算去掉 ehp")

OLD3 = (
    "\t\t\"ehp0\": engine.state.max_hp_opponent,\n"
    "\t\t\"ehp1\": engine.state.hp_opponent,\n"
    "\t\t\"dmg_in\": engine.state.self_hp_damage_taken,\n"
    "\t\t\"out\": \"flee\",\n"
)
NEW3 = (
    "\t\t\"dmg_in\": engine.state.self_hp_damage_taken,\n"
    "\t\t\"out\": \"flee\",\n"
)
s = rep(s, OLD3, NEW3, "battle: 逃跑去掉 ehp")

save(P, s, crlf)
print("done. crlf=%s" % crlf)
