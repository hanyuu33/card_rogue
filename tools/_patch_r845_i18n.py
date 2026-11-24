# -*- coding: utf-8 -*-
"""R845：暗影刺客 11 张卡的英 / 日 / 西卡面文本同步。

只改 `effect_text`（名字没动）。这几份文件是 `json.dumps(indent=1)` + 末尾换行，
可以整份重排 —— 写前先做一次「原样还原」自检，确认不会把无关行一起搅进 diff。
"""
import json
from pathlib import Path

ROOT = Path("E:/work/card_rogue")
TARGETS = {
    "en": {
        "9088": "Deal 2 damage to a target; that target loses 3 Power this turn.",
        "9087": "Deal 5 damage to a target, then add a random 0-cost Skill card from your Draw Pile to your Hand.",
        "9119": "Deal 5 damage to a target, then draw 1 card.",
        "9090": "Deal 4 damage; if the target is at full Health, deal 10 damage instead.",
        "9121": "Deal 13 damage to a target, then return **any card of your choice from the Discard Pile** to your Hand.",
        "9173": "Draw 4 cards. Until the end of this turn, you cannot use Ally or Structure cards.",
        "9091": "Every 3 cards you use in the same turn, deal 8 damage to a random enemy and reduce its Power by 1. Multiple copies of this card in the Effect Zone do not stack.",
        "9233": "Each time you deal damage to a Marked enemy, this card's Cost is permanently reduced by 1. When this card kills a unit, gain 2 Cost and draw 2 cards.",
        "9176": "The next time you take more than 1 damage, it becomes 1, then draw 2 cards.",
        "8062": "At the end of your turn, deal X damage to all enemies, where X is your remaining Cost.",
    },
    "ja": {
        "9088": "対象に2ダメージを与え、このターン、その攻撃力-3。",
        "9087": "対象に5ダメージを与え、山札からランダムなコスト0のスキルカード1枚を手札に加える。",
        "9119": "対象に5ダメージを与え、その後カードを1枚ドローする。",
        "9090": "4ダメージを与える。対象が最大HPの状態なら、代わりに10ダメージを与える。",
        "9121": "対象に13ダメージを与え、その後**捨て札置き場から任意の1枚**を手札に戻す。",
        "9173": "カードを4枚ドローする。このターンの終了まで、味方カードと構造物カードを使用できない。",
        "9091": "同じターン中にカードを3枚使用するたび、ランダムな敵1体に8ダメージを与え、その攻撃力-1。効果ゾーンにこのカードが複数あっても重複しない。",
        "9233": "標記された敵にダメージを与えるたび、このカードのコストを永続的に-1。このカードがユニットを撃破した時、コストを2回復し、カードを2枚ドローする。",
        "9176": "次にあなたが受ける1を超えるダメージは1になり、その後カードを2枚ドローする。",
        "8062": "自分のターン終了時、すべての敵にXダメージを与える。Xは残りコスト。",
    },
    "es": {
        "9088": "Inflige 2 de daño a un objetivo; ese objetivo pierde 3 de Poder este turno.",
        "9087": "Inflige 5 de daño a un objetivo y añade una carta de Habilidad aleatoria de Coste 0 de la pila de robo a la mano.",
        "9119": "Inflige 5 de daño a un objetivo y luego roba 1 carta.",
        "9090": "Inflige 4 de daño; si el objetivo tiene toda su Vida, inflige 10 de daño en su lugar.",
        "9121": "Inflige 13 de daño a un objetivo y luego devuelve **cualquier carta que elijas de la pila de descarte** a la mano.",
        "9173": "Roba 4 cartas. Hasta el final de este turno, no puedes usar cartas de Aliado ni de Estructura.",
        "9091": "Cada 3 cartas que uses en el mismo turno, inflige 8 de daño a un enemigo aleatorio y reduce su Poder en 1. Varias copias de esta carta en la zona de Efectos no se acumulan.",
        "9233": "Cada vez que infliges daño a un enemigo marcado, el Coste de esta carta se reduce permanentemente en 1. Cuando esta carta mata a una unidad, gana 2 de Coste y roba 2 cartas.",
        "9176": "La próxima vez que recibas más de 1 de daño, se convierte en 1 y luego robas 2 cartas.",
        "8062": "Al final de tu turno, inflige X de daño a todos los enemigos, donde X es tu Coste restante.",
    },
}


def main():
    for lang, table in TARGETS.items():
        path = ROOT / ("i18n/cards_%s.json" % lang)
        raw = path.read_bytes().decode("utf-8")
        data = json.loads(raw)
        again = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
        assert again == raw, "cards_%s.json 不是 indent=1 + 末尾换行的格式，停止整份重排" % lang
        for cid, text in table.items():
            assert cid in data["cards"], (lang, cid)
            data["cards"][cid]["effect_text"] = text
        out = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
        path.write_bytes(out.encode("utf-8"))
        print("OK", lang, "changed", len(table))


if __name__ == "__main__":
    main()
