# -*- coding: utf-8 -*-
"""R757 遥测 第三轮：局结束时**当场**交出 run_end（不等结算页点「确定」）。

为什么：`RunState.end_run()` 只在玩家点结算页「确定」时才跑。而失败 / 通关之后
直接关窗口是很常见的操作 —— 那样这一局在事件流里就只剩半截（有 run_start、
没有 run_end），「死在哪一层」这个最有价值的问题直接失效。
`mark_run_won()` / `mark_run_lost()` 是「这局已经定了」的唯一落章处，就在这里交。
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

OLD1 = "\t\t\t\tRunState.mark_run_won()\n"
NEW1 = (
    "\t\t\t\tRunState.mark_run_won()\n"
    "\t\t\t\t# R757 遥测：这一局到这里已经定了 —— **不等结算页点「确定」**。\n"
    "\t\t\t\t# 玩家很可能直接关窗口，那样这局在统计里就整条消失（只剩半截 run_start）。\n"
    "\t\t\t\tTelemetry.end_run(true, {\"cls\": RunState.player_class,\n"
    "\t\t\t\t\t\t\"diff\": RunState.difficulty})\n"
)
s = rep(s, OLD1, NEW1, "battle: 通关 run_end")

OLD2 = "\t\t\tRunState.mark_run_lost()\n"
NEW2 = (
    "\t\t\tRunState.mark_run_lost()\n"
    "\t\t\t# R757 遥测：失败同理 —— 这是「死在哪一层 / 哪一关」的唯一记录点。\n"
    "\t\t\tTelemetry.end_run(false, {\"cls\": RunState.player_class,\n"
    "\t\t\t\t\t\"diff\": RunState.difficulty})\n"
)
s = rep(s, OLD2, NEW2, "battle: 失败 run_end")

save(P, s, crlf)
print("done. crlf=%s" % crlf)
