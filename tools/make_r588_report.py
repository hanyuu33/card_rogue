# -*- coding: utf-8 -*-
"""R588 报告生成器：① 组合产物继承检查 ② 素材卡完整效果清单。

只读：读 cards.json / game_engine.gd / E:/tmp/probe_combo.json（由
tools/probe_combo_inherit.gd 产出），写 _preview/r588_combo_audit.html。
可重跑；不碰任何游戏脚本。
"""
import io, json, os, re

ROOT = r'E:/work/card_rogue'
OUT = os.path.join(ROOT, '_preview', 'r588_combo_audit.html')
PROBE = r'E:/tmp/probe_combo.json'


def load_cards():
    d = json.loads(io.open(os.path.join(ROOT, 'cards.json'), 'rb').read().decode('utf-8'))
    items = d['cards'] if isinstance(d, dict) else d
    return items


def engine_src():
    return io.open(os.path.join(ROOT, 'scripts', 'game_engine.gd'), 'rb').read().decode('utf-8')


def eff_traits(src):
    consts = dict(re.findall(r'const\s+([A-Z0-9_]+_TRAIT)\s*:?=\s*"([^"]+)"', src))
    lits = set(re.findall(r'traits\.has\("([^"]+)"\)', src))
    used = set(re.findall(r'traits\.has\(([A-Z0-9_]+_TRAIT)\)', src))
    return set(lits) | {consts[c] for c in used if c in consts}


ID_CONST = {}


def id_constants(src):
    """引擎里 `const XXX_ID := 8081` 且真的被 `== XXX_ID` 比较过的（只登记常量不算数）。"""
    for m in re.finditer(r'const\s+([A-Z0-9_]+_ID)\s*:?=\s*(\d+)', src):
        name, val = m.group(1), int(m.group(2))
        # 必须存在 `== / != XXX_ID` 这类比较用法（雪豹就是 `id != SNOW_LEOPARD_ID`）
        if re.search(r'[=!]=\s*' + name + r'\b', src) or re.search(r'\b' + name + r'\s*[=!]=', src):
            ID_CONST.setdefault(val, []).append(name)


# ────────────────────────────────── ② 素材卡完整效果（人工定案） ──────────────────────────────────

