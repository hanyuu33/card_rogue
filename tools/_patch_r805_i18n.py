# -*- coding: utf-8 -*-
"""R805 四语：卡牌 9276 / 事件 narrative haunted_house / event_ui haunted_house。

中文原文**从 event_scene.gd 直接读常量**，避免手抄与真源不一致（validate_narrative
与 validate_event_ui 都会拿真源逐字比对）。
写回用 json.dump(indent=1, ensure_ascii=False)：原文件就是这个格式，diff 应只有新增行。
"""
import io
import json
import re

I18N = "E:/work/card_rogue/i18n/"
SRC = io.open("E:/work/card_rogue/scripts/event_scene.gd", encoding="utf-8").read()

# ---- 从真源取中文正文 ----
desc = re.search(r'const HAUNTED_DESC := """(.*?)"""', SRC, re.S).group(1)
taken = re.search(r'const HAUNTED_TAKEN_DESC := """(.*?)"""', SRC, re.S).group(1)
OPT_EXPLORE = re.search(r'rest_btn\.text = "(推门进去[^"]*)"', SRC).group(1)
OPT_LEAVE = re.search(r'leave_btn\.text = "(掉头离开[^"]*)"', SRC).group(1)
RES_OK = re.search(r'_house_result = "(\u300c诅咒娃娃[^"]*等你挑。)"', SRC).group(1)
RES_NORELIC = re.search(r'_house_result = "(\u300c诅咒娃娃[^"]*史诗卡牌。)"', SRC).group(1)
print("desc lines=%d taken lines=%d" % (desc.count("\n") + 1, taken.count("\n") + 1))
print("explore=%r" % OPT_EXPLORE)
print("res_ok=%r" % RES_OK)

CARD_ID = "9276"
CARD_ZH = json.loads(io.open("E:/work/card_rogue/cards.json", encoding="utf-8").read())["cards"]
CARD_ZH = [c for c in CARD_ZH if str(c["id"]) == CARD_ID][0]

# ---- 译文 ----
CARD_TR = {
    "en": {"name": "Curse Doll",
           "effect_text": "Cannot be played. At the end of the turn, you take 3 damage. "
                          "At the start of your turn, if this card is in your Discard Pile, "
                          "return it to your Hand."},
    "ja": {"name": "呪いの人形",
           "effect_text": "使用不可。ターン終了時、あなたは3ダメージを受ける。"
                          "ターン開始時、このカードが捨て札置き場にあるなら、"
                          "このカードを捨て札置き場から手札に戻す。"},
    "es": {"name": "Muñeca maldita",
           "effect_text": "No puede jugarse. Al final del turno, recibes 3 de daño. "
                          "Al inicio de tu turno, si esta carta está en tu pila de descartes, "
                          "vuelve a tu mano."},
}

EVENT_NAME = {"en": "The Haunted House", "ja": "不気味な洋館", "es": "La casa embrujada"}

DESC_TR = {
    "en": "At the end of the path stands an old two-storey house. Most of the paint has\n"
          "peeled off the window frames, yet not a pane is broken, and a dim yellow light glows inside.\n"
          "The door is ajar. There is no wind and no footsteps, yet the light is on.\n"
          "A faded wooden sign is nailed above the door: NO ONE LIVES HERE.\n"
          "One window upstairs is curtained, but the light leaks through the gap, swaying slowly and steadily.",
    "ja": "林道の突き当たりに、二階建ての古い洋館が立っている。窓枠の塗装はほとんど剥がれ落ちているのに、\n"
          "ガラスは一枚も割れていない。中からはくすんだ黄色い光が漏れている。\n"
          "扉は半開きで、風も足音もない——なのに、あの灯りは点いている。\n"
          "門の梁には色あせた木の札が打ちつけてある：この家に人はいない。\n"
          "二階の一つの窓にはカーテンが下りているが、光が隙間から漏れて、ゆっくりと規則正しく揺れている。",
    "es": "Al final del sendero se alza una vieja casa de dos plantas. Casi toda la pintura\n"
          "se ha caído de los marcos, pero no hay ni un cristal roto, y dentro brilla una luz amarillenta.\n"
          "La puerta está entornada. No hay viento ni pasos, y sin embargo la luz está encendida.\n"
          "Sobre el dintel hay clavado un cartel de madera descolorido: AQUÍ NO VIVE NADIE.\n"
          "Una ventana de arriba tiene la cortina echada, pero la luz se escapa por la rendija, meciéndose despacio.",
}

TAKEN_TR = {
    "en": "The door closes behind you by itself.\n"
          "The fireplace is cold. Several cloth bags and a handful of written cards lie\n"
          "scattered on the tea table, as if someone left halfway through packing.\n"
          "As you gather them up, a very light sound comes from upstairs—\n"
          "like someone setting a foot down onto the floor.\n"
          "When you step back outside and turn around, a cloth doll sits on the windowsill, facing your way.",
    "ja": "扉はあなたの背後でひとりでに閉まった。\n"
          "暖炉は冷えていて、卓の上には布袋がいくつかと、文字のびっしり書かれたカードが\n"
          "散らばっている。誰かが片づけの途中で慌てて出ていったようだ。\n"
          "それらを懐に収めたとき、二階からごく小さな物音がした——\n"
          "誰かがベッドから片足を下ろしたような音だった。\n"
          "門口を出て振り返ると、窓辺に布の人形が一体増えていて、こちらを向いて座っていた。",
    "es": "La puerta se cierra sola a tu espalda.\n"
          "La chimenea está fría. Sobre la mesita hay varias bolsas de tela y un puñado de cartas\n"
          "escritas, como si alguien se hubiera marchado a medio recoger.\n"
          "Cuando te lo guardas todo, llega un ruido muy leve desde arriba:\n"
          "alguien ha bajado un pie de la cama.\n"
          "Al salir y girarte, sobre el alféizar hay una muñeca de tela sentada, mirando hacia ti.",
}

