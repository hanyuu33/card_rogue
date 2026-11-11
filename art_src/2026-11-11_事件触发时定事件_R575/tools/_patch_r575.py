# -*- coding: utf-8 -*-
"""R575 精确补丁：事件触发时才决定 + 飞行器不消耗巧克力。

用法：python _patch_r575.py          # 干跑，只核对锚点
      python _patch_r575.py --write  # 落地

纪律：全部 Python exact-replace / 行区间替换，assert 唯一；按文件原行尾写回。
"""
import sys
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")
WRITE = "--write" in sys.argv
LOG = []


def load(path: str):
    p = ROOT / path
    b = p.read_bytes()
    crlf_n, lf_n = b.count(b"\r\n"), b.count(b"\n")
    crlf = bool(crlf_n and crlf_n == lf_n)
    text = b.decode("utf-8").replace("\r\n", "\n") if crlf else b.decode("utf-8")
    return p, text, crlf


def miss(tag: str, why: str) -> None:
    if WRITE:
        raise AssertionError("%s %s" % (tag, why))
    LOG.append("MISS  %s (%s)" % (tag, why))
    print("MISS", tag, why)


def exact(text: str, old: str, new: str, tag: str) -> str:
    n = text.count(old)
    if n != 1:
        miss(tag, "count=%d" % n)
        return text
    LOG.append("exact  %s" % tag)
    return text.replace(old, new, 1)


def lines_between(text: str, first: str, last: str, new: str, tag: str) -> str:
    """把 [含 first 的行, 含 last 的行] 整段换成 new（new 以 \\n 结尾）。"""
    # first / last 可带换行结尾，也可跨多行：按「first 的第一行」与「last 的最后一行」定位行号
    f0 = first.rstrip("\n").split("\n")[0]
    l0 = [x for x in last.rstrip("\n").split("\n") if x][-1]
    L = text.split("\n")
    i = [k for k, l in enumerate(L) if f0 in l]
    if len(i) != 1:
        miss(tag, "first count=%d [%s]" % (len(i), f0[:60]))
        return text
    i = i[0]
    j = [k for k, l in enumerate(L) if l0 in l and k >= i]
    if not j:
        miss(tag, "last count=0 [%s]" % l0[:60])
        return text
    # 末行标志可能在别处重复（如 `\treturn out`），只取本块之后的第一处
    j = j[0]
    if j < i:
        miss(tag, "order")
        return text
    LOG.append("block  %s (%d lines -> %d)" % (tag, j - i + 1, len(new.rstrip("\n").split("\n"))))
    L[i:j + 1] = new.rstrip("\n").split("\n")
    return "\n".join(L)


def save(p: Path, text: str, crlf: bool, path: str):
    out = text.replace("\n", "\r\n") if crlf else text
    if WRITE:
        p.write_bytes(out.encode("utf-8"))
    b = out.encode("utf-8")
    n, c = b.count(b"\n"), b.count(b"\r\n")
    print("%-32s %s crlf=%d bareLF=%d bytes=%d" %
          (path, "CRLF" if c and c == n else ("LF" if c == 0 else "MIXED"), c, n - c, len(b)))


# ---------------------------------------------------------------- game_layers
p, t, crlf = load("scripts/game_layers.gd")
t = exact(t,
    '\t\t\t# R555 飞行器（第二层专属）：使用飞行器 → 在地图上任选一格没走过的房间传送过去\n'
    '\t\t\t# （消耗 1 巧克力）/ 不移动。R574：巧克力不足 2 块时**根本不会遇到**这个事件，\n'
    '\t\t\t# 过滤在进房统一入口 `RunState.resolve_event_kind()`，判据见 FLYER_MIN_CHOCOLATE。\n'
    '\t\t\t"flyer": 16,\n',
    '\t\t\t# R555 飞行器（第二层专属）：使用飞行器 → 在地图上任选一格没走过的房间传送过去\n'
    '\t\t\t# / 不移动。R575：**不消耗巧克力**；巧克力见底（入夜）时遇不到这个事件。\n'
    '\t\t\t# 事件格子生成时不预定内容，进房那一刻才按当下的巧克力决定\n'
    '\t\t\t# （唯一口 `RunState.resolve_event_kind()`，判据见 FLYER_MIN_CHOCOLATE）。\n'
    '\t\t\t"flyer": 16,\n', "game_layers flyer note")
t = exact(t,
    '## R574（用户口径）：巧克力不足时**根本遇不到飞行器事件**，不是遇到了再把按钮置灰。\n'
    '## 2 块的来历：飞一次扣 1，扣完至少还得剩 1，才不会把自己送进「巧克力耗尽 → 入夜」。\n'
    'const FLYER_MIN_CHOCOLATE := 2\n\n\n'
    'static func event_kind_available(kind: String, chocolate: int) -> bool:\n'
    '\t## 该事件子类型在「当前巧克力」下能不能被遇到 —— 唯一判据口，\n'
    '\t## 进房过滤（`RunState.resolve_event_kind`）与抽取过滤（`roll_event_kind`）共用。\n'
    '\t## 目前只有飞行器有条件；别在 UI 里另写一份 `chocolate < 2`。\n'
    '\tif kind == "flyer":\n'
    '\t\treturn chocolate >= FLYER_MIN_CHOCOLATE\n'
    '\treturn true\n',
    '## R575（用户口径）：飞行器**不消耗巧克力**；巧克力见底（入夜）时根本遇不到这个事件。\n'
    '## 1 块的来历：巧克力按「走进新房间」逐格扣，扣到 0 就入夜；见底时飞行器不再刷出。\n'
    '## 刷出来之后飞过去也不再额外收费 —— 门槛在「遇不遇得到」，不在「用不用得起」。\n'
    'const FLYER_MIN_CHOCOLATE := 1\n\n\n'
    'static func event_kind_available(kind: String, chocolate: int) -> bool:\n'
    '\t## 该事件子类型在「当前巧克力」下能不能被遇到 —— 唯一判据口。\n'
    '\t## R575：只在**触发（进房）那一刻**由 `RunState.resolve_event_kind()` 使用；\n'
    '\t## 生成期不预定事件，别在 UI / 地图生成里另写一份 `chocolate < 1`。\n'
    '\tif kind == "flyer":\n'
    '\t\treturn chocolate >= FLYER_MIN_CHOCOLATE\n'
    '\treturn true\n', "game_layers threshold")
