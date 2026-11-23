# -*- coding: utf-8 -*-
"""
组合（Combine）素材候选池「只读」审计（R772 探查，2026-11-16）。

把当前 cards.json 里「还没做成组合素材」的盟友/工事卡全部捞出来，按切分难度分三档：
  · pick  推荐优先切：整句/主句能用现成动作（或只加 1 个动作）兑现
  · maybe 可切但有坑：切了会丢一部分语义，需店长拍板
  · skip  不建议切：token/常驻被动/动态计数/组合入口/放置规则/纯词缀/跨战斗永久

⚠️ 本脚本不修改任何游戏文件。切分方案由店长定，这里的 tier/reason 只是
   基于引擎动作白名单（CardData.ASSEMBLE_EFFECT_TYPES，36 个）与扳机白名单
   （AssembleRules.TRIGGERS，16 个）的初判，不是最终决定。

用法：python tools/audit_combine_candidates.py
产出：_preview/combine_candidates.html
"""
import io
import json
import os
import html

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS = os.path.join(ROOT, 'cards.json')
OUT = os.path.join(ROOT, '_preview', 'combine_candidates.html')

# ── 切分难度初判（id -> (tier, reason)）──
TIER = {
    # pick：推荐优先切（4 张）
    8025: ('pick', 'upgraded 扳机 +「被改造时额外 +1 生命」；需新增 bonus_hp_per_upgrade 动作，实现口 _upgrade_hp_gain 现成（素体自己就在用）。'),
    8034: ('pick', 'upgraded 扳机 +「每层改造 +3 生命」；与 8025 同动作、值=3。注意「每层」是静态计数、素体「每次改造」是扳机，切分口径需店长定。'),
    9250: ('pick', 'use 扳机 +「召唤 2 只小鸭」；summon 动作现成（value=9251, count=2）。「两边各召唤」是位置限定，落点需店长确认。'),
    9251: ('pick', 'enter 扳机 +「随机效果卡 -1 费」；hand_discount 语义略宽（任意手牌），需放宽或新增 hand_effect_discount。'),
    # maybe：可切但有坑（2 张）
    8006: ('maybe', 'use +「从卡组加随机技能卡」可用 draw_random_skill；但「本回合第 3 张」条件会丢，只剩加卡。'),
    8008: ('maybe', 'death +「从卡组加随机技能卡」可用 draw_random_skill；但「自己回合开始自毁」是母卡自身机制，切出变纯亡语。'),
    # skip：不建议切（38 张）
    8065: ('skip', 'token/委托：替承伤 + 交付后从卡组删除，是负债机制。'),
    9022: ('skip', 'token：回合开始变宠物鸭。'),
    9023: ('skip', '放置代价：上场丢 4 张手牌是代价，不是效果。'),
    9072: ('skip', '常驻承伤，无动作。'),
    9177: ('skip', '常驻承伤，无动作。'),
    9213: ('skip', '专属机制：X 费落地记属性 + 跳跃行动。'),
    8009: ('skip', '动态计数 + 重置（card_played 黑名单）。'),
    8010: ('skip', '常驻 aura（技能伤害 +1）。'),
    9204: ('skip', '跨战斗永久 + 击杀（kill 黑名单）。'),
    9228: ('skip', '条件被动（减半），passive.reduce 只支持固定值。'),
    9233: ('skip', '跨战斗永久 + 击杀。'),
    8032: ('skip', '动态计数（每层改造敌人受伤 +1）。'),
    8042: ('skip', '常驻被动（接通代受伤害）。'),
    8043: ('skip', '常驻被动（接通共享改造）。'),
    8046: ('skip', '复合句 + 钩子不符（别的卡被破坏，不在 TRIGGERS）。'),
    8050: ('skip', '纯词缀（超负荷）。'),
    8052: ('skip', '纯词缀（嘲讽 + 超负荷）。'),
    8055: ('skip', '纯词缀（超负荷 + 嘲讽）。'),
    8058: ('skip', '动态计数减伤（每层改造减 1，passive.reduce 是固定值）。'),
    8060: ('skip', '动态计数（跨战斗炮击计数 + 本回合 0 费）。'),
    8072: ('skip', '动态计数（每层改造敌人 -1 力）+ 变形减费。'),
    8073: ('skip', '动态计数（跨战斗炮击计数 +1 力）。'),
    8074: ('skip', '复合句（变形手卡 + 随机变化加数值）。'),
    8075: ('skip', '条件触发（每回合一次 + 特定卡）。'),
    8080: ('skip', '变形（选单位变随机机械）。'),
    9161: ('skip', '动态计数 + 随机释放。'),
    9219: ('skip', '动态数值（等同负血量伤害）。'),
    9220: ('skip', '条件触发（钩子不在 TRIGGERS）。'),
    9221: ('skip', '复合句（破坏 + 吸收，保真串对不上 absorb_linked）。'),
    9247: ('skip', '组合入口（turn_start 开组合页，当素材会递归）。'),
    9033: ('skip', '复合句（返回手牌 + 变 1 费，可能循环）。'),
    9044: ('skip', 'token（冰墙术生成）。'),
    9067: ('skip', '承伤常驻 + 动态计数（每张效果卡最多 5 次）。'),
    9075: ('skip', '常驻 aura（伤害技能按费用换算）。'),
    9082: ('skip', '两层（常驻减费 + 动态计数）。'),
    9206: ('skip', '跨战斗永久 + 击杀。'),
    9235: ('skip', '动态数值（3X 伤害）+ 减费常驻。'),
    9246: ('skip', '组合入口（death 开组合页，递归）。'),
}

