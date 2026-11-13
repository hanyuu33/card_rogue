# -*- coding: utf-8 -*-
"""R659：道具与角色长文的只读完整性校验。"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "noncard_zh_canonical.json").read_text(encoding="utf-8"))
EN = json.loads((I18N / "noncard_en.json").read_text(encoding="utf-8"))
JA = json.loads((I18N / "noncard_ja.json").read_text(encoding="utf-8"))
GLOSSARY = json.loads((I18N / "glossary.json").read_text(encoding="utf-8"))
SOURCE = json.loads((ROOT / "relics.json").read_text(encoding="utf-8-sig"))["relics"]
CARDS = json.loads((ROOT / "cards.json").read_text(encoding="utf-8-sig"))["cards"]
CARDS_EN = json.loads((I18N / "cards_en.json").read_text(encoding="utf-8"))["cards"]
CARDS_JA = json.loads((I18N / "cards_ja.json").read_text(encoding="utf-8"))["cards"]
errors = []


def check(ok, message):
    if ok:
        print("  [OK]", message)
    else:
        errors.append(message)


def numbers(text):
    return set(re.findall(r"\d+", text))


def quoted(text):
    return re.findall(r"「([^」]+)」", text) + re.findall(r"【([^】]+)】", text)


source_by_id = {str(r["id"]): r for r in SOURCE}
expected_ids = set(source_by_id)
instant_ids = {rid for rid, r in source_by_id.items() if r["kind"] == "即时"}
check(len(SOURCE) == 62 and len(expected_ids) == 62, "真源为 62 件不重复道具")
check(len(instant_ids) == 12, "kind=即时 共 12 件")
check(set(ZH["relics"]) == expected_ids, "canonical 道具 ID 完整覆盖")
check(set(EN["relics"]) == expected_ids, "英文道具 ID 完整覆盖")
check(set(JA["relics"]) == expected_ids, "日文道具 ID 完整覆盖")
check(set(ZH["classes"]) == set(EN["classes"]) == set(JA["classes"]) == {"森林精魄", "暗影刺客", "机械之心"}, "三角色覆盖一致")

for rid, source in source_by_id.items():
    zh = ZH["relics"].get(rid, {})
    en = EN["relics"].get(rid, {})
    ja = JA["relics"].get(rid, {})
    if not zh or not en or not ja:
        continue
    if zh.get("name") != source["name"]:
        errors.append("%s canonical 名称漂移" % rid)
    for lang, entry in (("en", en), ("ja", ja)):
        expected_name = GLOSSARY["relics"][source["name"]][lang]
        if entry.get("name") != expected_name:
            errors.append("%s %s 道具名未复用术语表" % (rid, lang))
        desc = entry.get("desc", "")
        if not desc.strip():
            errors.append("%s %s 描述为空" % (rid, lang))
        missing_numbers = numbers(zh["desc"]) - numbers(desc)
        if missing_numbers:
            errors.append("%s %s 缺数字 %s" % (rid, lang, sorted(missing_numbers)))
        for value in re.findall(r"(\d+)%", zh["desc"]):
            if value + "%" not in desc:
                errors.append("%s %s 缺百分比 %s%%" % (rid, lang, value))
        if "X" in zh["desc"] and "X" not in desc:
            errors.append("%s %s 缺变量 X" % (rid, lang))
        if "→" in zh["desc"]:
            chain = re.search(r"[\d\s→]+", zh["desc"]).group(0).strip()
            if chain not in desc:
                errors.append("%s %s 复活概率序列漂移" % (rid, lang))
        is_instant = rid in instant_ids
        prefix = "On pickup: " if lang == "en" else "入手時："
        if is_instant != desc.startswith(prefix):
            errors.append("%s %s 即时标注错误" % (rid, lang))
        if "Consumed on pickup" in desc or "入手時に消費" in desc:
            errors.append("%s %s 错把即时译成消耗" % (rid, lang))

for lang, data in (("en", EN), ("ja", JA)):
    for cid, entry in data["classes"].items():
        expected_name = GLOSSARY["classes"][cid][lang]
        if entry.get("name") != expected_name:
            errors.append("%s %s 角色名未复用术语表" % (cid, lang))
        for field in ("subtitle", "desc"):
            if not entry.get(field, "").strip():
                errors.append("%s %s %s 为空" % (cid, lang, field))
        for value in numbers(ZH["classes"][cid]["desc"]):
            if value not in numbers(entry["desc"]):
                errors.append("%s %s 角色描述缺数字 %s" % (cid, lang, value))

# 引号中的卡名、术语与道具名必须复用既有译文；未登记的界面词单独跳过。
term_index = {}
for section, entries in GLOSSARY.items():
    if not isinstance(entries, dict):
        continue
    for zh, entry in entries.items():
        if isinstance(entry, dict) and "en" in entry and "ja" in entry:
            term_index.setdefault(zh, []).append(entry)
card_names = {}
for card in CARDS:
    cid = str(card["id"])
    card_names.setdefault(card["name"], set()).add((CARDS_EN[cid]["name"], CARDS_JA[cid]["name"]))

for rid, row in ZH["relics"].items():
    for word in quoted(row["desc"]):
        pairs = card_names.get(word, set())
        if len(pairs) == 1:
            en_name, ja_name = next(iter(pairs))
            if en_name not in EN["relics"][rid]["desc"]:
                errors.append("%s en 未复用卡名 %s" % (rid, en_name))
            if ja_name not in JA["relics"][rid]["desc"]:
                errors.append("%s ja 未复用卡名 %s" % (rid, ja_name))
        elif word in term_index:
            for lang, data in (("en", EN), ("ja", JA)):
                if not any(entry[lang] in data["relics"][rid]["desc"] for entry in term_index[word]):
                    errors.append("%s %s 未复用引号术语 %s" % (rid, lang, word))

for cid, row in ZH["classes"].items():
    for field in ("subtitle", "desc"):
        for word in quoted(row[field]):
            if word in term_index:
                for lang, data in (("en", EN), ("ja", JA)):
                    if not any(entry[lang] in data["classes"][cid][field] for entry in term_index[word]):
                        errors.append("%s %s %s 未复用术语 %s" % (cid, lang, field, word))

# 明确的数值纠错锁：8025 素体为 1 费 1 力量 3 生命。
chassis = next(c for c in CARDS if c["id"] == 8025)
check((chassis["cost"], chassis["power"], chassis["health"]) == (1, 1, 3), "8025 真源数值为 1 费 / 1 力量 / 3 生命")
check("1 费、1 力量、3 生命" in ZH["relics"]["6025"]["desc"], "6025 canonical 已纠正素体数值")
check("1-Cost" in EN["relics"]["6025"]["desc"] and "1 Power" in EN["relics"]["6025"]["desc"] and "3 Health" in EN["relics"]["6025"]["desc"], "6025 英文素体数值锁")
check("1コスト・攻撃力1・HP3" in JA["relics"]["6025"]["desc"], "6025 日文素体数值锁")
check("1 费的素体" in ZH["classes"]["机械之心"]["desc"], "机械之心角色 canonical 已纠正素体费用")
check("greater than 20" in EN["relics"]["6029"]["desc"] and "20を超える" in JA["relics"]["6029"]["desc"], "6029 严格大于 20")
check("15 or more" in EN["relics"]["6059"]["desc"] and "15以上" in JA["relics"]["6059"]["desc"], "6059 阈值达到 15")
check("Refit" in EN["classes"]["机械之心"]["subtitle"] and "改修" in JA["classes"]["机械之心"]["subtitle"], "8027 卡名与 Upgrade／改造机制不混用")

for rid, row in ZH["relics"].items():
    for old in ("手卡", "生命值", "血量", "攻击力", "抽牌库", "弃牌库", "弃牌堆"):
        if old in row["desc"]:
            errors.append("%s canonical 残留未归一词 %s" % (rid, old))

for lang, data in (("en", EN), ("ja", JA)):
    longest = sorted(((len(v["desc"]), rid) for rid, v in data["relics"].items()), reverse=True)[:5]
    print("  [INFO] %s 最长描述: %s" % (lang, ", ".join("%s=%d" % (rid, n) for n, rid in longest)))

if errors:
    print("\nNONCARD I18N FAIL")
    for error in errors:
        print("  -", error)
    sys.exit(1)
print("\nNONCARD I18N OK: 62 relics + 3 classes | 12 instant markers | numeric/term locks passed")
