# -*- coding: utf-8 -*-
"""R846：七张卡的四语文本同步（en / ja / es + zh_canonical）。

只改 effect_text；`count` / `updated` / `changed_count` 一律不动（R845 的教训：
改元数据会造出与内容无关的 diff）。
"""
import io
import json

ZH = {
    "8006": "打出时，若本回合已经使用过 3 张其他卡，抽 2 张牌。",
    "9231": "使用时，若场上没有标记，随机标记一个格子。"
            "自己回合结束时，处于标记格的敌人受到 4X 点伤害。X 为本卡在效果区的张数。",
    "9089": "对一个目标造成 X 点伤害，抽 X 张牌，X 为本回合你已使用其他卡的张数。"
            "这些牌本回合结束不会丢弃。",
    "9103": "使一个敌方单位力量 -X，X 为你本回合打出的牌数。",
    "9111": "自己回合结束时，对随机一个敌人造成 X 点伤害，X 为你本回合已使用的卡牌张数。"
            "效果区多张本卡不可叠加。",
}

EN = {
    "8006": "When played, if you have already used 3 other cards this turn, draw 2 cards.",
    "9231": "When used, if there is no Mark on the field, randomly Mark a tile. "
            "At the end of your turn, enemies on Marked tiles take 4X damage. "
            "X is the number of copies of this card in the Effect Zone.",
    "9089": "Deal X damage to a target and draw X cards, where X is the number of "
            "other cards you have used this turn. Those cards are not discarded at the "
            "end of this turn.",
    "9103": "Reduce an enemy unit's Power by X, where X is the number of cards you "
            "have played this turn.",
    "9111": "At the end of your turn, deal X damage to a random enemy, where X is the "
            "number of cards you have used this turn. Multiple copies of this card in "
            "the Effect Zone do not stack.",
}

JA = {
    "8006": "使用時、このターンに既に他のカードを3枚使用していれば、カードを2枚ドローする。",
    "9231": "使用時、場に標記が無ければランダムなマス1つを標記する。"
            "自分のターン終了時、標記されたマスにいる敵は4Xダメージを受ける。"
            "Xは効果ゾーンにあるこのカードの枚数。",
    "9089": "1体の対象にXダメージを与え、カードをX枚ドローする。"
            "Xはこのターンに使用した他のカードの枚数。"
            "それらのカードはこのターン終了時に捨て札にならない。",
    "9103": "敵ユニット1体の攻撃力をX減らす。Xはこのターンに使用したカードの枚数。",
    "9111": "自分のターン終了時、ランダムな敵1体にXダメージを与える。"
            "Xはこのターンに使用したカードの枚数。"
            "効果ゾーンにこのカードが複数あっても重複しない。",
}

ES = {
    "8006": "Al jugarse, si ya has usado otras 3 cartas este turno, roba 2 cartas.",
    "9231": "Al usarse, si no hay ninguna Marca en el campo, marca una casilla al azar. "
            "Al final de tu turno, los enemigos en casillas marcadas reciben 4X de daño. "
            "X es el número de copias de esta carta en la zona de Efectos.",
    "9089": "Inflige X de daño a un objetivo y roba X cartas, donde X es el número de "
            "otras cartas que has usado este turno. Esas cartas no se descartan al final "
            "de este turno.",
    "9103": "Reduce el Poder de una unidad enemiga en X, donde X es el número de cartas "
            "que has jugado este turno.",
    "9111": "Al final de tu turno, inflige X de daño a un enemigo aleatorio, donde X es "
            "el número de cartas que has usado este turno. Varias copias de esta carta "
            "en la zona de Efectos no se acumulan.",
}

PACKS = [("i18n/cards_en.json", "en", EN), ("i18n/cards_ja.json", "ja", JA),
         ("i18n/cards_es.json", "es", ES)]


def dump_like(path, obj):
    """i18n cards_*.json 的既有排版：indent=1 + 末尾换行（LF）。"""
    return json.dumps(obj, ensure_ascii=False, indent=1) + "\n"


def main():
    # 0) 先确认原文件能被「原样序列化」回来，否则说明排版假设错了，不能整份写回
    for path, _lang, _dict in PACKS:
        raw = io.open(path, "r", encoding="utf-8", newline="").read()
        obj = json.loads(raw)
        assert dump_like(path, obj) == raw, "%s 的排版不是 indent=1 + 末尾换行" % path

    for path, lang, table in PACKS:
        raw = io.open(path, "r", encoding="utf-8", newline="").read()
        obj = json.loads(raw)
        for cid, text in table.items():
            assert cid in obj["cards"], "%s 缺卡 %s" % (path, cid)
            obj["cards"][cid]["effect_text"] = text
        io.open(path, "w", encoding="utf-8", newline="").write(dump_like(path, obj))
        print("%s 更新 %d 条" % (path, len(table)))

    # zh_canonical：只改文本
    p = "i18n/zh_canonical.json"
    raw = io.open(p, "r", encoding="utf-8", newline="").read()
    obj = json.loads(raw)
    assert dump_like(p, obj) == raw, "zh_canonical 排版不是 indent=1 + 末尾换行"
    for cid, text in ZH.items():
        assert cid in obj["cards"], "zh_canonical 缺卡 %s" % cid
        obj["cards"][cid]["effect_text"] = text
    io.open(p, "w", encoding="utf-8", newline="").write(dump_like(p, obj))
    print("%s 更新 %d 条" % (p, len(ZH)))

    # 与 cards.json 逐条核对
    cards = {c["id"]: c for c in json.load(
        io.open("cards.json", encoding="utf-8"))["cards"]}
    zhc = json.load(io.open(p, encoding="utf-8"))["cards"]
    for cid in ZH:
        assert cards[int(cid)]["effect_text"] == zhc[cid]["effect_text"], \
            "zh_canonical 与 cards.json 不一致：%s" % cid
    print("I18N_OK")


if __name__ == "__main__":
    main()