SHEETS = [
    {
        "id": 8004, "act": "heal(6)", "tier": "A",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "heal", "value": 6}]},
        "prod": "使用时：回复6点生命",
        "fidelity": "「回复 6 点生命」",
        "drift": "「之后横置」「在场只能发动一次」「代替行动」三条全部丢失 —— 产物可以每回合反复触发。"
                 "放置类（横置）在现有组合动作里没有对应口。",
        "impl": "引擎已有 heal（`_op_heal`），扳机走 `use`（原卡「主动发动」≈ 使用后）。零新动作。",
    },
    {
        "id": 9222, "act": "add_card(9145)", "tier": "A",
        "upper": {"trigger": "damaged", "effects": []},
        "lower": {"effects": [{"type": "add_card", "card_id": 9145, "value": 1}]},
        "prod": "受伤后：将1张「聚能炮击」加入你的手卡",
        "fidelity": "「将一张「聚能炮击」加入手卡」",
        "drift": "原卡是「生命降到 0 或更低」才给，换成 `damaged` 后**挨一下就给**，强度差一个量级；"
                 "「超负荷」「次元（离场消失）」两条也丢。",
        "impl": "引擎已有 add_card（R584 的 `_op_add_card`），零新动作；代价是触发面放大。",
    },
    {
        "id": 8025, "act": "bonus_hp_per_upgrade(1)", "tier": "B",
        "upper": {"trigger": "upgraded", "effects": []},
        "lower": {"effects": [{"type": "bonus_hp_per_upgrade", "value": 1}]},
        "prod": "每次被改造时：额外获得 +1 生命",
        "fidelity": "「被任何「改造」时，额外获得 +1 生命」",
        "drift": "「回合结束时不会被丢弃」（`留手` trait）不在动作里 —— 而这正是属性槽会被整份继承的那一条。",
        "impl": "新动作 `bonus_hp_per_upgrade`：改造结算时 `upgrade_hp_bonus += value`，"
                "与素体自己（`upgrade_hp_bonus = 1`）共用 `_upgrade_hp_gain()` 唯一口。",
    },
    {
        "id": 8034, "act": "bonus_hp_per_upgrade(3)", "tier": "B",
        "upper": {"trigger": "upgraded", "effects": []},
        "lower": {"effects": [{"type": "bonus_hp_per_upgrade", "value": 3}]},
        "prod": "每次被改造时：每拥有一层改造，获得 +3 生命",
        "fidelity": "「每拥有一层改造，这张卡获得 +3 生命」",
        "drift": "无（原文只有这一句）。与素体共用同一个动作，只是 value 不同。",
        "impl": "同 8025，共用 `bonus_hp_per_upgrade`。",
    },
    {
        "id": 9074, "act": "next_effect_discount(2)", "tier": "B",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "next_effect_discount", "value": 2}]},
        "prod": "使用时：你使用的下一张效果卡费用减少 2",
        "fidelity": "「你使用的下一张效果卡费用减少 2」",
        "drift": "无（原文只有这一句）。",
        "impl": "新动作读/写 `state.self_next_effect_reduction`（小精灵本体已在用的字段），"
                "结算口与 9074 本体同一处，只是改由产物写入。",
    },
    {
        "id": 9052, "act": "next_ally_discount(1)", "tier": "B",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "next_ally_discount", "value": 1}]},
        "prod": "使用时：本回合使用的下一个盟友费用 -1",
        "fidelity": "「本回合使用下一个盟友时，费用 -1」",
        "drift": "无（原文只有这一句）。",
        "impl": "新动作写 `state.self_next_ally_discount`（斑鸠本体已在用的字段）。",
    },
    {
        "id": 9068, "act": "add_effect_from_deck(2)", "tier": "B",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "add_effect_from_deck", "value": 2}]},
        "prod": "使用时：从卡组将 1 张效果卡加入手卡，费用减少 2",
        "fidelity": "「从卡组将一张效果卡加入手卡，费用减少 2」",
        "drift": "常驻句「自己场上每有一张效果卡，这张卡费用 -1」不兑现（同老虎 9038 的放宽口径）。",
        "impl": "新动作复用 9068 本体段（效果卡池 7909~7924 + `_grant_to_hand` 减费），"
                "抽 1 张、本回合 -value 费。",
    },
    {
        "id": 8007, "act": "hand_skill_discount(1)", "tier": "B",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "hand_skill_discount", "value": 1}]},
        "prod": "使用时：手卡中所有技能牌本回合费用 -1",
        "fidelity": "「打出时，手卡中所有技能牌本回合费用 -1」",
        "drift": "后半句「手卡每有一张费用为 0 的技能卡，这张卡获得 +3 生命」不兑现。"
                 "R570 注释曾明确把影魔排除在候选外，落地前需确认。",
        "impl": "新动作复用 `_shadow_demon_enter()` 里写 `turn_card_discount` 的那一段。",
    },
    {
        "id": 9046, "act": "add_lowest_cost_ally(1)", "tier": "B",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "add_lowest_cost_ally", "value": 1}]},
        "prod": "使用时：从抽牌库将 1 张费用最低的盟友加入手卡",
        "fidelity": "「从抽牌库将一张费用最低的盟友加入手卡」",
        "drift": "无（原文只有这一句）。",
        "impl": "新动作复用巨鼠本体段（11876~11883 的最低价盟友检索）。",
    },
    {
        "id": 9039, "act": "raise_ally_from_discard(1)", "tier": "B",
        "upper": {"trigger": "use", "effects": []},
        "lower": {"effects": [{"type": "raise_ally_from_discard", "value": 1}]},
        "prod": "使用时：选择弃牌堆中 1 张盟友回到手卡，乌鸦除外",
        "fidelity": "「选择弃牌堆中一张盟友回到手卡，乌鸦除外」",
        "drift": "原文是「**选择**」，组合产物没有选牌 UI → 必须定一条默认策略（建议：费用最高 / 最新进弃牌的）。",
        "impl": "新动作复用 `crow_options()` + 自动落点，排除乌鸦 9039 自身。",
    },
]