t = exact(t,
    '\t## R574：`chocolate >= 0` 时按 `event_kind_available()` 过滤候选（飞行器不足 2 块不参与抽）；\n'
    '\t## 传 -1（默认）= 不按巧克力过滤，保持测试 / 工具原有行为。\n',
    '\t## R575：`chocolate >= 0` 时按 `event_kind_available()` 过滤候选 —— 这是「触发时决定事件」\n'
    '\t## 的唯一口径（进房由 `RunState.resolve_event_kind()` 传入当下的巧克力）。\n'
    '\t## 传 -1（默认）= 不按巧克力过滤，保持测试 / 工具原有行为。\n', "game_layers roll note")
save(p, t, crlf, "scripts/game_layers.gd")

# ---------------------------------------------------------------- rogue_map
p, t, crlf = load("scripts/rogue_map.gd")
t = lines_between(t,
    '\t\tif type == "event":', '\t\t\t\tcell["event_kind"] = ek\n',
    '\t\tif type == "event":\n'
    '\t\t\t# R575（用户口径）：**事件格子在生成时只是事件格子** —— 不预定子类型、不记账本。\n'
    '\t\t\t# 具体事件在玩家踩上去那一刻由 `RunState.resolve_event_kind()` 决定，\n'
    '\t\t\t# 那时才能按「当下的巧克力」过滤（巧克力是走一路扣一路的）。\n'
    '\t\t\t# 「一局只出一次」的账本也在那一刻才登记；池子抽空则按 R374 老口径降级成战斗。\n'
    '\t\t\t# ⚠️ 仍消耗一次与旧版等量的随机数：只为固定地图布局与回放的随机链（R312 口径），\n'
    '\t\t\t#    抽到的子类型当场丢弃，绝不写进 cell。\n'
    '\t\t\tGameLayers.roll_event_kind(layer, rng, {})\n', "rogue_map _make_cells")
t = exact(t,
    '\t# ② 事件子类型：从**本局账本**（`used`）出发，再把「仍然留在图上」的事件登记进去\n'
    '\t# （含没被重摇的 ? 房）。R374：`used` 就是全局账本本身（就地写回），\n'
    '\t# 所以重摇出来的新事件同样受「一局只出一次」约束。\n'
    '\tvar used_events: Dictionary = used\n',
    '\t# ② R575：事件子类型不再在生成 / 重摇期预定，统一等玩家踩上去那一刻决定。\n'
    '\t# 保留下面这一步只为兼容 R575 之前的老档：图上若还带 event_kind，补登记进账本。\n'
    '\tvar used_events: Dictionary = used\n', "rogue_map reroll note")
t = exact(t,
    '\t\tcell3["type"] = t\n'
    '\t\tcell3["hidden"] = true\n'
    '\t\tcell3["revealed"] = false\n'
    '\t\tcell3["event_kind"] = ""\n'
    '\t\tif t == "event":\n'
    '\t\t\tvar ek3 := GameLayers.roll_event_kind(layer, rng, used_events)\n'
    '\t\t\tif ek3 == "":\n'
    '\t\t\t\tcell3["type"] = "battle"   # R374：本局事件池用尽 → 这格是一场普通战斗\n'
    '\t\t\telse:\n'
    '\t\t\t\tcell3["event_kind"] = ek3\n',
    '\t\tcell3["type"] = t\n'
    '\t\tcell3["hidden"] = true\n'
    '\t\tcell3["revealed"] = false\n'
    '\t\tcell3["event_kind"] = ""\n'
    '\t\tif t == "event":\n'
    '\t\t\t# R575：与生成期同口径 —— 只保随机链，不预定事件、不记账。\n'
    '\t\t\tGameLayers.roll_event_kind(layer, rng, {})\n', "rogue_map reroll body")
save(p, t, crlf, "scripts/rogue_map.gd")

# ---------------------------------------------------------------- run_state
p, t, crlf = load("scripts/run_state.gd")
t = exact(t,
    '\t# R374：新的一局 → 事件账本清空。⚠️ 外部**预生成**的地图（`map` 非空，map_scene 的兜底\n'
    '\t# 与出图都这么干）要把图上已有的事件登记进来，否则换到第二层时会跟第一层撞同一个事件。\n',
    '\t# R374：新的一局 → 事件账本清空。R575：事件在**进房时**才决定，生成期不再往账本登记；\n'
    '\t# 外部**预生成**的地图（`map` 非空）里若带着老格式的 event_kind（R575 之前的存档），\n'
    '\t# 仍要补登记，免得换层又撞同一个事件。\n', "run_state start_run note")
