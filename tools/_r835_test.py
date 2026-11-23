# -*- coding: utf-8 -*-
"""R835 测试：新增 _test_r835() 并注册。

覆盖：数据层 / 池子（含试玩版真实发放池）/ 计数（没道具不计、事件幂等、非事件不计、
首领每层一次）/ 接线（complete_current 是收口）/ 机制（0 页不动、N 页全体各 N 伤）。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
P = "scripts/test_engine.gd"

s = io.open(ROOT + P, encoding="utf-8", newline="").read()

# ── 注册 ─────────────────────────────────────────────────────────────────
old_reg = "\t_test_r830()\r\n"
if s.count(old_reg) != 1:
    print("!! 注册锚点 count=%d" % s.count(old_reg))
    sys.exit(1)
s = s.replace(old_reg, "\t_test_r830()\r\n\t_test_r835()\r\n", 1)

BODY = '''
func _test_r835() -> void:
	## R835（店长口径）：新增一层初始道具「空故事书」6089 ——
	## 战斗开始时对全体敌人造成「页数」点伤害；每经过一个事件房 / 打赢一个首领 +1 页。
	var repo := CardRepo.load_json()
	var rrepo := RelicRepo.load_json()

	# ── ① 数据层 ──
	var r835_sb := rrepo.get_relic(6089)
	check(r835_sb != null and r835_sb.relic_name == "空故事书"
			and r835_sb.kind == "战斗" and r835_sb.source == "初始" and r835_sb.tier == "一般",
			"R835 数据：6089 空故事书（战斗 · 初始 · 一般）")
	check(r835_sb.desc.contains("0 伤害") and r835_sb.desc.contains("+1")
			and r835_sb.desc.contains("首领战") and r835_sb.desc.contains("事件"),
			"R835 文案：写着 0 伤害 / 事件 / 首领战 / +1（%s）" % r835_sb.desc)
	check(GameEngine.STORY_BOOK_RELIC_ID == 6089 and RunState.STORY_BOOK_RELIC_ID == 6089,
			"R835 常量：引擎与局状态两个常量都认 6089")

	# ── ② 池子 ──
	check(rrepo.initial_ids().has(6089), "R835 池：空故事书在一层初始池")
	check(not rrepo.reward_ids().has(6089) and not rrepo.event_ids().has(6089)
			and not rrepo.layer2_ids().has(6089), "R835 池：不进奖励 / 事件 / 二层起始池")
	check(DemoScope.allows_relic(6089), "R835 试玩版：6089 在 demo_scope 基线里")
	GameBuild.set_test_demo(1)
	var r835_demo_init: Array[int] = rrepo.initial_ids()
	var r835_demo_start1: Array[int] = rrepo.start_ids_for_layer(1)
	var r835_demo_all: int = rrepo.all_relics().size()
	GameBuild.set_test_demo(-1)
	check(r835_demo_init.has(6089) and r835_demo_start1.has(6089) and r835_demo_all == 84,
			"R835 试玩版：demo 下初始池（%d 件）与第一层起点池都含 6089，all_relics 仍 84"
			% r835_demo_init.size())

	# ── ③ 计数：没这道具时走过的事件不补记 ──
	var r835_saved_relics := RunState.relics
	var r835_saved_pages := RunState.story_book_pages
	var r835_saved_nodes := RunState.story_book_nodes
	var r835_saved_cells := RunState.map_cells
	var r835_saved_cn := RunState.current_node_id
	var r835_saved_boss := RunState.boss_beaten
	RunState.relics = []
	RunState.story_book_pages = 0
	RunState.story_book_nodes = []
	RunState.map_cells = [{"id": 0, "type": "event", "layer": 1}]
	RunState.current_node_id = 0
	RunState._note_story_book_event(0)
	check(RunState.story_book_pages == 0,
			"R835 计数：没这道具时经过事件不累计（捡到之前的经历不算）")

	# ── ④ 计数：事件 +1 · 同节点幂等 · 非事件房不计 ──
	RunState.relics = [6089]
	RunState._note_story_book_event(0)
	check(RunState.story_book_pages == 1, "R835 计数：经过一个事件房 → 1 页")
	RunState._note_story_book_event(0)
	check(RunState.story_book_pages == 1, "R835 计数：同一事件重复结算只记 1 页")
	RunState.map_cells = [{"id": 1, "type": "chest", "layer": 1}]
	RunState._note_story_book_event(1)
	check(RunState.story_book_pages == 1, "R835 计数：宝箱不算事件（只有 event 房记页）")

	# ── ⑤ 计数：首领 —— 每层一次，换层再记 ──
	RunState.boss_beaten = false
	RunState.mark_boss_beaten()
	check(RunState.story_book_pages == 2, "R835 计数：打赢一个首领 → 再 +1 页")
	RunState.mark_boss_beaten()
	check(RunState.story_book_pages == 2, "R835 计数：同一层的首领重复结算不翻倍")
	RunState.boss_beaten = false
	RunState.mark_boss_beaten()
	check(RunState.story_book_pages == 3, "R835 计数：换层之后新首领再 +1 页")

	# ── ⑥ 接线：complete_current 是「事件记页」的收口 ──
	var r835_src := FileAccess.get_file_as_string("res://scripts/run_state.gd")
	check_src(r835_src.contains("_note_story_book_event(current_node_id)"),
			"R835 接线：complete_current 里调 _note_story_book_event（事件场景十余处都汇到它）")

	# ── ⑦ 机制：0 页不掉血；N 页对全体敌人各 N 伤 ──
	var r835_e := _new_engine([], 40, 40, -1, false)
	r835_e.self_relics = [GameEngine.STORY_BOOK_RELIC_ID]
	# 靶子用灰烬龙副本**清空 traits**：嘲讽 / 死亡（亡语）/ 减伤都不参与，
	# 只留下「一个会掉血的敌方单位」这一件事。
	var r835_pa := repo.get_card(1013).to_dict()
	r835_pa["traits"] = []
	var r835_pb := repo.get_card(1051).to_dict()
	r835_pb["traits"] = []
	var r835_a := r835_e.state.place(CardData.from_dict(r835_pa),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r835_b := r835_e.state.place(CardData.from_dict(r835_pb),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	check(r835_a != null and r835_b != null, "R835 机制：两个敌方单位上场")
	var r835_a0 := r835_a.health
	var r835_b0 := r835_b.health
	RunState.story_book_pages = 0
	r835_e._story_book_tick()
	check(r835_a.health == r835_a0 and r835_b.health == r835_b0,
			"R835 机制：0 页时一个都不掉血（空书）")
	RunState.story_book_pages = 3
	r835_e._story_book_tick()
	check(r835_a.health == r835_a0 - 3 and r835_b.health == r835_b0 - 3,
			"R835 机制：3 页 → 全体敌人各 -3（%d→%d / %d→%d）"
			% [r835_a0, r835_a.health, r835_b0, r835_b.health])

	# ── 还原全局状态（后面的用例不该看到这本测试用的书）──
	RunState.relics = r835_saved_relics
	RunState.story_book_pages = r835_saved_pages
	RunState.story_book_nodes = r835_saved_nodes
	RunState.map_cells = r835_saved_cells
	RunState.current_node_id = r835_saved_cn
	RunState.boss_beaten = r835_saved_boss
'''

BODY = BODY.replace("\n", "\r\n")
if not s.endswith("\r\n"):
    s += "\r\n"
s += BODY

io.open(ROOT + P, "w", encoding="utf-8", newline="").write(s)
b = io.open(ROOT + P, "rb").read()
print("ok  CRLF=%d LFonly=%d" % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
