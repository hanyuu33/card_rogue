# -*- coding: utf-8 -*-
"""R667：商店、奖励、地图、剧情界面与共享组件的只读翻译校验。"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "interface_zh_canonical.json").read_text(encoding="utf-8"))
GLOSSARY = json.loads((I18N / "glossary.json").read_text(encoding="utf-8"))
CARDS = json.loads((ROOT / "cards.json").read_text(encoding="utf-8-sig"))["cards"]
CARDS_EN = json.loads((I18N / "cards_en.json").read_text(encoding="utf-8"))["cards"]
CARDS_JA = json.loads((I18N / "cards_ja.json").read_text(encoding="utf-8"))["cards"]
SCOPES = ("shop", "reward", "map", "battle", "shell", "shared")
errors = []
source_cache = {}


def check(ok, message):
    if ok:
        print("  [OK]", message)
    else:
        errors.append(message)


def flatten(data, translated=False):
    rows = {}
    for scope in SCOPES:
        for key, entry in data["scopes"].get(scope, {}).items():
            rows[scope + "." + key] = entry if translated else entry["zh"]
    return rows


def placeholders(text):
    return Counter(re.findall(r"%%|%(?:\d+\$)?[-+0-9.]*[sdfg]", text))


def digits(text):
    return Counter(re.findall(r"\d+", text))


def tags(text):
    return Counter(re.findall(r"\[/?[A-Za-z_]+(?:=[^\]]+)?\]|\{[A-Za-z_][A-Za-z0-9_]*\}", text))


def quoted(text):
    return re.findall(r"「([^」]+)」", text) + re.findall(r"【([^】]+)】", text)


def source_line_match(entry, text, source_text):
    """多段拼接/动态占位模板：限定源码行，逐段核对中文碎片，不整句跳过。"""
    ref = entry["source"].split(":", 1)[1]
    match = re.fullmatch(r"(\d+)(?:-(\d+))?", ref)
    if not match:
        return False
    start = int(match.group(1))
    end = int(match.group(2) or start)
    lines = source_text.splitlines()
    if start < 1 or end > len(lines):
        return False
    segment = "\n".join(lines[start - 1:end])
    literals = []
    for token in re.findall(r'"(?:\\.|[^"\\\r\n])*"', segment):
        try:
            literals.append(json.loads(token))
        except Exception:
            continue
    if entry.get("source_parts"):
        return all(part in literals and part in text for part in entry["source_parts"])
    fragments = [value for value in literals if re.search(r"[\u3400-\u9fff]", value)]
    return bool(fragments) and all(fragment in text for fragment in fragments)


def source_info(filename):
    if filename not in source_cache:
        path = ROOT / filename
        if not path.exists():
            source_cache[filename] = (set(), set(), "")
            return source_cache[filename]
        text = path.read_text(encoding="utf-8-sig")
        literals = {
            json.loads(token) for token in re.findall(r'"(?:\\.|[^"\\\r\n])*"', text)
        }
        literals.update(re.findall(r'"""([\s\S]*?)"""', text))
        pairs = {left + right for left in literals for right in literals}
        source_cache[filename] = (literals, pairs, text)
    return source_cache[filename]


# 每条规范中文都能回到权威源；明确审计过的漂移只在 canonical 修正。
zh_rows = flatten(ZH)
entries = {}
for scope in SCOPES:
    for key, entry in ZH["scopes"].get(scope, {}).items():
        entries[scope + "." + key] = entry
check(set(zh_rows) == set(entries), "六组界面底本键可稳定展开")
overrides = ZH.get("canonical_overrides", {})
for path, entry in entries.items():
    filename = entry["source"].split(":", 1)[0]
    literals, pairs, source_text = source_info(filename)
    if not source_text:
        errors.append(path + " 源文件不存在：" + filename)
        continue
    if path in overrides:
        original = overrides[path]
        if original not in literals and original not in pairs:
            errors.append(path + " canonical 原文锚点未在真源中找到")
        if entry["zh"] == original:
            errors.append(path + " 登记 canonical 修正但内容未变化")
    elif (entry["zh"] not in literals and entry["zh"] not in pairs
          and not source_line_match(entry, entry["zh"], source_text)):
        errors.append(path + " 未在源文件字面量、拼接或限定行碎片中找到")
for path in overrides:
    if path not in entries:
        errors.append(path + " canonical 修正锚点已失效")
for scope in SCOPES:
    check(bool(ZH["scopes"].get(scope)), scope + " 底本非空")
    expected = ZH.get("expected_counts", {}).get(scope)
    if expected is not None:
        check(len(ZH["scopes"][scope]) == expected,
              "%s 条目数锁定为 %d" % (scope, expected))

# 术语索引与卡名索引。
term_index = defaultdict(list)
for section, section_entries in GLOSSARY.items():
    if not isinstance(section_entries, dict):
        continue
    for zh, entry in section_entries.items():
        if isinstance(entry, dict) and "en" in entry and "ja" in entry:
            term_index[zh].append(entry)
card_names = defaultdict(set)
for card in CARDS:
    cid = str(card["id"])
    if cid in CARDS_EN and cid in CARDS_JA:
        card_names[card["name"]].add((CARDS_EN[cid]["name"], CARDS_JA[cid]["name"]))

# 已接入标题/设置骨架的译文必须复用，不能同句两译。
l10n_text = (ROOT / "scripts/l10n.gd").read_text(encoding="utf-8-sig")
l10n_rows = {}
pattern = re.compile(
    r'"(?P<key>[a-z0-9_.]+)"\s*:\s*\{\s*"zh"\s*:\s*(?P<zh>"(?:\\.|[^"\\])*")'
    r'\s*,\s*"en"\s*:\s*(?P<en>"(?:\\.|[^"\\])*")'
    r'\s*,\s*"ja"\s*:\s*(?P<ja>"(?:\\.|[^"\\])*")', re.S)
for match in pattern.finditer(l10n_text):
    l10n_rows[match.group("key")] = {
        lang: json.loads(match.group(lang)) for lang in ("zh", "en", "ja")
    }
check(len(l10n_rows) >= 50, "读取 l10n.gd 既有三语界面文案")


def check_text(path, zh_text, tr_text, lang):
    label = lang + " " + path
    if not isinstance(tr_text, str) or not tr_text.strip():
        errors.append(label + " 译文为空")
        return
    reuse_locked = path in ZH.get("l10n_reuse", {}) or path in ZH.get("glossary_reuse", {})
    same_short_japanese = lang == "ja" and len(zh_text) <= 16
    if (tr_text == zh_text and re.search(r"[\u3400-\u9fff]", zh_text)
            and not entries[path].get("allow_same") and not reuse_locked
            and not same_short_japanese):
        errors.append(label + " 译文与中文完全相同")
    if placeholders(tr_text) != placeholders(zh_text):
        errors.append("%s 占位符漂移 zh=%s tr=%s" % (
            label, dict(placeholders(zh_text)), dict(placeholders(tr_text))))
    if tags(tr_text) != tags(zh_text):
        errors.append("%s BBCode/花括号标签漂移 zh=%s tr=%s" % (
            label, dict(tags(zh_text)), dict(tags(tr_text))))
    if tr_text.count("\n") != zh_text.count("\n"):
        errors.append(label + " 换行数漂移")
    missing_digits = digits(zh_text) - digits(tr_text)
    if missing_digits:
        errors.append("%s 缺数字 %s" % (label, dict(missing_digits)))
    if lang == "en" and re.search(r"[\u3400-\u9fff]", tr_text) and not entries[path].get("allow_cjk"):
        errors.append(label + " 英文残留中文")
    for word in (quoted(zh_text) if not reuse_locked else []):
        if word in card_names:
            expected = {pair[0 if lang == "en" else 1] for pair in card_names[word]}
            if not any(name in tr_text for name in expected):
                errors.append("%s 未复用卡名 %s -> %s" % (label, word, sorted(expected)))
        elif word in term_index:
            if not any(entry[lang] in tr_text for entry in term_index[word]):
                expected = [entry[lang] for entry in term_index[word]]
                errors.append("%s 未复用术语 %s -> %s" % (label, word, expected))
    # 整句标签可能有时态、复数和按钮语境；强制同译只走显式 glossary_reuse，
    # 不对所有同形中文做上下文无关的硬匹配。


translations = {}
for lang in ("en", "ja"):
    path = I18N / ("interface_" + lang + ".json")
    if not path.exists():
        errors.append("缺少 " + path.name)
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    translations[lang] = data
    rows = flatten(data, translated=True)
    check(set(rows) == set(zh_rows), lang + " 全部界面 key 无缺无多")
    for text_path, zh_text in zh_rows.items():
        if text_path in rows:
            check_text(text_path, zh_text, rows[text_path], lang)

if len(translations) == 2:
    en = flatten(translations["en"], translated=True)
    ja = flatten(translations["ja"], translated=True)
    for path, key in ZH.get("l10n_reuse", {}).items():
        if path not in entries or key not in l10n_rows:
            errors.append(path + " 的 l10n 复用锚点失效：" + key)
            continue
        check(zh_rows[path].replace(" ", "") == l10n_rows[key]["zh"].replace(" ", ""),
              path + " 中文与 " + key + " 同源（标题排版空格除外）")
        check(en[path] == l10n_rows[key]["en"], path + " 英文复用 " + key)
        check(ja[path] == l10n_rows[key]["ja"], path + " 日文复用 " + key)
    for path, ref in ZH.get("glossary_reuse", {}).items():
        if path not in entries or "." not in ref:
            errors.append(path + " 的 glossary 复用锚点失效：" + ref)
            continue
        section, zh_name = ref.split(".", 1)
        expected = GLOSSARY.get(section, {}).get(zh_name)
        if not expected:
            errors.append(path + " 的 glossary 词条不存在：" + ref)
            continue
        if path in ZH.get("glossary_contains", []):
            check(expected["en"] in en[path], path + " 英文包含术语 " + ref)
            check(expected["ja"] in ja[path], path + " 日文包含术语 " + ref)
        else:
            check(en[path] == expected["en"], path + " 英文复用 " + ref)
            check(ja[path] == expected["ja"], path + " 日文复用 " + ref)

    # 已审计的规则与术语修正防回退。
    check("5" in en["map.DECK_EDIT_VENDOR_FAILED"]
          and "X" in en["map.DECK_EDIT_VENDOR_FAILED"]
          and ("except" in en["map.DECK_EDIT_VENDOR_FAILED"].lower()
               or "exclud" in en["map.DECK_EDIT_VENDOR_FAILED"].lower()),
          "易物失败英文为 5 费及以上且 X 费除外")
    check("5" in ja["map.DECK_EDIT_VENDOR_FAILED"]
          and "X" in ja["map.DECK_EDIT_VENDOR_FAILED"]
          and ("除外" in ja["map.DECK_EDIT_VENDOR_FAILED"]
               or "除く" in ja["map.DECK_EDIT_VENDOR_FAILED"]),
          "易物失败日文为 5 费及以上且 X 费除外")
    for path in ("map.DECK_EDIT_VENDOR_TITLE", "map.DECK_EDIT_VENDOR_HINT"):
        check("5" in en[path] and "X" in en[path]
              and "exclud" in en[path].lower(),
              path + " 英文保留 5 费及以上且 X 费除外")
        check("5" in ja[path] and "X" in ja[path]
              and ("除外" in ja[path] or "除く" in ja[path]),
              path + " 日文保留 5 费及以上且 X 费除外")
    check("search term" in en["map.GALLERY_SUMMARY_TEXT_ONLY"].lower()
          and "検索" in ja["map.GALLERY_SUMMARY_TEXT_ONLY"],
          "图鉴搜索计数明确为卡名不含搜索词")
    for path in ("map.MAP_FLINT_INVALID_CELL", "map.MAP_FLY_INVALID_CELL"):
        check("Fixed Shop" in en[path] and "固定商店" in ja[path],
              path + " 只排除固定商店")
    check("Boss" in en["map.MAP_FLINT_INVALID_CELL"]
          and "ボス" in ja["map.MAP_FLINT_INVALID_CELL"],
          "燧石提示保留首领格限制")
    same_text_groups = {
        "鸭血空复制结果": ("reward.REWARD_DUCK_BLOOD_NO_COPY", "map.DECK_EDIT_DUPLICATE_NONE"),
        "卡信息模板": ("reward.REWARD_CARD_META", "map.DECK_EDIT_CARD_META",
                       "map.PICK_CARD_META", "shell.CURTAIN_LINKED_CARD_META",
                       "shared.MENTION_CARD_TIP_META", "shared.MENTION_GRANTED_CARD_META"),
        "百科返回按钮": ("map.GALLERY_BACK_CODEX", "shell.STORY_BACK_CODEX"),
        "百科返回菜单": ("map.GALLERY_MENU_RETURN_CODEX", "shell.STORY_MENU_BACK_CODEX"),
        "标题返回按钮": ("map.GALLERY_BACK_TITLE", "shell.STORY_BACK_TITLE",
                         "shell.RECORD_BACK_TITLE"),
    }
    for label, paths in same_text_groups.items():
        check(len({en[path] for path in paths}) == 1
              and len({ja[path] for path in paths}) == 1,
              label + " 同文英日译法一致")
    for path in ("reward.REWARD_TYPE_LEGENDARY", "reward.REWARD_LEGENDARY_CARD_NAME",
                 "reward.REWARD_LEGENDARY_CARD_FALLBACK"):
        check("Epic" in en[path] and "エピック" in ja[path],
              path + " 洞穴奖励为 Epic／エピック")
    for path in ("reward.REWARD_CORE_DESCRIPTION", "reward.REWARD_CORE_SUBTITLE_SACRIFICE",
                 "reward.REWARD_CORE_TITLE_TARGET"):
        check(("unenchanted" in en[path].lower() or "no enchant" in en[path].lower())
              and "damage" in en[path].lower(), path + " 核心接收者英文条件完整")
        check(("未付呪" in ja[path] or "付呪されていない" in ja[path])
              and "ダメージ" in ja[path], path + " 核心接收者日文条件完整")
    shop_hint_en = en["shop.SHOP_ENCHANT_INELIGIBLE_CARD"].lower()
    shop_hint_ja = ja["shop.SHOP_ENCHANT_INELIGIBLE_CARD"]
    check("type" not in shop_hint_en
          and any(word in shop_hint_en for word in ("eligib", "require", "condition", "does not meet")),
          "商店附魔禁用提示英文不再误写为仅类型不符")
    check("タイプ" not in shop_hint_ja and "種類" not in shop_hint_ja
          and any(word in shop_hint_ja for word in ("条件", "要件", "対象外")),
          "商店附魔禁用提示日文不再误写为仅类型不符")
    check(en["shell.CURTAIN_SPEAKER"] == "Pippin"
          and ja["shell.CURTAIN_SPEAKER"] == "ピピン",
          "卷卷采用西幻本土化译名 Pippin／ピピン")
    check("risusumai" in en["shell.CREDITS_BODY"]
          and "risusumai" in ja["shell.CREDITS_BODY"]
          and "Juanjuan" not in en["shell.CREDITS_BODY"],
          "鸣谢使用官方署名 risusumai")
    for path, zh_text in zh_rows.items():
        if "删除" in zh_text or "永久移除" in zh_text:
            check("banish" not in en[path].lower() and "消滅" not in ja[path],
                  path + " 永久删除不译成 Banish／消滅")
        if "卡组" in zh_text:
            check("Draw Pile" not in en[path] and "山札" not in ja[path],
                  path + " 卡组不译成 Draw Pile／山札")
        if "抽牌堆" in zh_text:
            check("Draw Pile" in en[path] and "山札" in ja[path],
                  path + " 抽牌堆使用 Draw Pile／山札")
    event_reward_keys = [key for key, entry in ZH["scopes"]["reward"].items()
                         if entry["source"].startswith("scripts/event_scene.gd")]
    check(set(event_reward_keys) == {"REWARD_EVENT_ARCANE_TITLE", "REWARD_EVENT_CORE_TITLE"},
          "奖励分片仅保留两个事件标题，其余复用 R665")

if errors:
    print("\nINTERFACE I18N FAIL")
    for error in errors:
        print("  -", error)
    sys.exit(1)
counts = {scope: len(ZH["scopes"][scope]) for scope in SCOPES}
print("\nINTERFACE I18N OK:", counts, "total", len(zh_rows))
