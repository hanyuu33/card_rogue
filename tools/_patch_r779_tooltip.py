# -*- coding: utf-8 -*-
"""R779：工具栏「看不到效果描述」——电脑端悬浮 / 安卓端点上膛后都弹完整说明面板。

只改两个文件：
  scripts/battle_scene.gd   （battle_scene 是 CRLF，必须按二进制处理）
  scripts/test_trap_input.gd（LF）

补丁全部 exact-replace + assert count==1，锚点先 dump repr 复核。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tabs(s):
    """把 4 空格缩进转成 GDScript 的 tab（写入时不用手敲 tab，避免被编辑器吃掉）。"""
    out = []
    for line in s.split("\n"):
        stripped = line.lstrip(" ")
        n = len(line) - len(stripped)
        out.append("\t" * (n // 4) + stripped)
    return "\n".join(out)


def patch(path, edits, crlf):
    full = os.path.join(ROOT, path)
    data = open(full, "rb").read()
    text = data.decode("utf-8")
    nl = "\r\n" if crlf else "\n"
    for name, old, new in edits:
        old_b = old.replace("\n", nl)
        new_b = new.replace("\n", nl)
        cnt = text.count(old_b)
        if cnt != 1:
            print("!! %s [%s] 锚点命中 %d 次（应为 1）" % (path, name, cnt))
            print("   repr:", repr(old_b[:120]))
            sys.exit(1)
        text = text.replace(old_b, new_b, 1)
        print("ok %s [%s]" % (path, name))
    open(full, "wb").write(text.encode("utf-8"))


# ---------------------------------------------------------------- battle_scene
VARS_OLD = """var _tool_pick_slot := -1
"""
VARS_NEW = """var _tool_pick_slot := -1
## R779：鼠标此刻压着的工具槽（-1 = 没压）——电脑端悬浮就靠它弹出完整效果说明。
## 安卓没有 MouseMotion 事件：点一下上膛（`_tool_use_arm`）走同一条绘制。
## 两条路合成一个判据 `_tool_tip_anchor_slot()`，别在绘制处各写一份。
var _tool_tip_slot := -1
"""

CLEAR_OLD = """	_hover_relic_tip = ""
"""
CLEAR_NEW = """	_hover_relic_tip = ""
	_tool_tip_slot = -1          # R779：工具说明跟着一起收（否则会挂在屏幕上）
"""

HOVER_OLD = """	# (\u2462'') \u53f3\u680f\u9053\u5177\u680f\uff1a\u60ac\u505c\u770b\u9053\u5177\u63cf\u8ff0"""
HOVER_NEW = None  # 由下面按真实文本拼，见 build()

DRAW_OLD = """	_draw_relic_tip_panel()
"""
DRAW_NEW = """	_draw_relic_tip_panel()
	_draw_tool_tip_panel()   # R779：工具槽的完整效果说明（电脑悬浮 / 安卓点一下上膛）
"""

FUNC_ANCHOR_OLD = """func _draw_log_panel() -> void:
"""

FUNC_BLOCK = tabs("""func _tool_tip_anchor_slot() -> int:
    ## R779：工具说明面板**此刻该显示哪个槽**（-1 = 不显示）——绘制与回归共用的唯一判据。
    ## ① 上膛期优先：安卓没有 hover 事件，「点一下」就是「我要看这个工具」；
    ##    电脑端上膛后同样一直显示，直到用掉 / 丢掉 / 2.6 秒过期。
    ## ② 否则看鼠标悬停的槽（电脑端）。
    if _tool_use_arm >= 0 and _tool_use_arm < RunState.TRAP_SLOTS \\
            and Time.get_ticks_msec() <= _tool_use_until:
        return _tool_use_arm
    if _tool_tip_slot >= 0 and _tool_tip_slot < RunState.TRAP_SLOTS:
        return _tool_tip_slot
    return -1


func _draw_tool_tip_panel() -> void:
    ## R779：工具槽的完整效果说明（用户口径「工具栏看不到工具的效果描述」）。
    ## 版式与 `_draw_relic_tip_panel()` 共用同一套常量与折行，锚点换成**槽左侧**，
    ## 并且让开按钮栏 —— 按钮栏画在独立高层 CanvasLayer 上，压在它下面会被整块盖住。
    var slot := _tool_tip_anchor_slot()
    if slot < 0:
        return
    var tid := RunState.trap_at(slot)
    if tid <= 0:
        return
    var td: TrapData = TrapRepo.load_json().get_trap(tid)
    if td == null:
        return
    var sr := _trap_slot_rect(slot)
    var w := 400.0
    var inner := w - RELIC_TIP_PAD * 2.0
    # 右缘：上膛时让开按钮栏（它开在槽左侧），否则只让开槽本身。
    var armed: bool = _tool_use_arm >= 0 and slot == _tool_use_arm \\
            and Time.get_ticks_msec() <= _tool_use_until
    var right: float = sr.position.x - TOOL_BAR_OFFSET
    if armed:
        var bar: Rect2 = _tool_bar_layout(slot)["bar"]
        right = bar.position.x - TOOL_BAR_GAP
    var x: float = clampf(right - w, 8.0, maxf(8.0, WINDOW_W - w - 8.0))
    var fs := RELIC_TIP_SIZE
    var lines: Array[String] = ["「%s」" % td.trap_name]
    for ln in CardFace.wrap_text(_font, td.desc, inner, fs):
        lines.append(ln)
    var lh: float = maxf(_font.get_height(fs), float(fs))
    var max_h: float = WINDOW_H - 16.0
    while fs > RELIC_TIP_SIZE_MIN \\
            and RELIC_TIP_PAD * 2.0 + float(lines.size()) * lh > max_h:
        fs -= 1
        lines = ["「%s」" % td.trap_name]
        for ln in CardFace.wrap_text(_font, td.desc, inner, fs):
            lines.append(ln)
        lh = maxf(_font.get_height(fs), float(fs))
    var h: float = RELIC_TIP_PAD * 2.0 + float(lines.size()) * lh
    var y: float = clampf(sr.position.y, 8.0, maxf(8.0, WINDOW_H - h - 8.0))
    draw_rect(Rect2(x, y, w, h), Color(0.06, 0.07, 0.10, 0.96), true)
    draw_rect(Rect2(x, y, w, h), Color("ffd76a"), false, 1.6)
    for li in lines.size():
        var by: float = y + RELIC_TIP_PAD + lh * (float(li) + 0.5) + fs * 0.36
        if li == 0:
            draw_string(_font_bold, Vector2(x + RELIC_TIP_PAD, by), lines[li],
                    HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe6a2"))
        else:
            draw_string(_font, Vector2(x + RELIC_TIP_PAD, by), lines[li],
                    HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f0ead8"))


""")


