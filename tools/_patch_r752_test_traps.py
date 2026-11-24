# -*- coding: utf-8 -*-
"""R752 补丁：test_traps —— 11 件工具 / 商店池 / 三件新工具的结算。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:160])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/test_traps.gd", [
    # ---- ① 数据表 ----
    (
        """	# R745：新增野性图腾 7008（使用型）→ 8 件（4 放置型 + 4 使用型）
	check(repo.size() == 8, "traps.json 恰好 8 件工具（4 放置型 + 4 使用型）")""",
        """	# R745：新增野性图腾 7008（使用型）→ 8 件（4 放置型 + 4 使用型）
	# R752：新增万能牌 7009 / 快送鸭 7010 / 神秘牌 7011（都是使用型、都没有售价）→ 11 件
	check(repo.size() == 11, "traps.json 恰好 11 件工具（4 放置型 + 7 使用型）")""",
    ),
    (
        """	check(repo.random_traps().size() == 7 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（7 件可随机），全量仍是 8 件")
""",
        """	check(repo.random_traps().size() == 10 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（10 件可随机），全量仍是 11 件")
	# R752：野性图腾售价按店长口径 45 → 30
	check(repo.get_trap(7008).price == 30, "野性图腾：商店售价 30")
	# R752：三件新工具 —— 都是使用型、都没有售价（= 不进商店）
	var wild: TrapData = repo.get_trap(7009)
	var duck_tool: TrapData = repo.get_trap(7010)
	var mystic: TrapData = repo.get_trap(7011)
	check(wild != null and wild.trap_name == "万能牌" and wild.pick_kind == "deck_copy"
			and wild.is_usable() and wild.price == 0 and not wild.in_shop(),
			"万能牌 7009：pick_kind=deck_copy / 使用型 / 没有售价（不进商店）")
	check(duck_tool != null and duck_tool.trap_name == "快送鸭" and duck_tool.fill_toolbar
			and duck_tool.is_usable() and duck_tool.price == 0 and not duck_tool.in_shop(),
			"快送鸭 7010：fill_toolbar / 使用型 / 没有售价（不进商店）")
	check(mystic != null and mystic.trap_name == "神秘牌" and mystic.pick_kind == "random3"
			and mystic.is_usable() and mystic.price == 0 and not mystic.in_shop(),
			"神秘牌 7011：pick_kind=random3 / 使用型 / 没有售价（不进商店）")
	# 商店池（R752 新增的判据口）：有售价的 7 件；三件新工具与烤肉都不在里面
	var shop_pool: Array[TrapData] = repo.shop_traps()
	var shop_ids: Array[int] = []
	for sp: TrapData in shop_pool:
		shop_ids.append(int(sp.id))
	check(shop_pool.size() == 7 and not shop_ids.has(7007)
			and not shop_ids.has(7009) and not shop_ids.has(7010) and not shop_ids.has(7011),
			"`shop_traps()` = 7 件有售价的（烤肉与三件非卖品都被排除）")
	check(shop_ids.has(7008), "野性图腾售价 30 → 仍在商店货架上")
""",
    ),
    # ---- ①b 描述里的发动方式 ----
    (
        """		for tid in ["7005", "7006"]:
			var d := str(raw_rows.get(tid, ""))
			if not d.contains("轻点即可使用") or not d.contains("无需拖到战场格子上"):
				op_bad += "%s 缺轻点说明 " % tid""",
        """		# R752：交互改成「点两下」（第一下弹出「使用」，第二下才结算），
		# 所以使用型工具的说明也统一写成「轻点两下即可使用」。
		for tid in ["7005", "7006", "7007", "7008", "7009", "7010", "7011"]:
			var d := str(raw_rows.get(tid, ""))
			if not d.contains("轻点两下即可使用") or not d.contains("无需拖到战场格子上"):
				op_bad += "%s 缺轻点说明 " % tid""",
    ),
    (
        """	check(op_bad == "", "六件工具都写明发动方式（拖到格子 / 轻点）%s\"""",
        """	check(op_bad == "", "每件工具都写明发动方式（拖到格子 / 轻点两下）%s\"""",
    ),
    # ---- 商店源码守卫：货架池改口 ----
    (
        """	check(shop_src.contains("TRAP_SHOP_COUNT := 2") and shop_src.contains("_buy_trap"),
			"商店：右组 2 个工具商品与购买分支")""",
        """	check(shop_src.contains("TRAP_SHOP_COUNT := 2") and shop_src.contains("_buy_trap"),
			"商店：右组 2 个工具商品与购买分支")
	check(shop_src.contains("TrapRepo.load_json().shop_traps()")
			and not shop_src.contains("TrapRepo.load_json().random_traps()"),
			"R752：商店货架只从 `shop_traps()`（有售价）取货 —— 非卖品不会白送")""",
    ),
])

print("OK")
