# -*- coding: utf-8 -*-
"""抽取 game_levels.gd 的关卡数据 + cards.json 的敌方卡，生成 Markdown 文档。"""
import json, re, io, os

# 以脚本自身位置推导工程根目录，双机通用（R356 修正：原来写死 D 盘）
ROOT = os.path.dirname(os.path.abspath(__file__))

# ---------- 1. 解析 game_levels.gd ----------
src = open(os.path.join(ROOT, r'scripts\game_levels.gd'), encoding='utf-8').read()

m = re.search(r'static func builtin_levels\(\) -> Array:', src)
builtin_body = src[m.end():]
_start = builtin_body.find('return [') + 7
_depth = 0
_end = -1
for _i in range(_start, len(builtin_body)):
    _ch = builtin_body[_i]
    if _ch in '[{':
        _depth += 1
    elif _ch in ']}':
        _depth -= 1
        if _depth == 0:
            _end = _i
            break
assert _end > 0, 'builtin_levels 数组未配对'
arr = builtin_body[_start:_end]
order = re.findall(r'_(\w+)\(\)', arr)

TIER_NAMES = ['普通-简单', '普通-困难', '精英-简单', '精英-困难', 'Boss']
TIER_MAP = {
    'TIER_NORMAL_EASY': 0, 'TIER_NORMAL_HARD': 1, 'TIER_ELITE_EASY': 2,
    'TIER_ELITE_HARD': 3, 'TIER_BOSS': 4,
}
LAYER_MAP = {'GameLayers.LAYER_DEFAULT': '第一层', 'GameLayers.LAYER_TWO': '第二层',
             'GameLayers.LAYER_THREE': '第三层'}
# 对映 ui_theme.gd 的 RARITY_* 下标（0 普通 / 1 稀有 / 2 史诗 / 3 初始 / 4 怪物 / 5 事件）
RARITY_NAMES = {0: '普通', 1: '稀有', 2: '史诗', 3: '初始', 4: '怪物', 5: '事件'}

levels = {}
for ch in re.split(r'\n(?=static func _)', src):
    fm = re.match(r'static func _(\w+)\(\) -> Dictionary:', ch)
    if not fm:
        continue
    key = fm.group(1)
    body = ch

    def g(field, cast=str):
        mm = re.search(r'"%s":\s*(.+?),\n' % field, body)
        if not mm:
            return None
        v = mm.group(1).strip()
        if cast is str and v.startswith('"'):
            v = v.strip('"')
        return cast(v) if cast is not str else v

    units = []
    um = re.search(r'"enemy_units":\s*\[(.*?)\n\t\t\],', body, re.S)
    if um:
        for line in um.group(1).split('\n'):
            mm = re.match(
                r'\s*\[(\d+),\s*"([^"]+)",\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*Vector2i\((\d+),\s*(\d+)\)\]', line)
            if mm:
                units.append({
                    'id': int(mm.group(1)), 'name': mm.group(2),
                    'power': int(mm.group(3)), 'health': int(mm.group(4)),
                    'range': int(mm.group(5)), 'speed': int(mm.group(6)),
                    'row': int(mm.group(7)), 'col': int(mm.group(8)),
                })
    levels[key] = {
        'func': '_' + key, 'name': g('name'), 'key': g('key'),
        'tier': TIER_MAP.get((g('tier') or '').strip(), 0),
        'layer': LAYER_MAP.get((g('layer') or '').strip(), '第一层'),
        'deck_key': g('deck_key'), 'player_hp': g('player_hp'),
        'enemy_hp': ('∞' if 'enemy_hp_infinite' in body else g('enemy_hp')),
        'enemy_hp_raw': g('enemy_hp'), 'turn_limit': g('turn_limit'),
        'starting_hand': g('starting_hand'), 'units': units,
    }

builtin = [levels[k] for k in order if k in levels]
missing = [k for k in order if k not in levels]
l1 = [x for x in builtin if x['layer'] == '第一层']
l2 = [x for x in builtin if x['layer'] == '第二层']
l3 = [x for x in builtin if x['layer'] == '第三层']

