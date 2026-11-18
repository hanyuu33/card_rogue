# -*- coding: utf-8 -*-
"""R793 patch 7 —— 更新「写死计数」型守卫（新增 1 事件 + 1 道具后的必然变更）。

这些都是**故意写死**的快照守卫（防止内容被意外增删），所以按新基线更新数字，
而不是改成动态 —— 保留「一旦再变就会红」的防护语义。
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
    print("OK %-36s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


# ------------------------------------------------------------ test_engine.gd
patch("scripts/test_engine.gd", [
    # ① 第一层事件池：11 → 12（+ 林中的剑 sword）
    ('check(ev_kinds_layer.size() == 11 and not ev_kinds_layer.has("monster") \\\n',
     'check(ev_kinds_layer.size() == 12 and not ev_kinds_layer.has("monster") \\\n'),
    ('\t\t\tand ev_kinds_layer.has("snow_leopard") \\\n',
     '\t\t\tand ev_kinds_layer.has("snow_leopard") and ev_kinds_layer.has("sword") \\\n'),
    ('"第一层事件池：11 种子类型（挣扎/奥秘之泉/遗忘之泉/鸭鸭工匠/运送委托/湖中仙女/占卜室/'
     'R446 雪豹出现/R447 冒险家的遗物/R473 武术大师/R763d 奇异雕像；R512 移除卡牌宝箱；'
     'R514 移除鸭鸭低语→改二层起点三选一；无凝视、无怪物）")',
     '"第一层事件池：12 种子类型（挣扎/奥秘之泉/遗忘之泉/鸭鸭工匠/运送委托/湖中仙女/占卜室/'
     'R446 雪豹出现/R447 冒险家的遗物/R473 武术大师/R763d 奇异雕像/R793 林中的剑；'
     'R512 移除卡牌宝箱；R514 移除鸭鸭低语→改二层起点三选一；无凝视、无怪物）")'),
    # ② R447 那条同口径
    ('check(r447_l1.size() == 11 and r447_l1.has("adventurer"),',
     'check(r447_l1.size() == 12 and r447_l1.has("adventurer"),'),
    ('"R447 第一层事件池 11 种（+冒险家的遗物；R473 +武术大师；R512 移除卡牌宝箱；'
     'R514 移除鸭鸭低语；R763d +奇异雕像，实际 %d）" % r447_l1.size())',
     '"R447 第一层事件池 12 种（+冒险家的遗物；R473 +武术大师；R512 移除卡牌宝箱；'
     'R514 移除鸭鸭低语；R763d +奇异雕像；R793 +林中的剑，实际 %d）" % r447_l1.size())'),
    # ③ 道具总数 67 → 68（R792 已加到 67）
    ('check(icon577_src_ok and icon577_repo.all_relics().size() == 67,',
     'check(icon577_src_ok and icon577_repo.all_relics().size() == 68,'),
    ('"R577b 保真锁：67 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072）")',
     '"R577b 保真锁：68 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +大师之剑 6073）")'),
])

# ------------------------------------------------------------ i18n 校验脚本
patch("i18n/validate_narrative.py", [
    ('check(len(ZH["events"]) == 27, "事件页为 27 组（25 常规 + 篝火 + 旧存档兜底）")',
     'check(len(ZH["events"]) == 28, "事件页为 28 组（26 常规 + 篝火 + 旧存档兜底；R793 +林中的剑）")'),
    ('check(sum(len(x["texts"]) for x in ZH["events"].values()) == 68, "事件正文共 68 段（含 3 条休息处动态追加）")',
     'check(sum(len(x["texts"]) for x in ZH["events"].values()) == 70, "事件正文共 70 段（含 3 条休息处动态追加；R793 +2）")'),
])

patch("i18n/validate_event_ui.py", [
    ('EXPECTED_COUNTS = {"options": 87, "results": 67, "pickers": 5, "rest_dynamic": 3}',
     '# R793：林中的剑 +4 选项（拔剑 / 上限不足 / 已持有 / 离开）、+1 结果。\n'
     'EXPECTED_COUNTS = {"options": 91, "results": 68, "pickers": 5, "rest_dynamic": 3}'),
])

patch("i18n/validate_spanish.py", [
    ('check(len(NONCARD_ES["relics"]) == 67 and len(NONCARD_ES["classes"]) == 3,\n'
     '      "noncard 为 67 件道具 + 3 个角色")',
     'check(len(NONCARD_ES["relics"]) == 68 and len(NONCARD_ES["classes"]) == 3,\n'
     '      "noncard 为 68 件道具 + 3 个角色（R792 +3 / R793 +大师之剑 6073）")'),
    ('check(len(event_zh_rows) == 162, "event_ui 为 87 选项 + 67 结果 + 5 选货 + 3 动态")',
     'check(len(event_zh_rows) == 167, "event_ui 为 91 选项 + 68 结果 + 5 选货 + 3 动态（R793 +5）")'),
])

print("patch 7 done")
