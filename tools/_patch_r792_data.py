# -*- coding: utf-8 -*-
"""R792 补丁：三件新道具（板甲 / 兵 / 墙砖）+ 猴爪进池 + 第三层不再注册事件。

规则：
  * 每个锚点必须断言命中 1 次（多命中也算错，说明锚点不够独特）；
  * CRLF 文件按原行尾写回（placement.gd / field_state.gd / game_engine.gd）；
  * 不重排 JSON（只做文本插入）。
"""
import io
import sys

ROOT = 'E:/work/card_rogue/'


def rw(path, old, new, crlf=False, count=1):
    p = ROOT + path
    s = io.open(p, encoding='utf-8', newline='').read()
    if crlf:
        old = old.replace('\n', '\r\n')
        new = new.replace('\n', '\r\n')
    n = s.count(old)
    if n != count:
        print('FAIL %s: 命中 %d 次（期望 %d）' % (path, n, count))
        print('---- 锚点 ----')
        print(repr(old[:300]))
        sys.exit(1)
    s = s.replace(old, new)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK   %s' % path)


# ── 1. relics.json：追加三件 ────────────────────────────────────────────
OLD_TAIL = '''      "desc": "每回合第一次使用其他职业的盟友时，回复 1 点费用。其他职业的盟友 +2 力量（持续生效，不叠加）。"
    }
  ]
}'''
NEW_TAIL = '''      "desc": "每回合第一次使用其他职业的盟友时，回复 1 点费用。其他职业的盟友 +2 力量（持续生效，不叠加）。"
    },
    {
      "id": 6070,
      "name": "板甲",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "每场战斗使用的第一个盟友获得 +6 生命（不叠加），但移动速度变为 1。"
    },
    {
      "id": 6071,
      "name": "兵",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "每场战斗使用的第一个盟友可以行动两次（不叠加）。"
    },
    {
      "id": 6072,
      "name": "墙砖",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你的工事卡生命 +4（持续生效，不叠加）。"
    }
  ]
}'''
rw('relics.json', OLD_TAIL, NEW_TAIL)


# ── 2. i18n 四语 ─────────────────────────────────────────────────────
LOC = {
    'zh_canonical': ('"6069": {"name": "诗", "desc": "每回合第一次使用其他职业的盟友时，回复 1 点费用。其他职业的盟友 +2 力量（持续生效，不叠加）。"}',
        '''"6069": {"name": "诗", "desc": "每回合第一次使用其他职业的盟友时，回复 1 点费用。其他职业的盟友 +2 力量（持续生效，不叠加）。"},
    "6070": {"name": "板甲", "desc": "每场战斗使用的第一个盟友获得 +6 生命（不叠加），但移动速度变为 1。"},
    "6071": {"name": "兵", "desc": "每场战斗使用的第一个盟友可以行动两次（不叠加）。"},
    "6072": {"name": "墙砖", "desc": "你的工事卡生命 +4（持续生效，不叠加）。"}'''),
    'en': ('"6069": {"name": "Poem", "desc": "The first time each turn you play another class\'s Ally, refund 1 Energy. Other-class Allies have +2 Power (persistent; does not stack)."}',
        None),
}

# zh 直接写
rw('i18n/noncard_zh_canonical.json', LOC['zh_canonical'][0], LOC['zh_canonical'][1])

# en / ja / es 的锚点不同，逐条取现有 6069 行做锚点
def add_locale(fname, anchor_key, additions):
    p = ROOT + fname
    s = io.open(p, encoding='utf-8', newline='').read()
    i = s.find(anchor_key)
    if i < 0:
        print('FAIL %s: 找不到 %s' % (fname, anchor_key))
        sys.exit(1)
    j = s.find('\n', i)
    line = s[i:j]
    rw(fname, line, line + '\n' + additions)


# 先看 en/ja/es 的 6069 原文，脚本里用「从 6069 到行尾」的方式拼，避免手抄错
def load_6069(fname):
    s = io.open(ROOT + fname, encoding='utf-8', newline='').read()
    i = s.find('"6069"')
    j = s.find('\n', i)
    return s[i:j]


