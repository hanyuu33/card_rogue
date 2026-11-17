# -*- coding: utf-8 -*-
"""R786：手牌整体对齐站场中轴 + 手牌数徽标跟着左移 + 暗影刺客「本回合用卡数」徽标。

只做精确替换（每处 assert count == 1），改完逐文件复核行尾（battle_scene / test_smoke 是 CRLF）。
"""
import io

BS = "scripts/battle_scene.gd"
SMOKE = "scripts/test_smoke.gd"
NL = "\r\n"


def rd(p):
    return io.open(p, encoding="utf-8", newline="").read()


def wr(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag):
    n = s.count(old)
    assert n == 1, "%s 命中 %d 次" % (tag, n)
    return s.replace(old, new, 1)


s = rd(BS)

# ── ① 常量：手牌横向基准 = 棋盘中轴；徽标几何抽成常量 ─────────────────────────
old = (
    "const HAND_FAN_WIDTH := 356.0     # 手牌整体可用宽度（装不下就靠重叠压缩）\r\n"
    "# R154：手牌羊皮纸底板的几何（扇形居中于 WINDOW_W/2；底板略宽于扇形活动范围）\r\n"
    "const HAND_BASE_W := 420.0\r\n"
    "const HAND_BASE_X := (WINDOW_W - HAND_BASE_W) / 2.0\r\n"
)
new = (
    "const HAND_FAN_WIDTH := 356.0     # 手牌整体可用宽度（装不下就靠重叠压缩）\r\n"
    "\r\n"
    "## R786：手牌扇形 / 手牌底板 / 手牌数徽标的**横向基准** = 站场（棋盘）中轴。\r\n"
    "## 窗口 1280 的中线是 640，棋盘 3 列的中线是 590（GRID_X 404 + GRID_W 372 / 2），\r\n"
    "## 差整整 50px：以前整组按窗口居中，看着比上面对齐的棋盘偏右半个格子。\r\n"
    "## ⚠️ 凡是「跟着手牌走」的横坐标都读 HAND_CX，别再写 WINDOW_W / 2。\r\n"
    "const HAND_CX := GRID_X + GRID_W / 2.0\r\n"
    "const HAND_BADGE_W := 110.0\r\n"
    "const HAND_BADGE_H := 42.0\r\n"
    "const HAND_BADGE_Y := 628.0\r\n"
    "const HAND_BADGE_GAP := 20.0   # 手牌数徽标右沿 ↔ 手牌底板左沿\r\n"
    "const PLAYS_BADGE_GAP := 8.0   # 「本回合用卡」徽标 ↔ 手牌数徽标（并排成一对，留 8px 缝）\r\n"
    "# R154：手牌羊皮纸底板的几何（扇形居中于 HAND_CX；底板略宽于扇形活动范围）\r\n"
    "const HAND_BASE_W := 420.0\r\n"
    "const HAND_BASE_X := HAND_CX - HAND_BASE_W / 2.0\r\n"
)
s = rep(s, old, new, "① 常量")

# ── ② 扇形横向起点 ────────────────────────────────────────────────────────
s = rep(
    s,
    "\tvar x: float = (WINDOW_W - total) / 2 + step * i\r\n",
    "\tvar x: float = HAND_CX - total / 2.0 + step * i\r\n",
    "② _hand_rect 起点",
)

# ── ③ 两个徽标的几何抽成函数（绘制与测试同一个口，不许各写一份坐标）────────────
old = (
    "\tdraw_style_box(sb, Rect2(HAND_BASE_X, HAND_BASE_Y, HAND_BASE_W, HAND_BASE_H))\r\n"
    "\r\n"
    "\r\n"
    "func _draw_hand() -> void:\r\n"
)
new = (
    "\tdraw_style_box(sb, Rect2(HAND_BASE_X, HAND_BASE_Y, HAND_BASE_W, HAND_BASE_H))\r\n"
    "\r\n"
    "\r\n"
    "func _hand_badge_rect() -> Rect2:\r\n"
    "\t## R786：手牌数徽标 —— 贴在**手牌底板左沿**外侧（底板跟着棋盘中轴走了，它也一起）。\r\n"
    "\t## 坐标全由常量算：以前写死 `Rect2(300, 628, 110, 42)`，手牌一挪就脱节。\r\n"
    "\treturn Rect2(HAND_BASE_X - HAND_BADGE_GAP - HAND_BADGE_W, HAND_BADGE_Y,\r\n"
    "\t\t\tHAND_BADGE_W, HAND_BADGE_H)\r\n"
    "\r\n"
    "\r\n"
    "func _plays_badge_rect() -> Rect2:\r\n"
    "\t## R786：暗影刺客的「本回合用卡数」徽标 —— 摆在手牌数徽标**左边**，同高同宽成一对。\r\n"
    "\tvar hb := _hand_badge_rect()\r\n"
    "\treturn Rect2(hb.position.x - PLAYS_BADGE_GAP - HAND_BADGE_W, HAND_BADGE_Y,\r\n"
    "\t\t\tHAND_BADGE_W, HAND_BADGE_H)\r\n"
    "\r\n"
    "\r\n"
    "func _shows_plays_badge() -> bool:\r\n"
    "\t## 只给暗影刺客：终结 9086 的 4+X / 回转 9089 抽 X / 连环戏法 9093 / 疾风 9091 的 X\r\n"
    "\t## 读的都是 `state.self_card_plays`（本回合已用张数），以前玩家只能心里数。\r\n"
    "\treturn RunState.player_class == PlayerClass.ROGUE\r\n"
    "\r\n"
    "\r\n"
    "func _draw_hand() -> void:\r\n"
)
s = rep(s, old, new, "③ 徽标几何函数")

