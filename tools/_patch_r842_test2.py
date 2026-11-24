# -*- coding: utf-8 -*-
# R842 收尾：改掉被新增内容顶红的写死条数。
# 按行处理，每行保留自己的行尾（CRLF 不丢）；任何锚点匹配数 != 1 立即 assert。
import io

P = "scripts/test_engine.gd"
txt = io.open(P, "r", encoding="utf-8", newline="").read()
lines = txt.splitlines(keepends=True)
eol = "\r\n" if lines[0].endswith("\r\n") else "\n"
print("eol =", repr(eol), "lines =", len(lines))


def sub_line(pred_desc, pred, old, new):
    """在满足 pred 的行里把 old 换成 new，必须恰好 1 行命中。"""
    hits = [i for i, L in enumerate(lines) if pred(L)]
    assert len(hits) == 1, "%s: 命中 %d 行 %s" % (pred_desc, len(hits), hits)
    i = hits[0]
    assert old in lines[i], "%s: 行内找不到 old\nrepr=%r" % (pred_desc, lines[i])
    lines[i] = lines[i].replace(old, new, 1)
    print("OK %-24s L%d" % (pred_desc, i + 1))


# ① 第一层事件池 size 12 -> 13
sub_line("L1 size",
         lambda L: 'check(ev_kinds_layer.size() == 12' in L,
         "size() == 12", "size() == 13")

# ② 第一层事件池 断言里补 dragon_slab（挂在 sword 同一行，不新增行）
sub_line("L1 +dragon_slab",
         lambda L: 'ev_kinds_layer.has("sword")' in L,
         'ev_kinds_layer.has("sword") \\',
         'ev_kinds_layer.has("sword") \\')

sub_line("L1 +dragon_slab2",
         lambda L: 'ev_kinds_layer.has("snow_leopard") and ev_kinds_layer.has("sword")' in L,
         'and ev_kinds_layer.has("sword")',
         'and ev_kinds_layer.has("sword") and ev_kinds_layer.has("dragon_slab")')

# ③ 第一层事件池 文案
sub_line("L1 msg",
         lambda L: '第一层事件池：12 种子类型' in L,
         '第一层事件池：12 种子类型', '第一层事件池：13 种子类型')

sub_line("L1 msg tail",
         lambda L: 'R793 林中的剑；R512 移除卡牌宝箱' in L,
         'R793 林中的剑；R512 移除卡牌宝箱',
         'R793 林中的剑/R842 龙石板；R512 移除卡牌宝箱')

# ④ R447 第一层 12 -> 13
sub_line("R447 size",
         lambda L: 'check(r447_l1.size() == 12' in L,
         'r447_l1.size() == 12 and r447_l1.has("adventurer")',
         'r447_l1.size() == 13 and r447_l1.has("adventurer") and r447_l1.has("dragon_slab")')

sub_line("R447 msg",
         lambda L: 'R447 第一层事件池 12 种' in L,
         'R447 第一层事件池 12 种', 'R447 第一层事件池 13 种')

sub_line("R447 msg tail",
         lambda L: 'R793 +林中的剑，实际 %d' in L,
         'R793 +林中的剑，实际 %d', 'R793 +林中的剑；R842 +龙石板，实际 %d')

# ⑤ R229 附魔表 7 -> 8（+brawn），并在上一行注释补一句
sub_line("R229 size",
         lambda L: 'CardData.ENCHANT_DEFS.size() == 7' in L,
         'CardData.ENCHANT_DEFS.size() == 7', 'CardData.ENCHANT_DEFS.size() == 8')

idx = next(i for i, L in enumerate(lines)
           if 'R458：附魔表 6 → 7（+契约核心 core）' in L)
lines.insert(idx + 1,
             "\t# R842：附魔表 7 → 8（+力量 +8 brawn；事件「龙石板」独有，不进随机池）" + eol)
print("OK R229 comment          L%d（新增）" % (idx + 2))

# ⑥ R817 事件基线 24 -> 25
sub_line("R817 events",
         lambda L: 'baseline_count("events") == 24' in L,
         'baseline_count("events") == 24', 'baseline_count("events") == 25')

sub_line("R817 msg",
         lambda L: '事件 = 24 种子类型' in L,
         '事件 = 24 种子类型（一层 12 + 二层 16，去重后 24，实际 %d）',
         '事件 = 25 种子类型（一层 13 + 二层 16，去重后 25，实际 %d）')

io.open(P, "w", encoding="utf-8", newline="").write("".join(lines))
print("WROTE", P)
