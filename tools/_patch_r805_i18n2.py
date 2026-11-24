# -*- coding: utf-8 -*-
"""R805 补丁②：glossary 加「诡异洋房」事件术语 + 四语 narrative 正文按中文行数重排。

中文 6 行 / 7 行（5 个 / 6 个换行），译文必须逐条对齐换行数 ——
validate_narrative 与 validate_spanish 都会拿它比，差一个就红。
"""
import io
import json

I18N = "E:/work/card_rogue/i18n/"

DESC = {
    "en": "At the end of the path stands an old two-storey house. Most of the paint has\n"
          "peeled off the window frames, yet not a pane is broken, and a dim yellow light glows inside.\n"
          "The door is ajar. There is no wind and no footsteps, yet the light is on.\n"
          "A faded wooden sign is nailed above the door: NO ONE LIVES HERE.\n"
          "One window upstairs is curtained, but the light leaks out through the gap.\n"
          "It sways slowly, very steadily.",
    "ja": "林道の突き当たりに、二階建ての古い洋館が立っている。窓枠の塗装はほとんど剥がれ落ちているのに、\n"
          "ガラスは一枚も割れていない。中からはくすんだ黄色い光が漏れている。\n"
          "扉は半開きで、風も足音もない——なのに、あの灯りは点いている。\n"
          "門の梁には色あせた木の札が打ちつけてある：この家に人はいない。\n"
          "二階の一つの窓にはカーテンが下りているが、光が隙間から漏れている。\n"
          "ゆっくりと、規則正しく揺れている。",
    "es": "Al final del sendero se alza una vieja casa de dos plantas. Casi toda la pintura\n"
          "se ha caído de los marcos, pero no hay ni un cristal roto, y dentro brilla una luz amarillenta.\n"
          "La puerta está entornada. No hay viento ni pasos, y sin embargo la luz está encendida.\n"
          "Sobre el dintel hay clavado un cartel de madera descolorido: AQUÍ NO VIVE NADIE.\n"
          "Una ventana de arriba tiene la cortina echada, pero la luz se escapa por la rendija.\n"
          "Se mece despacio, con mucha regularidad.",
}

TAKEN = {
    "en": "The door closes behind you by itself.\n"
          "The fireplace is cold. Several cloth bags and a handful of written cards lie\n"
          "scattered on the tea table, as if someone left halfway through packing.\n"
          "As you gather them up, a very light sound comes from upstairs—\n"
          "like someone setting a foot down onto the floor.\n"
          "When you step back outside and turn around, a cloth doll sits on the windowsill.\n"
          "It faces your way.",
    "ja": "扉はあなたの背後でひとりでに閉まった。\n"
          "暖炉は冷えていて、卓の上には布袋がいくつかと、文字のびっしり書かれたカードが\n"
          "散らばっている。誰かが片づけの途中で慌てて出ていったようだ。\n"
          "それらを懐に収めたとき、二階からごく小さな物音がした——\n"
          "誰かがベッドから片足を下ろしたような音だった。\n"
          "門口を出て振り返ると、窓辺に布の人形が一体増えていた。\n"
          "こちらを向いて、座っている。",
    "es": "La puerta se cierra sola a tu espalda.\n"
          "La chimenea está fría. Sobre la mesita hay varias bolsas de tela y un puñado de cartas\n"
          "escritas, como si alguien se hubiera marchado a medio recoger.\n"
          "Cuando te lo guardas todo, llega un ruido muy leve desde arriba:\n"
          "alguien ha bajado un pie de la cama.\n"
          "Al salir y girarte, sobre el alféizar hay una muñeca de tela sentada.\n"
          "Mira hacia ti.",
}


def load(n):
    return json.loads(io.open(I18N + n, encoding="utf-8").read())


def save(n, o):
    io.open(I18N + n, "w", encoding="utf-8", newline="\n").write(
        json.dumps(o, ensure_ascii=False, indent=2) + "\n")


# ① glossary：events 段加一条（en/ja 必须与 narrative 的 name 一致）
g = load("glossary.json")
assert "诡异洋房" not in g["events"]
g["events"]["诡异洋房"] = {"en": "The Haunted House", "ja": "不気味な洋館",
                           "key": "haunted_house"}
save("glossary.json", g)

# ② 四语 narrative 的正文重排
zh = load("narrative_zh_canonical.json")
zh_texts = zh["events"]["haunted_house"]["texts"]
for lg in ("en", "ja", "es"):
    o = load("narrative_%s.json" % lg)
    row = o["events"]["haunted_house"]
    row["texts"]["HAUNTED_DESC"] = DESC[lg]
    row["texts"]["HAUNTED_TAKEN_DESC"] = TAKEN[lg]
    for k in ("HAUNTED_DESC", "HAUNTED_TAKEN_DESC"):
        a = zh_texts[k].count("\n")
        b = row["texts"][k].count("\n")
        assert a == b, "%s %s 换行数 %d vs %d" % (lg, k, a, b)
    save("narrative_%s.json" % lg, o)
    print("ok", lg, "换行对齐")

print("done")
