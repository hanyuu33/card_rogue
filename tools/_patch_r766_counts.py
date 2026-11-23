# -*- coding: utf-8 -*-
"""R766 计数收口：懊悔 9265 让图鉴 / 分组 / 公用卡 / 道具件数各 +1。

只改数字与说明文本，不动断言逻辑。test_engine.gd 是 CRLF，用单行锚点绕开换行。
"""
import pathlib

P = pathlib.Path(r"E:\work\card_rogue\scripts\test_engine.gd")
src = P.read_bytes().decode("utf-8")

EDITS = [
    # ① 图鉴总数 325 → 326
    ("check(repo.all_cards().size() == 325,",
     "check(repo.all_cards().size() == 326,", 1),
    ("图鉴 = 325 张（R761 +2：",
     "图鉴 = 326 张（R766 +1：懊悔 9265（猴爪的代价 · 1 费诅咒 · 次元 · 选弃牌区一张其他职业卡消失）；R761 +2：", 1),
    # ② 分组：玩家 247 → 248
    ("check(grp_player.size() == 247 and grp_enemy.size() == 78,",
     "check(grp_player.size() == 248 and grp_enemy.size() == 78,", 1),
    ("（期望 247 / 78（R761 玩家 +2：",
     "（期望 248 / 78（R766 玩家 +1：懊悔 9265；R761 玩家 +2：", 1),
    # ③ 角色系统：公用 26 → 27（诅咒 class 留空）
    ('check(int(dr_cls_count.get("", 0)) == 26,',
     'check(int(dr_cls_count.get("", 0)) == 27,', 1),
    ("吟游诗人 2 / 公用 26（R761 吟游诗人 +2：",
     "吟游诗人 2 / 公用 27（R766 公用 +1：懊悔 9265；R761 吟游诗人 +2：", 1),
    ("R756 代偿 9252（实际 %d）",
     "R756 代偿 9252 + R766 懊悔 9265（实际 %d）", 1),
    # ④ R45 全库归属：公用 26 → 27
    ('check(int(r45_cls_count.get("", 0)) == 26,',
     'check(int(r45_cls_count.get("", 0)) == 27,', 1),
    ("R473 乱打 9215 / 飞踢 9216 / 冲拳 9217（%d 张）",
     "R473 乱打 9215 / 飞踢 9216 / 冲拳 9217 + R766 懊悔 9265（%d 张）", 1),
    # ⑤ 注释两处（内容相同，允许 2 次）
    ("R632：删工事罐子 9158（class 留空）→ 公用 26 → 25；R756 代偿 9252 → 26。",
     "R632：删工事罐子 9158（class 留空）→ 公用 26 → 25；R756 代偿 9252 → 26；R766 懊悔 9265 → 27。", 2),
    # ⑥ 道具件数 63 → 64
    ("# ① 数据层：63 件道具逐件都有图标",
     "# ① 数据层：64 件道具逐件都有图标", 1),
    ('"R577b 保真锁：63 件道具的 id',
     '"R577b 保真锁：64 件道具的 id', 1),
]

for old, new, want in EDITS:
    n = src.count(old)
    if n != want:
        print("FAIL count=%d (want %d) for %r" % (n, want, old[:48]))
        raise SystemExit(1)
    src = src.replace(old, new)
    print("ok x%d %s" % (want, old[:44]))

P.write_bytes(src.encode("utf-8"))
raw = P.read_bytes()
print("done, CRLF intact:", raw.count(b"\r\n") == raw.count(b"\n"))