TRIGGER_LABEL = {"use": "使用时", "enter": "入场时", "death": "死亡时", "upgraded": "每次被改造时",
                 "turn_end": "回合结束时", "turn_start": "回合开始时", "attack": "攻击后",
                 "attacked": "被攻击时", "damaged": "受伤后"}


def esc(s):
    return (str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))


def build_rows(cards, eff, probe):
    byid = {c['id']: c for c in cards}
    prow = {r['id']: r for r in probe['rows']}
    out = []
    for cid in sorted(prow):
        c = byid[cid]
        r = prow[cid]
        kept = dict(r.get('kept', {}))
        tr = kept.pop('traits', [])
        live = [t for t in tr if t in eff]
        dead = [t for t in tr if t not in eff]
        idc = ID_CONST.get(cid, [])
        sev = 0
        if live or kept:
            sev = 2
        elif idc:
            sev = 1
        if not tr and not kept and not idc:
            sev = 0
        out.append({
            "id": cid, "name": c.get('name', ''), "cls": c.get('class', ''),
            "kind": c.get('kind', ''), "cost": c.get('cost', 0),
            "pw": "%d/%d" % (c.get('power', 0), c.get('health', 0)),
            "text": c.get('effect_text', '').replace('**', ''),
            "traits": tr, "live": live, "dead": dead,
            "extra": kept, "idc": idc,
            "shared": bool(r.get('traits_shared_ref')),
            "sev": sev,
        })
    return out


def load_behavior():
    """行为探针（tools/probe_combo_behavior.gd）的结果；缺失就返回空表。"""
    try:
        raw = io.open(r'E:/tmp/behav_raw.txt', encoding='utf-8', errors='replace').read()
    except OSError:
        return []
    m = re.search(r'BEHAVIOR_JSON_BEGIN\n(.*?)\nBEHAVIOR_JSON_END', raw, re.S)
    return json.loads(m.group(1)) if m else []


