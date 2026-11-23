# -*- coding: utf-8 -*-
## R857 卡面文案：沉睡单位获得甲壳（5 点，回合开始重置，醒来消失）。
## 四口齐改：cards.json / i18n/zh_canonical.json / cards_en / cards_ja / cards_es。
import io

def patch(path, pairs):
    src = io.open(path, encoding="utf-8", newline="").read()
    orig = src
    for old, new in pairs:
        c = src.count(old)
        assert c == 1, "[%s] 锚点命中 %d 次: %s" % (path, c, old[:40])
        src = src.replace(old, new, 1)
    assert src != orig, path
    io.open(path, "w", encoding="utf-8", newline="").write(src)
    print("ok", path, len(orig), "->", len(src))


OLD_9116 = "初始沉睡 2：不会行动。每过一个自己的回合沉睡 -1，每次受到伤害也 -1；沉睡归零后立刻恢复行动。醒着时每次受伤力量 +1（本局）。"
NEW_9116 = "初始沉睡 2：不会行动，沉睡期间每回合护甲重置为 5。每过一个自己的回合沉睡 -1，每次受到伤害也 -1；沉睡归零后立刻恢复行动，护甲随之消失。醒着时每次受伤力量 +1（本局）。"
OLD_9241 = "不能进行常规攻击。沉睡 2 回合。每回合随机选取两列并预告；"
NEW_9241 = "不能进行常规攻击。沉睡 2 回合，沉睡期间每回合护甲重置为 5。每回合随机选取两列并预告；"

# ① 玩家看到的卡面（唯一中文真源）
patch("cards.json", [(OLD_9116, NEW_9116), (OLD_9241, NEW_9241)])
# ② 译文母本
patch("i18n/zh_canonical.json", [(OLD_9116, NEW_9116), (OLD_9241, NEW_9241)])

EN_OLD_9116 = "Starts with Sleep 2: it does not act. Sleep decreases by 1 after each of its own turns, and by 1 each time it takes damage; it resumes acting as soon as Sleep reaches 0."
EN_NEW_9116 = "Starts with Sleep 2: it does not act, and while asleep its Armor is reset to 5 each turn. Sleep decreases by 1 after each of its own turns, and by 1 each time it takes damage; it resumes acting as soon as Sleep reaches 0, and its Armor disappears with it."
EN_OLD_9241 = "Cannot make normal attacks. Sleeps for 2 turns. Each turn it picks two columns"
EN_NEW_9241 = "Cannot make normal attacks. Sleeps for 2 turns, and while asleep its Armor is reset to 5 each turn. Each turn it picks two columns"
patch("i18n/cards_en.json", [(EN_OLD_9116, EN_NEW_9116), (EN_OLD_9241, EN_NEW_9241)])

JA_OLD_9116 = "初期睡眠2：行動しない。自分のターンが経過するたび睡眠-1、ダメージを受けるたびにも-1。睡眠が0になると即座に行動を再開する。"
JA_NEW_9116 = "初期睡眠2：行動しない。睡眠中は毎ターン装甲が5にリセットされる。自分のターンが経過するたび睡眠-1、ダメージを受けるたびにも-1。睡眠が0になると即座に行動を再開し、装甲も消える。"
JA_OLD_9241 = "通常攻撃は行えない。2ターン睡眠する。毎ターンランダムに2列を選んで予告する。"
JA_NEW_9241 = "通常攻撃は行えない。2ターン睡眠し、睡眠中は毎ターン装甲が5にリセットされる。毎ターンランダムに2列を選んで予告する。"
patch("i18n/cards_ja.json", [(JA_OLD_9116, JA_NEW_9116), (JA_OLD_9241, JA_NEW_9241)])

ES_OLD_9116 = "Comienza con dormir 2: no actúa. Dormir disminuye en 1 después de cada uno de sus turnos y en 1 cada vez que recibe daño; vuelve a actuar en cuanto dormir llega a cero."
ES_NEW_9116 = "Comienza con dormir 2: no actúa, y mientras duerme su Armadura se restablece a 5 cada turno. Dormir disminuye en 1 después de cada uno de sus turnos y en 1 cada vez que recibe daño; vuelve a actuar en cuanto dormir llega a cero, y su Armadura desaparece con él."
ES_OLD_9241 = "No puede realizar ataques normales. Duerme durante 2 turnos. Cada turno elige dos columnas al azar"
ES_NEW_9241 = "No puede realizar ataques normales. Duerme durante 2 turnos, y mientras duerme su Armadura se restablece a 5 cada turno. Cada turno elige dos columnas al azar"
patch("i18n/cards_es.json", [(ES_OLD_9116, ES_NEW_9116), (ES_OLD_9241, ES_NEW_9241)])