t = lines_between(t,
    'static func resolve_event_kind(', '\treturn out\n',
    'static func resolve_event_kind(cell: Dictionary) -> Dictionary:\n'
    '\t## R575（用户口径）：**事件格子在生成时只是事件格子，触发（进房）时才确定事件**。\n'
    '\t## 唯一调用点 = `map_scene._dispatch_node()`（正常进房 / 飞行器传送共用这一条）。\n'
    '\t## 按「当下的巧克力」过滤候选（`GameLayers.event_kind_available`），\n'
    '\t## 与 `event_kinds_used` 账本（一局只出一次，跨层共用）一起落地；\n'
    '\t## 池子抽空按 R374 老口径降级成一般战斗（「?」房本来就看不见内容）。\n'
    '\t## ⚠️ 用分类种子派生 rng（seed_of），**不消耗 run_rng**，回放确定性解耦（R312 口径）。\n'
    '\t## ⚠️ 结果写回 `map_cells` 里那一格：事件只决定一次，读档 / 再看时不会重摇。\n'
    '\t## R575 之前的老存档若已带 event_kind，原样沿用（不推翻旧档的决定）。\n'
    '\tif str(cell.get("type", "")) != "event":\n'
    '\t\treturn cell\n'
    '\tif str(cell.get("event_kind", "")) != "":\n'
    '\t\treturn cell\n'
    '\tvar out := cell.duplicate()   # 别污染 map_cells 里那份（与 delivery_override 同口径）\n'
    '\tvar layer := int(cell.get("layer", current_layer))\n'
    '\tvar rng := RandomNumberGenerator.new()\n'
    '\trng.seed = seed_of("event_pick", int(cell.get("id", 0)) + layer * 1000)\n'
    '\tvar kind := GameLayers.roll_event_kind(layer, rng, event_kinds_used, chocolate)\n'
    '\tif kind == "":\n'
    '\t\tout["type"] = "battle"\n'
    '\t\tout["event_kind"] = ""\n'
    '\telse:\n'
    '\t\tout["event_kind"] = kind\n'
    '\t# 定型：写回地图本体（按 id 找；外部预生成 / 测试图里找不到就只回副本）\n'
    '\tvar cid := int(cell.get("id", -1))\n'
    '\tif cid >= 0 and cid < map_cells.size():\n'
    '\t\tvar origin: Dictionary = map_cells[cid]\n'
    '\t\tif int(origin.get("id", -1)) == cid:\n'
    '\t\t\torigin["type"] = str(out["type"])\n'
    '\t\t\torigin["event_kind"] = str(out["event_kind"])\n'
    '\treturn out\n', "run_state resolve_event_kind")
t = exact(t,
    '\t## 飞过去 = 当次移动（扣 1 巧克力），所以目标只能是「没走过」的新格子。\n',
    '\t## R575：飞行器不消耗巧克力；目标仍只能是「没走过」的新格子（飞过去 = 一次跳跃）。\n',
    "run_state flyer_candidates note")
t = lines_between(t,
    'static func flyer_teleport(',
    '\treturn {"ok": true, "cost": cost, "revealed": revealed, "chocolate": chocolate}\n',
    'static func flyer_teleport(node_id: int) -> Dictionary:\n'
    '\t## R555 飞行器：无视相邻关系，直接飞到 node_id（必须是「没走过」的格子）。\n'
    '\t## 返回 {"ok", "cost", "revealed", "chocolate"}。\n'
    '\t## R575（用户口径）：**飞行器不消耗巧克力** —— cost 恒 0，也不触发入夜 / 疲惫同步。\n'
    '\t## 「巧克力见底就遇不到飞行器」由 `resolve_event_kind()` 在触发那一刻保证，\n'
    '\t## 这里不再摆第二道判据（不再有「遇到但不能用」）。\n'
    '\tif node_id < 0 or node_id >= map_cells.size():\n'
    '\t\treturn {"ok": false, "cost": 0, "revealed": false, "chocolate": chocolate}\n'
    '\tif cleared_ids.has(node_id) or not flyer_candidates().has(node_id):\n'
    '\t\treturn {"ok": false, "cost": 0, "revealed": false, "chocolate": chocolate}\n'
    '\tvar c: Dictionary = map_cells[node_id]\n'
    '\tcleared_ids.append(node_id)\n'
    '\tvar revealed := false\n'
    '\tif bool(c.get("hidden", false)) and not bool(c.get("revealed", false)):\n'
    '\t\tc["revealed"] = true\n'
    '\t\trevealed = true\n'
    '\tcurrent_node_id = node_id\n'
    '\treveal_known()\n'
    '\treturn {"ok": true, "cost": 0, "revealed": revealed, "chocolate": chocolate}\n',
    "run_state flyer_teleport")
save(p, t, crlf, "scripts/run_state.gd")

# ---------------------------------------------------------------- map_scene
p, t, crlf = load("scripts/map_scene.gd")
t = exact(t,
    '\t# R574：巧克力不足时飞行器事件在**进房前**就被替换掉（遇不到，不是遇到不能用）。\n'
    '\t# ⚠️ 必须排在所有事件改写之前：delivery 覆盖也走这一份 cell。\n'
    '\tcell = RunState.resolve_event_kind(cell)\n',
    '\t# R575：事件格子在生成时只是「事件格」，进房这一刻才决定具体事件\n'
    '\t# （按当下的巧克力过滤 + 一局只出一次）。正常进房 / 飞行器传送共用这一条。\n'
    '\t# ⚠️ 必须排在所有事件改写之前：delivery 覆盖也走这一份 cell。\n'
    '\tcell = RunState.resolve_event_kind(cell)\n', "map_scene _dispatch_node")
t = exact(t,
    '\t## R555 飞行器：点候选格 → 传送过去（扣 1 巧克力 + 进房结算）。\n',
    '\t## R555 飞行器：点候选格 → 传送过去（R575 起不消耗巧克力）+ 进房结算。\n',
    "map_scene _fly_click note")
t = exact(t,
    '\t\t_set_note("飞不过去（巧克力不足）")\n',
    '\t\t_set_note("这一格飞不过去")\n', "map_scene _fly_click hint")
save(p, t, crlf, "scripts/map_scene.gd")

# ---------------------------------------------------------------- event_scene
p, t, crlf = load("scripts/event_scene.gd")
t = lines_between(t,
    '# R555 飞行器（第二层专属）：两个选项',
    'const FLYER_TAKEN_DESC := """喷口已经热起来了，暖橙色的火苗轻轻跳着。\n回到地图后挑一个没去过的房间，它就把你送过去。"""\n',
    '# R555 飞行器（第二层专属）：两个选项 —— 使用飞行器（回地图选一格没去过的房间传过去）\n'
    '# / 不移动。R575（用户口径）：**不消耗巧克力**；巧克力见底时这个事件根本不会被遇到\n'
    '# （事件在进房那一刻才决定，见 `RunState.resolve_event_kind`）。这里不再有「没油」兜底页。\n'
    'const FLYER_DESC := """空地中央立着一架旧喷气背包，两只喷口还留着一点余温。\n'
    '背上它，你能直接飞到任何一个还没去过的房间——\n'
    '它靠自己那点余温就够，不用你掏巧克力。"""\n\n'
    'const FLYER_TAKEN_DESC := """喷口已经热起来了，暖橙色的火苗轻轻跳着。\n'
    '回到地图后挑一个没去过的房间，它就把你送过去。"""\n', "event_scene constants")
