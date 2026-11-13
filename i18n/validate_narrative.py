# -*- coding: utf-8 -*-
"""R665：事件、剧情与剧情成就提示的只读完整性校验。"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "narrative_zh_canonical.json").read_text(encoding="utf-8"))
EN = json.loads((I18N / "narrative_en.json").read_text(encoding="utf-8"))
JA = json.loads((I18N / "narrative_ja.json").read_text(encoding="utf-8"))
GLOSSARY = json.loads((I18N / "glossary.json").read_text(encoding="utf-8"))
STORIES = json.loads((ROOT / "stories.json").read_text(encoding="utf-8-sig"))
EVENT_SOURCE = (ROOT / "scripts/event_scene.gd").read_text(encoding="utf-8-sig")
CARDS = json.loads((ROOT / "cards.json").read_text(encoding="utf-8-sig"))["cards"]
CARDS_EN = json.loads((I18N / "cards_en.json").read_text(encoding="utf-8"))["cards"]
CARDS_JA = json.loads((I18N / "cards_ja.json").read_text(encoding="utf-8"))["cards"]
errors = []


def check(ok, message):
    if ok:
        print("  [OK]", message)
    else:
        errors.append(message)


def placeholders(text):
    return Counter(re.findall(r"%%|%[sd]", text))


def digits(text):
    return Counter(re.findall(r"\d+", text))


def quoted(text):
    return re.findall(r"「([^」]+)」", text) + re.findall(r"【([^】]+)】", text)


def translated_pair(pairs, lang):
    return pairs[0] if lang == "en" else pairs[1]


# 真源与 canonical：除显式登记的规范修正外，事件常量逐字一致。
source_constants = dict(re.findall(
    r'^const\s+([A-Z0-9_]+)\s*:=\s*"""(.*?)"""', EVENT_SOURCE, re.M | re.S))
canonical_by_constant = {}
for event_key, row in ZH["events"].items():
    for key, text in row["texts"].items():
        canonical_by_constant[key] = text
check(set(source_constants).issubset(canonical_by_constant), "55 个事件正文常量全部进入 canonical")
overrides = set(ZH.get("canonical_overrides", []))
for key, source_text in source_constants.items():
    canonical_text = canonical_by_constant.get(key, "")
    if key in overrides:
        if canonical_text == source_text:
            errors.append(key + " 登记了 canonical 修正但内容未变化")
    elif canonical_text != source_text:
        errors.append(key + " 存在未登记的 canonical 漂移")
for key, text in canonical_by_constant.items():
    if key not in source_constants and key not in overrides:
        # 内联双引号字符串在源码里以 \\n 表示换行；_rest_desc() 则是三引号真实换行。
        if text not in EVENT_SOURCE and text.replace("\n", "\\n") not in EVENT_SOURCE:
            # 部分正文由两段双引号字面量用 + 拼接，整段不会连续出现；逐行核对真源。
            source_lines = text.split("\n")
            if not all(not line or line in EVENT_SOURCE or line.replace("\n", "\\n") in EVENT_SOURCE
                       for line in source_lines):
                errors.append(key + " 内联正文未能在 event_scene.gd 真源中找到")

source_story_rows = {x["id"]: x for x in STORIES["episodes"] + STORIES["profiles"]}
source_achievement_rows = {x["id"]: x for x in STORIES["achievements"]}
check(set(ZH["stories"]) == set(source_story_rows), "canonical 剧情 ID 完整覆盖")
check(set(ZH["achievements"]) == set(source_achievement_rows), "canonical 成就 ID 完整覆盖")
for sid, source in source_story_rows.items():
    zh = ZH["stories"].get(sid, {})
    for field in ("chapter", "title", "text"):
        if zh.get(field) != source[field]:
            errors.append("%s canonical %s 与 stories.json 漂移" % (sid, field))
for aid, source in source_achievement_rows.items():
    zh = ZH["achievements"].get(aid, {})
    for field in ("name", "hint"):
        if zh.get(field) != source[field]:
            errors.append("%s canonical %s 与 stories.json 漂移" % (aid, field))

check(len(ZH["events"]) == 26, "事件页为 26 组（24 常规 + 篝火 + 旧存档兜底）")
check(sum(len(x["texts"]) for x in ZH["events"].values()) == 64, "事件正文共 64 段（含 3 条休息处动态追加）")
check(len(ZH["stories"]) == 11, "剧情共 11 段")
check(sum(len(x["text"]) for x in ZH["stories"].values()) == 54, "剧情正文共 54 行")
check(len(ZH["achievements"]) == 11, "剧情成就提示共 11 条")

# 名称唯一来源。
event_terms = {entry["key"]: (zh, entry) for zh, entry in GLOSSARY["events"].items()}
event_terms["rest"] = ("休息处", {"en": "Rest Stop", "ja": "休憩所"})
event_terms["bluefish"] = ("蓝色大肥鱼", {"en": "The Big Blue Fish", "ja": "青い大きな魚"})
story_terms = {entry["id"]: (zh, entry) for zh, entry in GLOSSARY["stories"].items()}
achievement_terms = {entry["id"]: (zh, entry) for zh, entry in GLOSSARY["achievements"].items()}

# 卡名索引：中文同名卡只要任一既有译名命中即可。
card_names = defaultdict(set)
for card in CARDS:
    cid = str(card["id"])
    card_names[card["name"]].add((CARDS_EN[cid]["name"], CARDS_JA[cid]["name"]))
relic_terms = {zh: (entry["en"], entry["ja"]) for zh, entry in GLOSSARY["relics"].items()}
proper_terms = {zh: (entry["en"], entry["ja"]) for zh, entry in GLOSSARY["names"].items()}
level_terms = {zh: (entry["en"], entry["ja"]) for zh, entry in GLOSSARY["levels"].items()}
class_terms = {zh: (entry["en"], entry["ja"]) for zh, entry in GLOSSARY["classes"].items()}


def check_text(zh_text, tr_text, lang, label):
    if not isinstance(tr_text, str) or not tr_text.strip():
        errors.append(label + " 译文为空")
        return
    if tr_text == zh_text:
        errors.append(label + " 译文与中文完全相同")
    if tr_text.count("\n") != zh_text.count("\n"):
        errors.append("%s 换行数漂移 zh=%d tr=%d" % (label, zh_text.count("\n"), tr_text.count("\n")))
    if placeholders(tr_text) != placeholders(zh_text):
        errors.append("%s 占位符漂移 zh=%s tr=%s" % (
            label, dict(placeholders(zh_text)), dict(placeholders(tr_text))))
    missing_digits = digits(zh_text) - digits(tr_text)
    if missing_digits:
        errors.append("%s 缺数字 %s" % (label, dict(missing_digits)))
    for word in quoted(zh_text):
        if word in card_names:
            expected = {translated_pair(pair, lang) for pair in card_names[word]}
            if not any(name in tr_text for name in expected):
                errors.append("%s 未复用卡名 %s -> %s" % (label, word, sorted(expected)))
        elif word in relic_terms:
            expected = relic_terms[word][0 if lang == "en" else 1]
            if expected not in tr_text:
                errors.append("%s 未复用道具名 %s -> %s" % (label, word, expected))
        elif word in level_terms:
            expected = level_terms[word][0 if lang == "en" else 1]
            if expected not in tr_text:
                errors.append("%s 未复用关卡名 %s -> %s" % (label, word, expected))


for lang, data in (("en", EN), ("ja", JA)):
    check(set(data["events"]) == set(ZH["events"]), lang + " 事件 key 无缺无多")
    check(set(data["stories"]) == set(ZH["stories"]), lang + " 剧情 ID 无缺无多")
    check(set(data["achievements"]) == set(ZH["achievements"]), lang + " 成就 ID 无缺无多")
    for event_key, zh_row in ZH["events"].items():
        row = data["events"].get(event_key, {})
        zh_name, term = event_terms[event_key]
        if zh_row["name"] != zh_name:
            errors.append("%s %s canonical 事件名漂移" % (lang, event_key))
        if row.get("name") != term[lang]:
            errors.append("%s %s 事件名未复用术语表" % (lang, event_key))
        if set(row.get("texts", {})) != set(zh_row["texts"]):
            errors.append("%s %s 正文 key 覆盖不一致" % (lang, event_key))
            continue
        for key, zh_text in zh_row["texts"].items():
            check_text(zh_text, row["texts"][key], lang, "%s %s/%s" % (lang, event_key, key))
    for sid, zh_row in ZH["stories"].items():
        row = data["stories"].get(sid, {})
        zh_name, term = story_terms[sid]
        if row.get("title") != term[lang]:
            errors.append("%s %s 剧情标题未复用术语表" % (lang, sid))
        if not row.get("chapter", "").strip():
            errors.append("%s %s chapter 为空" % (lang, sid))
        if not isinstance(row.get("text"), list) or len(row["text"]) != len(zh_row["text"]):
            errors.append("%s %s 剧情行数不一致" % (lang, sid))
            continue
        for index, zh_text in enumerate(zh_row["text"]):
            label = "%s %s/text[%d]" % (lang, sid, index)
            tr_text = row["text"][index]
            check_text(zh_text, tr_text, lang, label)
            # 剧情里未加直角引号的卡名、专名也必须复用既有译文。
            for word in ("谟涅摩叙涅", "巴兰-α", "安西-β", "塔基尼-γ"):
                if word in zh_text:
                    pairs = card_names[word]
                    expected = {translated_pair(pair, lang) for pair in pairs}
                    if not any(name in tr_text for name in expected):
                        errors.append("%s 未复用剧情卡名 %s -> %s" % (label, word, sorted(expected)))
            for word in ("普罗诺亚", "赫菲斯托斯", "谟涅摩叙涅", "巴兰", "安西", "塔基尼"):
                if word in zh_text and not any(word + suffix in zh_text for suffix in ("-α", "-β", "-γ")):
                    expected = proper_terms[word][0 if lang == "en" else 1]
                    if expected not in tr_text:
                        errors.append("%s 未复用专名 %s -> %s" % (label, word, expected))
    for aid, zh_row in ZH["achievements"].items():
        row = data["achievements"].get(aid, {})
        zh_name, term = achievement_terms[aid]
        if row.get("name") != term[lang]:
            errors.append("%s %s 成就名未复用术语表" % (lang, aid))
        check_text(zh_row["hint"], row.get("hint", ""), lang, "%s %s/hint" % (lang, aid))
        for word, pairs in class_terms.items():
            if word in zh_row["hint"]:
                expected = pairs[0 if lang == "en" else 1]
                if expected not in row.get("hint", ""):
                    errors.append("%s %s 未复用角色名 %s" % (lang, aid, word))
        for word in ("普罗诺亚之影", "机械巨鸭", "启示者", "叛逃机械"):
            if word in zh_row["hint"]:
                expected = (proper_terms if word in proper_terms else level_terms)[word][0 if lang == "en" else 1]
                if expected not in row.get("hint", ""):
                    errors.append("%s %s 未复用 Boss 名 %s" % (lang, aid, word))

# 关键机制与数值锁。
check("%d%%" in EN["events"]["rest"]["texts"]["REST_DESC"] and "%d%%" in JA["events"]["rest"]["texts"]["REST_DESC"], "篝火动态百分比占位符锁定")
check("50%" in EN["events"]["rest"]["texts"]["REST_SACRAMENT_DESC"] and "50%" in JA["events"]["rest"]["texts"]["REST_SACRAMENT_DESC"], "圣餐 50% 数值锁定")
check("%s" in EN["events"]["relic_chest"]["texts"]["RELIC_CHEST_OPENED_DESC"] and "%s" in JA["events"]["relic_chest"]["texts"]["RELIC_CHEST_OPENED_DESC"], "宝箱道具名占位符锁定")
check("%d" in EN["events"]["delivery"]["texts"]["DELIVERY_TAKEN_DESC"] and "%d" in JA["events"]["delivery"]["texts"]["DELIVERY_TAKEN_DESC"], "货物数量占位符锁定")
check("Legendary" in EN["events"]["furnace"]["texts"]["FURNACE_DESC"] and "伝説" in JA["events"]["furnace"]["texts"]["FURNACE_DESC"], "熔炉传奇档术语锁定")
check("square root" in EN["events"]["hero"]["texts"]["HERO_DESC"] and "without replacement" in EN["events"]["hero"]["texts"]["HERO_DESC"], "五换一英文为同名数平方根加权且无放回")
check("平方根" in JA["events"]["hero"]["texts"]["HERO_DESC"] and "重複なく" in JA["events"]["hero"]["texts"]["HERO_DESC"], "五换一日文为同名数平方根加权且无放回")
check("gain 1 Cost" in EN["events"]["rest"]["texts"]["REST_PIPE_RESULT_DESC"] and "draw 1 additional card" in EN["events"]["rest"]["texts"]["REST_PIPE_RESULT_DESC"], "烟斗重燃英文复用具体效果")
check("コストを1得て" in JA["events"]["rest"]["texts"]["REST_PIPE_RESULT_DESC"] and "追加で1枚ドロー" in JA["events"]["rest"]["texts"]["REST_PIPE_RESULT_DESC"], "烟斗重燃日文复用具体效果")
check("Remove" in EN["events"]["oblivion"]["texts"]["OBLIVION_DESC"] and "削除" in JA["events"]["oblivion"]["texts"]["OBLIVION_DESC"], "遗忘之泉是删除而非本场消失")

for lang, data in (("en", EN), ("ja", JA)):
    lengths = []
    for event_key, row in data["events"].items():
        lengths.extend((len(text), event_key + "/" + key) for key, text in row["texts"].items())
    lengths.sort(reverse=True)
    print("  [INFO] %s 最长事件正文: %s" % (lang, ", ".join("%s=%d" % (key, n) for n, key in lengths[:5])))

if errors:
    print("\nNARRATIVE I18N FAIL")
    for error in errors:
        print("  -", error)
    sys.exit(1)
print("\nNARRATIVE I18N OK: 26 events / 64 texts | 11 stories / 54 lines | 11 achievement hints")