# ---------- 2. 解析 cards.json 敌方卡 ----------
d = json.load(open(os.path.join(ROOT, 'cards.json'), encoding='utf-8'))
cards = d['cards'] if isinstance(d, dict) and 'cards' in d else d
if isinstance(cards, dict):
    cards = list(cards.values())
enemy_cards = {}
for c in cards:
    if isinstance(c, dict) and c.get('class') == '敌人':
        enemy_cards[c['id']] = c

# 登场关卡映射
appear = {}
for lv in builtin:
    for u in lv['units']:
        appear.setdefault(u['id'], {})
        appear[u['id']][lv['name']] = appear[u['id']].get(lv['name'], 0) + 1

out = io.StringIO()
w = out.write

w('# 卡牌肉鸽 · 关卡与敌人配置总览\n\n')
w('> 由 `scripts/game_levels.gd` + `cards.json` **自动抽取**生成；改数据后重跑 `_p14_gendoc.py` 即可刷新。\n')
w('> 棋盘 = **6 行 × 3 列**，格子键 `Vector2i(行, 列)`；敌方占 row 0~2，**row 0 = 最后排**（最靠敌方底线）。\n\n')

# ---------- 3. 总览 ----------
w('## 一、总览\n\n')
w('| 指标 | 数值 |\n|---|---|\n')
w('| 内置关卡总数 | **%d** |\n' % len(builtin))
w('| 第一层（LAYER_DEFAULT） | %d |\n' % len(l1))
w('| 第二层（LAYER_TWO） | %d |\n' % len(l2))
w('| 第三层（LAYER_THREE） | %d |\n' % len(l3))
w('| 敌方卡总数 | %d |\n' % len(enemy_cards))
w('| 敌方单位实例总数（各关编成求和） | %d |\n' % sum(len(x['units']) for x in builtin))
w('| 彩蛋关卡 | 1（恶魔鸭·复仇，`revenge_boss()`，刻意不在 builtin_levels） |\n\n')

# ---------- 4. 分级分布 ----------
w('## 二、分级分布（比例总览）\n\n')
w('### 2.1 分级 × 层 交叉表\n\n')
w('| 分级 | 全体 | 第一层 | 第二层 | 第三层 |\n|---|---|---|---|---|\n')
for t in range(5):
    a = len([x for x in builtin if x['tier'] == t])
    b = len([x for x in l1 if x['tier'] == t])
    c = len([x for x in l2 if x['tier'] == t])
    d3 = len([x for x in l3 if x['tier'] == t])
    w('| %s | %d | %d | %d | %d |\n' % (TIER_NAMES[t], a, b, c, d3))
w('| **合计** | **%d** | **%d** | **%d** | **%d** |\n\n' % (len(builtin), len(l1), len(l2), len(l3)))

w('### 2.2 各层分级占比（= 地图节点抽卡权重）\n\n')
for layer, lst in [('第一层', l1), ('第二层', l2), ('第三层', l3)]:
    w('**%s**（共 %d 关）\n\n' % (layer, len(lst)))
    w('| 分级 | 关数 | 占比 |\n|---|---|---|\n')
    for t in range(5):
        n = len([x for x in lst if x['tier'] == t])
        if not n:
            continue
        w('| %s | %d | %.0f%% |\n' % (TIER_NAMES[t], n, 100.0 * n / len(lst)))
    w('\n')

w('> **口径说明**：地图节点从「本层内容池」的对应分级池随机抽关 ——\n')
w('> 普通节点 → `normal_pool()`（普通-简单 + 普通-困难），精英节点 → `elite_pool()`（精英-简单 + 精英-困难），\n')
w('> Boss 节点 → 开局从 `boss_pool()` 摇一次存 `boss_pick`。\n')
w('> 因此上表占比即玩家在该层踩到某分级节点时，**各关卡被抽中的实际概率分布**。\n\n')

# ---------- 5. 缺口分析 ----------
w('## 三、缺口分析\n\n')