t = lines_between(t,
    '\telif _is_flyer():\n\t\tevent_name.text = "飞 行 器"',
    '\t\t\tresult_label.text = ""\n',
    '\telif _is_flyer():\n'
    '\t\tevent_name.text = "飞 行 器"\n'
    '\t\tdesc.text = FLYER_TAKEN_DESC if _fly_done else FLYER_DESC\n'
    '\t\tif _fly_done:\n'
    '\t\t\t_collapse_to_leave()\n'
    '\t\t\tresult_label.text = _fly_result\n'
    '\t\t\tresult_label.add_theme_color_override("font_color", Color("8fc0d8"))\n'
    '\t\telse:\n'
    '\t\t\trest_btn.visible = true\n'
    '\t\t\trest_btn.text = "使用飞行器（飞到一个没去过的房间）"\n'
    '\t\t\trest_btn.disabled = false\n'
    '\t\t\tbbq_btn.visible = false\n'
    '\t\t\talt_btn.visible = false\n'
    '\t\t\tleave_btn.visible = true\n'
    '\t\t\tleave_btn.text = "不移动（离开）"\n'
    '\t\t\tleave_btn.disabled = false\n'
    '\t\t\tresult_label.text = ""\n', "event_scene flyer branch")
t = exact(t,
    '\t\t# R574：进房入口已过滤，事件页也不再置灰；这里只留一道防死局的兜底。\n'
    '\t\tif not GameLayers.event_kind_available("flyer", RunState.chocolate):\n'
    '\t\t\treturn\n', '', "event_scene flyer fallback")
t = lines_between(t,
    '\t\tif args[i] == "--flyer":', '\t\t\tRunState.chocolate = 1\n',
    '\t\tif args[i] == "--flyer":  # 演示：伪装 run 飞行器事件（R573 背景截图验证）\n'
    '\t\t\tRunState.run_active = true\n'
    '\t\t\tRunState.pending_node = {"type": "event"}\n'
    '\t\t\tRunState.pending_event = "flyer"\n', "event_scene demo args")
save(p, t, crlf, "scripts/event_scene.gd")

# ---------------------------------------------------------------- test_engine
p, t, crlf = load("scripts/test_engine.gd")
t = exact(t,
    '\tcheck(cond, msg)\n\n\nfunc _new_engine(',
    '\tcheck(cond, msg)\n\n\n'
    'func _r575_trigger_all(cells: Array, keep_bank := false) -> void:\n'
    '\t## R575：把生成好的事件格逐个「触发」一遍（模拟玩家依次踩上去），\n'
    '\t## 让 event_kind 落到格子上 —— 历史断言因此仍能按「图上的事件」来验。\n'
    '\t## keep_bank = true 时沿用当前账本（跨层共用），否则本图单独起一本账。\n'
    '\tvar sv_map: Array = RunState.map_cells\n'
    '\tvar sv_bank: Dictionary = RunState.event_kinds_used\n'
    '\tvar sv_choco: int = RunState.chocolate\n'
    '\tRunState.map_cells = cells\n'
    '\tif not keep_bank:\n'
    '\t\tRunState.event_kinds_used = {}\n'
    '\tRunState.chocolate = 99\n'
    '\tfor _r575_c: Dictionary in cells:\n'
    '\t\tif str(_r575_c.get("type", "")) != "event":\n'
    '\t\t\tcontinue\n'
    '\t\tvar _r575_r := RunState.resolve_event_kind(_r575_c)\n'
    '\t\t_r575_c["event_kind"] = str(_r575_r.get("event_kind", ""))\n'
    '\t\tif str(_r575_r.get("type", "")) != "event":\n'
    '\t\t\t_r575_c["type"] = str(_r575_r["type"])\n'
    '\tRunState.map_cells = sv_map\n'
    '\tRunState.event_kinds_used = sv_bank\n'
    '\tRunState.chocolate = sv_choco\n\n\n'
    'func _new_engine(', "test_engine helper")
t = exact(t,
    '\tfor i in 40:\n'
    '\t\tvar em: Array = RogueMap.generate(ev_rng, GameLayers.LAYER_DEFAULT)\n'
    '\t\tfor node: Dictionary in em:\n',
    '\tfor i in 40:\n'
    '\t\tvar em: Array = RogueMap.generate(ev_rng, GameLayers.LAYER_DEFAULT)\n'
    '\t\t_r575_trigger_all(em)\n'
    '\t\tfor node: Dictionary in em:\n', "test_engine A")
t = lines_between(t,
    '\t# 事件房的 event_kind 必须取自本层事件池',
    '\tcheck(q_ev_kind_ok, "地图：事件房的 event_kind 全部取自本层事件池")\n',
    '\t# R575：事件格子在生成期只是「事件格」，event_kind 一律留空（触发时才决定）\n'
    '\tvar q_ev_kind_ok := true\n'
    '\tfor q_c: Dictionary in q_map1:\n'
    '\t\tif str(q_c["type"]) == "event" and str(q_c.get("event_kind", "")) != "":\n'
    '\t\t\tq_ev_kind_ok = false\n'
    '\tcheck(q_ev_kind_ok, "R575 地图：事件格生成时不预定子类型（event_kind 恒空）")\n',
    "test_engine B")
