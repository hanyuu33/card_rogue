# -*- coding: utf-8 -*-
"""R665：事件选项、结果模板与运送选货页的只读完整性校验。"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "event_ui_zh_canonical.json").read_text(encoding="utf-8"))
NARRATIVE_ZH = json.loads((I18N / "narrative_zh_canonical.json").read_text(encoding="utf-8"))
NARRATIVE_EN = json.loads((I18N / "narrative_en.json").read_text(encoding="utf-8"))
NARRATIVE_JA = json.loads((I18N / "narrative_ja.json").read_text(encoding="utf-8"))
SOURCE = (ROOT / "scripts/event_scene.gd").read_text(encoding="utf-8-sig")
GLOSSARY = json.loads((I18N / "glossary.json").read_text(encoding="utf-8"))
CARDS = json.loads((ROOT / "cards.json").read_text(encoding="utf-8-sig"))["cards"]
CARDS_EN = json.loads((I18N / "cards_en.json").read_text(encoding="utf-8"))["cards"]
CARDS_JA = json.loads((I18N / "cards_ja.json").read_text(encoding="utf-8"))["cards"]
SECTIONS = ("options", "results", "pickers", "rest_dynamic")
EXPECTED_COUNTS = {"options": 83, "results": 64, "pickers": 5, "rest_dynamic": 3}
errors = []


def check(ok, message):
    if ok:
        print("  [OK]", message)
    else:
        errors.append(message)


def flatten(data):
    rows = {}
    for section in SECTIONS:
        if section == "rest_dynamic":
            for key, text in data.get(section, {}).items():
                rows[section + "." + key] = text
            continue
        for group, entries in data.get(section, {}).items():
            for key, text in entries.items():
                rows[section + "." + group + "." + key] = text
    return rows


def placeholders(text):
    return Counter(re.findall(r"%%|%[sd]", text))


def digits(text):
    return Counter(re.findall(r"\d+", text))


def quoted(text):
    return re.findall(r"「([^」]+)」", text) + re.findall(r"【([^】]+)】", text)


# 每条底本都必须能回溯到 event_scene.gd；三处规则纠错的原文单独登记。
source_literals = {
    json.loads(token) for token in re.findall(r'"(?:\\.|[^"\\\r\n])*"', SOURCE)
}
source_concatenations = {
    left + right for left in source_literals for right in source_literals
}
zh_rows = flatten(ZH)
overrides = ZH["canonical_overrides"]
check(set(overrides) == {
    "options.card_merchant.BARTER_FOR_BIG_CHEST",
    "options.cave.EXPLORE_CAVE",
    "options.core_contract.CORE_NO_PAIR_DISABLED",
    "results.core_contract.CORE_CONTRACT_CORE_GAINED",
}, "仅登记 4 处已审计的交互 canonical 修正")
for path, text in zh_rows.items():
    if path in overrides:
        if overrides[path] not in source_literals:
            errors.append(path + " canonical 修正原文未在真源中找到")
        if text == overrides[path]:
            errors.append(path + " 登记修正但内容未变化")
    elif text not in source_literals and text not in source_concatenations:
        errors.append(path + " 未在 event_scene.gd 字符串字面量或二段拼接中找到")
for path in overrides:
    if path not in zh_rows:
        errors.append(path + " canonical 修正锚点已失效")
for section, expected in EXPECTED_COUNTS.items():
    count = (len(ZH[section]) if section == "rest_dynamic"
             else sum(len(rows) for rows in ZH[section].values()))
    check(count == expected, "%s 共 %d 条" % (section, expected))

# 动态正文在 narrative 与 event_ui 两份索引中保持同一规范中文。
dynamic_map = {
    "REST_DYNAMIC_SACRAMENT_HEAL": "REST_SACRAMENT_RESULT_DESC",
    "REST_DYNAMIC_BANDAGE_HEAL": "REST_BANDAGE_RESULT_DESC",
    "REST_DYNAMIC_PIPE_RELIGHT": "REST_PIPE_RESULT_DESC",
}
for dynamic_key, narrative_key in dynamic_map.items():
    dynamic = ZH["rest_dynamic"][dynamic_key].removeprefix("\n\n")
    narrative = NARRATIVE_ZH["events"]["rest"]["texts"][narrative_key]
    check(dynamic == narrative, dynamic_key + " 与 narrative 动态正文一致")

# 引号内卡名与道具名只能复用既有译文。
card_names = defaultdict(set)
for card in CARDS:
    cid = str(card["id"])
    card_names[card["name"]].add((CARDS_EN[cid]["name"], CARDS_JA[cid]["name"]))
term_index = defaultdict(list)
for section, entries in GLOSSARY.items():
    if not isinstance(entries, dict):
        continue
    for zh, entry in entries.items():
        if isinstance(entry, dict) and "en" in entry and "ja" in entry:
            term_index[zh].append(entry)


def check_text(path, zh_text, tr_text, lang):
    label = lang + " " + path
    if not isinstance(tr_text, str) or not tr_text.strip():
        errors.append(label + " 译文为空")
        return
    if tr_text == zh_text:
        errors.append(label + " 译文与中文完全相同")
    if placeholders(tr_text) != placeholders(zh_text):
        errors.append("%s 占位符漂移 zh=%s tr=%s" % (
            label, dict(placeholders(zh_text)), dict(placeholders(tr_text))))
    if tr_text.count("\n") != zh_text.count("\n"):
        errors.append(label + " 换行数漂移")
    missing_digits = digits(zh_text) - digits(tr_text)
    if missing_digits:
        errors.append("%s 缺数字 %s" % (label, dict(missing_digits)))
    if lang == "en" and re.search(r"[\u3400-\u9fff]", tr_text):
        errors.append(label + " 英文残留中文")
    for word in quoted(zh_text):
        if word in card_names:
            expected = {pair[0 if lang == "en" else 1] for pair in card_names[word]}
            if not any(name in tr_text for name in expected):
                errors.append("%s 未复用卡名 %s -> %s" % (label, word, sorted(expected)))
        elif word in term_index:
            if not any(entry[lang] in tr_text for entry in term_index[word]):
                expected = [entry[lang] for entry in term_index[word]]
                errors.append("%s 未复用术语 %s -> %s" % (label, word, expected))


translations = {}
for lang in ("en", "ja"):
    path = I18N / ("event_ui_" + lang + ".json")
    if not path.exists():
        errors.append("缺少 " + path.name)
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    translations[lang] = data
    rows = flatten(data)
    check(set(rows) == set(zh_rows), lang + " 全部交互 key 无缺无多")
    for text_path, zh_text in zh_rows.items():
        if text_path in rows:
            check_text(text_path, zh_text, rows[text_path], lang)
    for key in dynamic_map:
        check(data["rest_dynamic"][key].startswith("\n\n"), lang + " " + key + " 保留两个前导换行")
        narrative = NARRATIVE_EN if lang == "en" else NARRATIVE_JA
        expected = "\n\n" + narrative["events"]["rest"]["texts"][dynamic_map[key]]
        check(data["rest_dynamic"][key] == expected, lang + " " + key + " 与 narrative 共用同一译文")

# 永久删除与核心/商人规则锁。
if len(translations) == 2:
    en = flatten(translations["en"])
    ja = flatten(translations["ja"])
    permanent_removal = (
        "options.rest.ADD_FIREWOOD",
        "options.oblivion.FORGET_CARD",
        "results.lake_lady.LAKE_LADY_LIE_RESULT",
        "results.delivery_done.DELIVERY_DONE_CARGO_REMOVED",
        "pickers.delivery.note",
    )
    for path in permanent_removal:
        check("remov" in en[path].lower() and "削除" in ja[path], path + " 永久删除口径锁定")
    merchant = "options.card_merchant.BARTER_FOR_BIG_CHEST"
    check("5" in en[merchant] and "X" in en[merchant]
          and ("exclud" in en[merchant].lower() or "except" in en[merchant].lower()),
          "商人英文为 5 费及以上且 X 费除外")
    check("5" in ja[merchant] and "X" in ja[merchant]
          and ("除外" in ja[merchant] or "除く" in ja[merchant]),
          "商人日文为 5 费及以上且 X 费除外")
    check("Epic" in en["options.cave.EXPLORE_CAVE"]
          and "エピック" in ja["options.cave.EXPLORE_CAVE"],
          "枭熊奖励为 Epic／エピック，不虚构 Legendary 卡牌稀有度")
    check("consignee" in en["results.delivery.DELIVERY_ACCEPTED_RESTORE"],
          "货运恢复态由 consignee 兑付")
    check(translations["ja"]["pickers"]["delivery"]["title"].startswith("配送依頼")
          and translations["ja"]["pickers"]["delivery"]["short"] == "配送依頼",
          "运送选货页复用日文事件名 配送依頼")
    for path in ("options.core_contract.CORE_NO_PAIR_DISABLED",
                 "results.core_contract.CORE_CONTRACT_CORE_GAINED"):
        check(("unenchanted" in en[path].lower() or "no enchant" in en[path].lower())
              and "damage" in en[path].lower(),
              path + " 英文保留另一张尚未附魔的伤害技能牌")
        check(("未付呪" in ja[path] or "まだ付呪されていない" in ja[path])
              and "ダメージ" in ja[path],
              path + " 日文保留另一张尚未附魔的伤害技能牌")

if errors:
    print("\nEVENT UI I18N FAIL")
    for error in errors:
        print("  -", error)
    sys.exit(1)
print("\nEVENT UI I18N OK: 83 options / 64 results / 5 picker fields / 3 dynamic lines")