OPT_TR = {
    "en": {"EXPLORE": 'Push the door open (a Legendary Relic + an Epic card reward; '
                       'the price is a "Curse Doll")',
           "LEAVE": "Turn around and leave (nobody should be living here)"},
    "ja": {"EXPLORE": "扉を押して入る（伝説レリック ＋ エピックカード、代償は「呪いの人形」）",
           "LEAVE": "引き返す（この家に人が住んでいるはずがない）"},
    "es": {"EXPLORE": "Empujar la puerta (un Relic Legendario + una recompensa de carta Épica; "
                      "el precio es una «Muñeca maldita»)",
           "LEAVE": "Dar media vuelta e irse (nadie debería vivir aquí)"},
}

RES_TR = {
    "en": {"EXPLORED": 'The "Curse Doll" has joined your deck; it will not go away. '
                       "A Legendary Relic and an Epic card reward are waiting for you above.",
           "EXPLORED_NO_RELIC": 'The "Curse Doll" has joined your deck; it will not go away. '
                                "You have already taken every Legendary Relic, so only an Epic "
                                "card reward is left above."},
    "ja": {"EXPLORED": "「呪いの人形」がデッキに加わった。こいつは離れない。"
                       "伝説レリックとエピックカードが上で待っている。",
           "EXPLORED_NO_RELIC": "「呪いの人形」がデッキに加わった。こいつは離れない。"
                                "伝説レリックは取り尽くしたので、上に残っているのはエピックカードだけだ。"},
    "es": {"EXPLORED": "La «Muñeca maldita» se ha unido a tu mazo; no se irá. "
                       "Arriba te esperan un Relic Legendario y una recompensa de carta Épica.",
           "EXPLORED_NO_RELIC": "La «Muñeca maldita» se ha unido a tu mazo; no se irá. "
                                "Ya has cogido todos los Relics Legendarios, así que arriba solo "
                                "queda una recompensa de carta Épica."},
}


def load(name):
    return json.loads(io.open(I18N + name, encoding="utf-8").read())


def save(name, obj):
    # 各文件原有缩进不同：cards / zh_canonical 是 1 空格，narrative / event_ui 是 2 空格。
    # 用错就会整篇重排（2869+/2792- 的假噪音），所以按文件挑。
    ind = 1 if name in ("zh_canonical.json", "cards_en.json", "cards_ja.json",
                        "cards_es.json") else 2
    txt = json.dumps(obj, ensure_ascii=False, indent=ind) + "\n"
    io.open(I18N + name, "w", encoding="utf-8", newline="\n").write(txt)


# ---- 1. zh_canonical / cards_* ----
zh = load("zh_canonical.json")
zh["cards"][CARD_ID] = {"name": CARD_ZH["name"], "effect_text": CARD_ZH["effect_text"],
                        "changed": False}
save("zh_canonical.json", zh)
for lg in ("en", "ja", "es"):
    o = load("cards_%s.json" % lg)
    o["cards"][CARD_ID] = CARD_TR[lg]
    if "count" in o:
        o["count"] = len(o["cards"])
    save("cards_%s.json" % lg, o)

# ---- 2. narrative ----
zh = load("narrative_zh_canonical.json")
zh["events"]["haunted_house"] = {"name": "诡异洋房",
                                 "texts": {"HAUNTED_DESC": desc, "HAUNTED_TAKEN_DESC": taken}}
save("narrative_zh_canonical.json", zh)
for lg in ("en", "ja", "es"):
    o = load("narrative_%s.json" % lg)
    o["events"]["haunted_house"] = {"name": EVENT_NAME[lg],
                                    "texts": {"HAUNTED_DESC": DESC_TR[lg],
                                              "HAUNTED_TAKEN_DESC": TAKEN_TR[lg]}}
    save("narrative_%s.json" % lg, o)

# ---- 3. event_ui ----
zh = load("event_ui_zh_canonical.json")
zh["options"]["haunted_house"] = {"EXPLORE": OPT_EXPLORE, "LEAVE": OPT_LEAVE}
zh["results"]["haunted_house"] = {"EXPLORED": RES_OK, "EXPLORED_NO_RELIC": RES_NORELIC}
save("event_ui_zh_canonical.json", zh)
for lg in ("en", "ja", "es"):
    o = load("event_ui_%s.json" % lg)
    o["options"]["haunted_house"] = dict(OPT_TR[lg])
    o["results"]["haunted_house"] = dict(RES_TR[lg])
    save("event_ui_%s.json" % lg, o)

print("done")