t = lines_between(t,
    '\t# 「只属于第一层」的事件子类型',
    '\tcheck(q_l2_leak == "", "第二层地图：绝不出现第一层专属事件（本次泄漏：%s）"\n\t\t\t% ("无" if q_l2_leak == "" else q_l2_leak))\n',
    '\t# R575：生成期不预定事件，「不串第一层」由触发期判据（见 R575 块）保证\n'
    '\tfor q_l2_n: Dictionary in q_l2:\n'
    '\t\tif int(q_l2_n.get("layer", -1)) != GameLayers.LAYER_TWO:\n'
    '\t\t\tq_l2_bad = true\n'
    '\t\tif str(q_l2_n["type"]) == "event" and str(q_l2_n.get("event_kind", "")) != "":\n'
    '\t\t\tq_l2_ev_bad = true\n'
    '\tcheck(not q_l2_bad, "第二层地图：每个房间都标记 layer = 2")\n'
    '\tcheck(not q_l2_ev_bad, "R575 第二层地图：事件格生成时不预定子类型（event_kind 恒空）")\n'
    '\tcheck(q_l2_leak == "", "R575 第二层地图：生成期不出现第一层专属事件（本次泄漏：%s）"\n'
    '\t\t\t% ("无" if q_l2_leak == "" else q_l2_leak))\n', "test_engine C1")
t = lines_between(t,
    '\t# 多次生成第二层地图：只出第二层专属事件',
    '\tcheck(not q_l2_ev_seen.has("bluefish"),\n\t\t\t"R573：第二层地图 40 次生成里不再出现蓝色大肥鱼")\n',
    '\t# 多次生成第二层地图：R575 起先触发，再检查决定的事件只出第二层专属池\n'
    '\tvar q_l2_ev_ok := true\n'
    '\tvar q_l2_ev_seen := {}\n'
    '\tvar q_l2_ev_rng := RandomNumberGenerator.new()\n'
    '\tq_l2_ev_rng.randomize()\n'
    '\tfor q_l2_i in 40:\n'
    '\t\tvar q_l2m: Array = RogueMap.generate(q_l2_ev_rng, GameLayers.LAYER_TWO)\n'
    '\t\t_r575_trigger_all(q_l2m)\n'
    '\t\tfor q_l2m_n: Dictionary in q_l2m:\n'
    '\t\t\tif str(q_l2m_n["type"]) != "event":\n'
    '\t\t\t\tcontinue\n'
    '\t\t\tvar q_l2m_kind := str(q_l2m_n.get("event_kind", ""))\n'
    '\t\t\tq_l2_ev_seen[q_l2m_kind] = true\n'
    '\t\t\tif not GameLayers.event_kinds(GameLayers.LAYER_TWO).has(q_l2m_kind):\n'
    '\t\t\t\tq_l2_ev_ok = false\n'
    '\tcheck(q_l2_ev_ok, "R575 第二层地图：触发时决定的事件全部取自第二层事件池（不串第一层）")\n'
    '\tcheck(q_l2_ev_seen.has("pear") or q_l2_ev_seen.has("hero"),\n'
    '\t\t\t"第二层地图多次生成：出鸭梨山大/绝赞五换一专属事件（R573 已删蓝色大肥鱼）")\n'
    '\tcheck(not q_l2_ev_seen.has("bluefish"),\n'
    '\t\t\t"R573：第二层地图 40 次生成里不再出现蓝色大肥鱼")\n', "test_engine C2")
t = exact(t,
    '\t\tvar q_r68_map: Array = RogueMap.generate(q_r68_map_rng, GameLayers.LAYER_DEFAULT)\n\t\tvar q_r68_cnt := {}\n',
    '\t\tvar q_r68_map: Array = RogueMap.generate(q_r68_map_rng, GameLayers.LAYER_DEFAULT)\n'
    '\t\t_r575_trigger_all(q_r68_map)\n'
    '\t\tvar q_r68_cnt := {}\n', "test_engine D1")
t = exact(t,
    '\t\tvar q_r68_map2: Array = RogueMap.generate(q_r68_map_rng, GameLayers.LAYER_TWO)\n\t\tvar q_r68_cnt2 := {}\n',
    '\t\tvar q_r68_map2: Array = RogueMap.generate(q_r68_map_rng, GameLayers.LAYER_TWO)\n'
    '\t\t_r575_trigger_all(q_r68_map2)\n'
    '\t\tvar q_r68_cnt2 := {}\n', "test_engine D2")
t = lines_between(t,
    '\t# 现在：账本 = `RunState.event_kinds_used`',
    '\t\tvar r374_k2 := {}\n',
    '\t# R575：账本仍 = `RunState.event_kinds_used`（跨层共用），但**在触发（进房）时**才登记；\n'
    '\t# 池子抽空 → 那格在进房时降级成一般战斗。\n'
    '\tvar r374_dup := ""\n'
    '\tvar r374_total_ok := true\n'
    '\tvar r374_cross_ok := true\n'
    '\tvar r374_sv_bank: Dictionary = RunState.event_kinds_used\n'
    '\tfor r374_s in 40:\n'
    '\t\tvar r374_bank := {}\n'
    '\t\tvar r374_r1 := RandomNumberGenerator.new()\n'
    '\t\tr374_r1.seed = 770000 + r374_s\n'
    '\t\tvar r374_m1: Array = RogueMap.generate(r374_r1, GameLayers.LAYER_DEFAULT, null, r374_bank)\n'
    '\t\tRunState.event_kinds_used = r374_bank\n'
    '\t\t_r575_trigger_all(r374_m1, true)\n'
    '\t\tvar r374_k1 := {}\n'
    '\t\tfor r374_n1: Dictionary in r374_m1:\n'
    '\t\t\tif str(r374_n1["type"]) == "event":\n'
    '\t\t\t\tvar r374_e1 := str(r374_n1.get("event_kind", ""))\n'
    '\t\t\t\tif r374_k1.has(r374_e1):\n'
    '\t\t\t\t\tr374_total_ok = false\n'
    '\t\t\t\tr374_k1[r374_e1] = true\n'
    '\t\tvar r374_r2 := RandomNumberGenerator.new()\n'
    '\t\tr374_r2.seed = 880000 + r374_s\n'
    '\t\tvar r374_m2: Array = RogueMap.generate(r374_r2, GameLayers.LAYER_TWO, null, r374_bank)\n'
    '\t\tRunState.event_kinds_used = r374_bank\n'
    '\t\t_r575_trigger_all(r374_m2, true)\n'
    '\t\tvar r374_k2 := {}\n', "test_engine E1")
