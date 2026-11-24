# -*- coding: utf-8 -*-
"""R757 遥测：battle_scene.gd 三处接入（该文件是 CRLF，必须原样保留换行符）。

1) load_level 末尾：战斗开局快照（层号 / 双方血量 / 卡组张数 / 敌方单位 id）
2) _show_over 开头：胜 / 负两条路的总结算（回合数 / 结束血量 / 本场承受伤害）
3) _on_flee：逃跑也是一场战斗的结局 —— 不记会让「没打过」污染敌人胜率
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

# ---------------------------------------------------------------- 1) 开局快照
OLD1 = "\t_cur_level = lvl\n\t_refresh_flee_btn()   # R341 洞窟绳"
NEW1 = (
    "\t_cur_level = lvl\n"
    "\t# R757 遥测：**战斗开局快照**（发布版才写）。层号只有 run 里才有意义，\n"
    "\t# 单关演示给 0 —— 分析时按 layer 分层比较，演示局不会混进正式数据里。\n"
    "\tTelemetry.note_battle_start(lvl, p_hp, RunState.max_hp, deck.size(),\n"
    "\t\t\tRunState.current_layer if RunState.run_active else 0)\n"
    "\t_refresh_flee_btn()   # R341 洞窟绳"
)
s = rep(s, OLD1, NEW1, "battle_scene: 开局快照")

# ---------------------------------------------------------------- 2) 结算
OLD2 = "func _show_over(win: bool) -> void:\n"
NEW2 = (
    "func _show_over(win: bool) -> void:\n"
    "\t# R757 遥测：本场结算（发布版才写）。挂在这里而不是 `_record_defeat()`：\n"
    "\t# 胜 / 负两条路都会走到这个函数，且此刻 `engine.state` 还没被清。\n"
    "\t# `ehp0` 取 `max_hp_opponent`（关卡配置的敌方总血），`ehp1` 取当前值 ——\n"
    "\t# 两者之差就是「这一场打掉了多少」，比胜负更能区分难度。\n"
    "\tif engine != null:\n"
    "\t\tTelemetry.note_battle_end(win, {\n"
    "\t\t\t\"turns\": engine.turn_number,\n"
    "\t\t\t\"hp1\": maxi(0, engine.state.hp_self),\n"
    "\t\t\t\"ehp0\": engine.state.max_hp_opponent,\n"
    "\t\t\t\"ehp1\": engine.state.hp_opponent,\n"
    "\t\t\t\"dmg_in\": engine.state.self_hp_damage_taken,\n"
    "\t\t\t\"out\": \"win\" if win else \"lose\",\n"
    "\t\t})\n"
)
s = rep(s, OLD2, NEW2, "battle_scene: 结算事件")

# ---------------------------------------------------------------- 3) 逃跑
OLD3 = '\tRunState.complete_current()\n\tSceneFx.goto("res://scenes/map.tscn")'
NEW3 = (
    "\t# R757 遥测：逃跑同样是一场战斗的结局。不记的话，这场会从统计里彻底消失 ——\n"
    "\t# 「打不过就跑」的敌人会被算成「从没遇上」，胜率虚高。\n"
    "\tTelemetry.note_battle_end(false, {\n"
    "\t\t\"turns\": engine.turn_number,\n"
    "\t\t\"hp1\": maxi(0, engine.state.hp_self),\n"
    "\t\t\"ehp0\": engine.state.max_hp_opponent,\n"
    "\t\t\"ehp1\": engine.state.hp_opponent,\n"
    "\t\t\"dmg_in\": engine.state.self_hp_damage_taken,\n"
    "\t\t\"out\": \"flee\",\n"
    "\t})\n"
    '\tRunState.complete_current()\n\tSceneFx.goto("res://scenes/map.tscn")'
)
s = rep(s, OLD3, NEW3, "battle_scene: 逃跑事件")

save(P, s, crlf)
print("done. crlf=%s" % crlf)
