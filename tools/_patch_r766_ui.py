# -*- coding: utf-8 -*-
"""R766 界面：懊悔（9265）的「从弃牌区选一张其他职业卡」全屏选卡页。

照乌鸦（crow）那套五处接线原样复制，只换结算口与文案：
  A `_pick_active_kind()` 加 "regret"
  B `_build_pick_cfg()` 加 "regret" 配置（候选走 disc_cards，与乌鸦同一份）
  C 确认分发调 `engine.regret_pick()`
  D 取消 / 右键守卫：必须选一张，不接受取消
  E 结束回合守卫：把面板弹回来，别让玩家以为卡住
  F 结束回合按钮禁用
  G action 分发 "regret_pick"（播提示音 + 状态行）

⚠️ battle_scene.gd 是 **CRLF**：读 bytes、按 \\r\\n 拼锚点、原样写 bytes。
"""
import pathlib

P = pathlib.Path(r"E:\work\card_rogue\scripts\battle_scene.gd")
raw = P.read_bytes()
assert raw.count(b"\r\n") == raw.count(b"\n"), "battle_scene 行尾不是纯 CRLF，先查清楚再改"
src = raw.decode("utf-8")
orig = len(src)
applied = []


def L(*lines):
    return "\r\n".join(lines)


def sub(anchor, new, label):
    global src
    n = src.count(anchor)
    if n != 1:
        print("FAIL[%s] count=%d" % (label, n), flush=True)
        raise SystemExit(1)
    src = src.replace(anchor, new)
    applied.append(label)


# ------------------------------------------------------- A 选卡页 kind
A_OLD = L('\tif engine.crow_pending:', '\t\treturn "crow"', '')
A_NEW = L('\tif engine.crow_pending:', '\t\treturn "crow"',
          '\t# R766 懊悔（9265）：从弃牌区选一张其他职业卡让它消失。',
          '\tif engine.regret_pending:', '\t\treturn "regret"', '')
sub(A_OLD, A_NEW, "A-kind")

# ------------------------------------------------------- B 面板配置
B_OLD = L(
    '\t\t"crow":',
    '\t\t\tvar copts: Array = engine.crow_options()',
    '\t\t\treturn {"kind": k, "short": "乌鸦", "opts": copts,',
    '\t\t\t\t\t"title": "乌鸦：选择弃牌堆一张盟友回到手卡（必须选一张）",',
    '\t\t\t\t\t"note": "点卡选中，再点确认 —— 它立即回到你的手牌",',
    '\t\t\t\t\t"cards": copts.map(disc_cards),',
    '\t\t\t\t\t"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}')
B_NEW = B_OLD + L(
    '',
    '\t\t"regret":',
    '\t\t\t# R766 懊悔（9265）：候选只列**其他职业卡**（引擎 `regret_options()` 唯一判据）。',
    '\t\t\tvar gopts: Array = engine.regret_options()',
    '\t\t\treturn {"kind": k, "short": "懊悔", "opts": gopts,',
    '\t\t\t\t\t"title": "懊悔：选择弃牌区一张其他职业卡，让它消失（必须选一张）",',
    '\t\t\t\t\t"note": "点卡选中，再点确认 —— 它本场对战消失（不回手牌、也不进消耗区）",',
    '\t\t\t\t\t"cards": gopts.map(disc_cards),',
    '\t\t\t\t\t"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}')
sub(B_OLD, B_NEW, "B-cfg")

# ------------------------------------------------------- C 确认分发
C_OLD = L(
    '\t\t"crow":',
    '\t\t\tvar ci := int(opts[sel[0]])',
    '\t\t\tvar cnm := "?"',
    '\t\t\tif ci >= 0 and ci < engine.state.discard.size():',
    '\t\t\t\tcnm = engine.state.discard[ci].card_name',
    '\t\t\tif engine.crow_recall(ci):',
    '\t\t\t\tstatus_text = "乌鸦：%s 从弃牌堆回到手牌" % cnm',
    '\t\t\t_clear_selection()')
C_NEW = C_OLD + L(
    '\t\t"regret":',
    '\t\t\tvar gi := int(opts[sel[0]])',
    '\t\t\tvar gnm := "?"',
    '\t\t\tif gi >= 0 and gi < engine.state.discard.size():',
    '\t\t\t\tgnm = engine.state.discard[gi].card_name',
    '\t\t\tif engine.regret_pick(gi):',
    '\t\t\t\tstatus_text = "懊悔：弃牌区的「%s」消失" % gnm',
    '\t\t\t_clear_selection()')
sub(C_OLD, C_NEW, "C-confirm")

# ------------------------------------------------------- D 取消 / 右键
D_OLD = L(
    '\t# 乌鸦的回手面板：必须选一张（不接受取消）',
    '\tif engine.crow_pending:',
    '\t\t_say("乌鸦：必须从弃牌堆选择一张盟友回到手牌")',
    '\t\treturn')
D_NEW = D_OLD + L(
    '\t# R766 懊悔的消失面板：同样必须选一张（不接受取消）',
    '\tif engine.regret_pending:',
    '\t\t_say("懊悔：必须从弃牌区选择一张其他职业卡")',
    '\t\treturn')
sub(D_OLD, D_NEW, "D-cancel")

# ------------------------------------------------------- E 结束回合守卫
E_OLD = L(
    '\tif engine.crow_pending:',
    '\t\t_ensure_pick_visible("crow")',
    '\t\t_say("乌鸦：请先选择一张要回到手牌的盟友")',
    '\t\treturn')
E_NEW = E_OLD + L(
    '\tif engine.regret_pending:',
    '\t\t_ensure_pick_visible("regret")',
    '\t\t_say("懊悔：请先选择一张要让它消失的其他职业卡")',
    '\t\treturn')
sub(E_OLD, E_NEW, "E-endturn")

# ------------------------------------------------------- F 按钮禁用
F_OLD = L('\tif engine.crow_pending or engine.whale_pending or engine.endless_pending \\',
          '\t\t\tor engine.rebirth_pending or _recall_pending():')
F_NEW = L('\tif engine.crow_pending or engine.whale_pending or engine.endless_pending \\',
          '\t\t\tor engine.rebirth_pending or engine.regret_pending or _recall_pending():')
sub(F_OLD, F_NEW, "F-buttons")

# ------------------------------------------------------- G action 分发
G_OLD = L(
    '\t\t"crow_recall":',
    '\t\t\tsfx.play("place")',
    '\t\t\tvar cr_name := "?"',
    '\t\t\tif data.get("card") is CardData:',
    '\t\t\t\tcr_name = (data["card"] as CardData).card_name',
    '\t\t\t_say("乌鸦：%s 从弃牌堆回到手牌" % cr_name)')
G_NEW = G_OLD + L(
    '\t\t"regret_pick":',
    '\t\t\tsfx.play("place")',
    '\t\t\tvar rp_name := "?"',
    '\t\t\tif data.get("card") is CardData:',
    '\t\t\t\trp_name = (data["card"] as CardData).card_name',
    '\t\t\t_say("懊悔：弃牌区的「%s」消失" % rp_name)')
sub(G_OLD, G_NEW, "G-action")

P.write_bytes(src.encode("utf-8"))
print("patched %d spots, %d -> %d chars (+%d)" % (len(applied), orig, len(src), len(src) - orig))
for a in applied:
    print("  ok", a)
raw2 = P.read_bytes()
print("CRLF intact:", raw2.count(b"\r\n") == raw2.count(b"\n"))
