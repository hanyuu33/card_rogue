# -*- coding: utf-8 -*-
# R828 引擎补丁（game_engine.gd，CRLF）：
#   音乐盒 2→3 种、La 抽3→4/力量+3→+2、新增「这是礼帽」6087 亡语机制
import io

P = 'scripts/game_engine.gd'
NL = '\r\n'   # game_engine.gd 是 CRLF

def rep(old, new):
    raw = io.open(P, 'r', encoding='utf-8', newline='').read()
    n = raw.count(old)
    assert n == 1, '锚点 count=%d: %r' % (n, old[:80])
    raw = raw.replace(old, new)
    io.open(P, 'w', encoding='utf-8', newline='').write(raw)
    print('OK  ' + old[:60].replace(NL, '\\n'))

# ── 1. 音乐盒 2→3 种 ──
rep('const MUSIC_BOX_DRAW:= 2', 'const MUSIC_BOX_DRAW:= 3')

# ── 2. La 抽3→4 / 力量+3→+2 ──
rep('const NOTE_LA_DRAW:= 3', 'const NOTE_LA_DRAW:= 4')
rep('const NOTE_LA_POWER:= 3', 'const NOTE_LA_POWER:= 2')

# ── 3. 新增礼帽常量 ──
rep('const NOTE_SI_TIMES:= 7' + NL + 'const ICECREAM_RELIC_ID:= 6016',
    'const NOTE_SI_TIMES:= 7' + NL
    + 'const TOP_HAT_RELIC_ID:= 6087   # R828「这是礼帽」（二层鸭绅士）：己方盟友/工事死亡 → 洗回抽牌库 + 本局 -2 费 + 次元' + NL
    + 'const TOP_HAT_DISCOUNT:= 2' + NL
    + 'const ICECREAM_RELIC_ID:= 6016')

# ── 4. _music_box_tick 注释「不重复抽两张」→「三张」 ──
rep('# 不重复抽两张；音符不足两张时有多少抽多少（走引擎 rng → 回放一致）。',
    '# 不重复抽三张；音符不足三张时有多少抽多少（走引擎 rng → 回放一致）。')

# ── 5. _note_la 注释「力量 +3」→「力量 +2」 ──
rep('## La（9282，音符 · 3 费次元）：抽 NOTE_LA_DRAW 张，这些卡本局费用 -1；其中盟友与工事力量 +3。',
    '## La（9282，音符 · 3 费次元）：抽 NOTE_LA_DRAW 张，这些卡本局费用 -1；其中盟友与工事力量 +2。')
rep('## 「本局一直累加」同一条路）；「力量 +3」直接烘进卡面 power（手牌里的卡还没有 Placement）。',
    '## 「本局一直累加」同一条路）；「力量 +2」直接烘进卡面 power（手牌里的卡还没有 Placement）。')

# ── 6. _destroy 里插入礼帽分支 ──
rep('\t\telif _legacy_try_return(p):' + NL
    + '\t\t\tpass   # R528 传承记忆：已回手卡（日志与减费都在里面记）' + NL
    + '\t\telse:',
    '\t\telif _legacy_try_return(p):' + NL
    + '\t\t\tpass   # R528 传承记忆：已回手卡（日志与减费都在里面记）' + NL
    + '\t\telif self_relics.has(TOP_HAT_RELIC_ID) and (p.card.kind == "盟友" or p.card.is_fort()):' + NL
    + '\t\t\t# R828「这是礼帽」6087：己方盟友 / 工事死亡 → 洗回抽牌库 + 本局费用 -2 + 获得次元。' + NL
    + '\t\t\t# ⚠️ 带次元的卡在第一个分支已被「离场即消失」接走，走不到这里 —— 所以每张卡' + NL
    + '\t\t\t#    只会被礼帽救一次（救回来就带次元，下次死亡真消失），不会无限洗回。' + NL
    + '\t\t\tvar hat_back := _own_card(_card_leaving_field(p))' + NL
    + '\t\t\tif hat_back == null:' + NL
    + '\t\t\t\t_log("礼帽：%s 被击破 → 洗回失败（卡为空）" % p.card.card_name)' + NL
    + '\t\t\telse:' + NL
    + '\t\t\t\tstate.card_discount[hat_back] = int(state.card_discount.get(hat_back, 0)) + TOP_HAT_DISCOUNT' + NL
    + '\t\t\t\that_back.add_affix(AFFIX_DIMENSION)' + NL
    + '\t\t\t\tstate.deck.append(hat_back)' + NL
    + '\t\t\t\t_log("%s 被击破，洗回抽牌库（本局费用 -%d，获得次元）" % [p.card.card_name, TOP_HAT_DISCOUNT])' + NL
    + '\t\t\t\taction.emit("relic", {"id": TOP_HAT_RELIC_ID, "text": "%s 洗回抽牌库" % p.card.card_name})' + NL
    + '\t\telse:')

print('\n引擎补丁完成')
