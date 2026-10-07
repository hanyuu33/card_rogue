extends SceneTree
## headless 肉鸽奖励测试（卡牌肉鸽版）：godot --headless -s scripts/test_reward.gd
## 覆盖：稀有度字段与序列化（6 档）、真实奖励池（27 张奖励卡）、
## 初始/怪物不可获得、权重抽取（数量/去重/分布/可复现）。

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		fails += 1
		printerr("  ✗ ", msg)


func _mk(id: int, name: String, rarity: int) -> CardData:
	var c := CardData.new()
	c.id = id
	c.card_name = name
	c.kind = "盟友"
	c.cost = 1
	c.rarity = rarity
	return c


func _init() -> void:
	print("== 肉鸽卡牌奖励测试（卡牌肉鸽版） ==")
	var repo := CardRepo.load_json()

	# ---- 稀有度字段（6 档：含事件） ----
	var all := repo.all_cards()
	check(all.size() == 181, "卡牌库 181 张（+ 幽影 8005 / 终结 9086 / R45 扩展 / 回响·闪躲 R48 / 收尾 R49 / 爆炸陷阱 R50 / 冰霜·冻结·剧毒陷阱·陷阱精通 R51 / 紧急埋伏·陷阱工坊·暗影狩猎 R52 / 穿刺陷阱·双重陷阱 R53 / 巨物捕获·活体栅栏·警觉 R54 / 地狱猫·鲜血堡垒·活力转移 R55 / 暗影之刃·黑暗领主·暗影锁链 R56 / 黑暗扩散·地狱咏唱者·黑暗祭坛·无尽黑暗 R57 / 使魔之力 9115 R60 / 契约签订者·恶魔鸭·恶魔使魔 R63 / 机械之心 素体·构装体·升级 R82 / 清泉 8028 R83 / 战斗骨骼 8029 R84 / 过载 8030 R85 / 批量改造 8031·侦察塔 8032 R86 / 能量屏障 8033·堡垒 8034·自我修复 8035 R87 / 维修间 8036·改造工厂 8037 R88 / 无限装甲 8038 R89 / 系统升级 8039·批量传输 8040 R90 / 充电装置 8041 R91 / 护盾生成器 8042·模仿者 8043 R92 / 零件回收者 8046·嵌合暴君 8047·生产订单 8048 R96 / 拆解 8049 R97 / 重组 8051·城墙 8052·超越极限 8053 R99）")
	var bad_rarity := 0
	for c in all:
		if c.rarity < 0 or c.rarity > 5:
			bad_rarity += 1
	check(bad_rarity == 0, "全部卡牌稀有度取值合法（0~5）")
	check(repo.get_card(8001).rarity == 3 and repo.get_card(8001).rarity_name() == "初始",
			"木栅栏 = 初始")
	check(repo.get_card(1053).rarity == 4 and repo.get_card(1053).rarity_name() == "怪物",
			"骷髅兵 = 怪物")
	check(CardData.RARITY_NAMES.size() == 6
			and CardData.RARITY_NAMES[3] == "初始" and CardData.RARITY_NAMES[4] == "怪物"
			and CardData.RARITY_NAMES[5] == "事件",
			"稀有度名称表 6 档（含初始/怪物/事件）")
	var rt := repo.get_card(8002).to_dict()
	check(int(rt.get("rarity", -1)) == 3 and CardData.from_dict(rt).rarity == 3,
			"to_dict/from_dict 保留稀有度")
	var sv := repo.get_card(9002).to_dict()
	check(CardData.from_dict(sv).value == 2, "to_dict/from_dict 保留效果数值 value")
	var clamped := CardData.from_dict({"id": 1, "name": "x", "rarity": 9})
	check(clamped.rarity == 5, "非法稀有度被钳制到 5")

	# ---- 真实奖励池：27 张奖励卡，初始/怪物/事件不可获得 ----
	var pool := repo.reward_pool()
	check(pool.size() == 128, "奖励池 128 张（初始/怪物/事件卡不入池；实际 %d）" % pool.size())
	var pool_ids := {}
	var has_banned := false
	for c in pool:
		pool_ids[c.id] = true
		if c.rarity >= 3:
			has_banned = true
	check(pool_ids.has(9002) and pool_ids.has(9003) and pool_ids.has(9004)
			and pool_ids.has(9005) and pool_ids.has(9006) and pool_ids.has(9007)
			and pool_ids.has(9010) and pool_ids.has(9011) and pool_ids.has(9016)
			and pool_ids.has(9019) and pool_ids.has(9035) and pool_ids.has(9036)
			and pool_ids.has(9037) and pool_ids.has(9038)
			and pool_ids.has(9039) and pool_ids.has(9040) and pool_ids.has(9041)
			and pool_ids.has(9042) and pool_ids.has(9043) and pool_ids.has(9045)
			and pool_ids.has(9046) and pool_ids.has(9051) and pool_ids.has(9052)
			and pool_ids.has(9053) and pool_ids.has(9054) and pool_ids.has(9055)
			and pool_ids.has(9056) and pool_ids.has(9057) and pool_ids.has(9058)
			and pool_ids.has(9059) and pool_ids.has(9060) and pool_ids.has(9061)
			and pool_ids.has(9062) and pool_ids.has(9084) and pool_ids.has(9085),
			"奖励池含 削弱/寒冰箭/骑兵/箭塔 以及 9035~9062 全部新卡")
	check(pool_ids.has(8019) and pool_ids.has(8020) and pool_ids.has(9110),
			"奖励池含 R55 三张新卡：地狱猫 8019 / 鲜血堡垒 8020 / 活力转移 9110")
	check(pool_ids.has(9111) and pool_ids.has(8021) and pool_ids.has(9112),
			"奖励池含 R56 三张新卡：暗影之刃 9111 / 黑暗领主 8021 / 暗影锁链 9112")
	check(pool_ids.has(9113) and pool_ids.has(8022) and pool_ids.has(8023) and pool_ids.has(9114),
			"奖励池含 R57 四张新卡：黑暗扩散 9113 / 地狱咏唱者 8022 / 黑暗祭坛 8023 / 无尽黑暗 9114")
	# R63：契约签订者 8024 是**玩家**普通卡 → 进池；恶魔鸭 9116 / 恶魔使魔 9117 是敌方怪物/效果卡 → 不进池
	check(pool_ids.has(8024) and not pool_ids.has(9116) and not pool_ids.has(9117),
			"R63 奖励池：契约签订者 8024 进池，恶魔鸭 9116 / 恶魔使魔 9117 不进池")
	check(not pool_ids.has(8001) and not pool_ids.has(8004) and not pool_ids.has(9001)
			and not pool_ids.has(9018) and not pool_ids.has(9020) and not pool_ids.has(9050),
			"初始卡（木栅栏 / 熊）/ 鸭子骑士 / 金属龙 / 鲸鱼之怒（事件卡） / 爆炎鸭（怪物）不在奖励池")
	check(not has_banned, "初始/怪物/事件稀有度被排除在奖励池外")

	# 注入模拟卡池测试分布（避免与真实卡 id 冲突，用 7xxx 段）
	for i in 10:
		repo._cards[7100 + i] = _mk(7100 + i, "普通卡%d" % i, 0)
	for i in 6:
		repo._cards[7200 + i] = _mk(7200 + i, "稀有卡%d" % i, 1)
	for i in 2:
		repo._cards[7300 + i] = _mk(7300 + i, "史诗卡%d" % i, 2)
	repo._cards[7401] = _mk(7401, "初始卡X", 3)
	repo._cards[7501] = _mk(7501, "怪物卡X", 4)
	repo._cards[7601] = _mk(7601, "事件卡X", 5)
	var pool2 := repo.reward_pool()
	check(pool2.size() == 146, "注入后奖励池 146 张（初始/怪物/事件卡不入池；实际 %d）" % pool2.size())
	var has_banned2 := false
	for c in pool2:
		if c.rarity >= 3:
			has_banned2 = true
	check(not has_banned2, "注入后初始/怪物/事件卡仍被排除")

	# ---- 抽取：数量与去重 ----
	var r := CardReward.roll(repo, "normal")
	check(r.size() == 3, "普通过关奖励给 3 张候选")
	var names := {}
	var dup_name := false
	for c in r:
		if names.has(c.card_name):
			dup_name = true
		names[c.card_name] = true
	check(not dup_name, "三张候选互不重名")
	var r5 := CardReward.roll(repo, "boss", 5)
	check(r5.size() == 5, "自定义数量 5 张也可抽取")

	# ---- 可复现（注入 rng） ----
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var ra := CardReward.roll(repo, "boss", 3, rng1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var rb := CardReward.roll(repo, "boss", 3, rng2)
	var same := ra.size() == rb.size()
	if same:
		for i in ra.size():
			if ra[i].id != rb[i].id:
				same = false
	check(same, "同 seed 注入结果完全可复现")

	# ---- 概率分布 sanity ----
	var n_samples := 4000
	var cnt := {"normal": [0, 0, 0], "boss": [0, 0, 0]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for t: String in ["normal", "boss"]:
		for i in n_samples:
			for c in CardReward.roll(repo, t, 3, rng):
				cnt[t][c.rarity] += 1
	var total := n_samples * 3
	var n_common := float(cnt["normal"][0]) / total
	var n_epic := float(cnt["normal"][2]) / total
	var b_epic := float(cnt["boss"][2]) / total
	check(n_common > 0.60 and n_common < 0.80,
			"普通奖励：普通卡占比 ≈ 70%%（实测 %.1f%%）" % (n_common * 100))
	check(n_epic > 0.005 and n_epic < 0.10,
			"普通奖励：史诗卡占比小且存在（实测 %.1f%%）" % (n_epic * 100))
	check(b_epic > 0.10 and b_epic < 0.32,
			"Boss奖励：史诗占比 ≈ 20%%（实测 %.1f%%）" % (b_epic * 100))

	check(CardReward.type_label("boss") == "Boss过关奖励", "奖励类型标签")

	print("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")
	quit(1 if fails > 0 else 0)
