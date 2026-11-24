# -*- coding: utf-8 -*-
"""R783：手牌「额外效果可触发」金框换样式（店长口径「比较粗糙」）。

旧版：`draw_rect` 一圈 2.2k 纯金直角粗线 + 0.20 平涂填充 + 字体 ★。
新版：圆角双线（暗金衬底 + 亮金细线 + 内侧细线）+ 角部聚光 + 呼吸暖光 + 精修金星。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tabs(s):
    out = []
    for line in s.split("\n"):
        stripped = line.lstrip(" ")
        n = len(line) - len(stripped)
        out.append("\t" * (n // 4) + stripped)
    return "\n".join(out)


OLD = tabs("""func _draw_hand_bonus_mark(r: Rect2) -> void:
    ## 手卡「额外效果可触发」的金色标记：外框 + 右上角一颗金星。
    ## 只做视觉，判定在 engine.hand_bonus_ready。
    var k := r.size.y / CardFace.CARD_H_DESIGN
    var col := COL_HAND_BONUS
    draw_rect(r.grow(2.0 * k), Color(col.r, col.g, col.b, 0.20), true)
    draw_rect(r.grow(2.0 * k), col, false, 2.2 * k)
    var star := r.position + Vector2(r.size.x - 9.0 * k, 11.0 * k)
    draw_circle(star, 7.0 * k, Color(0.10, 0.09, 0.12, 0.92))
    draw_arc(star, 7.0 * k, 0, TAU, 20, col, 1.6 * k, true)
    _draw_string_center(_font_bold, int(10 * k), "★", star, col, -1)
