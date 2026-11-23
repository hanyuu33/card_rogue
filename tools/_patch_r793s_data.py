# -*- coding: utf-8 -*-
"""R793 patch 3/7 —— 数据与四语文案：relics.json(6075) + noncard / narrative / event_ui。

⚠️ 基线是 R792 之后（板甲 6070 / 兵 6071 / 墙砖 6072 已在库、条目为**单行**写法），
所以 6075 一律插在 6072 之后、沿用同一行格式。
⚠️ 文本口径：event_scene.gd 的 SWORD_DESC / SWORD_TAKEN_DESC 是中文权威原文，
i18n 映射的 key 就是这串中文全文 —— 两边必须逐字一致，改一边就要改另一边。
"""
import io, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def patch(path, pairs):
    p = ROOT.rstrip("/") + "/" + path
    raw = io.open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            o = old.replace("\n", "\r\n")
            n = new.replace("\n", "\r\n")
        else:
            o, n = old, new
        c = txt.count(o)
        assert c == 1, "%s: count=%d for %r" % (path, c, old[:70])
        txt = txt.replace(o, n)
    io.open(p, "wb").write(txt.encode("utf-8"))
    print("OK %-36s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


# ------------------------------------------------------------ relics.json
RELIC_6072 = '''    {
      "id": 6072,
      "name": "墙砖",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你的工事卡生命 +4（持续生效，不叠加）。"
    }
  ]
}
'''

RELIC_6072_NEW = '''    {
      "id": 6072,
      "name": "墙砖",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你的工事卡生命 +4（持续生效，不叠加）。"
    },
    {
      "id": 6075,
      "name": "大师之剑",
      "kind": "战斗",
      "source": "事件",
      "tier": "一般",
      "desc": "每场战斗使用的第一个盟友 +10 力量（不叠加）。"
    }
  ]
}
'''

patch("relics.json", [(RELIC_6072, RELIC_6072_NEW)])

# ------------------------------------------------------------ noncard（四语，单行格式）
NAMES = {
    "zh_canonical": ('    "6072": {"name": "墙砖", "desc": "你的工事卡生命 +4（持续生效，不叠加）。"}\n',
                     '    "6075": {"name": "大师之剑", "desc": "每场战斗使用的第一个盟友 +10 力量（不叠加）。"}\n'),
    "en": ('    "6072": {"name": "Wall Brick", "desc": "Your Structures have +4 Health (persistent; does not stack)."}\n',
           '    "6075": {"name": "Master Sword", "desc": "The first Ally you play each combat gains +10 Power (does not stack)."}\n'),
    "ja": ('    "6072": {"name": "壁のレンガ", "desc": "自分の構造物カードの生命+4（継続し、重複しない）。"}\n',
           '    "6075": {"name": "マスターソード", "desc": "各戦闘で最初に使う味方は攻撃力+10（重複しない）。"}\n'),
    "es": ('    "6072": {"name": "Ladrillo", "desc": "Tus Estructuras tienen +4 de Vida (efecto persistente; no se acumula)."}\n',
           '    "6075": {"name": "Espada Maestra", "desc": "El primer Aliado que juegas en cada combate obtiene +10 de Poder (no se acumula)."}\n'),
}

for code, (old, add) in NAMES.items():
    patch("i18n/noncard_%s.json" % code, [(old, old.rstrip("\n") + ",\n" + add)])

# ------------------------------------------------------------ narrative（四语）
ZH_DESC = ('空地上立着一块灰白的长石，石缝里插着一把剑，剑身没入大半。\\n'
           '苔顺着剑格爬下来，缠了不知多少年——它在这里等得太久了。\\n'
           '拔剑：失去 13 点最大生命（至少保留 1 点，最大生命不足时无法拔），\\n'
           '获得道具「大师之剑」：每场战斗使用的第一个盟友 +10 力量；\\n'
           '也可以什么都不碰，转身走出这片林子。')
ZH_TAKEN = ('石头从中间裂开。剑离地的那一刻轻得不像话，\\n'
            '像它一直在等你来拿。\\n'
            '握柄贴上掌心，林子静了一瞬——「大师之剑」已收进行囊。')

EN_DESC = ('A grey-white standing stone rises in the clearing, a sword wedged into its crack, most of the blade buried.\\n'
           'Moss has crept down over the crossguard, winding there for untold years—it has waited here far too long.\\n'
           'Draw the sword: lose 13 Max Health (you must retain at least 1; you cannot draw it if your Max Health is too low),\\n'
           'and gain the relic \\"Master Sword\\": the first Ally you play each combat gains +10 Power;\\n'
           'or touch nothing and walk out of the woods.')
EN_TAKEN = ('The stone splits down the middle. The sword comes free impossibly light,\\n'
            'as if it had been waiting for you to take it.\\n'
            'The grip settles into your palm and the woods go silent for a moment—the \\"Master Sword\\" is yours.')

JA_DESC = ('空き地に灰白色の長石が立っていて、その割れ目に剣が突き刺さっている。刀身は大半が石に埋もれている。\\n'
           '苔が鍔伝いに這い下り、いつの間にか幾年月も巻きついていた——あまりにも長く、ここで待っている。\\n'
           '剣を抜く：最大HPを13失い（最低1は残り、最大HPが足りない場合は抜けない）、\\n'
           '遺物「マスターソード」を獲得する：各戦闘で最初に使う味方は攻撃力+10。\\n'
           '何も触れず、森を出ることもできる。')
JA_TAKEN = ('石は真ん中から割れた。剣が抜けた瞬間は信じられないほど軽く、\\n'
            'まるでお前が来るのを待っていたかのようだ。\\n'
            '柄が手のひらに馴染み、森が一瞬だけ静まり返る——「マスターソード」はあなたのものになった。')

ES_DESC = ('En el claro se alza una piedra grisácea, con una espada clavada en su grieta; la hoja está casi enterrada.\\n'
           'El musgo ha trepado por la guarda, enroscándose durante años incontables: lleva demasiado tiempo esperando aquí.\\n'
           'Desenvainar: pierdes 13 de Vida máxima (debes conservar al menos 1; no puedes desenvainar si tu Vida máxima es insuficiente)\\n'
           'y obtienes el objeto «Espada Maestra»: el primer Aliado que juegas en cada combate obtiene +10 de Poder;\\n'
           'o no toques nada y sal del bosque.')
ES_TAKEN = ('La piedra se parte por la mitad. La espada sale con una ligereza imposible,\\n'
            'como si hubiera estado esperando a que la tomaras.\\n'
            'La empuñadura se asienta en tu palma y el bosque enmudece un instante: la «Espada Maestra» es tuya.')

ANCHOR = '    "struggle": {\n      "name": '


def narr_block(kind_names, desc, taken):
    return ('    "sword": {\n'
            '      "name": "%s",\n'
            '      "texts": {\n'
            '        "SWORD_DESC": "%s",\n'
            '        "SWORD_TAKEN_DESC": "%s"\n'
            '      }\n'
            '    },\n') % (kind_names, desc, taken)


patch("i18n/narrative_zh_canonical.json",
      [(ANCHOR, narr_block("林中的剑", ZH_DESC, ZH_TAKEN) + ANCHOR)])
patch("i18n/narrative_en.json",
      [(ANCHOR, narr_block("Sword in the Woods", EN_DESC, EN_TAKEN) + ANCHOR)])
patch("i18n/narrative_ja.json",
      [(ANCHOR, narr_block("森の剣", JA_DESC, JA_TAKEN) + ANCHOR)])
patch("i18n/narrative_es.json",
      [(ANCHOR, narr_block("La espada del bosque", ES_DESC, ES_TAKEN) + ANCHOR)])

# ------------------------------------------------------------ event_ui（四语）
OPT_SWORD = {
    "zh": ('    "sword": {\n'
           '      "TAKE_SWORD": "拔剑（失去 %d 最大生命，获得「大师之剑」）",\n'
           '      "MAX_HP_LOW_DISABLED": "最大生命不足（拔剑需失去 %d 点）",\n'
           '      "ALREADY_OWNED_DISABLED": "已持有「大师之剑」（不必再拔）",\n'
           '      "LEAVE_THE_SWORD": "转身离开（不碰那把剑）"\n'
           '    },\n'),
    "en": ('    "sword": {\n'
           '      "TAKE_SWORD": "Draw the sword (lose %d Max Health and gain \\"Master Sword\\")",\n'
           '      "MAX_HP_LOW_DISABLED": "Not enough Max Health (drawing costs %d)",\n'
           '      "ALREADY_OWNED_DISABLED": "You already carry the \\"Master Sword\\" (no need to draw it again)",\n'
           '      "LEAVE_THE_SWORD": "Turn and walk away (do not touch the sword)"\n'
           '    },\n'),
    "ja": ('    "sword": {\n'
           '      "TAKE_SWORD": "剣を抜く（最大HPを%d失い、「マスターソード」を獲得）",\n'
           '      "MAX_HP_LOW_DISABLED": "最大HPが足りない（剣を抜くには%d必要）",\n'
           '      "ALREADY_OWNED_DISABLED": "「マスターソード」を所持している（もう抜く必要はない）",\n'
           '      "LEAVE_THE_SWORD": "立ち去る（剣には触れない）"\n'
           '    },\n'),
    "es": ('    "sword": {\n'
           '      "TAKE_SWORD": "Desenvainar (pierdes %d de Vida máxima y obtienes «Espada Maestra»)",\n'
           '      "MAX_HP_LOW_DISABLED": "Vida máxima insuficiente (desenvainar cuesta %d)",\n'
           '      "ALREADY_OWNED_DISABLED": "Ya llevas la «Espada Maestra» (no hace falta desenvainar otra vez)",\n'
           '      "LEAVE_THE_SWORD": "Darte la vuelta y marcharte (no toques la espada)"\n'
           '    },\n'),
}

RES_SWORD = {
    "zh": ('    "sword": {\n'
           '      "SWORD_GAINED": "失去 %d 点最大生命（现 %d / %d）——「大师之剑」已收进行囊"\n'
           '    },\n'),
    "en": ('    "sword": {\n'
           '      "SWORD_GAINED": "Lost %d Max Health (current %d/%d)—the \\"Master Sword\\" is yours"\n'
           '    },\n'),
    "ja": ('    "sword": {\n'
           '      "SWORD_GAINED": "最大HPを%d失った（現在 %d/%d）——「マスターソード」を手に入れた"\n'
           '    },\n'),
    "es": ('    "sword": {\n'
           '      "SWORD_GAINED": "Has perdido %d de Vida máxima (actual: %d/%d); la «Espada Maestra» es tuya"\n'
           '    },\n'),
}

FILES = {"zh": "i18n/event_ui_zh_canonical.json",
         "en": "i18n/event_ui_en.json",
         "ja": "i18n/event_ui_ja.json",
         "es": "i18n/event_ui_es.json"}

for code, path in FILES.items():
    patch(path, [
        ('    "struggle": {\n      "ACCEPT_STRUGGLE": ',
         OPT_SWORD[code] + '    "struggle": {\n      "ACCEPT_STRUGGLE": '),
        ('    "struggle": {\n      "STRUGGLE_CARD_GAINED": ',
         RES_SWORD[code] + '    "struggle": {\n      "STRUGGLE_CARD_GAINED": '),
    ])

print("patch 3 done")