TIER_LABEL = {'pick': '推荐优先切', 'maybe': '可切但有坑', 'skip': '不建议切'}


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

    # 校验 TIER 覆盖全部 rest，且没写多余 id
    rest_ids = set(c['id'] for c in rest)
    tier_ids = set(TIER)
    assert rest_ids == tier_ids, 'TIER 未覆盖：%s / 多写：%s' % (
        sorted(rest_ids - tier_ids), sorted(tier_ids - rest_ids))

    by_tier = {'pick': [], 'maybe': [], 'skip': []}
    for c in rest:
        tier, _ = TIER[c['id']]
        by_tier[tier].append(c)

    def card_block(c):
        cid = c['id']
        tier, reason = TIER[cid]
        cls = c.get('class', '') or '(无职业)'
        text = c.get('effect_text', '').replace('**', '').strip()
        label = TIER_LABEL[tier]
        return ('<article class="card t-%s" data-text="%s">'
                '<div class="chead"><span class="cid">%d</span><span class="cname">%s</span>'
                '<span class="meta">%s · %s · r%s</span><span class="tag">%s</span></div>'
                '<div class="quote">%s</div>'
                '<div class="why">%s</div></article>') % (
                    tier,
                    esc(' '.join([str(cid), c.get('name', ''), cls, text, reason])),
                    cid, esc(c.get('name', '')), esc(cls), esc(c.get('kind', '')),
                    esc(c.get('rarity', '?')), label, esc(text), esc(reason))

    groups = {}
    for tier in ('pick', 'maybe', 'skip'):
        groups[tier] = '\n'.join(card_block(c) for c in sorted(by_tier[tier], key=lambda c: c['id']))

    pooled_rows = []
    for c in sorted(pooled, key=lambda c: (c.get('class', ''), c['id'])):
        upper = c.get('upper_effect', {})
        lower = c.get('lower_effect', {})
        trig = upper.get('trigger', '')
        lt = ', '.join(str(fx.get('type', '')) for fx in lower.get('effects', []))
        pooled_rows.append('<tr><td>%d</td><td>%s</td><td>%s</td><td>r%s</td>'
                           '<td><code>%s</code></td><td><code>%s</code></td></tr>' % (
                               c['id'], esc(c.get('name', '')), esc(c.get('class', '') or '(无职业)'),
                               esc(c.get('rarity', '?')), esc(trig), esc(lt)))
    pooled_html = '\n'.join(pooled_rows)

    body = []
    body.append('<header><h1>组合素材候选池 · 未入池 %d 张</h1>'
                '<p class="sub">只读审计 · 实时读 cards.json · 口径对齐引擎动作白名单（36）+ 扳机白名单（16）· '
                '切分方案由店长定，本页 tier 只是初判</p></header>' % len(rest))
    body.append('<div class="stats">'
                '<div><b>%d</b><span>全部卡牌</span></div>'
                '<div><b>%d</b><span>已入池素材</span></div>'
                '<div><b>%d</b><span>未入池候选</span></div>'
                '<div class="hl"><b>%d</b><span>推荐优先切</span></div>'
                '<div class="hl2"><b>%d</b><span>可切但有坑</span></div>'
                '<div><b>%d</b><span>不建议切</span></div></div>' % (
                    len(items), len(pooled), len(rest),
                    len(by_tier['pick']), len(by_tier['maybe']), len(by_tier['skip'])))
    body.append('<div class="toolbar">'
                '<button class="tab active" data-t="all">全部（%d）</button>'
                '<button class="tab" data-t="pick">推荐优先（%d）</button>'
                '<button class="tab" data-t="maybe">可切有坑（%d）</button>'
                '<button class="tab" data-t="skip">不建议（%d）</button>'
                '<button class="tab" data-t="pooled">已入池（%d）</button>'
                '<input id="q" placeholder="搜 id / 名称 / 职业 / 效果文本…"></div>' % (
                    len(rest), len(by_tier['pick']), len(by_tier['maybe']), len(by_tier['skip']), len(pooled)))
    body.append('<section class="pane active" data-p="all"><div class="lead">'
                '全部未入池候选，按 id 排序。绿色=推荐优先、黄色=可切有坑、灰色=不建议。</div>'
                '<div class="cards">%s%s%s</div></section>' % (
                    groups['pick'], groups['maybe'], groups['skip']))
    body.append('<section class="pane" data-p="pick"><div class="lead">'
                '整句/主句能用现成动作兑现（或只加 1 个动作）。建议优先做这批。</div>'
                '<div class="cards">%s</div></section>' % groups['pick'])
    body.append('<section class="pane" data-p="maybe"><div class="lead">'
                '可切，但切了会丢一部分语义（条件/自毁）。要不要收请店长拍板。</div>'
                '<div class="cards">%s</div></section>' % groups['maybe'])
    body.append('<section class="pane" data-p="skip"><div class="lead">'
                '按现有动作/扳机白名单凑不出一条可执行素材；以后口径放宽可回来重评。</div>'
                '<div class="cards">%s</div></section>' % groups['skip'])
    body.append('<section class="pane" data-p="pooled"><div class="lead">'
                '已入池 %d 张（cards.json 里同时带 upper_effect / lower_effect 的卡），供对照，避免重复切。</div>'
                '<table><thead><tr><th>id</th><th>名称</th><th>职业</th><th>稀有</th>'
                '<th>上半扳机</th><th>下半动作</th></tr></thead><tbody>%s</tbody></table></section>' % (
                    len(pooled), pooled_html))
    body.append('<footer>本页由 <code>tools/audit_combine_candidates.py</code> 生成；'
                '卡片原文实时读 cards.json；<b>本轮没有修改任何游戏文件</b>。</footer>')

    CSS = """
:root{--bg:#14161c;--panel:#1d2029;--panel2:#232733;--line:#333846;--fg:#e9e6dd;--dim:#9aa0ae;
--amber:#ffd89a;--blue:#8ec5ff;--red:#ff9e9e;--green:#a8dfbd;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.7 "Microsoft YaHei",system-ui,sans-serif}
header,.stats,.toolbar,.pane,footer{max-width:1180px;margin:0 auto;padding:0 22px}
header{padding-top:30px}h1{font-size:25px;margin:0 0 4px;color:var(--amber);letter-spacing:.5px}
.sub{margin:0 0 18px;color:var(--dim);font-size:12.5px}code{font-family:Consolas,monospace;
background:#0f1116;border:1px solid var(--line);border-radius:4px;padding:1px 5px;font-size:12px;color:var(--blue)}
.stats{display:flex;gap:10px;flex-wrap:wrap;padding-bottom:14px}
.stats>div{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:9px 15px;min-width:110px}
.stats b{display:block;font-size:21px;line-height:1.2;color:var(--fg)}
.stats span{font-size:11.5px;color:var(--dim)}
.stats .hl b{color:var(--green)}.stats .hl2 b{color:var(--amber)}
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
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:15px 16px;border-left:4px solid #4a5970}
.card.t-pick{border-left-color:#3f8f5f}.card.t-maybe{border-left-color:#b98a3d}.card.t-skip{border-left-color:#3a3f4d}
.chead{display:flex;align-items:baseline;gap:9px;flex-wrap:wrap;margin-bottom:9px}
.cid{font-family:Consolas,monospace;color:var(--amber);font-size:12.5px}
.cname{font-size:16px;font-weight:700;color:var(--fg)}
.meta{color:var(--dim);font-size:11.5px}
.tag{margin-left:auto;font-size:11.5px;border-radius:6px;padding:2px 8px}
.t-pick .tag{background:#1f3a2b;color:var(--green);border:1px solid #3f8f5f}
.t-maybe .tag{background:#332a1b;color:var(--amber);border:1px solid #5c4a29}
.t-skip .tag{background:#262a33;color:var(--dim);border:1px solid #3a3f4d}
.quote{background:#111319;border-left:3px solid #4a5970;border-radius:0 6px 6px 0;
padding:8px 11px;margin:0 0 9px;color:#cfd4df;font-size:12.5px}
.why{margin:0;color:var(--dim);font-size:12px;line-height:1.55}
table{border-collapse:collapse;width:100%;font-size:12.5px}
th,td{text-align:left;padding:6px 9px;border-bottom:1px solid var(--line)}
th{color:var(--dim);font-weight:500}
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
<title>组合素材候选池 · 未入池</title><style>__CSS__</style></head>
<body>__BODY__<script>__JS__</script></body></html>"""
    out = TPL.replace('__CSS__', CSS).replace('__BODY__', '\n'.join(body)).replace('__JS__', JS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'wb') as f:
        f.write(out.encode('utf-8'))
    print('cards=%d pooled=%d rest=%d' % (len(items), len(pooled), len(rest)))
    print('pick=%d maybe=%d skip=%d' % (len(by_tier['pick']), len(by_tier['maybe']), len(by_tier['skip'])))
    print('HTML', OUT, len(out.encode('utf-8')) // 1024, 'KB')


if __name__ == '__main__':
    main()
