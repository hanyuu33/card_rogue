# -*- coding: utf-8 -*-
"""R838b：暗动力 6054 文案改序 —— 收益前置（每回合多抽一张）、代价后置。"""
import io

ZH_OLD = "你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面，也不能留到以后领取。商店里同样无法删除卡牌。作为交换，每回合开始时多抽一张牌。"
ZH_NEW = "每回合开始时多抽一张牌。代价是你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面，也不能留到以后领取；商店里同样无法删除卡牌。"

EN_OLD = "You cannot skip card rewards: you must take 1 card on the spot to close the reward screen, and you cannot save the reward for later. You also cannot Remove cards from your Deck at shops. In exchange, draw 1 additional card at the start of each turn."
EN_NEW = "At the start of each turn, draw 1 additional card. The cost: you cannot skip card rewards — you must take 1 card on the spot to close the reward screen, and you cannot save the reward for later; you also cannot Remove cards from your Deck at shops."

JA_OLD = "カード報酬を見送れなくなる：報酬画面を閉じるにはその場でカードを1枚受け取る必要があり、後回しにすることもできない。商店でもデッキからカードを削除できない。代わりに、各ターン開始時に追加で1枚ドローする。"
JA_NEW = "各ターン開始時に追加で1枚ドローする。代償としてカード報酬を見送れなくなる：報酬画面を閉じるにはその場でカードを1枚受け取る必要があり、後回しにすることもできない。商店でもデッキからカードを削除できない。"

ES_OLD = "Ya no puedes omitir las recompensas de cartas: debes tomar 1 carta en el acto para cerrar la pantalla de recompensa, y no puedes guardarla para más adelante. Tampoco puedes eliminar cartas de tu mazo en las tiendas. A cambio, robas 1 carta adicional al comienzo de cada turno."
ES_NEW = "Al comienzo de cada turno, robas 1 carta adicional. El coste: no puedes omitir las recompensas de cartas — debes tomar 1 carta en el acto para cerrar la pantalla de recompensa, y no puedes guardarla para más adelante; tampoco puedes eliminar cartas de tu mazo en las tiendas."

JOBS = [
    ("relics.json", ZH_OLD, ZH_NEW),
    ("i18n/noncard_zh_canonical.json", ZH_OLD, ZH_NEW),
    ("i18n/noncard_en.json", EN_OLD, EN_NEW),
    ("i18n/noncard_ja.json", JA_OLD, JA_NEW),
    ("i18n/noncard_es.json", ES_OLD, ES_NEW),
]


def main():
    for path, old, new in JOBS:
        raw = io.open(path, encoding="utf-8", newline="").read()
        n = raw.count(old)
        assert n == 1, "%s 命中 %d 次（应为 1）" % (path, n)
        io.open(path, "w", encoding="utf-8", newline="").write(raw.replace(old, new))
        print("ok  %-34s %d → %d 字符" % (path, len(old), len(new)))


if __name__ == "__main__":
    main()
