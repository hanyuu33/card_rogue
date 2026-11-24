# -*- coding: utf-8 -*-
# R828 数据层 + i18n 精确补丁：音乐盒 2→3 种、La 抽3→4/力量+3→+2、新增「这是礼帽」6087
import io

def rep(path, old, new):
    raw = io.open(path, 'r', encoding='utf-8', newline='').read()
    n = raw.count(old)
    assert n == 1, '%s: 锚点 count=%d: %r' % (path, n, old[:70])
    raw = raw.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='').write(raw)
    print('OK  %s' % path)

# ── 1. cards.json（CRLF）：La 9282 effect_text 抽3→4、力量+3→+2 ──
rep('cards.json',
    '抽 3 张卡，这些卡本局费用 -1；其中盟友与工事力量 +3。',
    '抽 4 张卡，这些卡本局费用 -1；其中盟友与工事力量 +2。')

# ── 2. relics.json（LF）：音乐盒 6086 desc 2→3 种 + 新增 6087 这是礼帽 ──
rep('relics.json',
    '''    {
      "id": 6086,
      "name": "音乐盒",
      "kind": "战斗",
      "source": "二层",
      "tier": "一般",
      "desc": "每场战斗开始时，将 2 张随机音符加入抽牌库。"
    }''',
    '''    {
      "id": 6086,
      "name": "音乐盒",
      "kind": "战斗",
      "source": "二层",
      "tier": "一般",
      "desc": "每场战斗开始时，将 3 种随机音符加入抽牌库。"
    },
    {
      "id": 6087,
      "name": "这是礼帽",
      "kind": "战斗",
      "source": "二层",
      "tier": "一般",
      "desc": "你的盟友或工事获得「死亡：洗回你的抽牌库，本局费用 -2 并获得次元」。"
    }''')

# ── 3. demo_scope.json（LF）：relics 6086 后补 6087 ──
rep('demo_scope.json',
    '    6085,\n    6086\n  ],',
    '    6085,\n    6086,\n    6087\n  ],')

# ── 4. i18n cards 四语：9282 effect_text ──
rep('i18n/zh_canonical.json',
    '抽 3 张卡，这些卡本局费用 -1；其中盟友与工事力量 +3。',
    '抽 4 张卡，这些卡本局费用 -1；其中盟友与工事力量 +2。')
rep('i18n/cards_en.json',
    'Draw 3 cards; those cards cost 1 less this battle. Allies and Structures drawn this way gain +3 Power.',
    'Draw 4 cards; those cards cost 1 less this battle. Allies and Structures drawn this way gain +2 Power.')
rep('i18n/cards_ja.json',
    'カードを3枚引き、それらのカードのコストをこの戦闘中-1する。その中の味方または構造物のカードは攻撃力+3。',
    'カードを4枚引き、それらのカードのコストをこの戦闘中-1する。その中の味方または構造物のカードは攻撃力+2。')
rep('i18n/cards_es.json',
    'Roba 3 cartas; esas cartas cuestan 1 menos este combate. Los Aliados y Estructuras robados así ganan +3 de Poder.',
    'Roba 4 cartas; esas cartas cuestan 1 menos este combate. Los Aliados y Estructuras robados así ganan +2 de Poder.')

# ── 5. i18n noncard 四语：6086 desc + 新增 6087 ──
rep('i18n/noncard_zh_canonical.json',
    '    "6086": {"name": "音乐盒", "desc": "每场战斗开始时，将 2 张随机音符加入抽牌库。"}',
    '    "6086": {"name": "音乐盒", "desc": "每场战斗开始时，将 3 种随机音符加入抽牌库。"},\n    "6087": {"name": "这是礼帽", "desc": "你的盟友或工事获得「死亡：洗回你的抽牌库，本局费用 -2 并获得次元」。"}')
rep('i18n/noncard_en.json',
    '    "6086": {"name": "Music Box", "desc": "At the start of each battle, add 2 random Notes to your Draw Pile."}',
    '    "6086": {"name": "Music Box", "desc": "At the start of each battle, add 3 random Notes to your Draw Pile."},\n    "6087": {"name": "This Is a Top Hat", "desc": "Your Allies and Structures gain \\"Death\\": when Destroyed, they are shuffled back into your Draw Pile, cost 2 less this battle, and gain Dimensional."}')
rep('i18n/noncard_ja.json',
    '    "6086": {"name": "オルゴール", "desc": "各戦闘の開始時、ランダムな音符2枚を山札に加える。"}',
    '    "6086": {"name": "オルゴール", "desc": "各戦闘の開始時、ランダムな音符3種を山札に加える。"},\n    "6087": {"name": "これはシルクハット", "desc": "あなたの味方または構造物は「死亡」を得る：破壊された時、あなたの山札に戻り、この戦闘中コスト-2され、「次元」を得る。"}')
rep('i18n/noncard_es.json',
    '    "6086": {"name": "Caja de música", "desc": "Al inicio de cada combate, añade 2 Notas aleatorias a tu pila de robo."}',
    '    "6086": {"name": "Caja de música", "desc": "Al inicio de cada combate, añade 3 Notas aleatorias a tu pila de robo."},\n    "6087": {"name": "Este es un Sombrero de Copa", "desc": "Tus Aliados y Estructuras obtienen «Muerte»: al ser destruidos, vuelven a tu pila de robo, cuestan 2 menos este combate y obtienen «dimensional»."}')

# ── 6. glossary.json（LF）：音乐盒后补「这是礼帽」词条 ──
rep('i18n/glossary.json',
    '''    "音乐盒": {
      "en": "Music Box",
      "ja": "オルゴール",
      "id": 6086
    }''',
    '''    "音乐盒": {
      "en": "Music Box",
      "ja": "オルゴール",
      "id": 6086
    },
    "这是礼帽": {
      "en": "This Is a Top Hat",
      "ja": "これはシルクハット",
      "id": 6087
    }''')

print('\n全部数据层/i18n 补丁完成')
