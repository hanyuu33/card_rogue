# -*- coding: utf-8 -*-
"""R574 补丁：飞行器「巧克力不足 → 遇不到事件」而不是「遇到不能用」。

二进制 exact-replace + count==1 断言；test_engine.gd 是 CRLF，插入行显式转 \r\n。
可重跑：全部替换按锚点定位，跑完用 --check-only --script 验语法。
"""
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")


def patch(path: str, pairs, crlf: bool = False) -> None:
    p = ROOT / path
    b = p.read_bytes()
    for old, new in pairs:
        o = old.encode("utf-8")
        n = new.encode("utf-8")
        if crlf:
            o = o.replace(b"\n", b"\r\n")
            n = n.replace(b"\n", b"\r\n")
        assert b.count(o) == 1, "%s count=%d anchor=%r" % (path, b.count(o), o[:90])
        b = b.replace(o, n, 1)
    p.write_bytes(b)
    print("OK %-34s %d bytes" % (path, len(b)))


# ---------------------------------------------------------------- GameLayers
patch("scripts/game_layers.gd", [
    (
        '\t\t\t# R555 飞行器（第二层专属）：使用飞行器 → 在地图上任选一格没走过的房间传送过去\n'
        '\t\t\t# （消耗 1 巧克力；巧克力不足 2 时飞不起来）/ 不移动。\n'
        '\t\t\t"flyer": 16,\n',
        '\t\t\t# R555 飞行器（第二层专属）：使用飞行器 → 在地图上任选一格没走过的房间传送过去\n'
        '\t\t\t# （消耗 1 巧克力）/ 不移动。R574：巧克力不足 2 块时**根本不会遇到**这个事件，\n'
        '\t\t\t# 过滤在进房统一入口 `RunState.resolve_event_kind()`，判据见 FLYER_MIN_CHOCOLATE。\n'
        '\t\t\t"flyer": 16,\n',
    ),
    (
        'static func event_name(kind: String) -> String:\n'
        '\treturn str(EVENT_NAMES.get(kind, kind))\n'
        '\n'
        '\n'
        'static func roll_event_kind(layer: int, rng: RandomNumberGenerator,\n'
        '\t\tused: Dictionary = {}) -> String:\n',
        'static func event_name(kind: String) -> String:\n'
        '\treturn str(EVENT_NAMES.get(kind, kind))\n'
        '\n'
        '\n'
        '## R574（用户口径）：巧克力不足时**根本遇不到飞行器事件**，不是遇到了再把按钮置灰。\n'
        '## 2 块的来历：飞一次扣 1，扣完至少还得剩 1，才不会把自己送进「巧克力耗尽 → 入夜」。\n'
        'const FLYER_MIN_CHOCOLATE := 2\n'
        '\n'
        '\n'
        'static func event_kind_available(kind: String, chocolate: int) -> bool:\n'
        '\t## 该事件子类型在「当前巧克力」下能不能被遇到 —— 唯一判据口，\n'
        '\t## 进房过滤（`RunState.resolve_event_kind`）与抽取过滤（`roll_event_kind`）共用。\n'
        '\t## 目前只有飞行器有条件；别在 UI 里另写一份 `chocolate < 2`。\n'
        '\tif kind == "flyer":\n'
        '\t\treturn chocolate >= FLYER_MIN_CHOCOLATE\n'
        '\treturn true\n'
        '\n'
        '\n'
        'static func roll_event_kind(layer: int, rng: RandomNumberGenerator,\n'
        '\t\tused: Dictionary = {}, chocolate: int = -1) -> String:\n',
    ),
    (
        '\t## 不传 `used`（默认空表）= 纯按权重抽、允许重复（测试 / 工具用）。\n',
        '\t## 不传 `used`（默认空表）= 纯按权重抽、允许重复（测试 / 工具用）。\n'
        '\t## R574：`chocolate >= 0` 时按 `event_kind_available()` 过滤候选（飞行器不足 2 块不参与抽）；\n'
        '\t## 传 -1（默认）= 不按巧克力过滤，保持测试 / 工具原有行为。\n',
    ),
    (
        '\t# 本轮候选 = 池子里权重 > 0 且还没被 used 占掉的\n'
        '\tvar cand := {}\n'
        '\tfor k in w:\n'
        '\t\tif int(w[k]) > 0:\n'
        '\t\t\tcand[k] = int(w[k])\n',
        '\t# 本轮候选 = 池子里权重 > 0、按当前巧克力可用、且还没被 used 占掉的\n'
        '\tvar cand := {}\n'
        '\tfor k in w:\n'
        '\t\tif int(w[k]) > 0 and (chocolate < 0 or event_kind_available(str(k), chocolate)):\n'
        '\t\t\tcand[k] = int(w[k])\n',
    ),
])