""")

NEW = tabs("""func _round_frame(rect: Rect2, rad: float, col: Color, w: float) -> void:
    ## 圆角矩形描边（四条直边 + 四段圆弧）。Godot 没有 draw_round_rect，
    ## 而卡面本身就是圆角金框 —— 直角套上去正是「粗糙」的来源，所以自己拼一个。
    ## 只画线、不填充；`w` 会跟着手牌的选中缩放一起变（调用点在旋转/缩放坐标系里）。
    var r := clampf(rad, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
    if r <= 0.5:
        draw_rect(rect, col, false, w)
        return
    var l := rect.position.x
    var t := rect.position.y
    var rt := rect.end.x
    var bt := rect.end.y
    draw_line(Vector2(l + r, t), Vector2(rt - r, t), col, w, true)
    draw_line(Vector2(l + r, bt), Vector2(rt - r, bt), col, w, true)
    draw_line(Vector2(l, t + r), Vector2(l, bt - r), col, w, true)
    draw_line(Vector2(rt, t + r), Vector2(rt, bt - r), col, w, true)
    draw_arc(Vector2(l + r, t + r), r, PI, PI * 1.5, 10, col, w, true)
    draw_arc(Vector2(rt - r, t + r), r, PI * 1.5, TAU, 10, col, w, true)
    draw_arc(Vector2(rt - r, bt - r), r, 0.0, PI * 0.5, 10, col, w, true)
    draw_arc(Vector2(l + r, bt - r), r, PI * 0.5, PI, 10, col, w, true)


func _draw_hand_bonus_mark(r: Rect2) -> void:
    ## 手卡「额外效果可触发」的金色标记（判定在 `engine.hand_bonus_ready`，这里只管画）。
    ## R783（店长口径「效果生效的框比较粗糙」）：旧版是一圈 2.2k 纯金**直角**粗线 + 0.20
    ## 平涂，贴在圆角卡面上像绕了一圈黄胶带。现在改成与卡面同一语汇的金漆画法：
    ##   ① 极淡暖光填充（只暗示"在发光"，不糊住画面）
    ##   ② 圆角双线：暗金粗线压底 + 亮金细线走中，形成刻线感
    ##   ③ 内侧再加一道更淡的细线 → 从中心看过去是"光从卡边渗出来"
    ##   ④ 四角各一段加亮的短弧（角部聚光），是最见精致的一笔
    ##   ⑤ 慢呼吸：所有金色分量的 alpha 随 sin 轻微起伏，读作"生效中"而非静态贴纸
    ## 金星徽章同样收小一号、改成双环。
    var k := r.size.y / CardFace.CARD_H_DESIGN
    var col := COL_HAND_BONUS
    var breath := 0.5 + 0.5 * sin(float(_now()) / 1000.0 * 2.2)
    var cr := 9.0 * k
    var b := r.grow(2.2 * k)
    # ① 暖光填充：比旧版淡一半，且跟着呼吸
    draw_rect(b, Color(col.r, col.g, col.b, 0.045 + 0.035 * breath), true)
    # ② 暗金衬底 + 亮金细线
    _round_frame(b, cr, Color(0.20, 0.13, 0.04, 0.85), 3.2 * k)
    _round_frame(b, cr, Color(col.r, col.g, col.b, 0.92), 1.5 * k)
    # ③ 内侧细线（光晕内缘）
    _round_frame(b.grow(-2.4 * k), cr * 0.86,
            Color(col.r, col.g, col.b, 0.26 + 0.22 * breath), 1.0 * k)
    # ④ 四角聚光：每角两段短弧，比整圈加亮更"收"
    var hot := Color(1.0, minf(1.0, col.g + 0.10), minf(1.0, col.b + 0.16),
            0.55 + 0.35 * breath)
    var hr := cr + 1.0 * k
    draw_arc(Vector2(b.position.x + cr, b.position.y + cr), hr, PI * 1.06, PI * 1.44, 8,
            hot, 2.0 * k, true)
    draw_arc(Vector2(b.end.x - cr, b.position.y + cr), hr, PI * 1.56, PI * 1.94, 8,
            hot, 2.0 * k, true)
    draw_arc(Vector2(b.end.x - cr, b.end.y - cr), hr, PI * 0.06, PI * 0.44, 8,
            hot, 2.0 * k, true)
    draw_arc(Vector2(b.position.x + cr, b.end.y - cr), hr, PI * 0.56, PI * 0.94, 8,
            hot, 2.0 * k, true)
    # ⑤ 右上金星：双环 + 光晕
    var star := r.position + Vector2(r.size.x - 9.0 * k, 11.0 * k)
    var sr := 7.2 * k
    draw_circle(star, sr * 1.35, Color(col.r, col.g, col.b, 0.10 + 0.07 * breath))
    draw_circle(star, sr, Color(0.09, 0.08, 0.11, 0.96))
    draw_arc(star, sr, 0, TAU, 24, Color(col.r, col.g, col.b, 0.95), 1.5 * k, true)
    draw_arc(star, sr * 1.18, 0, TAU, 24,
            Color(col.r, col.g, col.b, 0.22 + 0.18 * breath), 0.9 * k, true)
    _draw_string_center(_font_bold, int(9 * k), "★", star, col, -1)
""")

SHOT_OLD = tabs("""	if "--mapview" in args and engine != null:
""")
SHOT_NEW = tabs("""	if "--handbonus" in args and engine != null:
    # 演示（R783）：手牌里「影魔 8007 + 0 费终结 9086」→ 影魔满足
    # `hand_bonus_ready`（手卡里有 0 费技能）→ 金色额外效果框。
    # 出图：`battle.tscn -- --screenshot --handbonus --level 0 --shotframe 200`
    engine.state.hand.clear()
    engine.state.hand.append(CardData.from_dict(repo.get_card(8007).to_dict()))
    engine.state.hand.append(CardData.from_dict(repo.get_card(9086).to_dict()))
    engine.state.energy = 5
    _demo_hover_idx = 0
    _hover_hand = 0
    status_text = "影魔：手卡有 0 费技能 → 现在打出去每张 +生命（金框＝可触发额外效果）"
    _shot_t0 = _now()
    queue_redraw()
	if "--mapview" in args and engine != null:
""")


def run(path, edits):
    full = os.path.join(ROOT, path)
    text = open(full, "rb").read().decode("utf-8")
    for name, old, new in edits:
        o, n = old.replace("\n", "\r\n"), new.replace("\n", "\r\n")
        c = text.count(o)
        if c != 1:
            print("!! [%s] 命中 %d" % (name, c))
            sys.exit(1)
        text = text.replace(o, n, 1)
        print("ok [%s]" % name)
    open(full, "wb").write(text.encode("utf-8"))


if __name__ == "__main__":
    run("scripts/battle_scene.gd", [("mark", OLD, NEW), ("shot", SHOT_OLD, SHOT_NEW)])
    print("R783 patch done")
