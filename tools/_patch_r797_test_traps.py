# -*- coding: utf-8 -*-
"""R797 测试：test_traps（售价 -5 / 河豚 7015）"""
ROOT = "E:/tmp/wt794/"
fails = []


def patch(path, pairs):
    raw = open(ROOT + path, "rb").read().decode("utf-8")
    for old, new in pairs:
        c = raw.count(old)
        if c != 1:
            fails.append("%s: %d → %r" % (path, c, old[:56]))
            continue
        raw = raw.replace(old, new)
    open(ROOT + path, "wb").write(raw.encode("utf-8"))
    print("patched %-26s CRLF %d / LF %d" % (path, raw.count("\r\n"), raw.count("\n")))


P = [
    # ---- 件数 ----
    ('	check(repo.size() == 14, "traps.json 恰好 14 件工具（4 放置 + 1 直接伤害 + 9 使用型）")',
     '	# R797：新增河豚 7015（**放置型**：踩到回弹一格 + 3 伤）→ 15 件\n'
     '	check(repo.size() == 15, "traps.json 恰好 15 件工具（5 放置 + 1 直接伤害 + 9 使用型）")'),

    # ---- 售价 -5（R797 店长口径「所有工具商店售价 -5」）----
    ('	check(bomb != null and bomb.trap_name == "炼金炸弹" and bomb.price == 30\n'
     '			and bomb.damage == 18, "炼金炸弹：18 伤 / 30 金")',
     '	# R797：全部带售价的工具各 -5（炼金炸弹 30 → 25 起），往下逐条同改。\n'
     '	check(bomb != null and bomb.trap_name == "炼金炸弹" and bomb.price == 25\n'
     '			and bomb.damage == 18, "炼金炸弹：18 伤 / 25 金")'),
    ('			and frost.price == 40, "冰冻陷阱：2 伤 + 冻结 1 回合 / 40 金")',
     '			and frost.price == 35, "冰冻陷阱：2 伤 + 冻结 1 回合 / 35 金")'),
    ('			and poison.price == 30, "毒瓶：8 伤 / 持续 3 回合 / 30 金")',
     '			and poison.price == 25, "毒瓶：8 伤 / 持续 3 回合 / 25 金")'),
    ('			and spike.price == 40, "穿刺陷阱：10 伤 + 禁足 1 回合 / 40 金")',
     '			and spike.price == 35, "穿刺陷阱：10 伤 + 禁足 1 回合 / 35 金")'),
    ('	check(hp_pot != null and hp_pot.trap_name == "小血瓶" and hp_pot.price == 50',
     '	check(hp_pot != null and hp_pot.trap_name == "小血瓶" and hp_pot.price == 45'),
    ('	check(mana_pot != null and mana_pot.trap_name == "法力药剂" and mana_pot.price == 35',
     '	check(mana_pot != null and mana_pot.trap_name == "法力药剂" and mana_pot.price == 30'),
    ('	check(repo.random_traps().size() == 12 and repo.get_trap(7007) != null,\n'
     '			"烤肉：`random_traps()` 把它排除（12 件可随机），全量仍是 14 件")',
     '	check(repo.random_traps().size() == 13 and repo.get_trap(7007) != null,\n'
     '			"烤肉：`random_traps()` 把它排除（13 件可随机），全量仍是 15 件")'),
    ('	# R752：野性图腾售价按店长口径 45 → 30\n'
     '	check(repo.get_trap(7008).price == 30, "野性图腾：商店售价 30")',
     '	# R752：野性图腾售价按店长口径 45 → 30；R797 全体 -5 → 25\n'
     '	check(repo.get_trap(7008).price == 25, "野性图腾：商店售价 25")'),
    ('	check(shop_pool.size() == 9 and not shop_ids.has(7007)',
     '	check(shop_pool.size() == 10 and not shop_ids.has(7007)'),
    ('			"`shop_traps()` = 9 件有售价的（烤肉与三件非卖品都被排除；R796 两件新工具有售价）")',
     '			"`shop_traps()` = 10 件有售价的（烤肉与三件非卖品都被排除；R796/R797 新工具都有售价）")'),
    ('	check(shop_ids.has(7008), "野性图腾售价 30 → 仍在商店货架上")',
     '	check(shop_ids.has(7008), "野性图腾售价 25 → 仍在商店货架上")'),
    ('			and cardpack.price == 55 and cardpack.is_usable(),\n'
     '			"卡牌包 7013：fill_hand / 使用型 / 55 金")',
     '			and cardpack.price == 50 and cardpack.is_usable(),\n'
     '			"卡牌包 7013：fill_hand / 使用型 / 50 金")'),
    ('			and wisdom.price == 40 and wisdom.is_usable(),\n'
     '			"智慧药剂 7014：抽 3 张 / 使用型 / 40 金")',
     '			and wisdom.price == 35 and wisdom.is_usable(),\n'
     '			"智慧药剂 7014：抽 3 张 / 使用型 / 35 金")'),

    # ---- 河豚 7015 数据 ----
    ('	check(shop_ids.has(7013) and shop_ids.has(7014)\n'
     '			and drop_ids.has(7013) and drop_ids.has(7014),\n'
     '			"R796 两件新工具：既进商店货架、也进随机掉落池")',
     '	check(shop_ids.has(7013) and shop_ids.has(7014)\n'
     '			and drop_ids.has(7013) and drop_ids.has(7014),\n'
     '			"R796 两件新工具：既进商店货架、也进随机掉落池")\n'
     '	# R797：河豚 7015 —— **放置型**（bounce，不是使用型），踩到回弹一格 + 3 伤，25 金\n'
     '	var puffer: TrapData = repo.get_trap(7015)\n'
     '	check(puffer != null and puffer.trap_name == "河豚" and puffer.bounce == 1\n'
     '			and puffer.damage == 3 and puffer.price == 25\n'
     '			and not puffer.is_usable() and not puffer.no_drop,\n'
     '			"河豚 7015：回弹 1 格 + 3 伤 / 放置型 / 25 金")\n'
     '	check(shop_ids.has(7015) and drop_ids.has(7015),\n'
     '			"河豚 7015：既进商店货架、也进随机掉落池")'),

    # ---- 描述覆盖：河豚是放置型 ----
    ('		for tid in ["7001", "7002", "7003", "7004"]:',
     '		for tid in ["7001", "7002", "7003", "7004", "7015"]:'),
]
patch("scripts/test_traps.gd", P)

# ---- 引擎侧：河豚回弹 + 龟壳 ----
if fails:
    print("失败：")
    for f in fails:
        print("  " + f)
else:
    print("OK 全部命中")
