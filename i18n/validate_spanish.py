# -*- coding: utf-8 -*-
"""R668：西班牙语全量译文只读校验；不写权威数据、设置或存档。"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
errors = []
checks = 0


def load(name):
    return json.loads((I18N / name).read_text(encoding="utf-8"))


def check(ok, message):
    global checks
    checks += 1
    if not ok:
        errors.append(message)


def placeholders(text):
    return Counter(re.findall(r"%%|%(?:\d+\$)?[-+0-9.]*[sdfg]", text))


def digits(text):
    return Counter(re.findall(r"\d+", text))


def tags(text):
    return Counter(re.findall(r"\[/?[A-Za-z_]+(?:=[^\]]+)?\]|\{[A-Za-z_][A-Za-z0-9_]*\}", text))


def urls(text):
    return Counter(re.findall(r"https?://[^\s\]]+", text))


def quoted(text):
    return re.findall(r"「([^」]+)」", text) + re.findall(r"【([^】]+)】", text)


def has_cjk(text):
    return bool(re.search(r"[\u3400-\u9fff]", text))


CARDS_ZH = load("zh_canonical.json")
CARDS_ES = load("cards_es.json")
NONCARD_ZH = load("noncard_zh_canonical.json")
NONCARD_ES = load("noncard_es.json")
NARRATIVE_ZH = load("narrative_zh_canonical.json")
NARRATIVE_ES = load("narrative_es.json")
EVENT_ZH = load("event_ui_zh_canonical.json")
EVENT_ES = load("event_ui_es.json")
INTERFACE_ZH = load("interface_zh_canonical.json")
INTERFACE_ES = load("interface_es.json")
TRAPS_ES = load("traps_es.json")
L10N_ES = load("l10n_es.json")
SOURCE_ALIASES = load("source_aliases.json")
GLOSSARY_ES = load("glossary_es.json")["terms"]
RAW_CARDS = json.loads((ROOT / "cards.json").read_text(encoding="utf-8-sig"))["cards"]
RAW_RELICS = json.loads((ROOT / "relics.json").read_text(encoding="utf-8-sig"))["relics"]
TRAPS_PATH = ROOT / "traps.json"
RAW_TRAPS = (json.loads(TRAPS_PATH.read_text(encoding="utf-8-sig"))["traps"]
             if TRAPS_PATH.exists() else [])

card_names = defaultdict(set)
for cid, row in CARDS_ES["cards"].items():
    zh_row = CARDS_ZH["cards"].get(cid)
    if zh_row:
        card_names[zh_row["name"]].add(row["name"])
relic_names = defaultdict(set)
for rid, row in NONCARD_ES["relics"].items():
    zh_row = NONCARD_ZH["relics"].get(rid)
    if zh_row:
        relic_names[zh_row["name"]].add(row["name"])


def check_text(label, zh, es, allow_cjk=False, check_terms=True):
    if not isinstance(es, str):
        errors.append(label + " 译文不是字符串")
        return
    if zh == "":
        check(es == "", label + " 中文空串对应的西语也应为空")
        return
    check(bool(es.strip()), label + " 译文为空")
    if not es:
        return
    if has_cjk(zh):
        check(es != zh, label + " 译文与中文完全相同")
    check(allow_cjk or not has_cjk(es), label + " 西语残留中文")
    check(placeholders(es) == placeholders(zh),
          "%s 占位符漂移 zh=%s es=%s" % (label, dict(placeholders(zh)), dict(placeholders(es))))
    check(tags(es) == tags(zh), label + " BBCode/花括号标签漂移")
    check(urls(es) == urls(zh), label + " URL 漂移")
    check(es.count("\n") == zh.count("\n"), label + " 换行数漂移")
    check(es.count("**") == zh.count("**"), label + " Markdown 加粗标记漂移")
    missing_digits = digits(zh) - digits(es)
    check(not missing_digits, "%s 缺数字 %s" % (label, dict(missing_digits)))
    if re.search(r"(?<![A-Za-z])X(?![A-Za-z])", zh):
        check(re.search(r"(?<![A-Za-z])X(?![A-Za-z])", es) is not None, label + " 缺变量 X")
    check(re.search(r"\b(?:vosotros|vosotras|vuestra|vuestro|vuestras|vuestros)\b", es, re.I) is None,
          label + " 使用了非国际中性口径的 vosotros/vuestro")
    if "抽牌库" in zh or "抽牌堆" in zh:
        check("pila de robo" in es.lower(), label + " 抽牌库未统一为 pila de robo")
    if "卡组" in zh:
        check("mazo" in es.lower(), label + " 卡组未统一为 mazo")
        if "抽牌库" not in zh and "抽牌堆" not in zh:
            check("pila de robo" not in es.lower(), label + " 把卡组误译为抽牌堆")
    if ("删除" in zh or "永久移除" in zh) and "消失" not in zh:
        check("desterr" not in es.lower(), label + " 永久删除误译为 desterrar")
    if check_terms:
        for word in quoted(zh):
            if word in card_names:
                check(any(name in es for name in card_names[word]),
                      "%s 未复用卡名 %s -> %s" % (label, word, sorted(card_names[word])))
            elif word in relic_names:
                check(any(name in es for name in relic_names[word]),
                      "%s 未复用道具名 %s -> %s" % (label, word, sorted(relic_names[word])))


def flatten_event(data):
    rows = {}
    for section in ("options", "results", "pickers"):
        for group, entries in data.get(section, {}).items():
            for key, text in entries.items():
                rows[section + "." + group + "." + key] = text
    for key, text in data.get("rest_dynamic", {}).items():
        rows["rest_dynamic." + key] = text
    return rows


def flatten_interface(data, translated=False):
    rows = {}
    entries = {}
    for scope in ("shop", "reward", "map", "battle", "shell", "shared"):
        for key, entry in data["scopes"].get(scope, {}).items():
            path = scope + "." + key
            rows[path] = entry if translated else entry["zh"]
            entries[path] = entry
    return rows, entries


# 卡牌：319 个稳定 ID（R692 +鸭妈妈 9250 / 小鸭 9251；R689 +种子 9248 / 被眷顾者 9249）；名称与效果字段完整，空效果只允许仍为空。
check(set(CARDS_ES["cards"]) == set(CARDS_ZH["cards"]), "cards ID 覆盖与 canonical 一致")
check(len(CARDS_ES["cards"]) == 319, "cards 共 319 张")
raw_cards = {str(row["id"]): row for row in RAW_CARDS}
for cid, zh_row in CARDS_ZH["cards"].items():
    es_row = CARDS_ES["cards"].get(cid, {})
    check({"name", "effect_text"}.issubset(es_row)
          and set(es_row) <= {"name", "effect_text", "lower_effect_note", "upper_effect_passive_text"},
          cid + " cards 字段符合既有译文结构")
    # 9005/9055 的权威 cards.json 已修正效果，旧 canonical 尚未同步；直接对权威原文验收。
    source_row = raw_cards[cid] if cid in {"9005", "9055"} else zh_row
    for field in ("name", "effect_text"):
        check_text("cards.%s.%s" % (cid, field), source_row[field], es_row.get(field))
    missing_raw_digits = digits(raw_cards[cid]["effect_text"]) - digits(es_row.get("effect_text", ""))
    check(not missing_raw_digits, "%s 相对 cards.json 缺数字 %s" % (cid, dict(missing_raw_digits)))
    for extra in ("lower_effect_note", "upper_effect_passive_text"):
        if extra in es_row:
            check(isinstance(es_row[extra], str) and not has_cjk(es_row[extra]),
                  cid + " " + extra + " 为无中文残留的字符串")

# 特性短词：卡名 / 既有 canonical 可复用的直接复用，其余 116 个由西语术语表补齐。
trait_source_texts = {str(row["name"]) for row in RAW_CARDS}


def collect_canonical_zh(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "zh" and isinstance(child, str):
                trait_source_texts.add(child)
            else:
                collect_canonical_zh(child)
    elif isinstance(value, list):
        for child in value:
            collect_canonical_zh(child)


for canonical in (CARDS_ZH, NONCARD_ZH, NARRATIVE_ZH, EVENT_ZH, INTERFACE_ZH):
    collect_canonical_zh(canonical)
used_traits = {str(trait) for row in RAW_CARDS for trait in row.get("traits", [])}
required_trait_terms = used_traits - trait_source_texts
check(set(GLOSSARY_ES) == required_trait_terms,
      "glossary_es 精确覆盖不能复用卡名/canonical 的特性短词（缺 %s / 多 %s）" % (
          sorted(required_trait_terms - set(GLOSSARY_ES)), sorted(set(GLOSSARY_ES) - required_trait_terms)))
for trait in sorted(required_trait_terms):
    check_text("glossary_es." + trait, trait, GLOSSARY_ES.get(trait))

# 道具与角色：62 件道具、3 个角色；即时效果只标获得时机，不译成消耗。
check(set(NONCARD_ES["relics"]) == set(NONCARD_ZH["relics"]), "noncard 道具 ID 覆盖一致")
check(set(NONCARD_ES["classes"]) == set(NONCARD_ZH["classes"]), "noncard 角色 ID 覆盖一致")
check(len(NONCARD_ES["relics"]) == 62 and len(NONCARD_ES["classes"]) == 3,
      "noncard 为 62 件道具 + 3 个角色")
raw_relics = {str(row["id"]): row for row in RAW_RELICS}
for rid, zh_row in NONCARD_ZH["relics"].items():
    es_row = NONCARD_ES["relics"].get(rid, {})
    for field in ("name", "desc"):
        check_text("noncard.relics.%s.%s" % (rid, field), zh_row[field], es_row.get(field))
    is_instant = raw_relics[rid]["kind"] == "即时"
    check(is_instant == es_row.get("desc", "").startswith("Al recoger"),
          rid + " 即时道具 Al recoger 标记错误")
    check(re.search(r"\bse consumen?\s+al recoger", es_row.get("desc", "").lower()) is None,
          rid + " 即时道具误写为获得时消耗")
for cid, zh_row in NONCARD_ZH["classes"].items():
    es_row = NONCARD_ES["classes"].get(cid, {})
    check_text("noncard.classes.%s.name" % cid, cid, es_row.get("name"))
    for field in ("subtitle", "desc"):
        check_text("noncard.classes.%s.%s" % (cid, field), zh_row[field], es_row.get(field))

# 陷阱：以 traps.json 为真源。R663 尚未合入的干净快照里允许该文件缺席，
# 仍检查译文包自身结构；真源存在时执行完整 ID 覆盖与逐字段校验。
raw_traps = {str(row["id"]): row for row in RAW_TRAPS}
if raw_traps:
    check(set(TRAPS_ES["traps"]) == set(raw_traps), "traps ID 覆盖与 traps.json 一致")
    for tid, zh_row in raw_traps.items():
        es_row = TRAPS_ES["traps"].get(tid, {})
        for zh_field, es_field in (("name", "name"), ("desc", "desc")):
            check_text("traps.%s.%s" % (tid, es_field), zh_row[zh_field], es_row.get(es_field))
else:
    for tid, es_row in TRAPS_ES["traps"].items():
        check(tid.isdigit(), "traps.%s ID 不是数字" % tid)
        for field in ("name", "desc"):
            value = es_row.get(field)
            check(isinstance(value, str) and bool(value.strip()) and not has_cjk(value),
                  "traps.%s.%s 译文包结构/中文残留" % (tid, field))

# 事件正文、剧情与成就。
for section in ("events", "stories", "achievements"):
    check(set(NARRATIVE_ES[section]) == set(NARRATIVE_ZH[section]),
          "narrative " + section + " ID 覆盖一致")
for event_id, zh_row in NARRATIVE_ZH["events"].items():
    es_row = NARRATIVE_ES["events"].get(event_id, {})
    check_text("narrative.events.%s.name" % event_id, zh_row["name"], es_row.get("name"))
    check(set(es_row.get("texts", {})) == set(zh_row["texts"]),
          event_id + " 事件正文 key 覆盖一致")
    for key, zh_text in zh_row["texts"].items():
        check_text("narrative.events.%s.%s" % (event_id, key), zh_text,
                   es_row.get("texts", {}).get(key))
for story_id, zh_row in NARRATIVE_ZH["stories"].items():
    es_row = NARRATIVE_ES["stories"].get(story_id, {})
    for field in ("chapter", "title"):
        check_text("narrative.stories.%s.%s" % (story_id, field), zh_row[field], es_row.get(field))
    check(isinstance(es_row.get("text"), list) and len(es_row["text"]) == len(zh_row["text"]),
          story_id + " 剧情行数一致")
    for index, zh_text in enumerate(zh_row["text"]):
        es_text = es_row.get("text", [])[index] if index < len(es_row.get("text", [])) else None
        check_text("narrative.stories.%s.text[%d]" % (story_id, index), zh_text, es_text)
for achievement_id, zh_row in NARRATIVE_ZH["achievements"].items():
    es_row = NARRATIVE_ES["achievements"].get(achievement_id, {})
    for field in ("name", "hint"):
        check_text("narrative.achievements.%s.%s" % (achievement_id, field),
                   zh_row[field], es_row.get(field))

# 事件选项、结果、选货与篝火动态行。
event_zh_rows = flatten_event(EVENT_ZH)
event_es_rows = flatten_event(EVENT_ES)
check(set(event_es_rows) == set(event_zh_rows), "event_ui 全部 key 覆盖一致")
check(len(event_zh_rows) == 155, "event_ui 为 83 选项 + 64 结果 + 5 选货 + 3 动态")
for path, zh_text in event_zh_rows.items():
    check_text("event_ui." + path, zh_text, event_es_rows.get(path))
dynamic_map = {
    "REST_DYNAMIC_SACRAMENT_HEAL": "REST_SACRAMENT_RESULT_DESC",
    "REST_DYNAMIC_BANDAGE_HEAL": "REST_BANDAGE_RESULT_DESC",
    "REST_DYNAMIC_PIPE_RELIGHT": "REST_PIPE_RESULT_DESC",
}
for dynamic_key, narrative_key in dynamic_map.items():
    expected = "\n\n" + NARRATIVE_ES["events"]["rest"]["texts"][narrative_key]
    check(EVENT_ES["rest_dynamic"][dynamic_key] == expected,
          dynamic_key + " 与 narrative 共用同一西语译文")

# 788 条 canonical 界面文案（含实机截图补出的图鉴 / 事件 / 战斗 / 关卡出口）。
interface_zh_rows, interface_entries = flatten_interface(INTERFACE_ZH)
interface_es_rows, _ = flatten_interface(INTERFACE_ES, translated=True)
check(set(interface_es_rows) == set(interface_zh_rows), "interface 全部 scope.key 覆盖一致")
check(len(interface_zh_rows) == 794, "interface 共 794 条")
reuse_locked = set(INTERFACE_ZH.get("l10n_reuse", {})) | set(INTERFACE_ZH.get("glossary_reuse", {}))
for path, zh_text in interface_zh_rows.items():
    entry = interface_entries[path]
    check_text("interface." + path, zh_text, interface_es_rows.get(path),
               allow_cjk=entry.get("allow_cjk", False), check_terms=path not in reuse_locked)
for path, key in INTERFACE_ZH.get("l10n_reuse", {}).items():
    check(interface_es_rows.get(path) == L10N_ES.get(key), path + " 西语复用骨架 " + key)

# 标题/设置/首次选择骨架的 56 个 key。
l10n_source = (ROOT / "scripts/l10n.gd").read_text(encoding="utf-8-sig")
l10n_zh_rows = {}
pattern = re.compile(
    r'"(?P<key>[a-z0-9_.]+)"\s*:\s*\{\s*"zh"\s*:\s*(?P<zh>"(?:\\.|[^"\\])*")', re.S)
for match in pattern.finditer(l10n_source):
    l10n_zh_rows[match.group("key")] = json.loads(match.group("zh"))
check(set(L10N_ES) == set(l10n_zh_rows), "l10n 骨架 key 覆盖一致")
check(len(L10N_ES) == 56, "l10n 骨架共 56 条")
for key, zh_text in l10n_zh_rows.items():
    check_text("l10n." + key, zh_text, L10N_ES.get(key))

# 已修复规则与同文同译防回退。R663 三张卡的增强尚未进入干净 HEAD 时，
# 对应附加断言随权威 cards.json 一起启用，不要求西语提交夹带玩法改动。
raw_card_texts = {str(row["id"]): row.get("effect_text", "") for row in RAW_CARDS}
card_9005 = CARDS_ES["cards"]["9005"]["effect_text"]
if "效果卡区" in raw_card_texts["9005"]:
    check(all(text in card_9005 for text in ("Roba 2 cartas", "al menos 2 cartas", "recupera 1 de Coste")),
          "9005 保留抽 2、效果区至少 2 张、回 1 费三个分句")
card_9055 = CARDS_ES["cards"]["9055"]["effect_text"]
if "费用 -2" in raw_card_texts["9055"]:
    check("Cuesta -2" in card_9055 and "3 o más Aliados" in card_9055,
          "9055 保留 3 个盟友条件与 -2 费用")
if "死亡：抽一张卡" in raw_card_texts["9037"]:
    check("Muerte: roba 1 carta" in CARDS_ES["cards"]["9037"]["effect_text"],
          "9037 保留死亡抽 1 张")
card_9207 = CARDS_ES["cards"]["9207"]["effect_text"]
check("también obtiene +1 de Poder" in card_9207 and "en su lugar" not in card_9207,
      "9207 已有护甲时同时 +1 力量，而非替代加甲")
check("carta Épica" in EVENT_ES["options"]["cave"]["EXPLORE_CAVE"],
      "枭熊 canonical 为史诗卡，西语不沿用旧称传说卡")
for path in ("map.DECK_EDIT_VENDOR_TITLE", "map.DECK_EDIT_VENDOR_HINT", "map.DECK_EDIT_VENDOR_FAILED"):
    text = interface_es_rows[path]
    check("Coste 5 o más" in text and "Coste X" in text and "excepto" in text.lower(),
          path + " 保留 5 费及以上且 X 费除外")
for path in ("reward.REWARD_CORE_DESCRIPTION", "reward.REWARD_CORE_SUBTITLE_SACRIFICE",
             "reward.REWARD_CORE_TITLE_TARGET", "map.DECK_EDIT_CORE_NO_PAIR_DISABLED"):
    if path in interface_es_rows:
        text = interface_es_rows[path].lower()
        check("daño" in text and ("sin encantar" in text or "sin encantamiento" in text
                                  or "no encantada" in text or "aún no esté encantada" in text
                                  or "aún no tenga encantamiento" in text),
              path + " 保留另一张尚未附魔的伤害技能卡")
check(NONCARD_ES["classes"]["机械之心"]["name"] == "Corazón mecánico", "机械之心专名大小写锁定")
check(NONCARD_ES["classes"]["森林精魄"]["name"] == "Espíritu del bosque", "森林精魄专名大小写锁定")
check(("más de 20" in NONCARD_ES["relics"]["6029"]["desc"].lower()
       or "superior a 20" in NONCARD_ES["relics"]["6029"]["desc"].lower())
      and "20 o más" not in NONCARD_ES["relics"]["6029"]["desc"].lower(), "6029 严格大于 20")
check("15 o más" in NONCARD_ES["relics"]["6059"]["desc"].lower(), "6059 阈值达到 15")
for path in ("options.card_merchant.BARTER_FOR_BIG_CHEST",):
    text = event_es_rows[path]
    check("5" in text and "X" in text and "excepto" in text.lower(),
          path + " 保留 5 费及以上且 X 费除外")
for path in ("options.cave.EXPLORE_CAVE",):
    check("Épica" in event_es_rows[path] or "épica" in event_es_rows[path],
          path + " 枭熊奖励为 Épica，不虚构 Legendaria")
for path in ("options.rest.ADD_FIREWOOD", "options.oblivion.FORGET_CARD",
             "results.lake_lady.LAKE_LADY_LIE_RESULT",
             "results.delivery_done.DELIVERY_DONE_CARGO_REMOVED", "pickers.delivery.note"):
    check("desterr" not in event_es_rows[path].lower(), path + " 永久删除不误译为 desterrar")
same_text_groups = (
    ("reward.REWARD_DUCK_BLOOD_NO_COPY", "map.DECK_EDIT_DUPLICATE_NONE"),
    ("reward.REWARD_CARD_META", "map.DECK_EDIT_CARD_META", "map.PICK_CARD_META",
     "shell.CURTAIN_LINKED_CARD_META", "shared.MENTION_CARD_TIP_META",
     "shared.MENTION_GRANTED_CARD_META"),
    ("map.GALLERY_BACK_CODEX", "shell.STORY_BACK_CODEX"),
    ("map.GALLERY_MENU_RETURN_CODEX", "shell.STORY_MENU_BACK_CODEX"),
    ("map.GALLERY_BACK_TITLE", "shell.STORY_BACK_TITLE", "shell.RECORD_BACK_TITLE"),
)
for paths in same_text_groups:
    check(len({interface_es_rows[path] for path in paths}) == 1,
          "同文西语译法一致：" + ", ".join(paths))

# 别名只能指向真实 canonical 正文，不允许静默制造孤立映射。
narrative_texts = {text for row in NARRATIVE_ZH["events"].values() for text in row["texts"].values()}
for raw, canonical in SOURCE_ALIASES.items():
    check(bool(raw.strip()) and canonical in narrative_texts, "事件别名锚点有效：" + raw[:24])

if errors:
    print("\nSPANISH I18N FAIL: %d errors / %d checks" % (len(errors), checks))
    for error in errors:
        print("  -", error)
    sys.exit(1)
print("SPANISH I18N OK: %d checks" % checks)
print("  cards=319 | relics=62 | classes=3 | traps=%d" % len(raw_traps))
print("  events=26/64 | stories=11/54 | achievements=11 | event_ui=155 | interface=794 | l10n=56")