t = lines_between(t,
    '\tcheck(r374_total_ok,',
    '\t\t\t% ("无" if r374_cross_ok else r374_dup))\n',
    '\tcheck(r374_total_ok,\n'
    '\t\t\t"R575/R374 一局内每种事件最多出现一次，且账本与图上事件严格对齐（违例：%s）"\n'
    '\t\t\t% ("无" if r374_total_ok else r374_dup))\n'
    '\tcheck(r374_cross_ok,\n'
    '\t\t\t"R575/R374 跨层共用账本：第一层出过的事件，第二层不再出（违例：%s）"\n'
    '\t\t\t% ("无" if r374_cross_ok else r374_dup))\n'
    '\tRunState.event_kinds_used = r374_sv_bank\n', "test_engine E2")
t = lines_between(t,
    '\t# ② 池子用尽 → 那一格降级成一般战斗',
    '\t\t\t% ("无" if r374_bad_cell == "" else r374_bad_cell))\n',
    '\t# ② R575：池子用尽 → **触发那一刻**那一格降级成一般战斗（生成期仍是事件格）\n'
    '\t#    R445 的「一局不会再出现占卜事件」口径不变：账本不清空、不重开。\n'
    '\tvar r374_starve_bank := {}\n'
    '\tfor r374_k_all in GameLayers.event_kinds(GameLayers.LAYER_DEFAULT):\n'
    '\t\tr374_starve_bank[r374_k_all] = true\n'
    '\tvar r374_srng := RandomNumberGenerator.new()\n'
    '\tr374_srng.seed = 990001\n'
    '\tvar r374_smap: Array = RogueMap.generate(r374_srng, GameLayers.LAYER_DEFAULT, null,\n'
    '\t\t\tr374_starve_bank)\n'
    '\tRunState.event_kinds_used = r374_starve_bank\n'
    '\t_r575_trigger_all(r374_smap, true)\n'
    '\tvar r374_left := 0\n'
    '\tvar r374_bad_cell := ""\n'
    '\tfor r374_c: Dictionary in r374_smap:\n'
    '\t\tif str(r374_c["type"]) == "event":\n'
    '\t\t\tr374_left += 1\n'
    '\t\t\tr374_bad_cell = "仍有事件房：%s" % str(r374_c.get("event_kind", ""))\n'
    '\t\tif str(r374_c.get("event_kind", "")) != "" and str(r374_c["type"]) != "event":\n'
    '\t\t\tr374_bad_cell = "非事件格残留 event_kind"\n'
    '\tcheck(r374_left == 0 and r374_bad_cell == "",\n'
    '\t\t\t"R575/R374 池子先用光 → 触发时每个事件格都降级成一般战斗（%s）"\n'
    '\t\t\t% ("无" if r374_bad_cell == "" else r374_bad_cell))\n'
    '\tRunState.event_kinds_used = r374_sv_bank\n', "test_engine E3")
t = lines_between(t,
    '\t# ②-b R445（用户口径）',
    '\t\t\t% ("无" if r445_div_hit == "" else r445_div_hit))\n',
    '\t# ②-b R445（用户口径）：占卜室跟其它事件走**同一本账** —— 已经出过就整层不再出现。\n'
    '\t#    R575：这一判据现在落在「触发那一刻」，生成期图上仍看不到事件。\n'
    '\tvar r445_div_bank := {"divination": true}\n'
    '\tvar r445_div_sv: Dictionary = RunState.event_kinds_used\n'
    '\tvar r445_divrng := RandomNumberGenerator.new()\n'
    '\tr445_divrng.seed = 550001\n'
    '\tvar r445_divmap: Array = RogueMap.generate(r445_divrng, GameLayers.LAYER_DEFAULT,\n'
    '\t\t\tnull, r445_div_bank)\n'
    '\tRunState.event_kinds_used = r445_div_bank\n'
    '\t_r575_trigger_all(r445_divmap, true)\n'
    '\tvar r445_div_hit := ""\n'
    '\tfor r445_dc: Dictionary in r445_divmap:\n'
    '\t\tif str(r445_dc.get("event_kind", "")) == "divination":\n'
    '\t\t\tr445_div_hit = "第 %d 格" % int(r445_dc.get("id", -1))\n'
    '\tcheck(r445_div_hit == "",\n'
    '\t\t\t"R575/R445 占卜室进了事件账本：触发时也不会再出（违例 %s）"\n'
    '\t\t\t% ("无" if r445_div_hit == "" else r445_div_hit))\n'
    '\tRunState.event_kinds_used = r445_div_sv\n', "test_engine F")
t = lines_between(t,
    '\t# ④ 外部预生成的地图',
    '\t\t\t"R374 预生成地图：start_run 把图上已有事件登记进本局账本（%s）" % r374_pre_first)\n',
    '\t# ④ R575：预生成地图的事件格不带子类型 → start_run 不该往账本登记任何东西\n'
    '\tvar r374_pre_rng := RandomNumberGenerator.new()\n'
    '\tr374_pre_rng.seed = 660001\n'
    '\tvar r374_pre: Array = RogueMap.generate(r374_pre_rng, GameLayers.LAYER_DEFAULT)\n'
    '\tvar r374_pre_first := ""\n'
    '\tfor r374_pc: Dictionary in r374_pre:\n'
    '\t\tif str(r374_pc["type"]) == "event":\n'
    '\t\t\tr374_pre_first = str(r374_pc.get("event_kind", ""))\n'
    '\t\t\tbreak\n'
    '\tRunState.start_run(r374_pre, GameLayers.LAYER_DEFAULT)\n'
    '\tcheck(r374_pre_first == "" and RunState.event_kinds_used.is_empty(),\n'
    '\t\t\t"R575 预生成地图：生成期不预定事件，start_run 不预登记账本")\n', "test_engine G")