# ------------------------------------------------------------------ RunState
patch("scripts/run_state.gd", [
    (
        'static func flyer_candidates() -> Array:\n'
        '\t## R555 飞行器（第二层事件）：能飞到的格子 = 全图「没走过」的格子。\n',
        'static func resolve_event_kind(cell: Dictionary) -> Dictionary:\n'
        '\t## R574（用户口径）：巧克力不足时**遇不到飞行器事件**，而不是遇到一个不能用的事件。\n'
        '\t## ⚠️ 时机：事件 kind 是地图生成时写进格子的（那时巧克力是满的），巧克力却一路走一路扣，\n'
        '\t##    所以过滤只能挂在**进房这一刻** —— 唯一调用点 `map_scene._dispatch_node()`。\n'
        '\t## 命中时：把这一格重摇成另一个当下可用的事件（与生成期同一本 `event_kinds_used` 账）；\n'
        '\t## 池子抽空则按 R374 老口径降级成一般战斗（「?」房本来就看不见内容）。\n'
        '\t## ⚠️ 不消耗 `run_rng`：用分类种子派生，回放确定性与别的分类解耦（R312 口径）。\n'
        '\tif str(cell.get("type", "")) != "event":\n'
        '\t\treturn cell\n'
        '\tif str(cell.get("event_kind", "")) != "flyer":\n'
        '\t\treturn cell\n'
        '\tif chocolate >= GameLayers.FLYER_MIN_CHOCOLATE:\n'
        '\t\treturn cell\n'
        '\tvar out := cell.duplicate()   # 别污染 map_cells 里那份（与 delivery_override 同口径）\n'
        '\tvar layer := int(cell.get("layer", current_layer))\n'
        '\tvar rng := RandomNumberGenerator.new()\n'
        '\trng.seed = seed_of("event_alt", int(cell.get("id", 0)) + layer * 1000)\n'
        '\t# 飞行器这一格没真被遇到 → 账本里摘掉，让替代事件占它的位置\n'
        '\tevent_kinds_used.erase("flyer")\n'
        '\tvar alt := GameLayers.roll_event_kind(layer, rng, event_kinds_used, chocolate)\n'
        '\tif alt == "":\n'
        '\t\tout["type"] = "battle"\n'
        '\t\tout["event_kind"] = ""\n'
        '\telse:\n'
        '\t\tout["event_kind"] = alt\n'
        '\treturn out\n'
        '\n'
        '\n'
        'static func flyer_candidates() -> Array:\n'
        '\t## R555 飞行器（第二层事件）：能飞到的格子 = 全图「没走过」的格子。\n',
    ),
    (
        '\t##   不能靠飞行器把自己飞到「巧克力耗尽 → 入夜」的死局（选项页已置灰，这里兜底）。\n',
        '\t##   不能靠飞行器把自己飞到「巧克力耗尽 → 入夜」的死局。R574：入口已按巧克力过滤，\n'
        '\t##   事件页也不再置灰，这里只保留最后一道防死局的兜底。\n',
    ),
])

# ----------------------------------------------------------------- map_scene
patch("scripts/map_scene.gd", [
    (
        '\t##    这里只管设置 pending_node 并跳场景 / 弹奖励。\n'
        '\t# R200：持有货物 → 第二层第一个事件房替换成「委托完成」（一次性）。\n',
        '\t##    这里只管设置 pending_node 并跳场景 / 弹奖励。\n'
        '\t# R574：巧克力不足时飞行器事件在**进房前**就被替换掉（遇不到，不是遇到不能用）。\n'
        '\t# ⚠️ 必须排在所有事件改写之前：delivery 覆盖也走这一份 cell。\n'
        '\tcell = RunState.resolve_event_kind(cell)\n'
        '\t# R200：持有货物 → 第二层第一个事件房替换成「委托完成」（一次性）。\n',
    ),
])

