# -*- coding: utf-8 -*-
"""R761 补丁 11：i18n 补齐（新增两张卡 + 一件角色赠品道具）。

改动面（照 R756 的惯例，那张卡只动了这一套）：
  zh_canonical / cards_en / cards_ja / cards_es   ← 杜鹃 9263 / 招募 9264
  glossary.json                                    ← 道具名「诗」（validate_glossary 逐件核对 id）
  noncard_zh_canonical / _en / _ja / _es           ← 「诗」6069 的名称与长描述
  validate_noncard.py                              ← 道具总数 62 → 63（计数锁，与 test_engine 同一口径）

⚠️ 吟游诗人**不进** noncard 的 classes 三件套（隐藏职业不给玩家看长描述，
   `GameI18n.class_field()` 缺键时回落到中文），validate_noncard 的「三角色覆盖」断言因此不动。

所有文件先验证「读进来再原样 dump 能否字节还原」，能还原才改 —— 避免整篇重排导致 diff 全红。
"""
import json
import sys

FILES = {}

TEXTS = {
    "9263": {
        "zh": {"name": "杜鹃", "effect_text": ""},
        "en": {"name": "Cuckoo", "effect_text": ""},
        "ja": {"name": "カッコウ", "effect_text": ""},
        "es": {"name": "Cuco", "effect_text": ""},
    },
    "9264": {
        "zh": {"name": "招募", "effect_text": "从三个其他职业的盟友中选一张，加入手卡。"},
        "en": {"name": "Recruit",
               "effect_text": "Choose 1 of 3 Allies (one from each other class) and add it to your Hand."},
        "ja": {"name": "勧誘",
               "effect_text": "他クラスの味方3枚（各クラス1枚）から1枚を選び、手札に加える。"},
        "es": {"name": "Reclutar",
               "effect_text": "Elige 1 de 3 Aliados (uno de cada otra clase) y añádelo a la mano."},
    },
}

RELIC_NAME = {"en": "Poem", "ja": "詩", "es": "Poema"}
RELIC_DESC_ZH = "每回合第一次使用其他职业的盟友时，回复 1 点费用。其他职业的盟友 +2 力量（持续生效，不叠加）。"
RELIC_DESC = {
    "en": "The first time each turn you use an Ally from another class: gain 1 Cost. "
          "Allies from other classes have +2 Power (persistent; does not stack).",
    "ja": "毎ターン最初に他クラスの味方を使用したとき、コストを1得る。"
          "他クラスの味方の攻撃力+2（継続し、重複しない）。",
    "es": "La primera vez cada turno que uses un Aliado de otra clase, ganas 1 de Coste. "
          "Los Aliados de otras clases tienen +2 de Poder (efecto persistente; no se acumula).",
}


def load_rt(path):
    """读入 JSON，并找出能字节还原原文的 indent（None = 紧凑格式）。"""
    raw = open(path, encoding="utf-8").read()
    data = json.loads(raw)
    body = raw[:-1] if raw.endswith("\n") else raw
    for indent in (1, 2, 4, None):
        cand = json.dumps(data, ensure_ascii=False, indent=indent)
        if cand == body:
            return data, indent, raw.endswith("\n")
    print("FAIL: %s 无法原样 dump（格式不统一，改用文本插入）" % path)
    sys.exit(1)


def save_rt(path, data, indent, trailing_nl):
    out = json.dumps(data, ensure_ascii=False, indent=indent)
    if trailing_nl:
        out += "\n"
    open(path, "w", encoding="utf-8", newline="\n").write(out)
    # 复核：读回来必须与内存一致
    assert json.loads(open(path, encoding="utf-8").read()) == data
    print("  wrote", path)


def patch_cards(path, lang):
    data, indent, nl = load_rt(path)
    cards = data["cards"]
    for cid in ("9263", "9264"):
        assert cid not in cards, "%s 已含 %s，本补丁不重入" % (path, cid)
        cards[cid] = dict(TEXTS[cid][lang])
    data["count"] = len(cards)
    save_rt(path, data, indent, nl)
    assert len(cards) == 325, "%s 卡数 %d（应 325）" % (path, len(cards))


def patch_zh_canonical(path):
    data, indent, nl = load_rt(path)
    cards = data["cards"]
    for cid in ("9263", "9264"):
        assert cid not in cards
        row = dict(TEXTS[cid]["zh"])
        row["changed"] = False
        cards[cid] = row
    save_rt(path, data, indent, nl)
    assert len(cards) == 325


def patch_glossary(path):
    data, indent, nl = load_rt(path)
    relics = data["relics"]
    assert "诗" not in relics
    relics["诗"] = {"en": RELIC_NAME["en"], "ja": RELIC_NAME["ja"], "id": 6069}
    save_rt(path, data, indent, nl)
    assert data["relics"]["诗"]["id"] == 6069


def patch_noncard(path, lang):
    data, indent, nl = load_rt(path)
    relics = data["relics"]
    assert "6069" not in relics
    if lang == "zh":
        relics["6069"] = {"name": "诗", "desc": RELIC_DESC_ZH}
    else:
        relics["6069"] = {"name": RELIC_NAME[lang], "desc": RELIC_DESC[lang]}
    save_rt(path, data, indent, nl)
    assert len(relics) == 63, "%s 道具 %d 件（应 63）" % (path, len(relics))


def patch_validator(path):
    raw = open(path, encoding="utf-8").read()
    pairs = [
        ('check(len(SOURCE) == 62 and len(expected_ids) == 62, "真源为 62 件不重复道具")',
         'check(len(SOURCE) == 63 and len(expected_ids) == 63, "真源为 63 件不重复道具")'),
        ('"\\nNONCARD I18N OK: 62 relics + 3 classes',
         '"\\nNONCARD I18N OK: 63 relics + 3 classes'),
    ]
    for old, new in pairs:
        if raw.count(old) != 1:
            print("FAIL: %s 锚点命中 %d 次：%r" % (path, raw.count(old), old[:60]))
            sys.exit(1)
        raw = raw.replace(old, new, 1)
    open(path, "w", encoding="utf-8", newline="\n").write(raw)
    print("  wrote", path)


def main():
    for lang, path in (("zh", "i18n/zh_canonical.json"),
                       ("en", "i18n/cards_en.json"),
                       ("ja", "i18n/cards_ja.json"),
                       ("es", "i18n/cards_es.json")):
        if lang == "zh":
            patch_zh_canonical(path)
        else:
            patch_cards(path, lang)
    patch_glossary("i18n/glossary.json")
    for lang, path in (("zh", "i18n/noncard_zh_canonical.json"),
                       ("en", "i18n/noncard_en.json"),
                       ("ja", "i18n/noncard_ja.json"),
                       ("es", "i18n/noncard_es.json")):
        patch_noncard(path, lang)
    patch_validator("i18n/validate_noncard.py")
    print("i18n OK")


if __name__ == "__main__":
    main()
