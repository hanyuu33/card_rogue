#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 界面层：金币分项「兔脚」四语 + 两件新工具的程序化图标配色。"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"


def rep(p, old, new, note=""):
    path = ROOT + p
    raw = io.open(path, encoding="utf-8", newline="").read()
    n = raw.count(old)
    if n != 1:
        print("FAIL %s 锚点命中 %d 次 %s" % (p, n, note))
        sys.exit(1)
    io.open(path, "w", encoding="utf-8", newline="").write(raw.replace(old, new))
    print("OK  %s %s" % (p, note))


# ── 金币分项：四语 ────────────────────────────────────────────────
rep("i18n/interface_zh_canonical.json",
    '      "REWARD_GOLD_PART_BOUNTY_HUNTER": {\n'
    '        "source": "scripts/battle_scene.gd:8137",\n'
    '        "zh": "赏金猎人 %d"\n'
    '      },\n',
    '      "REWARD_GOLD_PART_BOUNTY_HUNTER": {\n'
    '        "source": "scripts/battle_scene.gd:8137",\n'
    '        "zh": "赏金猎人 %d"\n'
    '      },\n'
    '      "REWARD_GOLD_PART_RABBIT_FOOT": {\n'
    '        "source": "scripts/battle_scene.gd:8750",\n'
    '        "zh": "兔脚 %d"\n'
    '      },\n',
    "(兔脚分项 zh)")

for lang, txt in (("en", "Rabbit's Foot %d"), ("ja", "ウサギの足 %d"),
                  ("es", "Pata de conejo %d")):
    rep("i18n/interface_%s.json" % lang,
        '      "REWARD_GOLD_PART_BOUNTY_HUNTER": "%s",\n'
        % {"en": "Bounty Hunter %d", "ja": "賞金稼ぎ %d",
           "es": "Cazarrecompensas %d"}[lang],
        '      "REWARD_GOLD_PART_BOUNTY_HUNTER": "%s",\n'
        '      "REWARD_GOLD_PART_RABBIT_FOOT": "%s",\n'
        % ({"en": "Bounty Hunter %d", "ja": "賞金稼ぎ %d",
            "es": "Cazarrecompensas %d"}[lang], txt),
        "(兔脚分项 %s)" % lang)

# ── 程序化图标：两件新工具要有自己的颜色（有 png 时自动让位）────────
rep("scripts/trap_art.gd",
    '		7012: return Color(0.68, 0.66, 0.62)   # 石头 · 石灰\n',
    '		7012: return Color(0.68, 0.66, 0.62)   # 石头 · 石灰\n'
    '		7013: return Color(0.86, 0.68, 0.42)   # 卡牌包 · 牛皮纸\n'
    '		7014: return Color(0.58, 0.72, 0.98)   # 智慧药剂 · 智慧蓝\n',
    "(新工具配色)")

rep("scripts/trap_art.gd",
    '		7012: _stone(ci, c, s, ink)\n'
    '		_: ci.draw_circle(c, s * 0.22, ink)\n',
    '		7012: _stone(ci, c, s, ink)\n'
    '		7013: _cardpack(ci, c, s, ink)\n'
    '		7014: _wisdom(ci, c, s, ink)\n'
    '		_: ci.draw_circle(c, s * 0.22, ink)\n',
    "(新工具分发)")

raw = io.open(ROOT + "scripts/trap_art.gd", encoding="utf-8", newline="").read()
if "_cardpack(" not in raw.split("static func draw(")[1]:
    pass
add = '''


static func _cardpack(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R796 卡牌包 7013：三张叠起来的卡 + 一道系带（程序化兜底；有 png 时整段不走）。
	var w := maxf(1.5, s * 0.028)
	var card := Rect2(c + Vector2(-s * 0.22, -s * 0.15), Vector2(s * 0.40, s * 0.30))
	ci.draw_rect(card.translate(Vector2(-s * 0.05, s * 0.03)), col, true)
	ci.draw_rect(card, col.lightened(0.35), true)
	ci.draw_rect(card, col, false, w)
	var band := Rect2(card.position + Vector2(card.size.x * 0.42, 0),
			Vector2(card.size.x * 0.16, card.size.y))
	ci.draw_rect(band, col.darkened(0.25), true)


static func _wisdom(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R796 智慧药剂 7014：蓝药瓶 + 瓶口一颗星（「智慧」靠星点区分法力药剂）。
	var w := maxf(1.5, s * 0.032)
	var body := PackedVector2Array([
		c + Vector2(-s * 0.15, -s * 0.04),
		c + Vector2(s * 0.15, -s * 0.04),
		c + Vector2(s * 0.11, s * 0.20),
		c + Vector2(-s * 0.11, s * 0.20)])
	ci.draw_colored_polygon(body, col)
	ci.draw_polyline(body + PackedVector2Array([body[0]]), col.darkened(0.35), w)
	ci.draw_line(c + Vector2(0, -s * 0.04), c + Vector2(0, -s * 0.13), col, w * 1.6)
	var star := c + Vector2(s * 0.17, -s * 0.19)
	for k in 4:
		var a := TAU * float(k) / 4.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(star - d * s * 0.055, star + d * s * 0.055, col.lightened(0.45), maxf(1.2, w * 0.8))


'''
p = ROOT + "scripts/trap_art.gd"
s = io.open(p, encoding="utf-8", newline="").read()
anchor = "static func _stone(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:"
assert s.count(anchor) == 1
s = s.replace(anchor, add.lstrip("\n") + anchor)
io.open(p, "w", encoding="utf-8", newline="").write(s)
print("OK  scripts/trap_art.gd (+_cardpack/_wisdom)")

for p in ["i18n/interface_%s.json" % l for l in ("zh_canonical", "en", "ja", "es")]:
    d = json.load(io.open(ROOT + p, encoding="utf-8"))
    assert "REWARD_GOLD_PART_RABBIT_FOOT" in d["scopes"]["reward"], p
print("OK  四语 JSON 可解析且含新键")
print("DONE")