# ── ④ 绘制：改用几何函数 + 新增用卡数徽标 ──────────────────────────────────
old = (
    "\tvar hand_badge := Rect2(300, 628, 110, 42)\r\n"
    "\tBattleHudMaterial.draw(self, hand_badge)\r\n"
    '\t_draw_string_center(_font_bold, 15, GameI18n.ui("battle", "BATTLE_HAND", '
    '"\u624b\u724c %d/%d") % [n, FieldState.HAND_LIMIT], hand_badge.get_center(), '
    'Color("9a493e") if full else Color("45654e"), -1)\r\n'
)
new = (
    "\tvar hand_badge := _hand_badge_rect()\r\n"
    "\tBattleHudMaterial.draw(self, hand_badge)\r\n"
    '\t_draw_string_center(_font_bold, 15, GameI18n.ui("battle", "BATTLE_HAND", '
    '"\u624b\u724c %d/%d") % [n, FieldState.HAND_LIMIT], hand_badge.get_center(), '
    'Color("9a493e") if full else Color("45654e"), -1)\r\n'
    "\t# R786：暗影刺客多一个「本回合用卡数」徽标，摆在手牌数徽标**左边**（同高同宽成一对）。\r\n"
    "\t# 计数读 `state.self_card_plays` —— 与终结 9086 的 X 是同一份数（`_note_card_played` 唯一口）。\r\n"
    "\tif _shows_plays_badge():\r\n"
    "\t\tvar plays_badge := _plays_badge_rect()\r\n"
    "\t\tBattleHudMaterial.draw(self, plays_badge)\r\n"
    "\t\t_draw_string_center_fit(_font_bold, 15,\r\n"
    '\t\t\t\tGameI18n.ui("battle", "BATTLE_TURN_PLAYS", "\u672c\u56de\u5408\u7528\u5361 %d")\r\n'
    "\t\t\t\t\t\t% engine.state.self_card_plays,\r\n"
    '\t\t\t\tplays_badge.get_center(), HAND_BADGE_W - 12.0, Color("5b4276"))\r\n'
)
s = rep(s, old, new, "④ 绘制")

# ── ⑤ 跟着手牌走的飘字 / 落位起点：横坐标一起搬 ────────────────────────────
for src in ("Vector2(WINDOW_W / 2.0, OWN_HAND_Y", "Vector2(WINDOW_W / 2, OWN_HAND_Y"):
    s = s.replace(src, "Vector2(HAND_CX, OWN_HAND_Y")
# 上面那条前缀替换已经把 `_place_from` 的 (WINDOW_W/2, OWN_HAND_Y-60) 一起带走了，
# 这里只做「一个都不许剩」的复核。
assert "WINDOW_W / 2.0, OWN_HAND_Y" not in s and "WINDOW_W / 2, OWN_HAND_Y" not in s

wr(BS, s)
c = rd(BS)
assert c.count("\n") == c.count("\r\n"), "battle_scene 行尾混了"
assert c.count("HAND_CX") >= 12, c.count("HAND_CX")

# ── ⑥ smoke：几何 + 只给暗影刺客 ─────────────────────────────────────────
t = rd(SMOKE)
old = "\t_check_hand_fan(scene)\r\n"
new = "\t_check_hand_fan(scene)\r\n\t_check_hand_alignment(scene)\r\n"
t = rep(t, old, new, "⑥ smoke 调用")

