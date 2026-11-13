# -*- coding: utf-8 -*-
"""只读校验：非卡牌术语覆盖、专名一致、剧情/成就同源。"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
G = json.loads((ROOT / "i18n/glossary.json").read_text(encoding="utf-8"))
errors = []

def block(text, start, end):
    match = re.search(re.escape(start) + r"(.*?)" + re.escape(end), text, re.S)
    if not match:
        errors.append("source block not found: " + start)
        return ""
    return match.group(1)

def check_names(section, expected):
    actual = set(G.get(section, {}))
    expected = set(expected)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        errors.append("%s missing=%s extra=%s" % (section, missing, extra))
    else:
        print("  [OK] %-18s %d" % (section, len(actual)))

def pair(entry):
    return entry.get("en", ""), entry.get("ja", "")

# 所有词条必须有英日译文。
for section, entries in G.items():
    if not isinstance(entries, dict) or section == "brand":
        continue
    for zh, entry in entries.items():
        if isinstance(entry, dict) and ("en" in entry or "ja" in entry):
            if not entry.get("en") or not entry.get("ja"):
                errors.append("empty translation: %s/%s" % (section, zh))

relics = json.loads((ROOT / "relics.json").read_text(encoding="utf-8-sig"))["relics"]
stories = json.loads((ROOT / "stories.json").read_text(encoding="utf-8-sig"))
card_data = (ROOT / "scripts/card_data.gd").read_text(encoding="utf-8")
run_state = (ROOT / "scripts/run_state.gd").read_text(encoding="utf-8")
map_scene = (ROOT / "scripts/map_scene.gd").read_text(encoding="utf-8")
levels_text = (ROOT / "scripts/game_levels.gd").read_text(encoding="utf-8")
layers_text = (ROOT / "scripts/game_layers.gd").read_text(encoding="utf-8")
steam_doc = (ROOT / "release/steam_achievements.md").read_text(encoding="utf-8")

check_names("relics", [r["name"] for r in relics])
check_names("relic_kinds", [r["kind"] for r in relics])
check_names("relic_sources", [r["source"] for r in relics])
check_names("relic_tiers", [r["tier"] for r in relics])
check_names("levels", re.findall(r"^\s*\"name\": \"([^\"]+)\"", levels_text, re.M))
event_pairs = re.findall(r"\"([^\"]+)\": \"([^\"]+)\"", block(layers_text, "const EVENT_NAMES := {", "\n}"))
check_names("events", [zh for key, zh in event_pairs])
check_names("stories", [x["title"] for x in stories["episodes"] + stories["profiles"]])
steam_pairs = [(api, zh.strip()) for api, zh in re.findall(r"\| `([A-Z0-9_]+)` \| ([^|]+?) \|", block(steam_doc, "## 一、成就清单", "## 二、代码侧"))]
check_names("achievements", [x["name"] for x in stories["achievements"]] + [zh for api, zh in steam_pairs])
check_names("difficulties", re.findall(r"\"([^\"]+)\"", block(run_state, "const DIFFICULTY_NAMES", "## 各档位")))
check_names("difficulty_notes", re.findall(r"\"([^\"]*)\"", block(run_state, "const DIFFICULTY_TEXTS", "## R224：全局规则")))
check_names("enchantments", re.findall(r"\"label\": \"([^\"]+)\"", block(card_data, "const ENCHANT_DEFS", "\n}")))
check_names("rarities", re.findall(r"\"([^\"]+)\"", block(card_data, "const RARITY_NAMES", "\n## 卡面边框色")))
room_names = re.findall(r"\"[^\"]+\": \"([^\"]+)\"", block(map_scene, "const ENTER_LABELS", "\n}"))
check_names("rooms", room_names + ["精英", "休息", "篝火", "未知房间", "迷雾", "通路", "当前房间", "已探索", "未探索", "入夜", "第一层", "第二层", "第三层"])

# 字段与机制词条也必须留在 mechanics 中。
affixes = re.findall(r"^\s*\"([^\"]+)\": \{\"label\":", block(card_data, "const AFFIX_DEFS", "\n}"), re.M)
mech_words = re.findall(r"^\s*\"([^\"]+)\": \{\"label\":", block(card_data, "const MECH_KEYWORDS", "\n}"), re.M)
for zh in affixes + mech_words:
    if zh not in G["mechanics"]:
        errors.append("mechanics missing affix/keyword: " + zh)
print("  [OK] %-18s %d" % ("affixes+keywords", len(affixes) + len(mech_words)))

# id / key 与真源一致。
for r in relics:
    if G["relics"].get(r["name"], {}).get("id") != r["id"]:
        errors.append("relic id mismatch: %s" % r["name"])
for key, zh in event_pairs:
    if G["events"].get(zh, {}).get("key") != key:
        errors.append("event key mismatch: %s" % zh)
for x in stories["episodes"] + stories["profiles"]:
    if G["stories"].get(x["title"], {}).get("id") != x["id"]:
        errors.append("story id mismatch: %s" % x["title"])
for x in stories["achievements"]:
    if G["achievements"].get(x["name"], {}).get("id") != x["id"]:
        errors.append("story achievement id mismatch: %s" % x["name"])
for api, zh in steam_pairs:
    if G["achievements"].get(zh, {}).get("id") != api:
        errors.append("steam achievement id mismatch: %s" % zh)

# 同名剧情与成就、同名关卡与事件必须共用译名。
for x in stories["achievements"]:
    if x["name"] in G["stories"] and pair(G["achievements"][x["name"]]) != pair(G["stories"][x["name"]]):
        errors.append("story/achievement translation drift: " + x["name"])
for zh in set(G["levels"]) & set(G["events"]):
    if pair(G["levels"][zh]) != pair(G["events"][zh]):
        errors.append("level/event translation drift: " + zh)

# 专名段内部不得两个中文名撞成同一组英日译名。
for section in ("relics", "levels", "events", "stories", "achievements"):
    seen = defaultdict(list)
    for zh, entry in G[section].items():
        seen[pair(entry)].append(zh)
    for translated, names in seen.items():
        if len(names) > 1:
            errors.append("duplicate translated name in %s: %s -> %s" % (section, names, translated))

# 与既有卡名同名的非卡牌专名必须复用卡名译文。
zh_cards = json.loads((ROOT / "cards.json").read_text(encoding="utf-8-sig"))["cards"]
en_cards = json.loads((ROOT / "i18n/cards_en.json").read_text(encoding="utf-8"))["cards"]
ja_cards = json.loads((ROOT / "i18n/cards_ja.json").read_text(encoding="utf-8"))["cards"]
by_name = defaultdict(list)
for card in zh_cards:
    by_name[card["name"]].append(str(card["id"]))
for section in ("names", "relics", "levels", "events", "stories", "achievements"):
    for zh, entry in G[section].items():
        for cid in by_name.get(zh, []):
            card_pair = en_cards[cid]["name"], ja_cards[cid]["name"]
            if pair(entry) != card_pair:
                errors.append("card-name reuse mismatch: %s/%s id=%s glossary=%s card=%s" % (section, zh, cid, pair(entry), card_pair))

if G["names"]["合体"]["en"] != "Merge" or en_cards["9167"]["name"] != "Merge":
    errors.append("9167 合体 must be Merge")
if G["mechanics"]["组合"]["en"] != "Assemble":
    errors.append("组合 must be Assemble")

if errors:
    print("\nGLOSSARY FAIL")
    for error in errors:
        print("  -", error)
    sys.exit(1)
print("\nGLOSSARY OK: %d sections | %d relics | %d levels | %d events | %d achievements" % (
    len(G), len(G["relics"]), len(G["levels"]), len(G["events"]), len(G["achievements"])))