ADD = {
    'i18n/noncard_en.json': [
        ('6070', 'Plate Armor', 'The first Ally you play each combat gains +6 Health (does not stack), but its Move Speed becomes 1.'),
        ('6071', 'Pawn', 'The first Ally you play each combat can act twice (does not stack).'),
        ('6072', 'Wall Brick', 'Your Structures have +4 Health (persistent; does not stack).'),
    ],
    'i18n/noncard_ja.json': [
        ('6070', '板金鎧', '各戦闘で最初に使う味方は生命+6（重複しない）を得るが、移動速度が1になる。'),
        ('6071', 'ポーン', '各戦闘で最初に使う味方は2回行動できる（重複しない）。'),
        ('6072', '壁のレンガ', '自分の構造物カードの生命+4（継続し、重複しない）。'),
    ],
    'i18n/noncard_es.json': [
        ('6070', 'Armadura de Placas', 'El primer Aliado que juegas en cada combate obtiene +6 de Vida (no se acumula), pero su Velocidad de Movimiento pasa a ser 1.'),
        ('6071', 'Peón', 'El primer Aliado que juegas en cada combate puede actuar dos veces (no se acumula).'),
        ('6072', 'Ladrillo', 'Tus Estructuras tienen +4 de Vida (efecto persistente; no se acumula).'),
    ],
}

for fname, rows in ADD.items():
    line = load_6069(fname)
    # 若 6069 行尾已有逗号则去掉，统一由脚本补
    base = line.rstrip()
    if base.endswith(','):
        base = base[:-1]
    extra = ',\n' + ',\n'.join(
        '    "%s": {"name": "%s", "desc": "%s"}' % (i, n, d) for i, n, d in rows)
    rw(fname, line, base + extra)


# ── 3. relic_repo.gd：猴爪 + 三件进奖励池 ────────────────────────────
rw('scripts/relic_repo.gd',
   '''	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065]''',
   '''	# R792：**猴爪 6066 与板甲 6070 / 兵 6071 / 墙砖 6072** 补进奖励池 ——
	#   猴爪原先在 relics.json 里标「奖励」、引擎也有机制，但不在本列表里，
	#   于是 `roll_reward_relic()` 永远摇不到它（孤儿道具）。这里一并收进来。
	#   三件新道具都是一般档、不锁剧情（进池即可摇到）。
	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065, 6066,
			6070, 6071, 6072]''')


# ── 4. game_layers.gd：第三层不再注册事件 ────────────────────────────
rw('scripts/game_layers.gd',
   '''	3: {
		"name": "第三层",
		# R356：本层的战斗关卡=**启示者**（唯一一个，layer 3），精英节点按用户口径
		# **沿用第二层**（直道第 2 格固定是精英战斗）→ `content_layers` 写 [2, 3]：
		#   关卡池 = 第二层的普通 / 精英 + 本层的 Boss；
		#   **R506b：精英节点只取第二层的困难档**（`GameLevels.third_elite_pool()`，
		#   3 关），不是 content_layers 摊开的全部 7 关；
		#   `boss_pool(3)` 仍只认「本层专属 Boss」，所以摇到的必然是启示者。
		# 事件表保留在这里（第三层地图只有 5 个固定格、没有事件节点，实际抽不到）。
		"content_layers": [2, 3],
		"events": {
			# 「全层通用」的两个（约定：每层都写一份，不继承）
			"oblivion": 14,   # 遗忘之泉（全层通用）：可从卡组删一张卡，或离开
			"smith": 12,      # 鸭鸭工匠（全层通用）：把卡组里一张卡变成「2 费铁栅栏」
			# 用户口径要「2、3 层都有」/「1、2、3 层都有」的两个
			"card_merchant": 16,  # 卡片商人：换卡 / 5 费卡换大宝箱 / 随机折价
			"divination": 12,     # 占卜室：占卜 → 随机 4 种幻象 → 两种解读
		},
	},''',
   '''	3: {
		"name": "第三层",
		# R356：本层的战斗关卡=**启示者**（唯一一个，layer 3），精英节点按用户口径
		# **沿用第二层**（直道第 2 格固定是精英战斗）→ `content_layers` 写 [2, 3]：
		#   关卡池 = 第二层的普通 / 精英 + 本层的 Boss；
		#   **R506b：精英节点只取第二层的困难档**（`GameLevels.third_elite_pool()`，
		#   3 关），不是 content_layers 摊开的全部 7 关；
		#   `boss_pool(3)` 仍只认「本层专属 Boss」，所以摇到的必然是启示者。
		# R792（用户口径「事件不再注册到第三层」）：**整张 events 表已删除**。
		#   第三层地图只有 5 个固定格、没有事件节点，登记在这里的四种事件本来就
		#   一次都抽不到；留着只会让 `event_weights(3)` 报一份假的可遇清单。
		#   `has_events(3)` 现在恒为 false —— 事件池只有第一 / 第二层。
		"content_layers": [2, 3],
	},''')


# ── 5. RULES_VERSION 3 → 4（奖励池变动，两处必须同升）──────────────
rw('scripts/daily_modifiers.gd', 'const RULES_VERSION := 3', 'const RULES_VERSION := 4')
rw('scripts/daily_challenge.gd', 'const RULES_VERSION := 3', 'const RULES_VERSION := 4')

print('数据层完成')
