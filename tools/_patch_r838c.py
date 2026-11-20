# -*- coding: utf-8 -*-
"""R838c：暗动力 6054 文案再删两处 —— 去掉「代价是」、去掉「也不能留到以后领取」

店长口径：
  ① 「代价是」这个转折词不要了（收益句与代价句直接并列即可）
  ② 「也不能留到以后领取」删掉 —— 它与「无法跳过卡牌奖励」是同一件事的两种说法
  ③ 「你也无法在商店删除卡牌」→ 独立成句（原来接在分号后面被压成半句）

五处齐改：relics.json / noncard_zh_canonical.json / noncard_en / ja / es
"""
import io
import sys

PAIRS = [
    # (文件, 旧串, 新串)
    (
        "relics.json",
        "每回合开始时多抽一张牌。代价是你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面，也不能留到以后领取；商店里同样无法删除卡牌。",
        "每回合开始时多抽一张牌。你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面。商店里同样无法删除卡牌。",
    ),
    (
        "i18n/noncard_zh_canonical.json",
        "每回合开始时多抽一张牌。代价是你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面，也不能留到以后领取；商店里同样无法删除卡牌。",
        "每回合开始时多抽一张牌。你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面。商店里同样无法删除卡牌。",
    ),
    (
        "i18n/noncard_en.json",
        "At the start of each turn, draw 1 additional card. The cost: you cannot skip card rewards — you must take 1 card on the spot to close the reward screen, and you cannot save the reward for later; you also cannot Remove cards from your Deck at shops.",
        "At the start of each turn, draw 1 additional card. You cannot skip card rewards — you must take 1 card on the spot to close the reward screen. You also cannot remove cards from your Deck at shops.",
    ),
    (
        "i18n/noncard_ja.json",
        "各ターン開始時に追加で1枚ドローする。代償としてカード報酬を見送れなくなる：報酬画面を閉じるにはその場でカードを1枚受け取る必要があり、後回しにすることもできない。商店でもデッキからカードを削除できない。",
        "各ターン開始時に追加で1枚ドローする。カード報酬を見送れなくなる：報酬画面を閉じるにはその場でカードを1枚受け取る必要がある。商店でもデッキからカードを削除できない。",
    ),
    (
        "i18n/noncard_es.json",
        "Al comienzo de cada turno, robas 1 carta adicional. El coste: no puedes omitir las recompensas de cartas — debes tomar 1 carta en el acto para cerrar la pantalla de recompensa, y no puedes guardarla para más adelante; tampoco puedes eliminar cartas de tu mazo en las tiendas.",
        "Al comienzo de cada turno, robas 1 carta adicional. No puedes omitir las recompensas de cartas — debes tomar 1 carta en el acto para cerrar la pantalla de recompensa. Tampoco puedes eliminar cartas de tu mazo en las tiendas.",
    ),
]


def main() -> int:
    ok = True
    for path, old, new in PAIRS:
        try:
            raw = io.open(path, "rb").read()
        except FileNotFoundError:
            print("MISSING", path)
            ok = False
            continue
        text = raw.decode("utf-8")
        n = text.count(old)
        if n != 1:
            print("FAIL  %-32s count=%d（应为 1）" % (path, n))
            ok = False
            continue
        text = text.replace(old, new)
        io.open(path, "wb").write(text.encode("utf-8"))
        print("ok    %-32s %d→%d 字" % (path, len(old), len(new)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