t = lines_between(t,
    '\t# 挑一个候选格传送',
    '\t\t\t"R555 飞行器：巧克力不足 2 块时传送被拒（扣完至少得剩 1）")\n',
    '\t# 挑一个候选格传送\n'
    '\tvar r555_target := int(r555_cands[0])\n'
    '\tvar r555_choco_before := RunState.chocolate\n'
    '\tvar r555_res := RunState.flyer_teleport(r555_target)\n'
    '\tcheck(bool(r555_res.get("ok", false))\n'
    '\t\t\tand RunState.current_node_id == r555_target\n'
    '\t\t\tand RunState.cleared_ids.has(r555_target)\n'
    '\t\t\tand RunState.chocolate == r555_choco_before\n'
    '\t\t\tand int(r555_res.get("cost", -1)) == 0,\n'
    '\t\t\t"R575 飞行器：传送成功（标记走过 + 换格，**不消耗巧克力**）")\n'
    '\tcheck(not bool(RunState.flyer_teleport(r555_target).get("ok", false)),\n'
    '\t\t\t"R555 飞行器：已经走过的格子不再能飞")\n'
    '\t# R575：飞行器不消耗巧克力 → 巧克力见底也能飞（「遇不到」由触发时过滤保证）\n'
    '\tRunState.chocolate = 0\n'
    '\tvar r555_cands2 := RunState.flyer_candidates()\n'
    '\tvar r555_target2 := -1\n'
    '\tfor r555_c2: Dictionary in r555_cells:\n'
    '\t\tvar r555_id2 := int(r555_c2["id"])\n'
    '\t\tif r555_cands2.has(r555_id2):\n'
    '\t\t\tr555_target2 = r555_id2\n'
    '\t\t\tbreak\n'
    '\tcheck(r555_target2 >= 0,\n'
    '\t\t\t"R575 飞行器：巧克力见底时候选仍在（选格不看巧克力）")\n'
    '\tvar r555_res2 := RunState.flyer_teleport(r555_target2)\n'
    '\tcheck(bool(r555_res2.get("ok", false)) and RunState.chocolate == 0\n'
    '\t\t\tand int(r555_res2.get("cost", -1)) == 0,\n'
    '\t\t\t"R575 飞行器：巧克力为 0 也能传送，且 cost = 0（不消耗巧克力）")\n', "test_engine J")
