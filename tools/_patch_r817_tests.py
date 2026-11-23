# -*- coding: utf-8 -*-
"""R817：修 R814 的计数口径（被禁卡表污染），并追加 R817 基线守卫用例。

test_engine.gd 是 CRLF —— 统一走 `crlf()` 归一，写完复查行尾。
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = "scripts/test_engine.gd"
P = os.path.join(ROOT, REL)


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n")


t = io.open(P, encoding="utf-8", newline="").read()
assert "_test_r815" not in t, "test_engine 已打过 R817 补丁"


def rep(old, new, tag):
    global t
    o, n = crlf(old), crlf(new)
    c = t.count(o)
    assert c == 1, "[%s] 锚点命中 %d 次（应为 1）" % (tag, c)
    t = t.replace(o, n)


# ── ① 卡池计数：reward_pool_for → 本职业自有卡 ─────────────────────────────
rep(
    '''	for r814_cid: String in [PlayerClass.DRUID, PlayerClass.ROGUE]:
		var r814_pool := r814_repo.reward_pool_for(r814_cid)
		check(r814_pool.size() == 60,
				"R814 卡池：%s 奖励池 = 60 张（实际 %d）" % [r814_cid, r814_pool.size()])
''',
    '''	for r814_cid: String in [PlayerClass.DRUID, PlayerClass.ROGUE]:
		# R817：口径从 `reward_pool_for()` 换成「本职业自有卡」。前者会再减掉玩家账号
		# 禁卡表里的卡（本机森林精魄禁了 4 张），于是「60 张」实际是「本机 60 张」，
		# 换台机器 / 玩家解禁就变 61/63 —— 内容条数必须与玩家档案无关。
		var r814_pool: Array[CardData] = []
		for r814_c: CardData in r814_repo.obtainable_cards():
			if r814_c.card_class == r814_cid:
				r814_pool.append(r814_c)
		check(r814_pool.size() == 60,
				"R814 卡池：%s 自有卡 = 60 张（实际 %d）" % [r814_cid, r814_pool.size()])
''', "pool count")

# ── ② 组合入口三张：同样的口径修正 ─────────────────────────────────────────
rep(
    '''		for r814_c: CardData in r814_repo.reward_pool_for(r814_cls):
			if r814_c.id == r814_id:
				r814_hit = true
		check(r814_hit, "R814 组合：%d 在 %s 的试玩版奖励池里" % [r814_id, r814_cls])
''',
    '''		for r814_c: CardData in r814_repo.obtainable_cards():
			if r814_c.id == r814_id and r814_repo.is_own_class_card(r814_c, r814_cls):
				r814_hit = true
		check(r814_hit, "R814 组合：%d 在 %s 的试玩版可获得池里" % [r814_id, r814_cls])
''', "combo three")

# ── ③ 剧情锁卡 9187：同样的口径修正 ────────────────────────────────────────
rep(
    '''	var r814_goose_in := false
	for r814_c: CardData in r814_repo.reward_pool_for(PlayerClass.DRUID):
		if r814_c.id == 9187:
			r814_goose_in = true
	check(not r814_goose_in, "R814 剧情：剧情锁卡不在试玩版奖励池里")
''',
    '''	var r814_goose_in := false
	for r814_c: CardData in r814_repo.obtainable_cards():
		if r814_c.id == 9187:
			r814_goose_in = true
	check(not r814_goose_in, "R814 剧情：剧情锁卡（鹅 9187）不在试玩版可获得池里")
''', "goose")

# ── ④ 注册调用 ─────────────────────────────────────────────────────────────
rep(
    '\t_test_r814()\n',
    '\t_test_r814()\n\t_test_r815()\n',
    "register")

# ── ⑤ 追加 R817 用例 ───────────────────────────────────────────────────────
body = '''

func _test_r815() -> void:
	## R817：试玩版「**修复跟着走、新增不跟着走**」的机制守卫。
	## 判据全部落在 `demo_scope.json`（准入白名单）上：老内容改数值 / 修 bug 用的是同一个
	## id，自动同步；新内容 id 不在表里，默认不进试玩。要放新品进去必须显式改基线 ——
	## 本用例会当场发现「加了内容却没决定去留」的漂移。
	var r815_repo := CardRepo.load_json()
	var r815_relics := RelicRepo.load_json()
	var r815_traps := TrapRepo.load_json()

	GameBuild.set_test_demo(1)

	# ── ① 基线文件本身：读不进来会 fail-open（试玩版多给内容），必须当场发现 ──
	check(DemoScope.is_loaded_ok(),
			"R817 基线：demo_scope.json 已加载（丢了会 fail-open，新增内容会漏进试玩）")

	# ── ② 条目数 = 试玩版真实内容量。改这几个数之前先确认店长的需求有没有变 ──
	check(DemoScope.baseline_count("cards") == 120,
			"R817 基线：卡 = 120 张（森林精魄 60 + 暗影刺客 60，实际 %d）"
			% DemoScope.baseline_count("cards"))
	check(DemoScope.baseline_count("relics") == r815_relics.all_relics().size(),
			"R817 基线：道具 = relics.json 全量 %d 件（试玩版一件不裁）"
			% r815_relics.all_relics().size())
	check(DemoScope.baseline_count("traps") == 16,
			"R817 基线：工具 = 16 件（实际 %d）" % DemoScope.baseline_count("traps"))
	check(DemoScope.baseline_count("events") == 24,
			"R817 基线：事件 = 24 种子类型（一层 12 + 二层 16，去重后 24，实际 %d）"
			% DemoScope.baseline_count("events"))

	# ── ③ 基线不许留脏：表里的每个 id 都必须在数据文件里真实存在 ──
	# （删卡 / 删道具之后忘了同步基线，就是这里红 —— 不会静默变成「少一张」）
	var r815_dirty: Array[String] = []
	for r815_id: Variant in DemoScope.baseline_ids("cards"):
		if r815_repo.get_card(int(r815_id)) == null:
			r815_dirty.append("卡 %d" % int(r815_id))
	for r815_id: Variant in DemoScope.baseline_ids("relics"):
		if r815_relics.get_relic(int(r815_id)) == null:
			r815_dirty.append("道具 %d" % int(r815_id))
	for r815_id: Variant in DemoScope.baseline_ids("traps"):
		if r815_traps.get_trap(int(r815_id)) == null:
			r815_dirty.append("工具 %d" % int(r815_id))
	check(r815_dirty.is_empty(),
			"R817 基线：表里的条目都还在数据文件里（残留 %s）" % str(r815_dirty))

	# ── ④ 新增内容默认**不进**试玩版：不在表里的 id 一律 false ──
	check(not DemoScope.allows_card(999999), "R817 新增：未登记的卡 id 不进试玩")
	check(not DemoScope.allows_relic(9999), "R817 新增：未登记的道具 id 不进试玩")
	check(not DemoScope.allows_trap(7999), "R817 新增：未登记的工具 id 不进试玩")
	check(not DemoScope.allows_event("__r815_new_event__"),
			"R817 新增：未登记的事件子类型不进试玩")

	# 真实对象也挡得住（造一张「明天新加的卡」：森林精魄、普通档、id 不在基线）
	var r815_fake := CardData.new()
	r815_fake.id = 999998
	r815_fake.card_class = PlayerClass.DRUID
	r815_fake.rarity = 0
	check(not CardRepo.demo_allows(r815_fake),
			"R817 新增：一张没登记的卡在试玩版里「不存在」（图鉴 / 奖励 / 商店同源）")
	check(not r815_repo.obtainable_cards().any(func(c: CardData): return c.id == 999998),
			"R817 新增：这张卡也确实没进可获得池")

	# ── ⑤ 修复自动跟随：基线内的老内容照常可用（改数值 / 修 bug 不碰本表）──
	check(CardRepo.demo_allows(r815_repo.get_card(8001)),
			"R817 修复：基线内的老卡（木栅栏 8001）照常在试玩版 —— 改它的数据不用动基线")

	# ── ⑥ 同一条规则在测试版 / 发布版**完全不生效** ──
	GameBuild.set_test_demo(-1)
	check(CardRepo.demo_allows(r815_fake),
			"R817 隔离：切回测试版后，同一张未登记的卡照常存在（基线不误伤正式流程）")
	check(DemoScope.baseline_count("cards") == 120,
			"R817 隔离：基线的存在与否不影响测试版内容量")

	# ── ⑦ 复位 ──
	GameBuild.set_test_demo(-1)
	GameBuild.set_test_release(-1)
	check(not GameBuild.is_demo() and not GameBuild.is_release(),
			"R817 复位：用例结束后回到测试版口径")
'''.replace("\n", "\r\n")

assert t.endswith("\r\n"), "文件末尾不是换行"
t = t + body
io.open(P, "w", encoding="utf-8", newline="").write(t)
print("test_engine.gd: R814 口径修正 + R817 用例追加")
b = io.open(P, encoding="utf-8", newline="").read()
print("CRLF", b.count("\r\n"), "LFonly", b.count("\n") - b.count("\r\n"))