# ---------------------------------------------------------------- event_scene
patch("scripts/event_scene.gd", [
    (
        '# R555 飞行器（第二层专属）：两个选项 —— 使用飞行器（回地图选一格没去过的房间传过去，\n'
        '# 消耗 1 巧克力）/ 不移动。巧克力不足 2 块时飞不起来（扣掉这格后至少还得剩 1）。\n'
        'const FLYER_DESC := """空地中央立着一架旧喷气背包，两只喷口还留着一点余温。\n'
        '背上它，你能直接飞到任何一个还没去过的房间——\n'
        '代价是 1 块巧克力；巧克力只剩 1 块或没有的时候，它飞不起来。"""\n',
        '# R555 飞行器（第二层专属）：两个选项 —— 使用飞行器（回地图选一格没去过的房间传过去，\n'
        '# 消耗 1 巧克力）/ 不移动。R574（用户口径）：巧克力不足 2 块时**遇不到**这个事件\n'
        '# （过滤在进房入口 `RunState.resolve_event_kind`），所以这里不再有「禁用」按钮。\n'
        'const FLYER_DESC := """空地中央立着一架旧喷气背包，两只喷口还留着一点余温。\n'
        '背上它，你能直接飞到任何一个还没去过的房间——\n'
        '代价是 1 块巧克力。"""\n'
        '\n'
        '# 只服务旧存档 / `--flyer` 演示：正常流程进不来，也不摆一个灰掉的按钮。\n'
        'const FLYER_NO_FUEL_DESC := """喷口凉着，背包沉沉地立在那里，像是早就算准了你今天带的巧克力不够。\n'
        '你拍了拍它，转身继续赶路。"""\n',
    ),
    (
        '\t## / 不移动。巧克力不足 2 块时飞不起来。\n',
        '\t## / 不移动。R574：巧克力不足 2 块时进房前就被替换掉，这里遇不到。\n',
    ),
    (
        '\t\telse:\n'
        '\t\t\trest_btn.visible = true\n'
        '\t\t\trest_btn.text = ("使用飞行器（飞到一个没去过的房间，消耗 1 块巧克力）"\n'
        '\t\t\t\t\tif RunState.chocolate >= 2\n'
        '\t\t\t\t\telse "巧克力不足，飞不起来（至少需要 2 块）")\n'
        '\t\t\trest_btn.disabled = RunState.chocolate < 2\n'
        '\t\t\tbbq_btn.visible = false\n',
        '\t\telif not GameLayers.event_kind_available("flyer", RunState.chocolate):\n'
        '\t\t\t# R574：旧存档 / 演示参数才可能走到这儿 —— 不摆灰按钮，直接给一个收尾页。\n'
        '\t\t\tdesc.text = FLYER_NO_FUEL_DESC\n'
        '\t\t\t_fly_done = true\n'
        '\t\t\t_collapse_to_leave()\n'
        '\t\t\tresult_label.text = "巧克力不够，飞行器没能起飞。你没有在这里停留。"\n'
        '\t\t\tresult_label.add_theme_color_override("font_color", Color("8fc0d8"))\n'
        '\t\telse:\n'
        '\t\t\trest_btn.visible = true\n'
        '\t\t\trest_btn.text = "使用飞行器（飞到一个没去过的房间，消耗 1 块巧克力）"\n'
        '\t\t\trest_btn.disabled = false\n'
        '\t\t\tbbq_btn.visible = false\n',
    ),
    (
        '\t\t# 巧克力不足（chocolate < 2）时按钮已经置灰，这里再兜底一次。\n'
        '\t\tif RunState.chocolate < 2:\n'
        '\t\t\treturn\n',
        '\t\t# R574：进房入口已过滤，事件页也不再置灰；这里只留一道防死局的兜底。\n'
        '\t\tif not GameLayers.event_kind_available("flyer", RunState.chocolate):\n'
        '\t\t\treturn\n',
    ),
])

