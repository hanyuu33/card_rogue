# -*- coding: utf-8 -*-
"""R617：野兽之心 9036 多张真叠加（可重放补丁）。

用法：
    python tools/_patch_r617.py --check-only   # 干跑，只报锚点命中
    python tools/_patch_r617.py               # 落盘

三处改动：
  1. scripts/game_engine.gd  _ally_dmg_bonus() / _beast_hp_bonus() 改按「野性」张数累加
  2. cards.json              9036 effect_text 补「可叠加。」
  3. scripts/test_engine.gd  追加多张叠加回归用例

⚠️ 三个文件均为纯 CRLF；补丁在 \n 域内做 exact-replace + count==1 断言，
   写回统一还原 \r\n。并行线（R509）正在动 game_engine.gd / test_engine.gd，
   补丁只碰自己的锚点段落，绝不整文件覆盖。
"""
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHECK = "--check-only" in sys.argv


def load(rel):
    b = (ROOT / rel).read_bytes()
    crlf = b.count(b"\r\n")
    bare = b.count(b"\n") - crlf
    assert bare == 0, "%s: 存在裸 LF %d 行，先处理换行" % (rel, bare)
    return b.decode("utf-8").replace("\r\n", "\n"), crlf


def rep(s, old, new, tag):
    n = s.count(old)
    print("  [%s] anchor hits = %d" % (tag, n))
    assert n == 1, "%s: 期望 1 处锚点，实得 %d" % (tag, n)
    return s.replace(old, new, 1)


def save(rel, s, crlf):
    if CHECK:
        print("  (dry-run) %s 未写盘" % rel)
        return
    out = s.replace("\n", "\r\n").encode("utf-8")
    (ROOT / rel).write_bytes(out)
    chk = (ROOT / rel).read_bytes()
    assert chk.count(b"\r\n") == chk.count(b"\n"), "%s: 写盘后出现裸 LF" % rel
    print("  wrote %s (%d CRLF)" % (rel, chk.count(b"\r\n")))


# ---------------------------------------------------------------- 1. game_engine.gd
ENG_OLD1 = """func _ally_dmg_bonus(card: CardData, side: String) -> int:
	if card == null or card.kind != "盟友":
		return 0
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(BEAST_TRAIT):
			return BEAST_DMG_BONUS
	return 0
"""

ENG_NEW1 = """func _ally_dmg_bonus(card: CardData, side: String) -> int:
	## R617：野兽之心卡面写明「可叠加」——按效果区「野性」**张数**逐份累加，
	## 别再见到第一张就 return（那样界面画 3 张、结算只认 1 张）。
	## 与致命 9226（_zone_has 不叠加）相对，和恐惧化身 9230 同走 _zone_count()。
	if card == null or card.kind != "盟友":
		return 0
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	return _zone_count(zone, BEAST_TRAIT) * BEAST_DMG_BONUS
"""

ENG_OLD2 = """func _beast_hp_bonus(card: CardData) -> int:
	if card.kind != "盟友":
		return 0
	for c: CardData in state.effects:
		if c.traits.has(BEAST_TRAIT):
			return maxi(BEAST_HP_BONUS, c.value)
	return 0
"""

ENG_NEW2 = """func _beast_hp_bonus(card: CardData) -> int:
	## R617：与 _ally_dmg_bonus 同源，按「野性」张数逐份累加；保留 maxi(2, value)
	## 给 value 更大的产物留口（组合候选池不含效果卡，正常恒为 2）。
	if card.kind != "盟友":
		return 0
	var total := 0
	for c: CardData in state.effects:
		if c.traits.has(BEAST_TRAIT):
			total += maxi(BEAST_HP_BONUS, c.value)
	return total
"""

print("[1] scripts/game_engine.gd")
eng, eng_crlf = load("scripts/game_engine.gd")
eng = rep(eng, ENG_OLD1, ENG_NEW1, "_ally_dmg_bonus")
eng = rep(eng, ENG_OLD2, ENG_NEW2, "_beast_hp_bonus")
save("scripts/game_engine.gd", eng, eng_crlf)

# ---------------------------------------------------------------- 2. cards.json
CJ_OLD = '"effect_text": "我方所有盟友造成的伤害 +1；从手牌使用盟友时，该盟友获得 +2 生命。",'
CJ_NEW = '"effect_text": "我方所有盟友造成的伤害 +1；从手牌使用盟友时，该盟友获得 +2 生命。可叠加。",'

print("[2] cards.json")
cj, cj_crlf = load("cards.json")
cj = rep(cj, CJ_OLD, CJ_NEW, "9036 effect_text")
save("cards.json", cj, cj_crlf)

# ---------------------------------------------------------------- 3. test_engine.gd
TS_ANCHOR = """	check(beast_t != null and beast_t.health == 25,

			"野兽之心：工事不是盟友，不吃伤害 +1（5 点，30 → 25）")"""

TS_ADD = """

	# R617：野兽之心多张真叠加（效果区 N 张 → 盟友伤害 +N、落地盟友 +2N 生命）
	check(beast.effect_text.contains("可叠加"),
			"R617：野兽之心卡面写明「可叠加」")
	var eng_beast3 := _new_engine([], 20, 20, -1, false)
	eng_beast3.start_game(1)
	eng_beast3.state.hand = [beast, beast, beast]
	for _i in 3:
		eng_beast3.state.energy = 5
		eng_beast3.use_effect(0)
	check(eng_beast3.state.effects.size() == 3,
			"R617：三张野兽之心都进效果区（实际 %d 张）" % eng_beast3.state.effects.size())
	eng_beast3.state.hand = [_card(8003, "农民", "盟友", 3, 3, 8)]
	eng_beast3.state.energy = 5
	eng_beast3.play_from_hand(0, Vector2i(4, 0))
	var beast3_p: Placement = eng_beast3.state.unit_at(Vector2i(4, 0))
	check(beast3_p != null and beast3_p.health == 14,
			"R617：三张叠加 → 盟友 +6 生命（8 → 14）")
	eng_beast3.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 30), Vector2i(3, 0), "opponent")
	eng_beast3.attack(Vector2i(4, 0), Vector2i(3, 0))
	var beast3_q: Placement = eng_beast3.state.unit_at(Vector2i(3, 0))
	check(beast3_q != null and beast3_q.health == 24,
			"R617：三张叠加 → 盟友伤害 +3（3 + 3 = 6，30 → 24）")"""

print("[3] scripts/test_engine.gd")
ts, ts_crlf = load("scripts/test_engine.gd")
ts = rep(ts, TS_ANCHOR, TS_ANCHOR + TS_ADD, "R617 测试段插入点")
save("scripts/test_engine.gd", ts, ts_crlf)

print("DONE" + " (dry-run)" if CHECK else " DONE")