def main():
    cards = load_cards()
    src = engine_src()
    eff = eff_traits(src)
    id_constants(src)
    probe = json.loads(io.open(PROBE, encoding='utf-8').read())
    rows = build_rows(cards, eff, probe)

    n_live = sum(1 for r in rows if r['sev'] == 2)
    n_id = sum(1 for r in rows if r['idc'])
    n_shared = sum(1 for r in rows if r['shared'])

    # ── 行为实测卡片
    behavi = load_behavior()
    case_html = []
    for b in behavi:
        broken = b.get('damage_taken', 5) != 5 or b.get('heal_after_tick', 0) > 0
        case_html.append(
            '<div class="case %s"><div class="cn">%s <span class="cid mono">%d</span></div>'
            '<div class="cq">%s</div>'
            '<div class="cv">5 点伤害 → 实际吃 <b>%d</b>；回合收尾回血 <b>%d</b></div>%s</div>' % (
                'bad' if broken else 'ok',
                esc(b.get('name', '')), b.get('id', 0),
                esc(b.get('prod_text', '')),
                b.get('damage_taken', 0), b.get('heal_after_tick', 0),
                '<div class="cx">『卡面上一个字都没写这两条』</div>' if broken
                else '<div class="cx ok">干净：只有属性跟过来</div>'))

    # ── 页签 1 表格行
    tr_rows = []
    for r in sorted(rows, key=lambda x: (-x['sev'], x['id'])):
        if r['sev'] == 0:
            continue
        badges = []
        for t in r['live']:
            badges.append('<span class="b b-live">%s</span>' % esc(t))
        for t in r['dead']:
            badges.append('<span class="b b-dead">%s</span>' % esc(t))
        for k, v in r['extra'].items():
            badges.append('<span class="b b-extra">%s=%s</span>' % (esc(k), esc(json.dumps(v, ensure_ascii=False))))
        for name in r['idc']:
            badges.append('<span class="b b-id">id 命中 %s</span>' % esc(name))
        tr_rows.append(
            '<tr data-k="%s">'
            '<td class="mono">%d</td><td>%s</td><td class="dim">%s</td>'
            '<td class="mono">%d费 %s</td><td class="txt">%s</td><td>%s</td></tr>' % (
                esc(r['name'] + ' ' + str(r['id'])), r['id'], esc(r['name']), esc(r['cls']),
                r['cost'], esc(r['pw']), esc(r['text']), ' '.join(badges) or '<span class="dim">—</span>'))

    # ── 页签 2 卡面
    byid = {c['id']: c for c in cards}
    sheet_html = []
    for s in SHEETS:
        c = byid[s['id']]
        up = s['upper']
        lo = s['lower']
        up_txt = (TRIGGER_LABEL.get(up['trigger'], up['trigger']) + '：') if not up['effects'] else \
                 (TRIGGER_LABEL.get(up['trigger'], up['trigger']) + '：' + '，'.join(
                     a.get('text', '') for a in up['effects']))
        lo_txt = '，'.join(a.get('text', '') for a in lo['effects']) or '（空）'
        tier = 'A 档 · 零新动作' if s['tier'] == 'A' else 'B 档 · 新增 1 个动作'
        sheet_html.append('''
<article class="sheet" data-k="{key}">
  <header>
    <div class="sid mono">{cid}</div>
    <div class="sname">{name}</div>
    <div class="smeta">{cls} · {kind} · {cost} 费 · {pw} · 稀有度 {rar}</div>
    <div class="tier {tcls}">{tier}</div>
  </header>
  <div class="orig"><b>原卡完整效果</b><p>{otext}</p></div>
  <div class="split">
    <div class="half up"><b>上半（只做钩子）</b><p class="mono">{upjson}</p><p class="quote">{uptxt}</p></div>
    <div class="half lo"><b>下半（只做动作）</b><p class="mono">{lojson}</p><p class="quote">{lotxt}</p></div>
  </div>
  <div class="prod"><b>组合产物卡面文案</b><p class="pc">{prod}</p></div>
  <div class="notes">
    <p><span class="tag t-fid">保真</span>{fid}</p>
    <p><span class="tag t-drift">走形</span>{drift}</p>
    <p><span class="tag t-impl">实现</span>{impl}</p>
  </div>
</article>'''.replace('{key}', esc(c.get('name', '') + ' ' + str(s['id'])))
            .replace('{cid}', str(s['id']))
            .replace('{name}', esc(c.get('name', '')))
            .replace('{cls}', esc(c.get('class', '')))
            .replace('{kind}', esc(c.get('kind', '')))
            .replace('{cost}', str(c.get('cost', 0)))
            .replace('{pw}', '%d/%d' % (c.get('power', 0), c.get('health', 0)))
            .replace('{rar}', str(c.get('rarity', 0)))
            .replace('{tcls}', 'ta' if s['tier'] == 'A' else 'tb')
            .replace('{tier}', tier)
            .replace('{otext}', esc(c.get('effect_text', '')))
            .replace('{upjson}', esc(json.dumps(up, ensure_ascii=False)))
            .replace('{uptxt}', esc(up_txt))
            .replace('{lojson}', esc(json.dumps(lo, ensure_ascii=False)))
            .replace('{lotxt}', esc(lo_txt))
            .replace('{prod}', esc(s['prod']))
            .replace('{fid}', esc(s['fidelity']))
            .replace('{drift}', esc(s['drift']))
            .replace('{impl}', esc(s['impl'])))

    CSS = """
:root{--bg:#15161a;--panel:#1d1f25;--line:#2f323b;--ink:#e8e9ee;--dim:#959aa6;
--gold:#ffd89a;--blue:#7fc4ff;--red:#ff8a7a;--green:#8ee0a8;--purple:#c9a6ff;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.65 "Microsoft YaHei","PingFang SC",system-ui,sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:28px 22px 70px}
h1{font-size:22px;margin:0 0 6px}
.sub{color:var(--dim);font-size:13px;margin-bottom:18px}
.verdict{border:1px solid #5a4130;background:linear-gradient(180deg,#2a2320,#211d1b);border-radius:10px;padding:14px 16px;margin-bottom:18px}
.verdict b{color:var(--gold)}
.verdict .big{font-size:16px}
.tabs{display:flex;gap:8px;margin:18px 0 14px;flex-wrap:wrap}
.tab{padding:7px 14px;border:1px solid var(--line);border-radius:999px;cursor:pointer;color:var(--dim);font-size:13px;user-select:none}
.tab.on{background:var(--panel);color:var(--ink);border-color:#4a4f5c}
input.search{width:100%;padding:9px 12px;border-radius:8px;border:1px solid var(--line);background:#101116;color:var(--ink);margin-bottom:12px;font-size:13px}
table{width:100%;border-collapse:collapse;font-size:12.5px}
th,td{text-align:left;padding:8px 9px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--dim);font-weight:600;font-size:12px;position:sticky;top:0;background:var(--bg)}
td.txt{color:#c6c9d2;max-width:300px}
td.dim,.dim{color:var(--dim)}
.mono{font-family:ui-monospace,Consolas,monospace;font-size:12px}
.b{display:inline-block;padding:1px 7px;border-radius:6px;margin:2px 3px 2px 0;font-size:11.5px;border:1px solid}
.b-live{color:var(--red);border-color:#5d3a34;background:#2a1d1b}
.b-dead{color:var(--dim);border-color:#3a3d46;background:#1b1d22}
.b-extra{color:var(--gold);border-color:#5a4a2c;background:#241f16}
.b-id{color:var(--purple);border-color:#463a5c;background:#221d2b}
.sheet{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px 18px;margin-bottom:16px}
.sheet header{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;padding-bottom:10px;border-bottom:1px solid var(--line);margin-bottom:12px}
.sid{color:var(--dim)}
.sname{font-size:17px;font-weight:700}
.smeta{color:var(--dim);font-size:12.5px}
.tier{margin-left:auto;font-size:12px;padding:3px 10px;border-radius:999px;border:1px solid}
.tier.ta{color:var(--green);border-color:#2f5540;background:#17251d}
.tier.tb{color:var(--blue);border-color:#2c4460;background:#16202b}
.orig p{margin:4px 0 10px;color:#d5d8e0}
.split{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.half{border:1px solid var(--line);border-radius:9px;padding:10px 12px;background:#17181d}
.half b{font-size:12.5px;color:var(--dim);font-weight:600}
.half .mono{color:#a9d8ff;margin:6px 0;word-break:break-all}
.half .quote{color:var(--gold);margin:0;font-size:13px}
.prod{margin:12px 0 8px;border-left:3px solid var(--gold);padding:6px 0 6px 12px}
.prod b{font-size:12.5px;color:var(--dim);font-weight:600}
.prod .pc{margin:4px 0 0;font-size:15px;color:#fff3dc;font-weight:600}
.notes p{margin:6px 0;font-size:13px;color:#c6c9d2}
.tag{display:inline-block;min-width:44px;text-align:center;font-size:11.5px;padding:1px 8px;border-radius:6px;margin-right:8px;border:1px solid}
.t-fid{color:var(--green);border-color:#2f5540}
.t-drift{color:var(--red);border-color:#5d3a34}
.t-impl{color:var(--blue);border-color:#2c4460}
.pane{display:none}.pane.on{display:block}
h2{font-size:15px;margin:22px 0 8px}
ul.tight{margin:6px 0 0;padding-left:20px;color:#c6c9d2}
ul.tight li{margin:4px 0}
code{background:#101116;border:1px solid var(--line);border-radius:5px;padding:1px 5px;font-size:12px;color:#a9d8ff}
.cases{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:10px 0 6px}
.case{border:1px solid var(--line);border-radius:9px;padding:10px 12px;background:#17181d}
.case.bad{border-color:#5d3a34;background:#20191a}
.case.ok{border-color:#2f5540;background:#16201a}
.case .cn{font-weight:700;font-size:14px}
.case .cid{color:var(--dim);font-weight:400}
.case .cq{margin:6px 0;font-size:12.5px;color:var(--gold)}
.case .cv{font-size:13px}
.case .cv b{color:var(--red)}
.case.ok .cv b{color:var(--green)}
.case .cx{margin-top:6px;font-size:12px;color:var(--red)}
.case .cx.ok{color:var(--green)}
.small{font-size:12.5px;color:var(--dim)}
"""

    JS = """
function go(i){document.querySelectorAll('.tab').forEach(function(t,k){t.classList.toggle('on',k===i)});
document.querySelectorAll('.pane').forEach(function(p,k){p.classList.toggle('on',k===i)});}
function filt(inp,sel){var q=inp.value.trim().toLowerCase();
document.querySelectorAll(sel).forEach(function(el){
var k=(el.getAttribute('data-k')||'').toLowerCase();
el.style.display=(q===''||k.indexOf(q)>=0)?'':'none';});}
"""

    BODY = """
<div class="wrap">
<h1>R588 · 组合产物继承检查 ＋ 素材卡完整效果</h1>
<div class="sub">只读审计 · HEAD <span class="mono">8b7d243</span> · 池内 28 张 · 探针 <span class="mono">tools/probe_combo_inherit.gd</span></div>

<div class="verdict">
<p class="big"><b>结论：还会发生。</b>属性槽（第①张）的效果会被整份带进产物 —— 不只是 traits，连 <b>id</b> 都被复制过去了。</p>
<p class="small">根因在 <code>AssembleRules.build()</code>：它以属性槽那张卡为模板
<code>CardData.from_dict(base.to_dict())</code> 整份克隆，之后只覆盖了 <code>effect_text</code> 与 <code>assemble</code> 两个字段。
于是 traits / id / 场地数值 / 击杀成长 / 改造加成 / 附魔 全部跟过来；
引擎里那 4 处 <code>assemble.is_empty()</code> 守卫只能挡住个别卡。</p>
<p class="small">实测：<b>__NLIVE__ / 28</b> 张属性槽卡会把「引擎里有判定的 trait」带进产物；
<b>__NID__ / 28</b> 张的属性槽 id 在引擎里被 <code>== XXX_ID</code> / <code>!= XXX_ID</code> 直接写死判定；
<b>__NSHARED__ / 28</b> 张的产物与卡库<b>共用同一个 traits 数组</b>（<code>is_same == true</code>，往产物 traits 里 append 会污染卡库）。</p>
<p class="small">最直白的一例：犀牛 9016 当属性槽，产物卡面只印「回合结束时：剩余费用换力量 / 生命」，
<b>实际吃 5 点伤只掉 4 点、每回合还回 2 点血</b>；换成火元素 9236 当属性槽就干净。详见下方实测区。</p>
</div>

<div class="tabs">
  <div class="tab on" onclick="go(0)">① 继承检查（__NROWS__ 张）</div>
  <div class="tab" onclick="go(1)">② 素材卡完整效果（10 张）</div>
  <div class="tab" onclick="go(2)">③ 修复方案</div>
</div>

<div class="pane on">
  <h2>实测：让产物上阵，看引擎认不认</h2>
  <p class="small">直接 new 一个 <code>FieldState + GameEngine</code>，把产物放进 board，调受击唯一口
  <code>_unit_damage_taken(p, 5)</code> 与回合收尾 <code>_regen_tick()</code>。四张属性槽卡的产物卡面文案<b>完全一样</b>，
  行为却分两组：</p>
  <div class="cases">__CASES__</div>
  <p class="small">探针 <code>tools/probe_combo_behavior.gd</code>（不读存档、不建场景）。</p>

  <h2>全池 28 张的属性槽继承情况</h2>
  <input class="search" placeholder="搜卡名 / id …" oninput="filt(this,'#t1 tbody tr')">
  <table id="t1"><thead><tr><th>id</th><th>卡名</th><th>职业</th><th>费用/攻血</th><th>原卡效果</th><th>产物会继承的东西</th></tr></thead>
  <tbody>__ROWS__</tbody></table>
  <p class="small">红 = 引擎里有判定、会真生效；灰 = 引擎里没搜到按该字面量判定的分支（多为分类标签）；
  金 = 非 trait 的数值/附魔字段；紫 = 该 id 在引擎里被常量写死判定（id 也被复制，所以一样命中）。
  按「会真生效 → 只有 id 命中 → 干净」排序，干净的 2 张（厄运的使者 9232 / 火元素 9236）没列出来。</p>
</div>

<div class="pane">
  <input class="search" placeholder="搜卡名 / id …" oninput="filt(this,'#t2 .sheet')">
  <div id="t2">__SHEETS__</div>
  <p class="small">「组合产物卡面文案」是按现有 <code>AssembleRules.assembled_text()</code> 的拼法算的
  （扳机 + 冒号 + 上半 + 下半），新动作的文案串就是落地时写进 <code>effect_text()</code> 的那一串。
  下文 JSON 即 cards.json 里要挂的 <code>upper_effect</code> / <code>lower_effect</code> 全文。</p>
</div>

<div class="pane">
  <h2>为什么只有个别卡没事</h2>
  <p class="small">引擎里已经有 4 处「组合产物」守卫 —— 说明这个坑以前被局部踩过、只是没统一：</p>
  <ul class="tight">
    <li><code>5433 / 6506</code> 集束炮台：<code>if ... and p.card.assemble.is_empty()</code> —— 产物不再触发「改造捞炮击」。</li>
    <li><code>12246</code> 组合永续减伤：读 <code>assemble.passive.reduce</code>，并靠 build 把承载体那条 <code>reduce</code> 清零防叠算。</li>
    <li><code>18018</code> 组合效果入口：<code>assemble</code> 为空才走卡本体扳机。</li>
  </ul>

  <h2>三档修法（按「保留多少母卡个性」排序）</h2>
  <ul class="tight">
    <li><b>① 只留数值（最干净）</b>：build 后清空 id / traits / trigger / 场地数值 / 击杀成长 / 改造加成 / 附魔 / combo_trigger，
        并把 id 换成 0 或专用 id。产物 = 纯属性 + 上下半效果。<b>代价</b>：R568「承载体是犀牛就减 1 伤」这条会失效，
        需要把犀牛的永续段改成无条件写入 <code>assemble.passive.reduce = 1</code>（不再靠 trait），回归里已有对应断言可改。</li>
    <li><b>② 保留「属性型」trait，清掉「效果型」</b>：维护一张白名单（机械 / 工事 / 野兽 / 事件 …）只留分类，
        其余 traits 与 id / 数值字段全清。<b>代价</b>：白名单要随新卡维护，且「嘲讽」这类半属性半效果的还得逐个定。</li>
    <li><b>③ 只清 id 与触发型字段</b>：保留 traits（当前设计），只把 id 归零、<code>combo_trigger</code> 清空、
        场地/成长/改造字段归零。<b>代价</b>：玩家仍然会看到「产物莫名其妙回 2 血」，只是不会再套娃。</li>
  </ul>
  <p class="small">我倾向 <b>①</b>：组合卡的卖点就是「属性 + 你挑的两段效果」，母卡自带效果跟过来等于白拿。
  但这条路会动到 R568 的既有断言，得您点头。</p>

  <h2>顺带说清「属性槽」与「提供属性的卡」</h2>
  <p class="small">UI 里第①槽叫「属性」，它提供的是费用 / 力量 / 生命 / 射程 / 移速 / 职业 / 卡面 —— 这些<b>该</b>继承。
  不该继承的是它的效果面：traits、id 写死的分支、场地光环、击杀成长、改造加成、附魔、再组合钩子。
  现在这两类东西在同一个 <code>to_dict()</code> 里，分不开。</p>
</div>
</div>
<script>__JS__</script>
"""

    body = (BODY.replace('__NLIVE__', str(n_live))
                .replace('__NID__', str(n_id))
                .replace('__NSHARED__', str(n_shared))
                .replace('__NROWS__', str(sum(1 for r in rows if r['sev'] > 0)))
                .replace('__ROWS__', '\n'.join(tr_rows))
                .replace('__CASES__', '\n'.join(case_html))
                .replace('__SHEETS__', '\n'.join(sheet_html))
                .replace('__JS__', JS))

    html = ('<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>R588 · 组合继承检查 & 素材完整效果</title><style>'
            + CSS + '</style></head><body>' + body + '</body></html>')

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, 'w', encoding='utf-8').write(html)
    print('HTML', OUT, os.path.getsize(OUT) // 1024, 'KB')
    print('rows', len(rows), 'sev2', n_live, 'id_hit', n_id, 'shared', n_shared)
    # 自检：没有未替换的占位符
    for ph in ('__ROWS__', '__SHEETS__', '__CSS__', '__BODY__', '__JS__', '{', 'None'):
        if ph in ('{',):
            continue
        assert ph not in html, 'placeholder left: ' + ph
    print('PLACEHOLDER OK')


main()
