# -*- coding: utf-8 -*-
## R801：爆炸蘑菇 7016 —— 测试断言（test_traps.gd + test_engine.gd）
import os

os.chdir("E:/work/card_rogue")
N = "\n"


def rep(d, old, new, tag):
    assert d.count(old) == 1, "[%s] 锚点 %d" % (tag, d.count(old))
    return d.replace(old, new)


# ================= ① test_traps.gd（纯 LF） =================
P = "scripts/test_traps.gd"
d = open(P, "rb").read().decode("utf-8")
assert d.count("\r\n") == 0

# 1) 总数 15 → 16
d = rep(d,
        '\t# R797：新增河豚 7015（**放置型**：踩到回弹一格 + 3 伤）→ 15 件' + N
        + '\tcheck(repo.size() == 15, "traps.json 恰好 15 件工具（5 放置 + 1 直接伤害 + 9 使用型）")',
        '\t# R797：新增河豚 7015（**放置型**：踩到回弹一格 + 3 伤）→ 15 件' + N
        + '\t# R801：新增爆炸蘑菇 7016（**放置型**：踩到炸一圈 15 伤，不分敌我）→ 16 件' + N
        + '\tcheck(repo.size() == 16, "traps.json 恰好 16 件工具（6 放置 + 1 直接伤害 + 9 使用型）")',
        "total")

# 2) 随机池 13 → 14
d = rep(d,
        '\tcheck(repo.random_traps().size() == 13 and repo.get_trap(7007) != null,' + N
        + '\t\t\t"烤肉：`random_traps()` 把它排除（13 件可随机），全量仍是 15 件")',
        '\tcheck(repo.random_traps().size() == 14 and repo.get_trap(7007) != null,' + N
        + '\t\t\t"烤肉：`random_traps()` 把它排除（14 件可随机），全量仍是 16 件")',
        "random")

# 3) 商店池 10 → 11
d = rep(d,
        '\tcheck(shop_pool.size() == 10 and not shop_ids.has(7007)',
        '\tcheck(shop_pool.size() == 11 and not shop_ids.has(7007)',
        "shop")
d = rep(d,
        '"`shop_traps()` = 10 件有售价的（烤肉与三件非卖品都被排除；R796/R797 新工具都有售价）")',
        '"`shop_traps()` = 11 件有售价的（烤肉与三件非卖品都被排除；R796/R797/R801 新工具都有售价）")',
        "shop-msg")

# 4) 7016 数据断言（接在河豚断言之后）
anchor = ('\tcheck(shop_ids.has(7015) and drop_ids.has(7015),' + N
          + '\t\t\t"河豚 7015：既进商店货架、也进随机掉落池")' + N)
BLOCK = ('\t# R801：爆炸蘑菇 7016 —— **放置型**（blast 范围伤害，不走使用型），炸一圈 15 伤，30 金' + N
         + '\tvar shroom: TrapData = repo.get_trap(7016)' + N
         + '\tcheck(shroom != null and shroom.trap_name == "爆炸蘑菇" and shroom.blast == 1' + N
         + '\t\t\tand shroom.damage == 15 and shroom.price == 30' + N
         + '\t\t\tand not shroom.is_usable() and not shroom.no_drop,' + N
         + '\t\t\t"爆炸蘑菇 7016：半径 1 / 15 伤 / 放置型 / 30 金")' + N
         + '\tcheck(shop_ids.has(7016) and drop_ids.has(7016),' + N
         + '\t\t\t"爆炸蘑菇 7016：既进商店货架、也进随机掉落池")' + N)
assert d.count(anchor) == 1, "河豚断言锚点 %d" % d.count(anchor)
d = d.replace(anchor, anchor + BLOCK)

# 5) 描述覆盖列表加 7016
d = rep(d,
        '\t\tfor tid in ["7001", "7002", "7003", "7004", "7015"]:',
        '\t\tfor tid in ["7001", "7002", "7003", "7004", "7015", "7016"]:',
        "desc-list")