def verdict(tname, n):
    if tname == 'Boss':
        if n >= 3:
            return '充足（%d 选 1）' % n
        if n == 2:
            return '尚可（2 选 1）'
        return '偏少'
    if n == 0:
        return '**空池**'
    if n == 1:
        return '**结构性缺口**：仅 1 关，抽中即 100% 重复'
    if n == 2:
        return '偏少，连抽易撞'
    if n == 3:
        return '尚可'
    return '充足'


w('| 层 | 分级 | 关数 | 评估 |\n|---|---|---|---|\n')
for layer, lst in [('第一层', l1), ('第二层', l2), ('第三层', l3)]:
    for t in range(5):
        n = len([x for x in lst if x['tier'] == t])
        w('| %s | %s | %d | %s |\n' % (layer, TIER_NAMES[t], n, verdict(TIER_NAMES[t], n)))
w('\n')

gaps = []
for layer, lst in [('第一层', l1), ('第二层', l2)]:
    for t in range(4):
        gaps.append((len([x for x in lst if x['tier'] == t]), layer, TIER_NAMES[t]))
gaps.sort()
w('### 3.1 缺口优先级\n\n')
w('| 优先级 | 缺口 | 关数 | 单关被抽中概率 | 建议 |\n|---|---|---|---|---|\n')
shown = 0
for n, layer, tname in gaps:
    if n >= 3:
        break
    shown += 1
    prob = 100.0 / n if n else 0
    w('| P%d | %s · %s | %d | %.0f%% | 至少补到 3 关 |\n' % (shown - 1, layer, tname, n, prob))
if not shown:
    w('| — | 无（各分级池均 ≥ 3 关） | — | — | — |\n')
w('\n')

w('### 3.2 其他观察\n\n')
w('- **普通-简单**总量 %d 关（第一层 %d + 第二层 %d）。\n'
  % (len([x for x in builtin if x['tier'] == 0]),
     len([x for x in l1 if x['tier'] == 0]), len([x for x in l2 if x['tier'] == 0])))
w('- **Boss 池**：第一层 %d 个、第二层 %d 个；第二层含「恶魔鸭·复仇」彩蛋位（不进池）。\n'
  % (len([x for x in l1 if x['tier'] == 4]), len([x for x in l2 if x['tier'] == 4])))
w('- 层数分布：第一层 %d 关 / 第二层 %d 关 / 第三层 %d 关。\n' % (len(l1), len(l2), len(l3)))
w('- **敌方卡复用率**：%d 张敌方卡中，有 %d 张**未在任何内置关卡登场**（见 §5.2）；\n' % (len(enemy_cards), len([cid for cid in enemy_cards if cid not in appear])))
w('  其中部分为敌方「效果卡」（通过 `enemy_effects` 机制进入关卡），不占用 `enemy_units` 编成，属正常。\n\n')

# ---------- 6. 关卡明细 ----------
w('## 四、关卡明细\n\n')
for li, (layer, lst) in enumerate([('第一层', l1), ('第二层', l2), ('第三层', l3)]):
    w('### 4.%d %s（%d 关）\n\n' % (li + 1, layer, len(lst)))
    for i, lv in enumerate(lst):
        idx = builtin.index(lv)
        tl = lv['turn_limit']
        tl_s = '无限制' if tl in ('-1', '-1', None) else str(tl)
        w('#### %d. %s · %s\n\n' % (i + 1, lv['name'], TIER_NAMES[lv['tier']]))
        w('- **key**：`%s`　|　**函数**：`GameLevels.%s()`　|　**builtin 下标**：`%d`\n' % (lv['key'], lv['func'], idx))
        w('- **生命**：我方 %s / 敌方 %s　|　**卡组**：`%s`　|　**起始手牌**：%s　|　**回合上限**：%s\n'
          % (lv['player_hp'], lv['enemy_hp'], lv['deck_key'], lv['starting_hand'], tl_s))
        w('- **编成**：%d 个单位\n\n' % len(lv['units']))
        if lv['units']:
            w('| 卡 id | 名称 | 攻 | 血 | 程 | 速 | 位置(行,列) | 排位 |\n|---|---|---|---|---|---|---|---|\n')
            for u in lv['units']:
                pos = '后排' if u['row'] == 0 else ('中排' if u['row'] == 1 else '前排')
                w('| %d | %s | %d | %d | %d | %d | (%d,%d) | %s |\n'
                  % (u['id'], u['name'], u['power'], u['health'], u['range'], u['speed'], u['row'], u['col'], pos))
        w('\n')

