# -*- coding: utf-8 -*-
"""R690 引擎补丁：水元素改抓漩涡（_water_element_fetch）。

用法：python tools/_patch_r690_engine.py [--write]
"""
import sys

WRITE = "--write" in sys.argv
PATH = "scripts/game_engine.gd"


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    assert raw.count("\r\n") == raw.count("\n"), path + " 不是纯 CRLF"
    return raw.replace("\r\n", "\n")


def save(path, txt):
    open(path, "wb").write(txt.replace("\n", "\r\n").encode("utf-8"))
    b = open(path, "rb").read()
    print("  %s → CRLF %d / LF %d / 杂散 CR %d" % (
        path, b.count(b"\r\n"), b.count(b"\n"), b.count(b"\r") - b.count(b"\r\n")))


src = load(PATH)
out = src


def rep(old, new, tag):
    global out
    c = out.count(old)
    assert c == 1, "[%s] 锚点命中 %d 次" % (tag, c)
    out = out.replace(old, new)


# ① 常量：漩涡 9186（水元素现在抓的场地卡）
rep('''const AETHER_DEMON_TRAIT:= "水元素"
const DEMON_FETCH_DISCOUNT:= 2
''',
    '''const AETHER_DEMON_TRAIT:= "水元素"
# R690：水元素「使用时」给的那张场地卡 = 漩涡 9186。它是剧情卡（`locked`，卡组里没有），
# 水元素目前是它**唯一的获得渠道** —— 所以这里按卡库造卡，不查牌库。
const WATER_VORTEX_ID:= 9186
const DEMON_FETCH_DISCOUNT:= 2
''', "常量")

# ② 入场触发改指向新实现口
rep('''	if card.id == AETHER_DEMON_ID:
		_demon_fetch(p)
''',
    '''	if card.id == AETHER_DEMON_ID:
		_water_element_fetch(p)
''', "入场触发")

# ③ _demon_fetch 的说明改写：水元素不再走它
rep('''	## 水元素 9068「使用时，从卡组将一张效果卡加入手卡，费用减少 2」的**唯一实现口**。
	## R589：组合动作 `add_effect_from_deck` 也走这里（张数由调用方循环）。
''',
    '''	## 「使用时，从卡组将一张效果卡加入手卡，费用减少 N」的**唯一实现口**。
	## R589：组合动作 `add_effect_from_deck` 也走这里（张数由调用方循环）。
	## ⚠️ R690：水元素 9068 改成「将一张「漩涡」加入手卡」后走 `_water_element_fetch()`，
	##    目前**没有卡**用这条动作。实现保留：它还在拼装动作白名单里，后续卡可直接复用。
''', "_demon_fetch 说明")

# ④ 新增 _water_element_fetch
NEW_FN = '''func _water_element_fetch(_p: Placement, source: String = "水元素") -> void :
	## R690：水元素 9068「使用时，将一张「漩涡」加入手卡」的**唯一实现口**。
	## 与旧口径（从卡组捞一张效果卡、再给它减 2 费）彻底分开：
	##   * **不查卡组**：漩涡 9186 是剧情场地卡（`locked`），牌库里本来就不该有它 ——
	##     按卡库造一张独立实例发过去，水元素就是它目前唯一的获得渠道。
	##   * `own_copy = true`：新造副本，之后对它减费 / 改造不会串到卡库那份
	##     （与 `_demon_fetch` 里那一步同理）。
	##   * 手牌满 → 走 `_grant_to_hand()` 的统一口径（进弃牌区，不静默蒸发）。
	##   * 漩涡当前 0 费（R690 店长口径：拿到手就能直接摆），费用读卡库，不写死在这里。
	var proto: CardData = CardRepo.load_json().get_card(WATER_VORTEX_ID)
	if proto == null:
		_log("%s：找不到 %d 号卡（漩涡）" % [source, WATER_VORTEX_ID])
		return
	var vortex := CardData.from_dict(proto.to_dict())
	vortex.own_copy = true
	var landed := _grant_to_hand(vortex, source)
	_log("%s：将一张「%s」加入手卡%s" % [
			source, vortex.card_name,
			"" if landed else "（手牌已满，改投弃牌区）"])
	action.emit("water_element", {"card": vortex})

'''

rep('''	action.emit("demon_fetch", {"card": chosen})


func _owl_fetch() -> void :''',
    '''	action.emit("demon_fetch", {"card": chosen})


''' + NEW_FN + '''func _owl_fetch() -> void :''', "插入 _water_element_fetch")

# ⑤ 拼装分发处注释
rep('''			"add_effect_from_deck":
				# 水元素 9068（共用 `_demon_fetch`）：value = 张数，discount = 每张减费。
''',
    '''			"add_effect_from_deck":
				# 「从卡组将 N 张效果卡加入手卡，每张减 discount 费」（共用 `_demon_fetch`）。
				# R690：水元素 9068 已改用 `add_card`（抓漩涡），本条暂无卡使用。
''', "拼装注释")

if WRITE:
    save(PATH, out)
else:
    print("干跑通过（未写入）")