anchor = "func _check_hand_fan(scene: Variant) -> void:\r\n"
func_txt = (
    "func _check_hand_alignment(scene: Variant) -> void:\r\n"
    "\t## R786（店长要求）：手牌整体**纵向对齐站场**（棋盘中轴 590，不是窗口中线 640），\r\n"
    "\t## 手牌数徽标按同一个位移左移；暗影刺客再多一个「本回合用卡数」徽标，摆它左边。\r\n"
    "\tvar n: int = scene.engine.state.hand.size()\r\n"
    "\tif n < 1:\r\n"
    '\t\t_smoke_fail("手牌对齐：手里一张牌都没有，量不出扇形中线")\r\n'
    "\t\treturn\r\n"
    "\tvar want: float = scene.GRID_X + scene.GRID_W / 2.0\r\n"
    "\tvar mid: float = (scene._hand_rect(0).position.x\r\n"
    "\t\t\t+ scene._hand_rect(n - 1).position.x + scene.HAND_CARD_W) / 2.0\r\n"
    "\tif absf(mid - want) > 0.6:\r\n"
    '\t\t_smoke_fail("手牌对齐：扇形中线 %.1f，棋盘中线 %.1f（差 %.1f，应为 0）"\r\n'
    "\t\t\t\t% [mid, want, mid - want])\r\n"
    "\tvar base_cx: float = scene.HAND_BASE_X + scene.HAND_BASE_W / 2.0\r\n"
    "\tif absf(base_cx - want) > 0.6:\r\n"
    '\t\t_smoke_fail("手牌对齐：手牌底板中线 %.1f 没跟着棋盘中线 %.1f（以前按窗口居中）"\r\n'
    "\t\t\t\t% [base_cx, want])\r\n"
    "\tvar hb: Rect2 = scene._hand_badge_rect()\r\n"
    "\tif absf((hb.end.x + scene.HAND_BADGE_GAP) - scene.HAND_BASE_X) > 0.6:\r\n"
    '\t\t_smoke_fail("手牌数徽标：右沿 %.1f 与底板左沿 %.1f 之间不是 HAND_BADGE_GAP 的缝"\r\n'
    "\t\t\t\t% [hb.end.x, scene.HAND_BASE_X])\r\n"
    "\tvar pb: Rect2 = scene._plays_badge_rect()\r\n"
    "\tif pb.position.x < scene.INFO_X + 4.0:\r\n"
    '\t\t_smoke_fail("本回合用卡徽标：左沿 %.1f 顶出屏幕左侧（信息栏 x=%.0f）"\r\n'
    "\t\t\t\t% [pb.position.x, scene.INFO_X])\r\n"
    "\tif absf((pb.end.x + scene.PLAYS_BADGE_GAP) - hb.position.x) > 0.6:\r\n"
    '\t\t_smoke_fail("本回合用卡徽标：右沿 %.1f 与手牌数徽标左沿 %.1f 之间不是 PLAYS_BADGE_GAP"\r\n'
    "\t\t\t\t% [pb.end.x, hb.position.x])\r\n"
    "\t# 只给暗影刺客：换两次职业验「该出现的出现、不该出现的不出现」\r\n"
    "\tvar keep_cls: String = RunState.player_class\r\n"
    "\tRunState.player_class = PlayerClass.ROGUE\r\n"
    "\tvar rogue_on: bool = scene._shows_plays_badge()\r\n"
    "\tRunState.player_class = PlayerClass.DRUID\r\n"
    "\tvar druid_on: bool = scene._shows_plays_badge()\r\n"
    "\tRunState.player_class = keep_cls\r\n"
    "\tif not rogue_on:\r\n"
    '\t\t_smoke_fail("本回合用卡徽标：暗影刺客应当显示，实际没显示")\r\n'
    "\telif druid_on:\r\n"
    '\t\t_smoke_fail("本回合用卡徽标：非暗影刺客也显示了（应只给读 self_card_plays 的那个职业）")\r\n'
    "\telse:\r\n"
    '\t\tprint("SMOKE OK 手牌对齐：扇形中线 %.1f = 棋盘中线 / 手牌数徽标 %.1f 起 / "\r\n'
    '\t\t\t\t"暗影刺客用卡徽标 %.1f 起" % [mid, hb.position.x, pb.position.x])\r\n'
    "\r\n"
    "\r\n"
)
t = rep(t, anchor, func_txt + anchor, "⑥ smoke 函数")
wr(SMOKE, t)
c = rd(SMOKE)
assert c.count("\n") == c.count("\r\n"), "test_smoke 行尾混了"

print("PATCH OK")
