# -*- coding: utf-8 -*-
"""
组装素材候选池「只读」审计（R587 探查，2026-11-11）。

用法：python tools/audit_assemble_materials.py
产出：
  · 控制台摘要（已有候选 / 未入池 / 分层统计 / 保真判据漏洞）
  · _preview/r587_materials.html（可筛选的分层清单页）

⚠️ 本脚本不修改任何游戏文件；分层是人工判定的结论，卡片原文 / 职业 / 稀有度
   一律实时从 cards.json 读取，避免清单和卡面文案漂移。
"""
import io
import json
import os
import html
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS = os.path.join(ROOT, 'cards.json')
OUT = os.path.join(ROOT, '_preview', 'r587_materials.html')

# ── A 档：不新增动作即可入池（现成 25 个动作里有对应；但都有时机漂移，需店长确认） ──
TIER_A = {
    8004: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "heal", "value": 6}]}',
        action='heal(6)（已实现）',
        impl='_assemble_execute 的 heal 分支',
        fidelity='原文「回复 6 点生命」→ _fx_in_text 查「6 点生命」✓',
        risk='高：原卡是「主动发动」（场上手动，代替行动 + 横置 + 只能一次）；'
             '换成 use 会变成「打出即回 6 血」，横置与次数限制丢失。',
        note='唯一一句效果能完整兑现，但时机不是同一件事。'),
    9222: dict(
        upper='{"trigger": "damaged", "effects": []}',
        lower='{"effects": [{"type": "add_card", "card_id": 9145, "value": 1}]}',
        action='add_card(9145)（R584 已实现）',
        impl='_grant_to_hand / 忒修斯奇械段 game_engine.gd:13631~13652',
        fidelity='原文「将一张「聚能炮击」加入手卡」→ 卡名 +「加入手卡」✓',
        risk='高：原卡条件是「生命降到 0 或更低」，damaged（受伤后）宽得多，'
             '每次挨打都会白拿炮击；超负荷 / 次元两个常驻机制也会丢。',
        note='想收的话建议新增 trigger「hp_zero」而不是复用 damaged。'),
}

