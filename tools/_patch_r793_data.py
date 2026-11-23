# -*- coding: utf-8 -*-
"""R793 数据层：刺墙 6073 / 应急装甲 6074 进 relics.json + 四语 + 奖励池。"""
import io
import json
import sys

ROOT = 'E:/work/card_rogue/'


def read(p):
    return io.open(ROOT + p, encoding='utf-8', newline='').read()


def write(p, s):
    io.open(ROOT + p, 'w', encoding='utf-8', newline='').write(s)


# ── ① relics.json：在 6072 那条之后追加两条 ──────────────────────────
P = 'relics.json'
s = read(P)
old = '''      "id": 6072,
      "name": "墙砖",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你的工事卡生命 +4（持续生效，不叠加）。"
    }
  ]
}'''
new = '''      "id": 6072,
      "name": "墙砖",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你的工事卡生命 +4（持续生效，不叠加）。"
    },
    {
      "id": 6073,
      "name": "刺墙",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你的工事被攻击时，对攻击者造成 5 点伤害。"
    },
    {
      "id": 6074,
      "name": "应急装甲",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "每回合最多受到 20 点伤害。"
    }
  ]
}'''
if s.count(old) != 1:
    print('FAIL relics.json 锚点命中 %d 次' % s.count(old))
    sys.exit(1)
write(P, s.replace(old, new))

# ── ② i18n 四语 ────────────────────────────────────────────────────
TEXTS = {
    'zh_canonical': {
        '6073': {'name': '刺墙',
                 'desc': '你的工事被攻击时，对攻击者造成 5 点伤害。'},
        '6074': {'name': '应急装甲',
                 'desc': '每回合最多受到 20 点伤害。'},
    },
    'en': {
        '6073': {'name': 'Spike Wall',
                 'desc': 'Whenever one of your Structures is attacked, deal 5 damage to the attacker.'},
        '6074': {'name': 'Emergency Armor',
                 'desc': 'You take at most 20 damage each turn.'},
    },
    'ja': {
        '6073': {'name': 'トゲの壁',
                 'desc': '自分の構造物が攻撃されたとき、攻撃者に5ダメージを与える。'},
        '6074': {'name': '緊急装甲',
                 'desc': '毎ターン最大20ダメージしか受けない。'},
    },
    'es': {
        '6073': {'name': 'Muro de Púas',
                 'desc': 'Cuando una de tus Estructuras es atacada, inflige 5 de daño al atacante.'},
        '6074': {'name': 'Armadura de Emergencia',
                 'desc': 'No puedes recibir más de 20 de daño por turno.'},
    },
}

# 最后一条的原文（用作每份文件各自的锚点）
LAST = {
    'zh_canonical': '"6072": {"name": "墙砖", "desc": "你的工事卡生命 +4（持续生效，不叠加）。"}',
    'en': '"6072": {"name": "Wall Brick", "desc": "Your Structures have +4 Health (persistent; does not stack)."}',
    'ja': '"6072": {"name": "壁のレンガ", "desc": "自分の構造物カードの生命+4（継続し、重複しない）。"}',
    'es': '"6072": {"name": "Ladrillo", "desc": "Tus Estructuras tienen +4 de Vida (efecto persistente; no se acumula)."}',
}

for lang, items in TEXTS.items():
    P = 'i18n/noncard_%s.json' % lang
    s = read(P)
    anchor = LAST[lang] + '\n  },\n  "classes": {'
    if s.count(anchor) != 1:
        print('FAIL %s 锚点命中 %d 次' % (P, s.count(anchor)))
        sys.exit(1)
    add = []
    for rid in ('6073', '6074'):
        add.append('    "%s": %s' % (rid, json.dumps(items[rid], ensure_ascii=False)))
    repl = LAST[lang] + ',\n' + ',\n'.join(add) + '\n  },\n  "classes": {'
    write(P, s.replace(anchor, repl))

# ── ③ 奖励池 id 列表 ───────────────────────────────────────────────
P = 'scripts/relic_repo.gd'
s = read(P)
old = '''	#   三件新道具都是一般档、不锁剧情（进池即可摇到）。
	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065, 6066,
			6070, 6071, 6072]'''
new = '''	#   三件新道具都是一般档、不锁剧情（进池即可摇到）。
	# R793：加「刺墙」6073（己方工事被攻击 → 攻击者受 5 伤）与「应急装甲」6074
	#   （玩家 HP 每回合最多受 20 伤）。同样一般档、不锁剧情。
	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065, 6066,
			6070, 6071, 6072, 6073, 6074]'''
if s.count(old) != 1:
    print('FAIL relic_repo 锚点命中 %d 次' % s.count(old))
    sys.exit(1)
write(P, s.replace(old, new))

# ── 校验 ───────────────────────────────────────────────────────────
d = json.load(io.open(ROOT + 'relics.json', encoding='utf-8'))['relics']
print('relics', len(d), [x['name'] for x in d if x['id'] >= 6073])
for lang in ('zh_canonical', 'en', 'ja', 'es'):
    j = json.load(io.open(ROOT + 'i18n/noncard_%s.json' % lang, encoding='utf-8'))['relics']
    print(lang, len(j), j['6073']['name'], '|', j['6074']['name'])
print('OK')