# 彩蛋关卡（不在 builtin_levels，独立一节）
rv = levels.get('boss_demon_duck_revenge')
if rv:
    w('### 4.%d 彩蛋关卡（刻意不在 builtin_levels）\n\n' % (len([l1, l2, l3]) + 1))
    w('#### %s · %s\n\n' % (rv['name'], TIER_NAMES[rv['tier']]))
    w('- **key**：`%s`　|　**函数**：`GameLevels.%s()`\n' % (rv['key'], rv['func']))
    w('- **生命**：我方 %s / 敌方 %s　|　**卡组**：`%s`\n'
      % (rv['player_hp'], rv['enemy_hp'], rv['deck_key']))
    w('- ⚠️ 不进 `builtin_levels` 的理由：否则它会 ①出现在调试关卡选择菜单、②进 `boss_pool`\n')
    w('  （第二层 3 个 Boss 随机抽到它 → 「50% 概率触发复仇」形同虚设）。入口见 `revenge_boss()`。\n\n')
    if rv['units']:
        w('| 卡 id | 名称 | 攻 | 血 | 程 | 速 | 位置(行,列) |\n|---|---|---|---|---|---|---|\n')
        for u in rv['units']:
            w('| %d | %s | %d | %d | %d | %d | (%d,%d) |\n'
              % (u['id'], u['name'], u['power'], u['health'], u['range'], u['speed'], u['row'], u['col']))
        w('\n')

# ---------- 7. 敌方卡图鉴 ----------
w('## 五、敌方卡图鉴\n\n')
w('### 5.1 全表（%d 张）\n\n' % len(enemy_cards))
w('| id | 名称 | 种类 | 费 | 攻 | 血 | 程 | 速 | 稀有度 | 登场关卡 | 说明 |\n')
w('|---|---|---|---|---|---|---|---|---|---|---|\n')
for cid in sorted(enemy_cards):
    c = enemy_cards[cid]
    desc = str(c.get('effect_text') or '').replace('\n', ' ').replace('|', '/')
    if len(desc) > 44:
        desc = desc[:44] + '…'
    apps = appear.get(cid, {})
    if apps:
        parts = ['%s×%d' % (k, v) if v > 1 else k for k, v in apps.items()]
        app_s = '、'.join(parts)
    else:
        app_s = '—'
    w('| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n'
      % (cid, c.get('name', '?'), c.get('kind', ''), c.get('cost', ''),
         c.get('power', ''), c.get('health', ''), c.get('attack_range', ''),
         c.get('move_speed', ''), RARITY_NAMES.get(c.get('rarity'), ''),
         app_s, desc))
w('\n')

w('### 5.2 未在内置关卡登场的敌方卡\n\n')
unused = [cid for cid in sorted(enemy_cards) if cid not in appear]
if unused:
    w('| id | 名称 | 种类 | 说明 |\n|---|---|---|---|\n')
    for cid in unused:
        c = enemy_cards[cid]
        desc = str(c.get('effect_text') or '').replace('\n', ' ').replace('|', '/')
        if len(desc) > 50:
            desc = desc[:50] + '…'
        w('| %d | %s | %s | %s |\n' % (cid, c.get('name', '?'), c.get('kind', ''), desc))
else:
    w('无。\n')
w('\n')

# ---------- 8. 登场频次 ----------
w('## 六、敌方单位登场频次（按出现次数降序）\n\n')
freq = []
for cid, names in appear.items():
    freq.append((sum(names.values()), cid, enemy_cards.get(cid, {}).get('name', '?'), len(names)))
