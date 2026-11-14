# -*- coding: utf-8 -*-
"""R689 三语同步：疾风之力触发条件 / 群起攻之新口径 / 生命循环改效果卡 + 新卡 9248 种子 · 9249 被眷顾者。

顺带修 R688 留下的一个 bug：cards_en.json 的 9002 用了未转义的双引号（"Deep Echo"），
整份文件不是合法 JSON → 英文界面读卡表会直接失败。改回 "add a copy of it"（与镜像 9056 同措辞）。
"""
import json
import sys

WRITE = "--write" in sys.argv

TEXT = {
    "ja": {
        "9045": "味方ユニットが戦場に入るたび、または効果カードを使用するたび、ランダムな敵1体に4ダメージを与える。効果ゾーンにこのカードが複数あっても重複しない。",
        "9070": "**リンク**している味方ユニットは、リンクしている他の味方ユニットの位置から攻撃できる。効果ゾーンにこのカードが複数あっても重複しない。",
        "9150": "使用時、味方のすべてのユニットは「次元」と「死亡」を得る――破壊された時、手札に「種」1枚を加える。効果ゾーンにこのカードが複数あっても重複しない。",
        "9248": ("種", "ターン開始時、このカードを破壊する：ランダムにコスト1を獲得するか、ランダムなカード1枚を手札に加える。Xは効果ゾーンにあるこのカードの枚数で、1枚ごとに処理する。"),
        "9249": ("祝福されし者", "山札からランダムに効果カード1枚を選び、そのコピーを使用する。山札にある効果カードの枚数に等しいコストを回復する。"),
    },
    "en": {
        "9045": "Whenever a friendly Ally enters the battlefield, or whenever you use an Effect card, deal 4 damage to a random enemy. Multiple copies of this card in the Effect Zone do not stack.",
        "9070": "**Linked** friendly units can attack from the position of another friendly unit Linked to them. Multiple copies of this card in the Effect Zone do not stack.",
        "9150": "When used, all friendly Allies gain \"Dimensional\" and \"Death\" - when Destroyed, add a Seed to your Hand. Multiple copies of this card in the Effect Zone do not stack.",
        "9248": ("Seed", "At the start of your turn, Destroy this card: randomly gain 1 Cost, or add a random card to your Hand. X is the number of copies of this card in the Effect Zone; each one resolves separately."),
        "9249": ("The Favored", "Randomly use a copy of an Effect card from your Draw Pile. Restore Cost equal to the number of Effect cards in your Draw Pile."),
    },
    "es": {
        "9045": "Cada vez que un Aliado aliado entra al campo de batalla, o cada vez que uses una carta de Efectos, inflige 4 de daño a un enemigo aleatorio. Varias copias de esta carta en la zona de Efectos no se acumulan.",
        "9070": "Las unidades **vinculadas** aliadas pueden atacar desde la posición de otra unidad aliada vinculada a ellas. Varias copias de esta carta en la zona de Efectos no se acumulan.",
        "9150": "Al usarse, todos los Aliados aliados obtienen «dimensional» y «Muerte»: al ser destruidos, añade una Semilla a la mano. Varias copias de esta carta en la zona de Efectos no se acumulan.",
        "9248": ("Semilla", "Al comienzo de tu turno, destruye esta carta: obtén aleatoriamente 1 de Coste o añade una carta aleatoria a la mano. X es el número de copias de esta carta en la zona de Efectos; cada una se resuelve por separado."),
        "9249": ("El Favorecido", "Usa aleatoriamente una copia de una carta de Efectos de tu pila de robo. Recupera Coste igual al número de cartas de Efectos en tu pila de robo."),
    },
}

