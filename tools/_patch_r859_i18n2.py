# -*- coding: utf-8 -*-
## R859 附带（续）：cards_en/ja/es 补 9284/9285 + 修 9130 过期译文；术语表补词条。
import io


def patch(path, pairs):
    src = io.open(path, encoding="utf-8", newline="").read()
    orig = src
    for old, new, tag in pairs:
        c = src.count(old)
        assert c == 1, "[%s/%s] 锚点命中 %d 次" % (path, tag, c)
        src = src.replace(old, new, 1)
    assert src != orig, path
    io.open(path, "w", encoding="utf-8", newline="").write(src)
    print("ok", path, len(orig), "->", len(src))


# ── cards_en ──
patch("i18n/cards_en.json", [
    (' "count": 344,', ' "count": 346,', "count"),
    ('''  "9276": {''',
     '''  "9284": {
   "name": "Duck Egg Pitcher",
   "effect_text": "While holding the Golden Duck Egg: instead of acting, throw the Golden Duck Egg straight ahead (along its column). The egg stops at the first unit it hits and deals damage equal to its own Power to that unit, with Trample (if there is no unit, hit the opponent's HP directly). While not holding the Golden Duck Egg, its Move Speed becomes 3 and it gains +3 Power at the start of each turn."
  },
  "9285": {
   "name": "Golden Duck Egg",
   "effect_text": "When taking non-attack damage, it takes at most 1 damage each time. Death: add a random Epic card to the opponent's Hand and let the Duck Egg Pitcher regain the Golden Duck Egg."
  },
  "9276": {''', "add"),
    ('   "effect_text": "While on the field, \\"Mass-Produced Onyae\\" on the field may act twice per turn and restore 2 Health each turn."',
     '   "effect_text": "While on the field, \\"Mass-Produced\\" cards on the field may act twice per turn and take 2 less skill damage (minimum 1)."',
     "9130"),
])

# ── cards_ja ──
patch("i18n/cards_ja.json", [
    (' "count": 344,', ' "count": 346,', "count"),
    ('''  "9276": {''',
     '''  "9284": {
   "name": "卵投げアヒル",
   "effect_text": "「金のアヒル卵」を所持している場合：行動の代わりに、正面（同じ縦列方向）へ金のアヒル卵を投げる。金のアヒル卵は最初に当たったユニットの位置で止まり、そのユニットに自身の攻撃力と同じダメージを与える。踏みつけ（ユニットがいない場合は相手のHPへ直接ダメージ）。金のアヒル卵を所持していない場合、移動速度が3になり、ターン開始時に攻撃力+3。"
  },
  "9285": {
   "name": "金のアヒル卵",
   "effect_text": "攻撃以外のダメージを受けるとき、1回につき最大1ダメージしか受けない。死亡時：ランダムなエピックカード1枚を相手の手札に加え、卵投げアヒルに金のアヒル卵を再び持たせる。"
  },
  "9276": {''', "add"),
    ('   "effect_text": "フィールド上にいる間、フィールド上の「量産型オニエ」は毎ターン2回行動でき、毎ターンHPを2回復する。"',
     '   "effect_text": "フィールド上にいる間、フィールド上の「量産型」カードは毎ターン2回行動でき、受けるスキルダメージが2減少する（最小1）。"',
     "9130"),
])

# ── cards_es ──
patch("i18n/cards_es.json", [
    (' "count": 344,', ' "count": 346,', "count"),
    ('''  "9276": {''',
     '''  "9284": {
   "name": "Lanzador de Huevos de Pato",
   "effect_text": "Mientras sostiene el Huevo de Pato Dorado: en lugar de actuar, lanza el Huevo de Pato Dorado hacia adelante (en su misma columna). El huevo se detiene en la primera unidad con la que choca y le inflige daño igual a su propio Poder, con Atropellar (si no hay ninguna unidad, golpea directamente los HP del oponente). Mientras no sostenga el Huevo de Pato Dorado, su Velocidad de Movimiento pasa a 3 y obtiene +3 de Poder al inicio de cada turno."
  },
  "9285": {
   "name": "Huevo de Pato Dorado",
   "effect_text": "Al recibir daño que no sea de ataque, recibe como máximo 1 de daño cada vez. Muerte: añade una carta Épica aleatoria a la mano del oponente y hace que el Lanzador de Huevos de Pato recupere el Huevo de Pato Dorado."
  },
  "9276": {''', "add"),
    ('   "effect_text": "Mientras esté en el campo, los «Onie de Producción en Serie» del campo pueden actuar dos veces por turno y recuperan 2 de Vida cada turno."',
     '   "effect_text": "Mientras esté en el campo, las cartas de «Producción en Serie» del campo pueden actuar dos veces por turno y reciben 2 menos de daño de habilidad (mínimo 1)."',
     "9130"),
])

# ── 术语表：traits「投手」/ levels「鸭蛋投手」 ──
patch("i18n/glossary.json", [
    ('''  "traits": {
    "机械": {''',
     '''  "traits": {
    "投手": {
      "en": "Pitcher",
      "ja": "投手"
    },
    "机械": {''', "trait_pitcher"),
    ('''  "levels": {
    "洞穴": {''',
     '''  "levels": {
    "鸭蛋投手": {
      "en": "Duck Egg Pitcher",
      "ja": "卵投げアヒル"
    },
    "洞穴": {''', "level"),
])

# ── glossary_es：投手 ──
patch("i18n/glossary_es.json", [
    ('''    "亡灵": "No muerto",''',
     '''    "亡灵": "No muerto",
    "投手": "Lanzador",''', "es_pitcher"),
])