def build_hover():
    # 真实文本里 ③'' 后面是「右栏道具栏：悬停看道具描述（装不下时悬停「+N」摘要 → 提示点开看全部）」
    old = (
        "\t# ③'' 右栏道具栏：悬停看道具描述（装不下时悬停「+N」摘要 → 提示点开看全部）\n"
        "\tif _hover_card == null:\n"
        "\t\tvar rel_hit := false\n"
    )
    new = (
        "\t# ③''' R779：工具槽悬停 → 弹出完整效果说明（电脑端）。\n"
        "\t# 用户口径「工具栏看不到工具的效果描述」：描述有四五十字，状态栏一行读不完，\n"
        "\t# 所以走与道具说明同一套浮动折行面板。安卓没有 MouseMotion，\n"
        "\t# 点一下槽上膛（`_tool_use_arm`）时同一个面板照样弹（见 `_tool_tip_anchor_slot`）。\n"
        "\tif _hover_card == null:\n"
        "\t\tfor ti in RunState.TRAP_SLOTS:\n"
        "\t\t\tif RunState.trap_at(ti) > 0 and _trap_slot_rect(ti).has_point(pos):\n"
        "\t\t\t\t_tool_tip_slot = ti\n"
        "\t\t\t\tbreak\n"
        + old
    )
    return ("hover", old, new)


# ------------------------------------------------------------- test_trap_input
TEST_RESET_OLD = """	_sc._tool_pick_slot = -1
"""
TEST_RESET_NEW = """	_sc._tool_pick_slot = -1
	_sc._tool_tip_slot = -1      # R779：工具说明面板的悬停态
"""

TEST_ANCHOR_OLD = """	# ---- ⑧e R754：石头（7012）要拖到**敌方单位**身上才砸得下去 ----
"""

TEST_BLOCK = tabs("""    # ---- ⑧f R779：工具栏能**看到效果描述**（电脑悬浮 / 安卓点一下上膛） ----
    # 用户口径：「工具栏看不到工具的效果描述」→ 电脑端悬浮、安卓端点击都要能看到。
    RunState.traps = [-1, -1, -1]
    RunState.gain_trap(7008)          # 野性图腾：使用型（ally_atk）
    _sc._tool_use_arm = -1
    _sc._tool_use_until = 0
    _sc._tool_tip_slot = -1
    _sc._on_hover(s0)
    check(_sc._tool_tip_slot == 0, "工具说明：鼠标悬停在槽上就认得这个槽（野性图腾）")
    check(_sc._tool_tip_anchor_slot() == 0, "工具说明：电脑端悬浮即可显示（不必先点）")
    var tip_td: TrapData = TrapRepo.load_json().get_trap(7008)
    check(tip_td != null and tip_td.trap_name != "" and tip_td.desc != "",
            "工具说明：图腾有可显示的名字与效果描述")
    _sc._on_hover(Vector2(640.0, 40.0))
    check(_sc._tool_tip_slot == -1 and _sc._tool_tip_anchor_slot() == -1,
            "工具说明：鼠标移开就收起")
    # 安卓：没有 MouseMotion，点一下（上膛）也必须看得到。
    _feed(_mb(s0, true))
    _feed(_mb(s0, false))
    check(_sc._tool_use_arm == 0, "工具说明：点一下照样上膛（安卓路径）")
    check(_sc._tool_tip_anchor_slot() == 0, "工具说明：安卓点一下也能看到（上膛即显示）")
    # 上膛过期 → 面板跟着收起，不留残影。
    _sc._tool_use_until = Time.get_ticks_msec() - 1
    check(_sc._tool_tip_anchor_slot() == -1, "工具说明：上膛过期后面板收起")
    _sc._tool_use_arm = -1
    _sc._tool_use_until = 0
    _sc._tool_tip_slot = -1

    # ---- ⑧e R754：石头（7012）要拖到**敌方单位**身上才砸得下去 ----
""")

if __name__ == "__main__":
    patch("scripts/battle_scene.gd", [
        ("vars", VARS_OLD, VARS_NEW),
        ("clear", CLEAR_OLD, CLEAR_NEW),
        build_hover(),
        ("draw", DRAW_OLD, DRAW_NEW),
        ("func", FUNC_ANCHOR_OLD, FUNC_BLOCK + FUNC_ANCHOR_OLD),
    ], crlf=True)
    patch("scripts/test_trap_input.gd", [
        ("reset", TEST_RESET_OLD, TEST_RESET_NEW),
        ("case", TEST_ANCHOR_OLD, TEST_BLOCK),
    ], crlf=False)
    print("R779 patch done")