# 6) 行为断言（插在 ⑥b 之前）
anchor2 = '\t# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----' + N
BEHAVE = '''\t# ---- ⑥e R801：爆炸蘑菇 7016 —— 踩到炸一圈（15 伤，不分敌我）----
\t# 半径 1 = 曼哈顿距离 ≤ 1（含中心格自身）：中心 + 上下左右四格。
\tvar e13 := _engine()
\te13.state.trap_fields[c31] = 7016
\tvar foe13: Placement = _unit(9014, 60, GameEngine.SIDE_OPPONENT)     # 踩上去的那位
\te13.state.board[c31] = foe13
\tvar mate13: Placement = _unit(9015, 60, GameEngine.SIDE_OPPONENT)    # 相邻同伴
\te13.state.board[Vector2i(2, 1)] = mate13
\tvar ally13: Placement = _unit(9016, 60, GameEngine.SIDE_SELF)        # 相邻己方
\te13.state.board[Vector2i(4, 1)] = ally13
\tvar far13: Placement = _unit(9017, 60, GameEngine.SIDE_OPPONENT)     # 距离 2，安全
\te13.state.board[Vector2i(1, 1)] = far13
\te13._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
\tcheck(foe13.health == 45, "爆炸蘑菇：踩上去那句只吃一次 15（不是单体 + 范围 30）")
\tcheck(mate13.health == 45, "爆炸蘑菇：相邻的**敌方**同伴也被炸（15）")
\tcheck(ally13.health == 45, "爆炸蘑菇：**不分敌我** —— 相邻的己方单位同样吃 15")
\tcheck(far13.health == 60, "爆炸蘑菇：距离 2 的单位不在范围内")
\tcheck(not e13.state.trap_fields.has(c31), "爆炸蘑菇：触发后从场上摘掉（一次性的）")

\t# 波及致死 → 由 `_trap_path_check` 循环外的 `_destroy_dead()` 统一清场
\tvar e14 := _engine()
\te14.state.trap_fields[c31] = 7016
\tvar foe14: Placement = _unit(9018, 60, GameEngine.SIDE_OPPONENT)
\te14.state.board[c31] = foe14
\tvar weak14: Placement = _unit(9019, 10, GameEngine.SIDE_SELF)
\te14.state.board[Vector2i(2, 1)] = weak14
\te14._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
\tcheck(not e14.state.board.has(Vector2i(2, 1)),
\t\t\t"爆炸蘑菇：被波及致死的单位立刻清场（不顶着负血留在棋盘上）")

\t# 我方踩自己的爆炸蘑菇：不触发（与其它陷阱同口径）
\tvar e15 := _engine()
\te15.state.trap_fields[c31] = 7016
\tvar mine15: Placement = _unit(9020, 60, GameEngine.SIDE_SELF)
\te15.state.board[c31] = mine15
\te15._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_SELF)
\tcheck(mine15.health == 60 and e15.state.trap_fields.has(c31),
\t\t\t"爆炸蘑菇：我方踩到不触发、不消耗")

'''.replace("\n", N)
assert d.count(anchor2) == 1, "⑥b 锚点 %d" % d.count(anchor2)
d = d.replace(anchor2, BEHAVE + anchor2)

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("test_traps CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))

# ================= ② test_engine.gd（纯 CRLF） =================
P2 = "scripts/test_engine.gd"
e = open(P2, "rb").read().decode("utf-8")
assert e.count("\r\n") > 0
old = ('\tcheck(r744_trepo.random_traps().size() == 13,' + "\r\n"
       + '\r\n'
       + '\t\t\t"R745 工具池：可随机 13 件（烤肉 7007 仍被 rest_only 排除；R797 +河豚 7015）")')
new = ('\tcheck(r744_trepo.random_traps().size() == 14,' + "\r\n"
       + '\r\n'
       + '\t\t\t"R745 工具池：可随机 14 件（烤肉 7007 仍被 rest_only 排除；'
       + 'R797 +河豚 7015 / R801 +爆炸蘑菇 7016）")')
assert e.count(old) == 1, "engine 工具池锚点 %d" % e.count(old)
e = e.replace(old, new)
open(P2, "wb").write(e.encode("utf-8"))
b2 = open(P2, "rb").read()
print("test_engine CRLF", b2.count(b"\r\n"), "LFonly", b2.count(b"\n") - b2.count(b"\r\n"))
print("残留 /r/n:", d.count("/r/n") + e.count("/r/n"))