# ── B 档：新增 1 个动作即可完整兑现，实现口现成（推荐） ──
TIER_B = {
    8025: dict(
        upper='{"trigger": "upgraded", "effects": []}',
        lower='{"effects": [{"type": "bonus_hp_per_upgrade", "value": 1}]}',
        action='bonus_hp_per_upgrade(1) · 新增',
        impl='CardData.upgrade_hp_bonus + _upgrade_hp_gain()（game_engine.gd:6353）；素体自己就在用',
        fidelity='原文「被任何「改造」时，额外获得 +1 生命」→ 新增判据「额外获得 +%d 生命」',
        risk='低：整句单动作、实现口现成、钩子就是「每次被改造」。',
        note='机械之心（当前缺口职业）；「回合结束时不会被丢弃」是常驻词缀，按老虎口径不兑现。'),
    8034: dict(
        upper='{"trigger": "upgraded", "effects": []}',
        lower='{"effects": [{"type": "bonus_hp_per_upgrade", "value": 3}]}',
        action='bonus_hp_per_upgrade(3) · 与 8025 共用同一动作',
        impl='同上 _upgrade_hp_gain()；堡垒的 upgrade_hp_bonus 本来就是 3',
        fidelity='原文「每拥有一层改造，这张卡获得 +3 生命」→ 判据「获得 +%d 生命」',
        risk='低：与素体是同一动作、只差数值，正好符合 R569「每动作抽唯一实现口与母卡共用」。',
        note='两张一起做，白名单只加一条；机械之心 +2 张。'),
    9074: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "next_effect_discount", "value": 2}]}',
        action='next_effect_discount(2) · 新增',
        impl='state.self_next_effect_reduction + _sprite_effect_discount()（4737 / 7946）',
        fidelity='原文「你使用的下一张效果卡费用减少 2」→ 判据「下一张效果卡」+「费用减少 %d」',
        risk='低：整句单效果、状态位现成、跨回合保留的口径也已有实现。',
        note='森林精魄；与水元素 / 斑鸠同族，但三条状态位各自独立，别合并。'),
    9052: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "next_ally_discount", "value": 1}]}',
        action='next_ally_discount(1) · 新增',
        impl='state.self_next_ally_discount（4770 / 7989）+ TURTLE_DOVE_DISCOUNT',
        fidelity='原文「本回合使用下一个盟友时，费用 -1」→ 判据「下一个盟友」+「费用 -%d」',
        risk='中：原文没写「使用后」，钩子要按「打出后生效」理解；与 9074 别共用状态位。',
        note='森林精魄。'),
    9068: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "add_effect_from_deck", "value": 2}]}',
        action='add_effect_from_deck(2) · 新增',
        impl='水元素段 7909~7924 + _grant_to_hand(chosen, "水元素")',
        fidelity='原文「从卡组将一张效果卡加入手卡，费用减少 2」→ 判据「效果卡」+「费用减少 %d」',
        risk='中：要按老虎 9038 的放宽口径 —— 首句「场上每有一张效果卡，此卡费用 -1」'
             '属常驻费用句，不兑现，只兑现主句。',
        note='R570 曾因「只做半句」排除同类，老虎后来已入池，需店长确认口径是否沿用。'),
    8007: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "hand_skill_discount", "value": 1}]}',
        action='hand_skill_discount(1) · 新增',
        impl='_shadow_demon_enter()（8920）写 state.turn_card_discount',
        fidelity='原文「手卡中所有技能牌本回合费用 -1」→ 判据「技能牌」+「本回合费用 -%d」',
        risk='中：R570 注释明确把影魔排除（后半句是动态计数）；'
             '若按老虎放宽口径则可收，需店长点头。',
        note='暗影刺客；注意别和 draw_random_skill（赤狐）混成同一个动作。'),
    9046: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "add_lowest_cost_ally", "value": 1}]}',
        action='add_lowest_cost_ally(1) · 新增',
        impl='巨鼠段（game_engine.gd:11876~11883 / RAT_ID 739）',
        fidelity='原文「从抽牌库将一张费用最低的盟友加入手卡」→ 判据「费用最低的盟友」+「加入手卡」',
        risk='低：整句单效果，选牌是引擎自动落点，不需要玩家面板。',
        note='森林精魄。'),
    9039: dict(
        upper='{"trigger": "use", "effects": []}',
        lower='{"effects": [{"type": "raise_ally_from_discard", "value": 1}]}',
        action='raise_ally_from_discard(1) · 新增',
        impl='crow_options()（12072）+ 自动落点分支（4023）+ 乌鸦排除（12130）',
        fidelity='原文「选择弃牌堆中一张盟友回到手卡，乌鸦除外」→ 判据「弃牌堆」+「回到手卡」',
        risk='中：组合产物是自动结算，选牌要定「取哪张」的默认策略（建议沿用'
             ' crow_auto 那套），否则 AI 侧会卡住。',
        note='森林精魄；实现口最完整，但要先定自动落点口径。'),
}

