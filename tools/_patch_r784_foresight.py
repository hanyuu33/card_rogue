import io

CRLF = "\r\n"


def L(*lines):
    return CRLF.join(lines)


def patch(path, pairs):
    b = io.open(path, "rb").read()
    s = b.decode("utf-8")
    for old, new in pairs:
        n = s.count(old)
        assert n == 1, (path, n, old[:80])
        s = s.replace(old, new)
    io.open(path, "wb").write(s.encode("utf-8"))
    print("patched", path)


# ── 1) 引擎：foresight_choose 的 ② 与两条「落空」分支都收口到本卡消失 ──
eng = "scripts/game_engine.gd"
p1 = [
    # ② 抽完牌 → 本卡消失
    (
        L('\t\t_log("预判②：%s" % (("卡组随机非 0 费技能卡「%s」加入手卡" % c.card_name) if c != null else "卡组里没有非 0 费技能卡"))',
          '\t\taction.emit("foresight", {"mode": 2, "card": c})'),
        L('\t\t_log("预判②：%s" % (("卡组随机非 0 费技能卡「%s」加入手卡" % c.card_name) if c != null else "卡组里没有非 0 费技能卡"))',
          '\t\t_foresight_void_self()   # R784：② 也吃「次元」，不许停在弃牌区',
          '\t\taction.emit("foresight", {"mode": 2, "card": c})'),
    ),
    # ① 无候选 → 落空也要消失
    (
        L('\t\t_log("预判①：弃牌区没有 0 费技能卡，效果落空")',
          '\t\treturn true'),
        L('\t\t_log("预判①：弃牌区没有 0 费技能卡，效果落空")',
          '\t\t_foresight_void_self()   # R784：效果落空也算用掉（否则留一张 0 费次元卡在弃牌区）',
          '\t\treturn true'),
    ),
    # ① 手牌满 → 同上
    (
        L('\t\t_log("预判①：手牌已满（%d 张），效果落空" % FieldState.HAND_LIMIT)',
          '\t\treturn true'),
        L('\t\t_log("预判①：手牌已满（%d 张），效果落空" % FieldState.HAND_LIMIT)',
          '\t\t_foresight_void_self()',
          '\t\treturn true'),
    ),
    # 新增唯一收口函数（插在 foresight_choose 之后）
    (
        L('\t_log("预判①：从弃牌区选择一张 0 费技能卡")',
          '\treturn true',
          '',
          '',
          'func foresight_pick_card(discard_index: int) -> bool:'),
        L('\t_log("预判①：从弃牌区选择一张 0 费技能卡")',
          '\treturn true',
          '',
          '',
          'func _foresight_void_self() -> void:',
          '\t## R784：预判（9097）自身的「次元」收尾 —— **唯一口**。',
          '\t## 打出时它先落进弃牌区（① 要拿它当候选池标记），结算完（①选完 / ②抽完 / 效果落空）',
          '\t## 由这里把自己搬进消耗区。R784 之前只有 ① 走这一趟，② 和两条落空分支会把一张',
          '\t## 带「次元」的卡永久留在弃牌区，与字段描述「不会进入弃牌区」正面冲突。',
          '\tfor v_i in state.discard.size():',
          '\t\tif state.discard[v_i].id == FORESIGHT_ID:',
          '\t\t\tstate.void_cards.append(state.discard[v_i])',
          '\t\t\tstate.discard.remove_at(v_i)',
          '\t\t\tstate.void_count += 1   # R140：消耗区计数（预判自身用后消失）',
          '\t\t\t_log("预判：用后消失（不进弃牌区，本场不再出现）")',
          '\t\t\treturn',
          '',
          '',
          'func foresight_pick_card(discard_index: int) -> bool:'),
    ),
    # ① 选完 → 改调收口函数
    (
        L('\tforesight_pick = false',
          '\tfor v_i in state.discard.size():',
          '\t\tif state.discard[v_i].id == FORESIGHT_ID:',
          '\t\t\t_log("预判：用后消失（不进弃牌区，本场不再出现）")',
          '\t\t\tstate.void_cards.append(state.discard[v_i])',
          '\t\t\tstate.discard.remove_at(v_i)',
          '\t\t\tstate.void_count += 1   # R140：消耗区计数（预判自身用后消失）',
          '\t\t\tbreak',
          ''),
        L('\tforesight_pick = false',
          '\t_foresight_void_self()   # R784：与 ② / 落空分支共用一个收口',
          ''),
    ),
]
patch(eng, p1)


# ── 2) 二选一面板：把「之后本卡消失」提到标题上，两行对称 ──
bs = "scripts/battle_scene.gd"
p2 = [
    (
        '"预判：选择一个效果"',
        '"预判：选择一个效果（之后本卡消失）"',
    ),
    (
        '"① 从弃牌区选一张费用为 0 的技能卡加入手卡（之后本卡消失）"',
        '"① 从弃牌区选一张费用为 0 的技能卡加入手卡"',
    ),
]
patch(bs, p2)


# ── 3) 测试：② 不再留在弃牌区；补一条「① 落空也消失」 ──
te = "scripts/test_engine.gd"
p3 = [
    (
        "# 预判（9097）②：卡组随机非 0 费技能卡入手（本卡照常进弃牌区）",
        "# 预判（9097）②：卡组随机非 0 费技能卡入手，本卡消失（R784 起 ② 也走「次元」）",
    ),
    (
        L('\t\t\tand r45_fs.state.discard.size() == 1,', '', '\t\t\t"预判②：卡组非 0 费技能卡入手，本卡进弃牌区")'),
        L('\t\t\tand r45_fs.state.discard.is_empty() and r45_fs.state.void_count == 1,', '',
          '\t\t\t"预判②：卡组非 0 费技能卡入手，本卡消失（弃牌区不留）")'),
    ),
    (
        L('\t\t\t"预判①：选回 0 费技能卡，本卡消失（弃牌区清空）")', '', ''),
        L('\t\t\t"预判①：选回 0 费技能卡，本卡消失（弃牌区清空）")', '',
          '\t# R784：① 无候选（效果落空）时本卡同样消失 —— 上一版会在弃牌区留一张 0 费次元卡',
          '\tvar r784_fs3 := _new_engine([], 30, 30)',
          '\tr784_fs3.state.hand.append(repo.get_card(GameEngine.FORESIGHT_ID))',
          '\tr784_fs3.use_spell(0, null)',
          '\tr784_fs3.foresight_choose(1)',
          '\tcheck(r784_fs3.state.discard.is_empty() and r784_fs3.state.void_count == 1,',
          '\t\t\t"预判①落空：本卡同样消失（弃牌 %d / 消耗 %d）" % [',
          '\t\t\t\tr784_fs3.state.discard.size(), r784_fs3.state.void_count])', '',
          ''),
    ),
]
patch(te, p3)
print("done")
