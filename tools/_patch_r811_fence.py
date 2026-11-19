# -*- coding: utf-8 -*-
"""R811：初始道具「栅栏修复术」6021 加强 —— 叠加后栅栏**回满血**。

旧口径：`_merge_fence` 只把「新栅栏的生命」加到当前值（2/6 的残墙 + 6 → 8/12），
一堵被打残的墙叠上去等于白亏一截。
新口径：上限相加之后**直接把当前值填满**（2/6 + 6 → 12/12）。

回满读 `p.card.health` —— 它 = 基础 + fence_bonus_hp + relic_bonus_hp + upgrade_hp，
与 `_card_leaving_field` 的还原公式同源，所以回满天然含板甲 / 墙砖 / 改造的加成。

⚠️ 只改**当前值**，上限口径与离场还原一律不动（`fence_bonus_hp` 照旧累加）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def read(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def write(rel, text):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(text)


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次（应为 1）" % (tag, n)
    return text.replace(old, new)


# ─────────────────────────── ① 引擎：合并即回满 ───────────────────────────
p = "scripts/game_engine.gd"
s = read(p)

s = sub(s,
        "\t## 两张栅栏合并成一张：生命值相加、特性取并集（效果叠加）。",
        "\t## 两张栅栏合并成一张：生命值相加、特性取并集（效果叠加），**并把当前生命回满**（R811）。",
        "doc")

OLD = ("\tp.card = merged\r\n"
       "\tp.fence_bonus_hp += card.health\r\n"
       "\tp.health += card.health\r\n")
NEW = ("\tp.card = merged\r\n"
       "\tp.fence_bonus_hp += card.health\r\n"
       "\t# R811：**叠加即回满**。旧行为只把「新栅栏的生命」加到当前值 —— 2/6 的残墙叠一张\r\n"
       "\t# 6 血木栅栏只到 8/12，等于白亏一截；现在上限相加之后直接把当前值填满。\r\n"
       "\t# 读 `p.card.health`（= 基础 + fence_bonus_hp + relic_bonus_hp + upgrade_hp，与\r\n"
       "\t# `_card_leaving_field` 的还原公式同源），所以回满天然包含板甲 / 墙砖 / 改造的加成。\r\n"
       "\t# ⚠️ 只改**当前值**：上限口径与离场还原一律不动（`fence_bonus_hp` 照旧累加）。\r\n"
       "\tp.health = p.card.health\r\n")
s = sub(s, OLD, NEW, "merge")
write(p, s)

# ─────────────────────────── ② 演出：气泡点明回满 ───────────────────────────
p = "scripts/battle_scene.gd"
s = read(p)
s = sub(s,
        '_say("▣ 栅栏修复术：两张栅栏合并 → %s 生命 %d" % [fm_name,',
        '_say("▣ 栅栏修复术：两张栅栏合并 → %s 生命 %d（回满）" % [fm_name,',
        "say")
write(p, s)

# ─────────────────────────── ③ 描述：中文 canonical + 三语 ───────────────────────────
DESCS = [
    ("relics.json",
     "【栅栏】卡可以打在已有栅栏的格子上，两张栅栏合并为一张，生命值与特性叠加。",
     "【栅栏】卡可以打在已有栅栏的格子上，两张栅栏合并为一张，生命上限相加并回满，特性叠加。"),
    ("i18n/noncard_zh_canonical.json",
     "【栅栏】卡可以打在已有我方栅栏的格子上，两张栅栏合并为一张：生命相加，特性合并，同名特性不重复。",
     "【栅栏】卡可以打在已有我方栅栏的格子上，两张栅栏合并为一张：生命上限相加并回满，特性合并，同名特性不重复。"),
    ("i18n/noncard_en.json",
     "Fence cards can be played on tiles that already contain a friendly Fence. "
     "The Fences merge into one, adding their Health together and combining their traits "
     "without duplicating identical traits.",
     "Fence cards can be played on tiles that already contain a friendly Fence. "
     "The Fences merge into one: their maximum Health adds together and the merged Fence "
     "is healed to full, and their traits combine without duplicating identical traits."),
    ("i18n/noncard_ja.json",
     "【柵】カードは既に味方の柵があるマスにも使用でき、2枚の柵は1枚に統合される："
     "HPを合算し、特性も統合するが、同名の特性は重複しない。",
     "【柵】カードは既に味方の柵があるマスにも使用でき、2枚の柵は1枚に統合される："
     "HP上限を合算して全回復し、特性も統合するが、同名の特性は重複しない。"),
    ("i18n/noncard_es.json",
     "Las cartas de Valla se pueden jugar en casillas que ya contengan una Valla aliada. "
     "Las Vallas se fusionan en una, suman su Vida y combinan sus rasgos sin duplicar los rasgos idénticos.",
     "Las cartas de Valla se pueden jugar en casillas que ya contengan una Valla aliada. "
     "Las Vallas se fusionan en una: sus máximos de Vida se suman y la Valla fusionada recupera "
     "toda su Vida, y sus rasgos se combinan sin duplicar los rasgos idénticos."),
]
for rel, old, new in DESCS:
    s = read(rel)
    s = sub(s, old, new, rel)
    write(rel, s)

# ─────────────────────────── ④ 测试：注册 + 新增函数 ───────────────────────────
p = "scripts/test_engine.gd"
s = read(p)
s = sub(s, "\t_test_r809()\r\n\t_test_r810()\r\n", "\t_test_r809()\r\n\t_test_r810()\r\n\t_test_r811()\r\n", "reg")

BLOCK = '''
func _test_r811() -> void :
	## R811：初始道具「栅栏修复术」6021 加强 —— **叠加后栅栏回满血**。
	## 旧口径只把「新栅栏的生命」加到当前值（2/6 的残墙叠一张 6 血木栅栏只到 8/12），
	## 一堵被打残的墙叠上去等于白亏一截。新口径 = 上限相加之后**直接把当前值填满**。
	var r811_repo := CardRepo.load_json()

	# ── ① 残墙 + 同款木栅栏 → 上限 12、直接回满 ──
	var r811_e1 := _new_engine([], 20, 20, -1, false)
	r811_e1.self_relics = [6021]
	r811_e1.start_game()
	var r811_p1 := r811_e1.state.place(r811_repo.get_card(8001), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r811_p1.health = 2                                  # 打成 2/6 的残墙
	r811_e1.state.hand = [CardData.from_dict(r811_repo.get_card(8001).to_dict())]
	r811_e1.state.energy = 5
	var r811_ev: Array = []
	r811_e1.action.connect(func(k: String, d: Dictionary) -> void:
		if k == "fence_merge":
			r811_ev.append(int(d.get("gained", -1))))
	r811_e1.play_from_hand(0, Vector2i(4, 1))
	check(r811_p1.health == 12 and r811_p1.card.health == 12,
			"R811 栅栏回满：2/6 的残墙叠一张木栅栏 → 12/12（旧行为只会到 8/12）")
	check(r811_ev.size() == 1 and int(r811_ev[0]) == 10,
			"R811 栅栏回满：飘字按「实际涨了多少」算（2 → 12 = +10），不是新栅栏的 6")

	# ── ② 残墙 + 铁栅栏 → 上限 6+12=18 并回满（跨种类叠加同样回满）──
	var r811_e2 := _new_engine([], 20, 20, -1, false)
	r811_e2.self_relics = [6021]
	r811_e2.start_game()
	var r811_p2 := r811_e2.state.place(r811_repo.get_card(9072), Vector2i(3, 1), GameEngine.SIDE_SELF)
	r811_p2.health = 3                                  # 3/12 的铁栅栏
	r811_e2.state.hand = [CardData.from_dict(r811_repo.get_card(8001).to_dict())]
	r811_e2.state.energy = 5
	r811_e2.play_from_hand(0, Vector2i(3, 1))
	check(r811_p2.health == 18 and r811_p2.card.health == 18,
			"R811 栅栏回满：3/12 的铁栅栏叠一张木栅栏 → 18/18（上限 12+6 并回满）")

	# ── ③ 回满只动当前值：离场交出去的仍是原始卡 ──
	var r811_out := r811_e1._card_leaving_field(r811_p1)
	check(r811_out != null and r811_out.health == 6 and not r811_out.traits.has("铁栅栏"),
			"R811 栅栏回满：上限仍由 fence_bonus_hp 还原（离场交回 6 血原卡、没偷来的特性）")
	var r811_out2 := r811_e2._card_leaving_field(r811_p2)
	var r811_tr2: Array = r811_out2.traits if r811_out2 != null else []
	check(r811_out2 != null and r811_out2.health == 12 and r811_tr2.has("铁栅栏") and not r811_tr2.has("防御"),
			"R811 栅栏回满：铁栅栏离场还原成 12 血、特性只留自己的（叠来的「防御」被摘掉）")

	# ── ④ 没道具 → 不触发合并（残墙一滴血都不涨）──
	## 注：这里打的是**空地**。无道具时把栅栏拍到已占用格上会走到 `state.place` 直接覆盖，
	## 那是另一条既存路径（界面根本点不出来），与本轮无关，别拿它当断言。
	var r811_e3 := _new_engine([], 20, 20, -1, false)
	r811_e3.start_game()
	var r811_p3 := r811_e3.state.place(r811_repo.get_card(8001), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r811_p3.health = 2
	r811_e3.state.hand = [CardData.from_dict(r811_repo.get_card(8001).to_dict())]
	r811_e3.state.energy = 5
	var r811_ev3: Array = []
	r811_e3.action.connect(func(k: String, _d: Dictionary) -> void:
		if k == "fence_merge":
			r811_ev3.append(k))
	r811_e3.play_from_hand(0, Vector2i(4, 0))          # 4,0 是空着的己方格
	check(r811_ev3.is_empty() and r811_p3.health == 2,
			"R811 栅栏回满：没「栅栏修复术」时不触发合并、残墙不被回血")

	# ── ⑤ 源码守卫（口径不许被后来的改动悄悄改回去）──
	var r811_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r811_src.contains("p.health = p.card.health"),
			"R811 守卫：`_merge_fence` 用 `p.health = p.card.health` 回满")
	check_src(not r811_src.contains("p.health += card.health"),
			"R811 守卫：旧的 `p.health += card.health`（只加新栅栏血量）已移除")
'''
s = s + BLOCK.replace("\n", "\r\n").lstrip("\r\n")
write(p, s)

print("R811 patch OK")
