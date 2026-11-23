# -*- coding: utf-8 -*-
"""R793 patch 1/4 —— 事件注册（game_layers.gd）与事件界面（event_scene.gd）。

林中的剑（第一层专属）：拔剑 → 失去 13 点最大生命 + 道具「大师之剑」6073；
转身离开。道具效果 = 每场战斗使用的第一个盟友 +10 力量。
"""
import io, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def patch(path, pairs):
    p = ROOT.rstrip("/") + "/" + path
    raw = io.open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            o = old.replace("\n", "\r\n")
            n = new.replace("\n", "\r\n")
        else:
            o, n = old, new
        c = txt.count(o)
        assert c == 1, "%s: count=%d for %r" % (path, c, old[:70])
        txt = txt.replace(o, n)
    io.open(p, "wb").write(txt.encode("utf-8"))
    print("OK %-34s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


# ============================================================ 1. game_layers.gd
patch("scripts/game_layers.gd", [
    (
        '\t\t\t"statue": 16,\n'
        '\t\t},\n'
        '\t},\n'
        '\t2: {',
        '\t\t\t"statue": 16,\n'
        '\t\t\t# R793（店长口径「新增一层事件」）：林中的剑 —— 拔剑失去 13 点最大生命，\n'
        '\t\t\t# 换道具「大师之剑」（每场战斗使用的第一个盟友 +10 力量）/ 转身离开。\n'
        '\t\t\t# 与「挣扎」同属第一层「拿血换强度」那一类，代价走 `RunState.lose_max_hp()`。\n'
        '\t\t\t"sword": 16,\n'
        '\t\t},\n'
        '\t},\n'
        '\t2: {'
    ),
    (
        '\t"statue": "奇异雕像",\n',
        '\t"statue": "奇异雕像",\n'
        '\t"sword": "林中的剑",\n'
    ),
])

# ============================================================ 2. event_scene.gd
patch("scripts/event_scene.gd", [
    # --- 顶部文档：事件清单补一行
    (
        '##   * event + gaze     鸭之凝视（**第二层**）：获得事件道具「一袋米抗几楼」，或放弃；\n',
        '##   * event + gaze     鸭之凝视（**第二层**）：获得事件道具「一袋米抗几楼」，或放弃；\n'
        '##   * event + sword    林中的剑（R793，第一层专属）：拔剑 -13 最大生命 → 道具「大师之剑」，\n'
        '##                      或转身离开；\n'
    ),
    # --- 常量 + 文案（放在奇异雕像那组之后，保留「事件 → 文案」的成组写法）
    (
        'const STATUE_SMASH_DESC := """你抄起一块石头砸向它的前腿。\n'
        '裂纹从爪子一路爬到山羊头上，整尊雕像塌成一堆白渣——\n'
        '握得住的那些，正好够塞满你的工具栏。"""\n',
        'const STATUE_SMASH_DESC := """你抄起一块石头砸向它的前腿。\n'
        '裂纹从爪子一路爬到山羊头上，整尊雕像塌成一堆白渣——\n'
        '握得住的那些，正好够塞满你的工具栏。"""\n'
        '\n'
        '# R793 林中的剑（第一层专属）：两个选项 —— 拔剑（失去 13 点最大生命 → 道具「大师之剑」）/\n'
        '# 转身离开。代价与占卜室 5 点是同一条 `RunState.lose_max_hp()`（**至少保留 1 点最大生命**），\n'
        '# 所以最大生命 <= 13 时按钮直接置灰 —— 不拦的话玩家会白掉一截上限换一件拿不到的东西。\n'
        '# 已持有大师之剑时同样置灰：`gain_relic()` 对重复持有是直接 return，血却是照扣的。\n'
        'const SWORD_MASTER_ID := 6073     # 大师之剑（事件道具，不进奖励池）\n'
        'const SWORD_LIFE_COST := 13       # 拔剑的代价：失去的最大生命\n'
        '\n'
        'const SWORD_DESC := """空地上立着一块灰白的长石，石缝里插着一把剑，剑身没入大半。\n'
        '苔顺着剑格爬下来，缠了不知多少年——它在这里等得太久了。\n'
        '拔剑：失去 13 点最大生命（至少保留 1 点，最大生命不足时无法拔），\n'
        '获得道具「大师之剑」：每场战斗使用的第一个盟友 +10 力量；\n'
        '也可以什么都不碰，转身走出这片林子。"""\n'
        '\n'
        'const SWORD_TAKEN_DESC := """石头从中间裂开。剑离地的那一刻轻得不像话，\n'
        '像它一直在等你来拿。\n'
        '握柄贴上掌心，林子静了一瞬——「大师之剑」已收进行囊。"""\n'
    ),
    # --- 状态变量
    (
        'var _statue_result := ""        # R754 奇异雕像：收尾那行结果（重绘要能复现）\n',
        'var _statue_result := ""        # R754 奇异雕像：收尾那行结果（重绘要能复现）\n'
        'var _sword_taken := false       # R793 林中的剑：本次是否已拔剑（拔了就只剩离开）\n'
        'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）\n'
    ),
    # --- 判定函数
    (
        'func _is_cave() -> bool:\n',
        'func _is_sword() -> bool:\n'
        '\t## R793 林中的剑（第一层专属）：拔剑（-13 最大生命 → 道具「大师之剑」）/ 离开。\n'
        '\t## 与「挣扎」（-21 当前生命 → 卡「金属龙」）是一对：一个扣血、一个扣上限。\n'
        '\treturn _is_event_node() and _pending_kind() == "sword"\n'
        '\n'
        '\n'
        'func _is_cave() -> bool:\n'
    ),
    # --- _is_treasure 兜底排除（漏了就会被当成小宝箱）
    (
        '\t\t\tand not _is_flyer() and not _is_statue()\n',
        '\t\t\tand not _is_flyer() and not _is_statue() and not _is_sword()\n'
    ),
    # --- _kind()：图片名后缀
    (
        '\tif _is_statue():\n'
        '\t\treturn "statue"\n'
        '\tif _is_treasure():\n',
        '\tif _is_statue():\n'
        '\t\treturn "statue"\n'
        '\tif _is_sword():\n'
        '\t\treturn "sword"\n'
        '\tif _is_treasure():\n'
    ),
    # --- 主题色：林中的剑归「自然 / 探索」绿
    (
        '\t\t"pear", "snow_leopard", "adventurer", "cave", "flyer":\n',
        '\t\t"pear", "snow_leopard", "adventurer", "cave", "flyer", "sword":\n'
    ),
    # --- _refresh() 白名单（漏登记会被当成休息处、按钮文案被刷掉）
    (
        '\t\t\tor _is_core_contract() or _is_flyer() or _is_statue():\n',
        '\t\t\tor _is_core_contract() or _is_flyer() or _is_statue() or _is_sword():\n'
    ),
    # --- 演示参数
    (
        '\t\tif args[i] == "--struggle":  # 演示：伪装 run 挣扎事件（截图验证）\n',
        '\t\tif args[i] == "--sword":  # R793 演示：伪装 run 林中的剑事件（截图验证）\n'
        '\t\t\tRunState.run_active = true\n'
        '\t\t\tRunState.pending_node = {"type": "event"}\n'
        '\t\t\tRunState.pending_event = "sword"\n'
        '\t\tif args[i] == "--struggle":  # 演示：伪装 run 挣扎事件（截图验证）\n'
    ),
])

print("patch 1/4 done")