t = lines_between(t,
    '\t# ==== R574：巧克力不足时',
    '\t\t\t"R574：阈值常量只在 GameLayers 定义一处")\n',
    '\t# ==== R575：事件在触发时才决定 + 飞行器不消耗巧克力 ====\n'
    '\t# ① 数据层：唯一判据口在 GameLayers；阈值 = 1（巧克力见底 = 入夜）\n'
    '\tcheck(GameLayers.FLYER_MIN_CHOCOLATE == 1,\n'
    '\t\t\t"R575：飞行器出现门槛 = 巧克力 >= 1（不消耗巧克力，见底才遇不到）")\n'
    '\tcheck(not GameLayers.event_kind_available("flyer", 0)\n'
    '\t\t\tand GameLayers.event_kind_available("flyer", 1)\n'
    '\t\t\tand GameLayers.event_kind_available("flyer", 12),\n'
    '\t\t\t"R575：event_kind_available 只在巧克力见底时挡住飞行器")\n'
    '\tcheck(GameLayers.event_kind_available("pear", 0)\n'
    '\t\t\tand GameLayers.event_kind_available("hero", 0),\n'
    '\t\t\t"R575：其它事件不受巧克力约束")\n'
    '\t# ② 生成期：事件格子只是事件格，event_kind 恒空\n'
    '\tvar r575_gen_empty := true\n'
    '\tvar r575_gen_events := 0\n'
    '\tfor r575_s in 12:\n'
    '\t\tvar r575_grng := RandomNumberGenerator.new()\n'
    '\t\tr575_grng.seed = 575000 + r575_s\n'
    '\t\tvar r575_gm: Array = RogueMap.generate(r575_grng, GameLayers.LAYER_TWO)\n'
    '\t\tfor r575_gc: Dictionary in r575_gm:\n'
    '\t\t\tif str(r575_gc.get("type", "")) != "event":\n'
    '\t\t\t\tcontinue\n'
    '\t\t\tr575_gen_events += 1\n'
    '\t\t\tif str(r575_gc.get("event_kind", "")) != "":\n'
    '\t\t\t\tr575_gen_empty = false\n'
    '\tcheck(r575_gen_events > 0 and r575_gen_empty,\n'
    '\t\t\t"R575 生成期：%d 个事件格全部不带子类型（触发时才决定）" % r575_gen_events)\n'
    '\t# ③ 触发期：巧克力见底时遇不到飞行器；充足时能遇到\n'
    '\tvar r575_sv_bank: Dictionary = RunState.event_kinds_used\n'
    '\tvar r575_sv_map: Array = RunState.map_cells\n'
    '\tvar r575_sv_choco: int = RunState.chocolate\n'
    '\tvar r575_low_seen := false\n'
    '\tvar r575_ok_seen := false\n'
    '\tfor r575_t in 30:\n'
    '\t\tvar r575_trng := RandomNumberGenerator.new()\n'
    '\t\tr575_trng.seed = 576000 + r575_t\n'
    '\t\tvar r575_tm: Array = RogueMap.generate(r575_trng, GameLayers.LAYER_TWO)\n'
    '\t\tRunState.map_cells = r575_tm\n'
    '\t\tRunState.event_kinds_used = {}\n'
    '\t\tRunState.chocolate = 0\n'
    '\t\tfor r575_tc: Dictionary in r575_tm:\n'
    '\t\t\tif str(r575_tc.get("type", "")) != "event":\n'
    '\t\t\t\tcontinue\n'
    '\t\t\tvar r575_low := RunState.resolve_event_kind(r575_tc)\n'
    '\t\t\tif str(r575_low.get("event_kind", "")) == "flyer":\n'
    '\t\t\t\tr575_low_seen = true\n'
    '\t\tvar r575_tm2: Array = RogueMap.generate(r575_trng, GameLayers.LAYER_TWO)\n'
    '\t\tRunState.map_cells = r575_tm2\n'
    '\t\tRunState.event_kinds_used = {}\n'
    '\t\tRunState.chocolate = 12\n'
    '\t\tfor r575_tc2: Dictionary in r575_tm2:\n'
    '\t\t\tif str(r575_tc2.get("type", "")) != "event":\n'
    '\t\t\t\tcontinue\n'
    '\t\t\tvar r575_high := RunState.resolve_event_kind(r575_tc2)\n'
    '\t\t\tif str(r575_high.get("event_kind", "")) == "flyer":\n'
    '\t\t\t\tr575_ok_seen = true\n'
    '\tcheck(not r575_low_seen and r575_ok_seen,\n'
    '\t\t\t"R575 触发期：巧克力见底时 30 张图没有一格出飞行器，充足时能遇到")\n'
    '\t# ④ 决定只做一次：结果写回 map_cells 并登记账本；老档已带 kind 的格子沿用\n'
    '\tvar r575_one := {"id": 0, "col": 0, "row": 0, "type": "event",\n'
    '\t\t\t"hidden": false, "revealed": true, "doors": [], "layer": 2,\n'
    '\t\t\t"event_kind": ""}\n'
    '\tRunState.map_cells = [r575_one]\n'
    '\tRunState.event_kinds_used = {}\n'
    '\tRunState.chocolate = 12\n'
    '\tvar r575_decided := RunState.resolve_event_kind(r575_one)\n'
    '\tvar r575_kind := str(r575_decided.get("event_kind", ""))\n'
    '\tcheck(r575_kind != "" and str(RunState.map_cells[0].get("event_kind", "")) == r575_kind\n'
    '\t\t\tand RunState.event_kinds_used.has(r575_kind),\n'
    '\t\t\t"R575 触发期：决定写回地图本体并登记账本（%s）" % r575_kind)\n'
    '\tcheck(str(RunState.resolve_event_kind(RunState.map_cells[0]).get("event_kind", "")) == r575_kind,\n'
    '\t\t\t"R575 触发期：同一格不会重摇（第二次沿用已定型的事件）")\n'
    '\tvar r575_legacy := {"id": 0, "type": "event", "event_kind": "divination", "layer": 1}\n'
    '\tcheck(str(RunState.resolve_event_kind(r575_legacy).get("event_kind", "")) == "divination",\n'
    '\t\t\t"R575：R575 之前的老存档里已带 event_kind 的格子原样沿用")\n'
    '\t# ⑤ 池空 → 触发那一刻降级成一般战斗\n'
    '\tRunState.event_kinds_used = {}\n'
    '\tfor r575_k_all in GameLayers.event_kinds(GameLayers.LAYER_TWO):\n'
    '\t\tRunState.event_kinds_used[r575_k_all] = true\n'
    '\tvar r575_empty_cell := {"id": 0, "type": "event", "event_kind": "", "layer": 2}\n'
    '\tRunState.map_cells = [r575_empty_cell]\n'
    '\tRunState.chocolate = 12\n'
    '\tvar r575_starved := RunState.resolve_event_kind(r575_empty_cell)\n'
    '\tcheck(str(r575_starved.get("type", "")) == "battle"\n'
    '\t\t\tand str(r575_starved.get("event_kind", "")) == "",\n'
    '\t\t\t"R575：本局事件池用尽 → 触发时那一格降级成一般战斗")\n'
    '\tRunState.map_cells = r575_sv_map\n'
    '\tRunState.event_kinds_used = r575_sv_bank\n'
    '\tRunState.chocolate = r575_sv_choco\n'
    '\t# ⑥ 飞行器不消耗巧克力（引擎 + 源码锁）\n'
    '\tcheck(int(r555_res.get("cost", -1)) == 0 and int(r555_res2.get("cost", -1)) == 0,\n'
    '\t\t\t"R575：飞行器传送 cost = 0（巧克力充足 / 见底两态都不扣）")\n'
    '\tvar r575_rs := FileAccess.get_file_as_string("res://scripts/run_state.gd")\n'
    '\tvar r575_ev := FileAccess.get_file_as_string("res://scripts/event_scene.gd")\n'
    '\tvar r575_ms := FileAccess.get_file_as_string("res://scripts/map_scene.gd")\n'
    '\tvar r575_rm := FileAccess.get_file_as_string("res://scripts/rogue_map.gd")\n'
    '\tcheck_src("resolve_event_kind" in r575_ms and r575_rs.find("event_pick") >= 0,\n'
    '\t\t\t"R575：进房统一入口调触发期决定，且用分类种子派生 rng（不消耗 run_rng）")\n'
    '\tcheck_src(r575_rm.find(\'cell["event_kind"] = ek\') < 0\n'
    '\t\t\tand r575_rm.find(\'cell3["event_kind"] = ek3\') < 0,\n'
    '\t\t\t"R575 源码：地图生成 / 重摇期不再写死事件子类型")\n'
    '\tvar r575_ft_a := r575_rs.find("static func flyer_teleport(")\n'
    '\tvar r575_ft_b := r575_rs.find("static func lucky7_left(")\n'
    '\tvar r575_ft := r575_rs.substr(r575_ft_a, r575_ft_b - r575_ft_a)\n'
    '\tcheck_src(r575_ft_a >= 0 and r575_ft_b > r575_ft_a\n'
    '\t\t\tand not r575_ft.contains("chocolate -") and not r575_ft.contains("sync_fatigue"),\n'
    '\t\t\t"R575 源码：飞行器传送函数里不再有扣巧克力 / 疲惫同步")\n'
    '\tcheck_src("消耗 1 块巧克力" not in r575_ev and "FLYER_NO_FUEL_DESC" not in r575_ev\n'
    '\t\t\tand "巧克力不足" not in r575_ev,\n'
    '\t\t\t"R575 源码：事件页不再有消耗 / 不足 / 灰按钮那套文案")\n'
    '\tcheck_src("FLYER_MIN_CHOCOLATE" in FileAccess.get_file_as_string("res://scripts/game_layers.gd"),\n'
    '\t\t\t"R575：阈值常量只在 GameLayers 定义一处")\n', "test_engine K")
save(p, t, crlf, "scripts/test_engine.gd")

print("\n--- %d edits, mode=%s ---" % (len(LOG), "WRITE" if WRITE else "DRY-RUN"))
for x in LOG:
    print(" ", x)
