# -*- coding: utf-8 -*-
## R859 卡面：沉睡甲壳改为「开局 10 点、不重置、护甲未破挨打不减沉睡、醒来全失」。
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


OLD_9116 = "初始沉睡 2：不会行动，沉睡期间每回合护甲重置为 5。每过一个自己的回合沉睡 -1，每次受到伤害也 -1；沉睡归零后立刻恢复行动，护甲随之消失。醒着时每次受伤力量 +1（本局）。"
NEW_9116 = "初始沉睡 2：不会行动，开局获得 10 护甲（不会重置）。护甲未破时挨打不减少沉睡；每过一个自己的回合沉睡 -1，护甲被打破后每次受伤也 -1；沉睡归零后立刻恢复行动并失去所有护甲。醒着时每次受伤力量 +1（本局）。"
OLD_9241 = "不能进行常规攻击。沉睡 2 回合，沉睡期间每回合护甲重置为 5。每回合随机选取两列并预告；"
NEW_9241 = "不能进行常规攻击。沉睡 2 回合，开局获得 10 护甲（不会重置，护甲未破时挨打不减少沉睡）。每回合随机选取两列并预告；"

patch("cards.json", [(OLD_9116, NEW_9116), (OLD_9241, NEW_9241)])
patch("i18n/zh_canonical.json", [(OLD_9116, NEW_9116), (OLD_9241, NEW_9241)])

EN_OLD_9116 = "Starts with Sleep 2: it does not act, and while asleep its Armor is reset to 5 each turn. Sleep decreases by 1 after each of its own turns, and by 1 each time it takes damage; it resumes acting as soon as Sleep reaches 0, and its Armor disappears with it."
EN_NEW_9116 = "Starts with Sleep 2: it does not act, and it starts with 10 Armor (the Armor is never reset). While the Armor holds, hits do not reduce Sleep. Sleep decreases by 1 after each of its own turns, and by 1 each time it takes damage once the Armor is broken; it resumes acting as soon as Sleep reaches 0, losing all Armor."
EN_OLD_9241 = "Cannot make normal attacks. Sleeps for 2 turns, and while asleep its Armor is reset to 5 each turn. Each turn it picks two columns"
EN_NEW_9241 = "Cannot make normal attacks. Sleeps for 2 turns and starts with 10 Armor (never reset; while the Armor holds, hits do not reduce Sleep). Each turn it picks two columns"
patch("i18n/cards_en.json", [(EN_OLD_9116, EN_NEW_9116), (EN_OLD_9241, EN_NEW_9241)])

JA_OLD_9116 = "初期睡眠2：行動しない。睡眠中は毎ターン装甲が5にリセットされる。自分のターンが経過するたび睡眠-1、ダメージを受けるたびにも-1。睡眠が0になると即座に行動を再開し、装甲も消える。"
JA_NEW_9116 = "初期睡眠2：行動しない。開始時装甲10を得る（リセットされない）。装甲が残っている間は攻撃を受けても睡眠は減らない。自分のターンが経過するたび睡眠-1、装甲が割れた後はダメージを受けるたびにも-1。睡眠が0になると即座に行動を再開し、装甲をすべて失う。"
JA_OLD_9241 = "通常攻撃は行えない。2ターン睡眠し、睡眠中は毎ターン装甲が5にリセットされる。毎ターンランダムに2列を選んで予告する。"
JA_NEW_9241 = "通常攻撃は行えない。2ターン睡眠し、開始時装甲10を得る（リセットされず、装甲が残っている間は攻撃を受けても睡眠は減らない）。毎ターンランダムに2列を選んで予告する。"
patch("i18n/cards_ja.json", [(JA_OLD_9116, JA_NEW_9116), (JA_OLD_9241, JA_NEW_9241)])

ES_OLD_9116 = "Comienza con dormir 2: no actúa, y mientras duerme su Armadura se restablece a 5 cada turno. Dormir disminuye en 1 después de cada uno de sus turnos y en 1 cada vez que recibe daño; vuelve a actuar en cuanto dormir llega a cero, y su Armadura desaparece con él."
ES_NEW_9116 = "Comienza con dormir 2: no actúa, y empieza con 10 de Armadura (la Armadura nunca se restablece). Mientras la Armadura aguante, los golpes no reducen dormir. Dormir disminuye en 1 después de cada uno de sus turnos y en 1 cada vez que recibe daño una vez rota la Armadura; vuelve a actuar en cuanto dormir llega a cero, perdiendo toda la Armadura."
ES_OLD_9241 = "No puede realizar ataques normales. Duerme durante 2 turnos, y mientras duerme su Armadura se restablece a 5 cada turno. Cada turno elige dos columnas al azar"
ES_NEW_9241 = "No puede realizar ataques normales. Duerme durante 2 turnos y empieza con 10 de Armadura (nunca se restablece; mientras la Armadura aguante, los golpes no reducen dormir). Cada turno elige dos columnas al azar"
patch("i18n/cards_es.json", [(ES_OLD_9116, ES_NEW_9116), (ES_OLD_9241, ES_NEW_9241)])