# --------------------------------------------------------------- test_engine (CRLF)
patch("scripts/test_engine.gd", [
    (
        '\t# 巧克力不足（< 2）飞不过去 —— 候选仍在，但传送被拦\n',
        '\t# R574：入口已按巧克力过滤，这里只验引擎侧最后一道防死局兜底\n'
        '\t# 巧克力不足（< 2）飞不过去 —— 候选仍在，但传送被拦\n',
    ),
    (
        '\t# 还原\n'
        '\tRunState.map_cells = r555_sv_cells\n',
        '\t# ==== R574：巧克力不足时**遇不到**飞行器（入口过滤，不是遇到不能用）====\n'
        '\t# ① 数据层判据：唯一口在 GameLayers，别在 UI 里另写一份 chocolate < 2\n'
        '\tcheck(GameLayers.FLYER_MIN_CHOCOLATE == 2,\n'
        '\t\t\t"R574：飞行器最低巧克力 = 2（扣 1 后至少剩 1）")\n'
        '\tcheck(not GameLayers.event_kind_available("flyer", 1)\n'
        '\t\t\tand not GameLayers.event_kind_available("flyer", 0)\n'
        '\t\t\tand GameLayers.event_kind_available("flyer", 2),\n'
        '\t\t\t"R574：event_kind_available 只在巧克力 >= 2 时放行飞行器")\n'
        '\tcheck(GameLayers.event_kind_available("pear", 0)\n'
        '\t\t\tand GameLayers.event_kind_available("hero", 1),\n'
        '\t\t\t"R574：其它事件不受巧克力约束")\n'
        '\t# ② 抽取过滤：chocolate >= 0 时飞行器不入候选；-1 保持旧行为（测试 / 工具）\n'
        '\tvar r574_rng := RandomNumberGenerator.new()\n'
        '\tr574_rng.seed = 574001\n'
        '\tvar r574_seen_low := false\n'
        '\tfor r574_i in 400:\n'
        '\t\tif GameLayers.roll_event_kind(GameLayers.LAYER_TWO, r574_rng, {}, 1) == "flyer":\n'
        '\t\t\tr574_seen_low = true\n'
        '\t\t\tbreak\n'
        '\tcheck(not r574_seen_low,\n'
        '\t\t\t"R574：巧克力不足 2 块时 400 次抽取都抽不到飞行器")\n'
        '\tvar r574_rng2 := RandomNumberGenerator.new()\n'
        '\tr574_rng2.seed = 574002\n'
        '\tvar r574_seen_ok := false\n'
        '\tfor r574_j in 400:\n'
        '\t\tif GameLayers.roll_event_kind(GameLayers.LAYER_TWO, r574_rng2, {}, 12) == "flyer":\n'
        '\t\t\tr574_seen_ok = true\n'
        '\t\t\tbreak\n'
        '\tcheck(r574_seen_ok,\n'
        '\t\t\t"R574：巧克力充足时飞行器仍能被抽到（没被误删出池）")\n'
        '\t# ③ 进房替换：同一格在巧克力 1 / 12 两种状态下走 resolve_event_kind\n'
        '\tvar r574_sv_used: Dictionary = RunState.event_kinds_used.duplicate()\n'
        '\tvar r574_cell := {"id": 17, "type": "event", "event_kind": "flyer",\n'
        '\t\t\t"layer": GameLayers.LAYER_TWO}\n'
        '\tRunState.event_kinds_used = {"pear": true, "hero": true}\n'
        '\tRunState.chocolate = 1\n'
        '\tvar r574_low := RunState.resolve_event_kind(r574_cell)\n'
        '\tcheck(str(r574_low.get("event_kind", "flyer")) != "flyer",\n'
        '\t\t\t"R574：巧克力不足时进房过滤把飞行器格换掉（或降级成战斗）")\n'
        '\tcheck(r574_cell.get("event_kind") == "flyer",\n'
        '\t\t\t"R574：过滤只改返回的副本，不污染 map_cells 本体")\n'
        '\tRunState.chocolate = 12\n'
        '\tvar r574_ok := RunState.resolve_event_kind(r574_cell)\n'
        '\tcheck(str(r574_ok.get("event_kind", "")) == "flyer",\n'
        '\t\t\t"R574：巧克力充足时飞行器格原样保留")\n'
        '\tRunState.event_kinds_used = r574_sv_used\n'
        '\tRunState.chocolate = r555_sv_choco\n'
        '\t# ④ 分发 + 源码锁：界面入口真的调了过滤、事件页不再有禁用按钮\n'
        '\tcheck_src("resolve_event_kind" in FileAccess.get_file_as_string("res://scripts/map_scene.gd"),\n'
        '\t\t\t"R574：进房统一入口 _dispatch_node 调了 resolve_event_kind")\n'
        '\tcheck_src("resolve_event_kind" in FileAccess.get_file_as_string("res://scripts/run_state.gd"),\n'
        '\t\t\t"R574：引擎侧真的有进房过滤")\n'
        '\tvar r574_ev_src := FileAccess.get_file_as_string("res://scripts/event_scene.gd")\n'
        '\tcheck_src("巧克力不足，飞不起来" not in r574_ev_src\n'
        '\t\t\tand "rest_btn.disabled = RunState.chocolate < 2" not in r574_ev_src,\n'
        '\t\t\t"R574：事件页不再有「遇到但不能用」的禁用按钮")\n'
        '\tcheck_src("FLYER_MIN_CHOCOLATE" in FileAccess.get_file_as_string("res://scripts/game_layers.gd"),\n'
        '\t\t\t"R574：阈值常量只在 GameLayers 定义一处")\n'
        '\t# 还原\n'
        '\tRunState.map_cells = r555_sv_cells\n',
    ),
], crlf=True)

print("R574 PATCH DONE")