# ── C 档：暂不建议（逐张给原因） ──
TIER_C = {
    8032: ('动态计数', '「每层改造 → 范围内敌人受伤 +1」是动态层数，单动作表达不了。'),
    8042: ('常驻被动', '接通代受伤害，凑不出一条可执行动作。'),
    8043: ('常驻被动', '接通共享改造，凑不出一条可执行动作。'),
    8046: ('复合句 / 钩子不符', '前半「力量增加等量数值」动态；后半加素体能兑现，但只做半句走形，'
                          '且钩子是「别的卡被破坏」，不在 TRIGGERS。'),
    8050: ('常驻被动', '超负荷负血存活，下半凑不出动作。'),
    8052: ('常驻被动', '嘲讽 + 超负荷，没有可执行下半。'),
    8055: ('常驻被动', '超负荷 + 嘲讽，没有可执行下半。'),
    8056: ('放置规则', '「交换」是放置规则不是效果，产物无法兑现。'),
    8058: ('常驻被动', '与犀牛 passive 同款减伤，但缺犀牛那句「每回合回血」，下半凑不出动作。'),
    8060: ('动态计数', '「每用过一张炮击 +3 生命」+「手卡炮击 0 费」两句，计数跨整场战斗。'),
    8072: ('动态计数', '「每层改造敌人 -1 力」+ 变形减费，两句都要状态位。'),
    8073: ('动态计数', '「每用过一张炮击 +1 力量」，需整场战斗计数。'),
    8074: ('复合句', '变形手卡 + 被随机变化出来时加数值，两句不同时机。'),
    8075: ('条件触发', '「每回合一次：你使用炮击时 +7 伤」不是现有 TRIGGERS。'),
    8080: ('变形', '「选场上单位变成随机机械单位」没有对应动作。'),
    9161: ('动态计数', '「每变化过一张牌随机释放一张技能」，计数 + 随机释放两层。'),
    9219: ('动态数值', '「等同负血量的伤害」，数值随局面变，damage 要写死 value。'),
    9220: ('条件触发', '「己方超负荷盟友死亡时放回一张此卡」，钩子不在 TRIGGERS。'),
    9221: ('复合句', '破坏单位 + 吸收属性，语义近 absorb_linked 但保真串对不上。'),
    9247: ('组合入口', '自己开组合页（combo_trigger=turn_start），当素材会递归。'),
    8006: ('条件句', '「本回合第 3 张」是条件，产物会丢条件只剩加卡。'),
    8008: ('复合句', '自毁 + 死亡加技能卡，只做半句走形。'),
    8009: ('动态计数', '「每使用一张卡 +1 力，攻击 / 离场重置」，需重置状态机。'),
    8010: ('token / 衍生物', '荧光草术生成，r5，不该进候选池。'),
    9204: ('跨战斗永久', '「本局永久 +1 力量」，产物挂在 Placement 上无法持久化。'),
    9228: ('条件被动', '「被标记的敌人伤害减半」，passive.reduce 只能表达固定减伤。'),
    9233: ('复合句 / 钩子不符', '费用永久 -1 + 击杀回满血，「击杀」不在 TRIGGERS。'),
    9031: ('机制', '「每回合可以行动两次」是行动次数，不是效果。'),
    9033: ('复合句', '返回手牌 + 变 1 费两句；产物死后回手可能循环。'),
    9044: ('token / 衍生物', '冰墙术生成的墙。'),
    9067: ('动态计数', '「每张效果卡 +1 力 +2 血，最多 5 次」，计数 + 上限。'),
    9075: ('动态计数', '「伤害技能每 1 点费用 +1 伤」，按费用动态换算。'),
    9080: ('token / 衍生物', '魔像术召唤，带次元。'),
    9082: ('动态计数 / 常驻', '「技能牌 -1 费」+「每次技能伤害此卡 -1 费」，两层。'),
    9206: ('跨战斗永久', '同赏金猎人，「本局永久」无法挂 Placement。'),
    9235: ('动态数值', '「3X 点伤害」X = 已用盟友数，damage 写死 value 会走形。'),
    9246: ('组合入口', '自己开组合页（combo_trigger=death），当素材会递归。'),
    8065: ('token / 委托', '被破坏时从卡组删除，是负债机制。'),
    9022: ('token / 衍生物', '生蛋鸭放置，回合结束变宠物鸭。'),
    9023: ('token / 衍生物', '上场需额外丢 4 张手牌。'),
    9072: ('token / 衍生物', '坚固围栏召唤的墙。'),
    9158: ('token / 衍生物', '死亡召唤「随机敌人」，summon 需要固定 card_id。'),
    9177: ('token / 衍生物', '鸭蛋孵出，代替承受 HP 伤害。'),
    9213: ('token / 关卡卡', 'X 费、落地记属性、只能跳跃行动，整套专属机制。'),
}

