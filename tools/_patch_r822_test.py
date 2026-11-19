# -*- coding: utf-8 -*-
"""R822：追加 `_test_r822`（鸭绅士事件）并在 runner 里注册。

test_engine.gd 是 CRLF —— 一律按字节写，不交给编辑工具。
"""
import io
import os

ROOT = r"E:\work\card_rogue"
P = os.path.join(ROOT, "scripts", "test_engine.gd")

with io.open(P, encoding="utf-8", newline="") as f:
    src = f.read()

# ── ① 注册 ──
reg_old = "\t_test_r819()\r\n"
assert src.count(reg_old) == 1, "注册点 _test_r819() 命中 %d 次" % src.count(reg_old)
src = src.replace(reg_old, reg_old + "\t_test_r822()\r\n")

# ── ② 追加函数体 ──
FUNC = '''
func _test_r822() -> void:
	## R822（店长口径）：第二层起点**新增「鸭绅士」这场事件，与卷卷权重相等**；
	## 4 件「带鸭」的道具归属移到鸭绅士；依然是随机 3 选 1。
	##
	## 四条容易被写漏的判据：
	##   ① 「遇到谁」必须由**种子派生**（不摇 rng、不进存档）—— 存场景变量 / 存档里，
	##      退出去再进就能重摇，等于让玩家自选主持人（R819 占卜室的原坑）。
	##   ② 两位主持人的道具池**互斥**，且并集必须还是原来那 9 件 —— 少一件就是内容凭空蒸发。
	##   ③ 「带鸭」的判据用**名字里有没有「鸭」**，不写死 id 名单：以后新增带鸭道具会自动归位。
	##   ④ 试玩版不进鸭绅士（R817「新增不跟着走」），但那 4 件要留在卷卷池里发得出去。
	var r822_seed_bak := RunState.run_seed
	var r822_rng_seed_bak := RunState.run_rng.seed
	var r822_rng_state_bak := RunState.run_rng.state
	var r822_relics := RelicRepo.load_json()

	# ── ① 派生稳定：同一种子，反复问都是同一位 ──
	RunState.run_seed = 424242
	var r822_a := RunState.layer2_host()
	var r822_b := RunState.layer2_host()
	check(r822_a == r822_b,
			"R822 宿主：同一种子两次调用必然同一位（%d / %d）" % [r822_a, r822_b])

	# ── ② 不花随机数：连问 20 次，run_rng 的状态一格不动 ──
	# （动了就说明它偷用了顺序链，同种子重跑的地图 / 掉落会跟着变）
	var r822_state0 := RunState.run_rng.state
	for _r822_i in 20:
		RunState.layer2_host()
	check(RunState.run_rng.state == r822_state0,
			"R822 宿主：派生不消耗 run_rng（状态 %d → %d）" % [r822_state0, RunState.run_rng.state])

	# ── ③ 与 rng 状态无关：把随机源打乱，答案不许变 ──
	RunState.run_rng.seed = 999
	var r822_c := RunState.layer2_host()
	RunState.run_rng.seed = 1
	var r822_d := RunState.layer2_host()
	check(r822_c == r822_a and r822_d == r822_a,
			"R822 宿主：只认种子，不认 rng 当前状态（%d / %d / %d）" % [r822_a, r822_c, r822_d])

	# ── ④ 权重相等：扫 1000 个种子，鸭绅士那一边落在 40%~60% ──
	var r822_cnt := [0, 0]
	for r822_s in 1000:
		var r822_h := RunState.layer2_host(r822_s)
		r822_cnt[r822_h] = int(r822_cnt[r822_h]) + 1
	var r822_ratio := float(r822_cnt[1]) / 1000.0
	check(r822_ratio > 0.40 and r822_ratio < 0.60,
			"R822 宿主：权重相等（鸭绅士 %.1f%%）" % (r822_ratio * 100.0))
	check(int(r822_cnt[0]) > 0 and int(r822_cnt[1]) > 0,
			"R822 宿主：两种结果都能出现（卷卷 %d / 鸭绅士 %d）" % [int(r822_cnt[0]), int(r822_cnt[1])])

	# ── ⑤ 池子分流：9 = 5 + 4，互不重叠 ──
	var r822_all := r822_relics.layer2_ids()
	var r822_duck := r822_relics.duck_host_ids()
	var r822_bun := r822_relics.layer2_ids_for(RunState.LAYER2_HOST_BUNBUN)
	var r822_duck_pool := r822_relics.layer2_ids_for(RunState.LAYER2_HOST_DUCK)
	check(r822_all.size() == 9, "R822 池：二层起始池全量仍是 9 件（实际 %d）" % r822_all.size())
	check(r822_duck.size() == 4, "R822 池：鸭绅士 4 件（实际 %d）" % r822_duck.size())
	check(r822_bun.size() == 5, "R822 池：卷卷 5 件（实际 %d）" % r822_bun.size())
	check(r822_duck_pool == r822_duck, "R822 池：遇到鸭绅士时出的就是那 4 件")
	var r822_overlap: Array[int] = []
	for r822_id: int in r822_bun:
		if r822_duck.has(r822_id):
			r822_overlap.append(r822_id)
	check(r822_overlap.is_empty(), "R822 池：两位主持人的池子不重叠（重叠 %s）" % str(r822_overlap))
	var r822_union := r822_bun.duplicate()
	for r822_id2: int in r822_duck:
		if not r822_union.has(r822_id2):
			r822_union.append(r822_id2)
	check(r822_union.size() == 9,
			"R822 池：5 + 4 = 原 9 件，一件没丢（实际 %d）" % r822_union.size())

	# ── ⑥ 归属：名字带「鸭」的道具全部在鸭绅士池，鸭绅士池里也只有带鸭的 ──
	var r822_missing: Array[String] = []
	for r822_id3: int in r822_all:
		var r822_rel := r822_relics.get_relic(r822_id3)
		if r822_rel == null:
			continue
		if r822_rel.relic_name.contains("鸭") and not r822_duck.has(r822_id3):
			r822_missing.append("%d %s" % [r822_id3, r822_rel.relic_name])
	check(r822_missing.is_empty(),
			"R822 归属：带「鸭」的道具都归鸭绅士（漏 %s）" % str(r822_missing))
	var r822_extra: Array[String] = []
	for r822_id4: int in r822_duck:
		var r822_rel2 := r822_relics.get_relic(r822_id4)
		if r822_rel2 == null or not r822_rel2.relic_name.contains("鸭"):
			r822_extra.append(str(r822_id4))
	check(r822_extra.is_empty(),
			"R822 归属：鸭绅士池里只有带鸭道具（多出 %s）" % str(r822_extra))

	# ── ⑦ 三选一：两位都凑得出 3 件不重复 ──
	for r822_host: int in [RunState.LAYER2_HOST_BUNBUN, RunState.LAYER2_HOST_DUCK]:
		var r822_pool := r822_relics.layer2_ids_for(r822_host)
		var r822_bag := r822_pool.duplicate()
		var r822_pick: Array[int] = []
		while r822_pick.size() < 3 and not r822_bag.is_empty():
			r822_pick.append(r822_bag.pop_front())
		var r822_uniq: Dictionary = {}
		for r822_p: int in r822_pick:
			r822_uniq[r822_p] = true
		check(r822_pick.size() == 3,
				"R822 三选一：host=%d 能凑够 3 件（池 %d）" % [r822_host, r822_pool.size()])
		check(r822_uniq.size() == r822_pick.size(),
				"R822 三选一：host=%d 的 3 件互不重复" % r822_host)

	# ── ⑧ 文案：三个职业都有自己的两句，且与卷卷那套不同 ──
	check(CurtainLines.speaker_of(CurtainLines.HOST_DUCK)
			!= CurtainLines.speaker_of(CurtainLines.HOST_BUNBUN),
			"R822 文案：两位主持人的名称牌不同")
	for r822_cls: String in [PlayerClass.DRUID, PlayerClass.ROGUE, PlayerClass.MECH]:
		var r822_g := CurtainLines.greeting(GameLayers.LAYER_TWO, r822_cls, CurtainLines.HOST_DUCK)
		var r822_r := CurtainLines.reply(GameLayers.LAYER_TWO, r822_cls, CurtainLines.HOST_DUCK)
		check(r822_g != "" and not r822_g.begins_with("CURTAIN_"),
				"R822 文案：%s 的招呼取到了（%s）" % [r822_cls, r822_g])
		check(r822_r != "" and not r822_r.begins_with("CURTAIN_"),
				"R822 文案：%s 的回答取到了（%s）" % [r822_cls, r822_r])
		check(r822_g != CurtainLines.greeting(GameLayers.LAYER_TWO, r822_cls,
				CurtainLines.HOST_BUNBUN),
				"R822 文案：%s 鸭绅士那句与卷卷那句不是同一句" % r822_cls)
		check(r822_g != r822_r, "R822 文案：%s 招呼与回答不重复" % r822_cls)
		check(CurtainLines.greeting(GameLayers.LAYER_DEFAULT, r822_cls, CurtainLines.HOST_DUCK)
				== CurtainLines.greeting(GameLayers.LAYER_DEFAULT, r822_cls,
						CurtainLines.HOST_BUNBUN),
				"R822 文案：第一层恒为卷卷（鸭绅士只在第二层起点出场）")
	check(CurtainLines.has_reply(GameLayers.LAYER_TWO, CurtainLines.HOST_DUCK),
			"R822 文案：鸭绅士也是「对方一句 + 玩家一句」的两句制")
	check(not CurtainLines.has_reply(GameLayers.LAYER_DEFAULT, CurtainLines.HOST_DUCK),
			"R822 文案：第一层不出回答")

	# ── ⑨ 四语齐：新加的 7 个 key 在 en / ja / es 里都有字 ──
	var r822_keys := ["CURTAIN_DUCK_SPEAKER", "CURTAIN_DUCK_GREETING_DRUID",
			"CURTAIN_DUCK_GREETING_ROGUE", "CURTAIN_DUCK_GREETING_MECH",
			"CURTAIN_DUCK_REPLY_DRUID", "CURTAIN_DUCK_REPLY_ROGUE",
			"CURTAIN_DUCK_REPLY_MECH"]
	for r822_lang: String in ["zh", "en", "ja", "es"]:
		var r822_name := "interface_zh_canonical.json" if r822_lang == "zh" \
				else "interface_%s.json" % r822_lang
		var r822_file := FileAccess.open("res://i18n/" + r822_name, FileAccess.READ)
		check(r822_file != null, "R822 文案：%s 表可读" % r822_lang)
		if r822_file == null:
			continue
		var r822_data: Variant = JSON.parse_string(r822_file.get_as_text())
		var r822_rows: Dictionary = {}
		if r822_data is Dictionary:
			var r822_scopes: Variant = (r822_data as Dictionary).get("scopes", {})
			if r822_scopes is Dictionary:
				var r822_shell: Variant = (r822_scopes as Dictionary).get("shell", {})
				if r822_shell is Dictionary:
					r822_rows = r822_shell
		var r822_lack: Array[String] = []
		for r822_k: String in r822_keys:
			if not r822_rows.has(r822_k):
				r822_lack.append(r822_k)
				continue
			var r822_cell: Variant = r822_rows[r822_k]
			var r822_text := ""
			if r822_cell is Dictionary:
				r822_text = str((r822_cell as Dictionary).get("zh", ""))
			else:
				r822_text = str(r822_cell)
			if r822_text.strip_edges() == "":
				r822_lack.append(r822_k)
		check(r822_lack.is_empty(),
				"R822 文案：%s 七条齐全（缺 %s）" % [r822_lang, str(r822_lack)])

	# ── ⑩ 背景素材在位（缺图会退回暗底，看着像「事件没加载」）──
	check(CurtainLines.backdrop_name(CurtainLines.HOST_DUCK) == "bg_curtain_duck",
			"R822 素材：鸭绅士走 bg_curtain_duck")
	check(CurtainLines.backdrop_name(CurtainLines.HOST_BUNBUN) == "bg_curtain",
			"R822 素材：卷卷仍走 bg_curtain（老图不动）")
	check(ResourceLoader.exists("res://assets/ui/bg_curtain_duck.png"),
			"R822 素材：bg_curtain_duck.png 在包里")

	# ── ⑪ 试玩版：不进鸭绅士，但那 4 件要留在卷卷池发得出去 ──
	GameBuild.set_test_demo(1)
	check(RunState.layer2_host(424242) == RunState.LAYER2_HOST_BUNBUN,
			"R822 试玩版：恒为卷卷（鸭绅士是新增内容，按 R817 不进试玩）")
	check(r822_relics.layer2_ids_for(RunState.LAYER2_HOST_BUNBUN).size() == 9,
			"R822 试玩版：卷卷池仍是 9 件（鸭绅士不在，4 件不能凭空消失）")
	GameBuild.set_test_demo(-1)
	check(RunState.layer2_host(424242) == r822_a,
			"R822 试玩版：关掉注入后回到派生值")

	# ── ⑫ 老调用点不受影响：不传 host 按卷卷算 ──
	check(r822_relics.start_ids_for_layer(GameLayers.LAYER_TWO) == r822_bun,
			"R822 兼容：start_ids_for_layer(2) 省略 host 时仍是卷卷池")

	# ── 还原现场 ──
	RunState.run_seed = r822_seed_bak
	RunState.run_rng.seed = r822_rng_seed_bak
	RunState.run_rng.state = r822_rng_state_bak
'''

assert "func _test_r822()" not in src, "已经加过了"
src = src.rstrip("\r\n") + "\r\n" + FUNC.replace("\n", "\r\n").rstrip("\r\n") + "\r\n"

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(src)

b = io.open(P, encoding="utf-8", newline="").read()
print("OK | CRLF", b.count("\r\n"), "| LF-only", b.count("\n") - b.count("\r\n"),
      "| _test_r822", b.count("_test_r822"))