# 旧文案（用于精确替换，并验证文件里确实是它）
OLD = {
    "ja": {
        "9045": "味方ユニットが戦場に入るたび、ランダムな敵1体に4ダメージを与える。効果ゾーンにこのカードが複数あっても重複しない。",
        "9070": "**リンク**しているユニットは、自身の攻撃時に距離を計算しない（フィールド全体に届く）。効果ゾーンにこのカードが複数あっても重複しない。",
        "9150": "味方ユニット1体を選ぶ：それは「次元」と「死亡」を得る。それが破壊された時、ランダムな味方カード1枚を手札に加える。",
    },
    "en": {
        "9045": "Whenever a friendly Ally enters the battlefield, deal 4 damage to a random enemy. Multiple copies of this card in the Effect Zone do not stack.",
        "9070": "**Linked** units ignore distance when making their own attacks (they can reach the whole field). Multiple copies of this card in the Effect Zone do not stack.",
        "9150": "Choose a friendly Ally: it gains \"Dimensional\" and \"Death\" - when it is Destroyed, add a random Ally card to your Hand.",
    },
    "es": {
        "9045": "Cada vez que un Aliado aliado entra al campo de batalla, inflige 4 de daño a un enemigo aleatorio. Varias copias de esta carta en la zona de Efectos no se acumulan.",
        "9070": "Las unidades **vinculadas** ignoran la distancia al realizar sus propios ataques (pueden alcanzar todo el campo). Varias copias de esta carta en la zona de Efectos no se acumulan.",
        "9150": "Elige un Aliado aliado: obtiene «dimensional» y «Muerte»; cuando sea destruido, añade una carta de Aliado aleatoria a la mano.",
    },
}


def esc(s):
    return s.replace('"', '\\"')


for lang in ("ja", "en", "es"):
    p = "i18n/cards_%s.json" % lang
    raw = open(p, "rb").read().decode("utf-8")
    assert raw.count("\r\n") == 0, p + " 应为纯 LF"

    # ① 三条旧文案
    for cid in ("9045", "9070", "9150"):
        old = '"effect_text": "%s"' % esc(OLD[lang][cid])
        new = '"effect_text": "%s"' % esc(TEXT[lang][cid])
        c = raw.count(old)
        if c != 1:
            raise SystemExit("[%s %s] 锚点命中 %d 次" % (lang, cid, c))
        raw = raw.replace(old, new)

    # ② 追加两张新卡（9247 是当前最后一条）
    tail = '  }\n }\n}'
    if not raw.rstrip("\n").endswith(tail):
        raise SystemExit("[%s] 文件结尾格式不是预期的 `  }\\n }\\n}`" % lang)
    body = raw.rstrip("\n")[:-len(tail)]
    n1, t1 = TEXT[lang]["9248"]
    n2, t2 = TEXT[lang]["9249"]
    add = ('  },\n'
           '  "9248": {\n   "name": "%s",\n   "effect_text": "%s"\n  },\n'
           '  "9249": {\n   "name": "%s",\n   "effect_text": "%s"\n  }\n }\n}' % (
               n1, esc(t1), n2, esc(t2)))
    raw = body + add
    if raw.endswith("}\n"):
        pass
    out = raw if raw.endswith("}\n") else raw + "\n"

    if WRITE:
        open(p, "wb").write(out.encode("utf-8"))
        d = json.loads(out)["cards"]
        print("%s OK  cards=%d  9248=%s / 9249=%s  9045=%s…" % (
            lang, len(d), d["9248"]["name"], d["9249"]["name"], d["9045"]["effect_text"][:24]))
    else:
        json.loads(out)
        print("%s 干跑通过 cards=%d" % (lang, len(json.loads(out)["cards"])))

# ③ canonical 的 updated 日期
p = "i18n/zh_canonical.json"
b = open(p, "rb").read().decode("utf-8")
if '"updated": "2026-11-13"' in b:
    if WRITE:
        open(p, "wb").write(b.replace('"updated": "2026-11-13"', '"updated": "2026-11-14"').encode("utf-8"))
    print("canonical updated → 2026-11-14")