# 保真判据里「没有分支 → return true」的动作（R583 只补了 taunt）
ZERO_FIDELITY = ['damage', 'shield', 'freeze', 'summon', 'upgrade']

ACTION_COUNT = 25
POOL_MIN = 24


def esc(s):
    return html.escape(str(s), quote=True)


def load():
    raw = io.open(CARDS, 'rb').read().decode('utf-8')
    d = json.loads(raw)
    return d['cards'] if isinstance(d, dict) else d


def main():
    items = load()
    by_id = {c['id']: c for c in items}
    pooled = [c for c in items if 'upper_effect' in c and 'lower_effect' in c]
    pooled_ids = set(c['id'] for c in pooled)
    rest = [c for c in items
            if c.get('kind') in ('盟友', '工事')
            and c.get('group', 'player') == 'player'
            and c['id'] not in pooled_ids
            and c.get('effect_text', '').strip()]

    by_class = collections.Counter(c.get('class', '') or '(无职业)' for c in pooled)
    print('cards=%d  pooled=%d  unpooled=%d' % (len(items), len(pooled), len(rest)))
    print('pooled by class:', dict(by_class))
    print('tier A=%d  B=%d  C=%d  (sum=%d)' %
          (len(TIER_A), len(TIER_B), len(TIER_C), len(TIER_A) + len(TIER_B) + len(TIER_C)))

    rest_ids = set(c['id'] for c in rest)
    classified = set(TIER_A) | set(TIER_B) | set(TIER_C)
    assert classified == rest_ids, '分层未覆盖：%s / 多写了：%s' % (
        sorted(rest_ids - classified), sorted(classified - rest_ids))
    for cid in classified:
        assert cid in by_id, '分层里有不存在的卡 id %d' % cid
    assert len(ZERO_FIDELITY) == 5
    print('CLASSIFY OK (54/54)')

    # ── 生成 HTML ──
    def card_block(cid, tier):
        c = by_id[cid]
        info = TIER_A.get(cid) or TIER_B.get(cid) or {}
        cls = c.get('class', '') or '(无职业)'
        text = c.get('effect_text', '').replace('**', '')
        parts = []
        parts.append('<article class="card" data-tier="%s" data-text="%s">' % (
            tier, esc(' '.join([str(cid), c.get('name', ''), cls, text,
                                info.get('action', ''), info.get('impl', '')]))))
        parts.append('<div class="chead"><span class="cid">%d</span>'
                     '<span class="cname">%s</span>'
                     '<span class="meta">%s · %s · r%s</span></div>' %
                     (cid, esc(c.get('name', '')), esc(cls), esc(c.get('kind', '')),
                      esc(c.get('rarity', '?'))))
        parts.append('<div class="quote">%s</div>' % esc(text))
        if tier in ('A', 'B'):
            parts.append('<div class="kv"><span class="k">上半</span><code>%s</code></div>' % esc(info['upper']))
            parts.append('<div class="kv"><span class="k">下半</span><code>%s</code></div>' % esc(info['lower']))
            parts.append('<div class="kv"><span class="k">动作</span><span>%s</span></div>' % esc(info['action']))
            parts.append('<div class="kv"><span class="k">实现口</span><span>%s</span></div>' % esc(info['impl']))
            parts.append('<div class="kv"><span class="k">保真</span><span>%s</span></div>' % esc(info['fidelity']))
            parts.append('<div class="risk risk-%s"><b>风险 / 待确认</b>　%s</div>' %
                         ('hi' if info['risk'].startswith('高') else 'mid', esc(info['risk'])))
            parts.append('<div class="note">%s</div>' % esc(info['note']))
        parts.append('</article>')
        return '\n'.join(parts)

    a_html = '\n'.join(card_block(i, 'A') for i in sorted(TIER_A))
    b_html = '\n'.join(card_block(i, 'B') for i in sorted(TIER_B))

    groups = collections.defaultdict(list)
    for cid, (cat, why) in TIER_C.items():
        groups[cat].append((cid, why))
    c_html = []
    for cat in sorted(groups, key=lambda k: (-len(groups[k]), k)):
        rows = []
        for cid, why in sorted(groups[cat]):
            c = by_id[cid]
            rows.append('<li data-tier="C" data-text="%s"><span class="cid">%d</span>'
                        '<b>%s</b><span class="meta2">%s</span> — %s</li>' % (
                            esc(' '.join([str(cid), c.get('name', ''), cat, why])),
                            cid, esc(c.get('name', '')),
                            esc(c.get('class', '') or '(无职业)'), esc(why)))
        c_html.append('<section class="cgroup"><h3>%s <span>%d 张</span></h3><ul>%s</ul></section>' %
                      (esc(cat), len(rows), '\n'.join(rows)))
    c_html = '\n'.join(c_html)

    pooled_rows = []
    for c in sorted(pooled, key=lambda c: (c.get('class', ''), c['id'])):
        pooled_rows.append('<tr><td>%d</td><td>%s</td><td>%s</td><td>r%s</td><td><code>%s</code></td></tr>' % (
            c['id'], esc(c.get('name', '')), esc(c.get('class', '') or '(无职业)'),
            esc(c.get('rare', c.get('rarity', '?'))),
            esc(', '.join(str(fx.get('type', '')) for fx in c.get('lower_effect', {}).get('effects', [])))))
    pooled_html = '\n'.join(pooled_rows)

    body = []
    body.append('<header><h1>组装素材候选池 · 继续寻找</h1>'
                '<p class="sub">只读审计 · HEAD <code>8b7d243</code> · 2026-11-11 · '
                '口径依 R569 池形状 / R565 保真 / R570 整句兑现</p></header>')
    body.append('<div class="stats">'
                '<div><b>%d</b><span>全部卡牌</span></div>'
                '<div><b>%d</b><span>已入池</span></div>'
                '<div><b>%d</b><span>未入池（有文本）</span></div>'
                '<div class="hl"><b>%d</b><span>零新增可做</span></div>'
                '<div class="hl2"><b>%d</b><span>新增 1 动作可做</span></div>'
                '<div><b>%d</b><span>现有动作</span></div>'
                '<div class="warn"><b>%d</b><span>保真零校验动作</span></div>'
                '</div>' % (len(items), len(pooled), len(rest), len(TIER_A), len(TIER_B),
                            ACTION_COUNT, len(ZERO_FIDELITY)))
    body.append('<div class="clsbar">已入池分布：%s</div>' %
                esc(' · '.join('%s %d' % (k, v) for k, v in by_class.most_common())))
    body.append('<div class="toolbar"><button class="tab active" data-t="A">A · 零新增（%d）</button>'
                '<button class="tab" data-t="B">B · 新增 1 动作（%d）</button>'
                '<button class="tab" data-t="C">C · 暂不建议（%d）</button>'
                '<button class="tab" data-t="P">已入池（%d）</button>'
                '<button class="tab" data-t="F">判据漏洞</button>'
                '<input id="q" placeholder="搜 id / 名称 / 实现口 / 原因…"></div>' %
                (len(TIER_A), len(TIER_B), len(TIER_C), len(pooled)))
    body.append('<section class="pane active" data-p="A"><div class="lead">'
                '不新增动作就能挂进池，现成 25 个动作里已有对应、保真子串也能过；'
                '<b>但两张都把原卡时机换掉了</b>，先请店长定。<div class="cards">%s</div></section>' % a_html)
    body.append('<section class="pane" data-p="B"><div class="lead">'
                '推荐档：整句能用一个动作完整兑现，且引擎里已有唯一实现口可抽出来与母卡共用'
                '（R569 口径）。两张改造型共用一条动作，白名单实际只加 6 条。<div class="cards">%s</div></section>' % b_html)
    body.append('<section class="pane" data-p="C"><div class="lead">'
                '按 R570「只做半句就算走形」与 R569 池形状排除；逐张写了原因，'
                '以后口径放宽可以回来重评。%s</section>' % c_html)
    body.append('<section class="pane" data-p="P"><div class="lead">当前候选池全量（cards.json 里'
                '同时带 upper_effect / lower_effect 的卡）。<table><thead><tr><th>id</th><th>名称</th>'
                '<th>职业</th><th>稀有</th><th>下半动作</th></tr></thead><tbody>%s</tbody></table>'
                '</section>' % pooled_html)
    body.append('<section class="pane" data-p="F"><div class="lead">'
                '<h3>保真判据漏洞（本轮顺手查到）</h3>'
                '<p><code>test_assemble.gd::_fx_in_text()</code> 末尾是 <code>return true</code>；'
                'R583 补回了 <code>taunt</code>，但下面 5 个动作<b>至今没有分支</b>，'
                '意味着挂上它们时「原文有没有这句话」完全不校验 —— 自动匹配里 54 张全命中'
                '就是这么来的。</p><ul class="loose">%s</ul>'
                '<p>现有 28 张候选都没用这 5 个动作，所以补判据不会让回归变红；'
                '建议下一轮和 B 档一起补上。</p></section>' %
                '\n'.join('<li><code>%s</code></li>' % t for t in ZERO_FIDELITY))
    body.append('<footer>本页由 <code>tools/audit_assemble_materials.py</code> 生成，'
                '卡片原文实时读 cards.json；<b>本轮没有修改任何游戏文件</b>。</footer>')

    CSS = """
:root{--bg:#14161c;--panel:#1d2029;--panel2:#232733;--line:#333846;--fg:#e9e6dd;--dim:#9aa0ae;
--amber:#ffd89a;--blue:#8ec5ff;--red:#ff9e9e;--green:#a8dfbd;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.7 "Microsoft YaHei",system-ui,sans-serif}
header,.stats,.clsbar,.toolbar,.pane,footer{max-width:1180px;margin:0 auto;padding:0 22px}
header{padding-top:30px}h1{font-size:25px;margin:0 0 4px;color:var(--amber);letter-spacing:.5px}
.sub{margin:0 0 18px;color:var(--dim);font-size:12.5px}code{font-family:Consolas,monospace;
background:#0f1116;border:1px solid var(--line);border-radius:4px;padding:1px 5px;font-size:12px;color:var(--blue)}
.stats{display:flex;gap:10px;flex-wrap:wrap;padding-bottom:14px}
.stats>div{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:9px 15px;min-width:112px}
.stats b{display:block;font-size:21px;line-height:1.2;color:var(--fg)}
.stats span{font-size:11.5px;color:var(--dim)}
.stats .hl b{color:var(--amber)}.stats .hl2 b{color:var(--blue)}.stats .warn b{color:var(--red)}
.clsbar{color:var(--dim);font-size:12.5px;padding-bottom:14px}
.toolbar{display:flex;gap:8px;flex-wrap:wrap;align-items:center;padding-bottom:16px;
position:sticky;top:0;background:var(--bg);z-index:5;padding-top:10px;border-bottom:1px solid var(--line)}
.tab{background:var(--panel);color:var(--dim);border:1px solid var(--line);border-radius:8px;
padding:7px 13px;cursor:pointer;font-size:13px;font-family:inherit}
.tab:hover{color:var(--fg)}.tab.active{background:#333a4d;color:var(--amber);border-color:#5a6480}
#q{flex:1;min-width:220px;background:#0f1116;color:var(--fg);border:1px solid var(--line);
border-radius:8px;padding:8px 12px;font-family:inherit;font-size:13px}
.pane{display:none;padding-top:18px;padding-bottom:30px}.pane.active{display:block}
.lead{color:var(--dim);font-size:13px;margin-bottom:16px;max-width:900px}
.lead b{color:var(--fg)}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(430px,1fr));gap:14px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:15px 16px}
.chead{display:flex;align-items:baseline;gap:9px;flex-wrap:wrap;margin-bottom:9px}
.cid{font-family:Consolas,monospace;color:var(--amber);font-size:12.5px}
.cname{font-size:16px;font-weight:700;color:var(--fg)}
.meta,.meta2{color:var(--dim);font-size:11.5px}
.quote{background:#111319;border-left:3px solid #4a5970;border-radius:0 6px 6px 0;
padding:8px 11px;margin:0 0 11px;color:#cfd4df;font-size:12.5px}
.kv{display:flex;gap:8px;margin:5px 0;font-size:12.5px;align-items:flex-start}
.kv .k{flex:0 0 46px;color:var(--dim)}
.kv code{display:block;word-break:break-all}
.kv>span:last-child{flex:1}
.risk{border-radius:7px;padding:8px 11px;margin-top:10px;font-size:12.5px;line-height:1.6}
.risk-hi{background:#3a2024;color:#ffc9c9;border:1px solid #6a353b}
.risk-mid{background:#332a1b;color:var(--amber);border:1px solid #5c4a29}
.note{margin-top:9px;color:var(--dim);font-size:12px;font-style:italic}
.cgroup{margin-bottom:20px}.cgroup h3{font-size:14px;color:var(--blue);margin:0 0 7px}
.cgroup h3 span{color:var(--dim);font-size:11.5px;font-weight:400}
.cgroup ul{list-style:none;margin:0;padding:0;display:grid;
grid-template-columns:repeat(auto-fill,minmax(520px,1fr));gap:5px 18px}
.cgroup li{background:var(--panel2);border-radius:7px;padding:6px 10px;font-size:12.5px;color:#c7cbd6}
.cgroup li b{color:var(--fg);margin:0 7px}
table{border-collapse:collapse;width:100%;font-size:12.5px}
th,td{text-align:left;padding:6px 9px;border-bottom:1px solid var(--line)}
th{color:var(--dim);font-weight:500}
.loose li{display:inline-block;margin:0 14px 8px 0;font-size:13px}
footer{color:var(--dim);font-size:12px;padding:18px 22px 34px;border-top:1px solid var(--line)}
"""

    JS = """
var tabs=document.querySelectorAll('.tab'),panes=document.querySelectorAll('.pane'),q=document.getElementById('q');
function apply(){
 var t=document.querySelector('.tab.active').dataset.t,
     s=(q.value||'').trim().toLowerCase();
 panes.forEach(function(p){p.classList.toggle('active',p.dataset.p===t)});
 document.querySelectorAll('[data-text]').forEach(function(el){
   var ok=!s||el.dataset.text.toLowerCase().indexOf(s)>=0;
   el.style.display=ok?'':'none';
 });
}
tabs.forEach(function(b){b.addEventListener('click',function(){
 tabs.forEach(function(x){x.classList.remove('active')});b.classList.add('active');apply();});});
q.addEventListener('input',apply);apply();
"""

    TPL = """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>组装素材候选池 · 继续寻找</title><style>__CSS__</style></head>
<body>__BODY__<script>__JS__</script></body></html>"""
    out = TPL.replace('__CSS__', CSS).replace('__BODY__', '\n'.join(body)).replace('__JS__', JS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'wb') as f:
        f.write(out.encode('utf-8'))
    print('HTML', OUT, len(out.encode('utf-8')) // 1024, 'KB')
    print('ZERO FIDELITY TYPES:', ', '.join(ZERO_FIDELITY))


if __name__ == '__main__':
    main()