freq.sort(reverse=True)
w('| 排名 | 卡 id | 名称 | 单位实例数 | 涉及关卡数 |\n|---|---|---|---|---|\n')
for i, (n, cid, nm, lv_n) in enumerate(freq):
    w('| %d | %d | %s | %d | %d |\n' % (i + 1, cid, nm, n, lv_n))
w('\n')

# ---------- 9. 素材覆盖缺口 ----------
bg_dir = os.path.join(ROOT, 'assets', 'ui')
have_bg = set()
if os.path.isdir(bg_dir):
    for f in os.listdir(bg_dir):
        if f.startswith('battle_bg_') and f.endswith('.png'):
            have_bg.add(f[len('battle_bg_'):-4])
all_keys = [lv['key'] for lv in builtin]
if rv:
    all_keys.append(rv['key'])
lack_bg = [k for k in all_keys if k not in have_bg]

img_ok = [cid for cid, c in enemy_cards.items() if str(c.get('image') or '').strip()]

w('## 七、素材覆盖缺口\n\n')
w('| 槽位类型 | 命名 | 应有 | 实有 | 覆盖率 |\n|---|---|---|---|---|\n')
w('| 关卡专属战斗背景 | `assets/ui/battle_bg_<key>.png` | %d | %d | %.0f%% |\n'
  % (len(all_keys), len(all_keys) - len(lack_bg),
     100.0 * (len(all_keys) - len(lack_bg)) / max(1, len(all_keys))))
w('| 敌方卡图 | `cards.json` 的 `image` 字段 | %d | %d | %.0f%% |\n'
  % (len(enemy_cards), len(img_ok), 100.0 * len(img_ok) / max(1, len(enemy_cards))))
w('\n')
w('**回退链**（唯一口径 `UiAssets.battle_bg_path(key, layer)`）：\n\n')
w('```\n① res://assets/ui/battle_bg_<关卡key>.png   本关专属（当前 0 张）\n')
w('② res://assets/ui/map_bg_<层号>.png         当层地图底图 —— ① 缺时落这里（已存在）\n')
w('③ res://assets/battle_bg.png                全局兜底（已存在）\n```\n\n')
w('缺专属背景**不报错也不会空白**，会静默回退；当前 26 关全部落在 ②。\n')
w('⚠️ 因此「出图核验」时看到的背景不随关卡变化，别误判为背景已就位。\n\n')
if lack_bg:
    w('**缺专属背景的关卡 key（%d 个）**：\n\n' % len(lack_bg))
    w('```\n' + '  '.join(lack_bg) + '\n```\n\n')
else:
    w('全部关卡均有专属背景。\n\n')

w('---\n\n')
w('## 八、附：文档生成方式\n\n')
w('本文件由 `scripts/game_levels.gd`（关卡定义）与 `cards.json`（卡牌数据）自动抽取：\n\n')
w('```\npython _p14_gendoc.py\n```\n\n')
w('抽取口径：\n\n')
w('- 关卡列表 = `builtin_levels()` 的 return 数组顺序（**唯一权威顺序**），逐个解析对应 `static func _xxx()`\n')
w('- `tier` 常量 → 分级名；`layer` 常量 → 层名\n')
w('- 敌方卡 = `cards.json` 中 `class == "敌人"` 的卡（共 %d 张）\n' % len(enemy_cards))
w('- 「登场关卡」按各关 `enemy_units` 元组统计（**不含** `enemy_effects` 效果卡）\n\n')
w('⚠️ 若新增关卡，请同步：① `builtin_levels()` 挂载 ② §二分级分布 ③ §四关卡明细 ④ 基线测试\n')

open(os.path.join(ROOT, '关卡与敌人配置总览.md'), 'wb').write(out.getvalue().encode('utf-8'))
print('builtin:', len(builtin), 'L1:', len(l1), 'L2:', len(l2), 'L3:', len(l3))
print('enemy cards:', len(enemy_cards), 'unused:', len(unused))
print('order missing:', missing)
for t in range(5):
    c1 = len([x for x in l1 if x['tier'] == t])
    c2 = len([x for x in l2 if x['tier'] == t])
    print('  %s  L1=%d  L2=%d' % (TIER_NAMES[t], c1, c2))
