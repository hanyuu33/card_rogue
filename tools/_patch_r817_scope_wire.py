# -*- coding: utf-8 -*-
"""R817：把 DemoScope 基线接到道具 / 工具 / 事件三条链上。

口径（店长 2026-11-19）：**修复跟着走、新增不跟着走**。
每条链只加一处过滤，非试玩版全部 `return ids` / `continue` 前就短路（零行为变化）。
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(rel):
    return io.open(os.path.join(ROOT, rel), encoding="utf-8", newline="").read()


def save(rel, txt):
    io.open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="").write(txt)


def rep(txt, old, new, tag):
    n = txt.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次（应为 1）：%r" % (tag, n, old[:80])
    return txt.replace(old, new)


# ── ① 道具 ─────────────────────────────────────────────────────────────────
rel = "scripts/relic_repo.gd"
t = load(rel)
assert "_demo_ids" not in t, "relic_repo 已打过补丁"

t = rep(t,
        'func all_relics() -> Array[RelicData]:\n'
        '\tvar out: Array[RelicData] = []\n'
        '\tfor id: int in _relics.keys():\n'
        '\t\tout.append(_relics[id])\n',
        'func all_relics() -> Array[RelicData]:\n'
        '\tvar out: Array[RelicData] = []\n'
        '\tfor id: int in _relics.keys():\n'
        '\t\t# R817：试玩版只列基线内的道具（图鉴 / 商店陈列 / 事件取货都读这里）\n'
        '\t\tif GameBuild.is_demo() and not DemoScope.allows_relic(id):\n'
        '\t\t\tcontinue\n'
        '\t\tout.append(_relics[id])\n',
        "all_relics")

t = rep(t,
        '\treturn [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068]\n',
        '\tvar out: Array[int] = [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068]\n'
        '\treturn _demo_ids(out)\n',
        "initial_ids")

t = rep(t,
        '\t\t6081, 6082, 6083, 6084]\n'
        '\treturn _filter_by_tier(_drop_locked(ids), tier)\n',
        '\t\t6081, 6082, 6083, 6084]\n'
        '\treturn _demo_ids(_filter_by_tier(_drop_locked(ids), tier))\n',
        "reward_ids")

t = rep(t,
        '\treturn [6010, 6012, 6019, 6027]\n',
        '\tvar out: Array[int] = [6010, 6012, 6019, 6027]\n'
        '\treturn _demo_ids(out)\n',
        "event_ids")

t = rep(t,
        '\treturn [6014, 6015, 6016, 6017, 6018, 6033, 6049, 6010, 6067]\n',
        '\tvar out: Array[int] = [6014, 6015, 6016, 6017, 6018, 6033, 6049, 6010, 6067]\n'
        '\treturn _demo_ids(out)\n',
        "layer2_ids")

t = rep(t,
        '\treturn [6022, 6023, 6025]\n',
        '\tvar out: Array[int] = [6022, 6023, 6025]\n'
        '\treturn _demo_ids(out)\n',
        "class_ids")

t = rep(t,
        'func _drop_locked(ids: Array[int]) -> Array[int]:\n',
        'func _demo_ids(ids: Array[int]) -> Array[int]:\n'
        '\t## R817：试玩版的内容基线过滤（道具侧的**唯一口**，与卡池的\n'
        '\t## `CardRepo.demo_allows()` 同一张表）。口径 =「修复跟着走、新增不跟着走」：\n'
        '\t## 老道具改效果 / 修 bug 用的是同一个 id，自动同步到试玩；新道具 id 不在\n'
        '\t## `demo_scope.json` 里，默认不进试玩。非试玩版原样返回（零行为变化）。\n'
        '\tif not GameBuild.is_demo():\n'
        '\t\treturn ids\n'
        '\tvar out: Array[int] = []\n'
        '\tfor id: int in ids:\n'
        '\t\tif DemoScope.allows_relic(id):\n'
        '\t\t\tout.append(id)\n'
        '\treturn out\n'
        '\n'
        '\n'
        'func _drop_locked(ids: Array[int]) -> Array[int]:\n',
        "_demo_ids")

save(rel, t)
print("relic_repo.gd: 6 处池出口已接基线")

# ── ② 工具 ─────────────────────────────────────────────────────────────────
rel = "scripts/trap_repo.gd"
t = load(rel)
assert "DemoScope" not in t, "trap_repo 已打过补丁"

t = rep(t,
        'func all_traps() -> Array[TrapData]:\n'
        '\tvar out: Array[TrapData] = []\n'
        '\tfor id: int in _traps.keys():\n'
        '\t\tout.append(_traps[id])\n',
        'func all_traps() -> Array[TrapData]:\n'
        '\tvar out: Array[TrapData] = []\n'
        '\tfor id: int in _traps.keys():\n'
        '\t\t# R817：试玩版只列基线内的工具 —— `random_traps()` / `shop_traps()`\n'
        '\t\t# 都基于本函数，所以「新工具默认不进试玩」一处收口就够。\n'
        '\t\tif GameBuild.is_demo() and not DemoScope.allows_trap(id):\n'
        '\t\t\tcontinue\n'
        '\t\tout.append(_traps[id])\n',
        "all_traps")

save(rel, t)
print("trap_repo.gd: all_traps 已接基线")

# ── ③ 事件 ─────────────────────────────────────────────────────────────────
rel = "scripts/game_layers.gd"
t = load(rel)
assert "DemoScope" not in t, "game_layers 已打过补丁"

t = rep(t,
        '\t\tvar ev: Dictionary = cfg["events"]\n'
        '\t\tfor k in ev:\n'
        '\t\t\tout[k] = int(out.get(k, 0)) + int(ev[k])\n',
        '\t\tvar ev: Dictionary = cfg["events"]\n'
        '\t\tfor k in ev:\n'
        '\t\t\t# R817：试玩版只出基线内的事件（新事件默认不进试玩）。\n'
        '\t\t\t# `event_kinds()` / `has_events()` / 地图生成全读本函数，一处收口。\n'
        '\t\t\tif GameBuild.is_demo() and not DemoScope.allows_event(str(k)):\n'
        '\t\t\t\tcontinue\n'
        '\t\t\tout[k] = int(out.get(k, 0)) + int(ev[k])\n',
        "event_weights")

save(rel, t)
print("game_layers.gd: event_weights 已接基线")
print("OK")
