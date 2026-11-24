# -*- coding: utf-8 -*-
"""R836：缺陷时钟 —— ① 触发后本场不再显示角标；② 棋盘正中的「时针转动」演出。

用户口径：
  · 「触发＝12 后，本局都不再显示计数，直到下局」→ 角标在触发后返回 ""（不再画「0」）。
    按「本场战斗」理解：下一场是新引擎、计数复位，角标自然重新出现。
  · 「做一个时针转动的小动画，在触发时在屏幕战斗区域正中播放（同步进行回合结束丢卡和
    新回合开始）」→ 新 fx：钟面 + 代码画的指针转一整圈后卡住抖两下。
    ⚠️ 引擎侧 `end_turn(true)` 是同步完成的（丢手牌 + 起新回合同一帧），
       动画只演、不排队、不改时序 —— 玩家看到的就是「钟一转，牌换了」。

素材：钟面由 codex 出（art_src/2026-11-20_缺陷时钟时针_R836/），落 assets/fx/clock_face.png；
缺图时 `_draw_clock_face_fallback()` 画程序化表盘（项目既有纪律：不因缺图黑屏）。

⚠️ 行尾：battle_scene / test_engine 是 CRLF；run_state / ui_assets / 命名说明是 LF。
"""
ROOT = "E:/work/card_rogue/"


def rd(rel):
    return open(ROOT + rel, "rb").read()


def wr(rel, b):
    open(ROOT + rel, "wb").write(b)


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8")


def lf(s):
    return s.encode("utf-8")


def rep(b, old, new, tag):
    assert b.count(old) == 1, "[%s] 命中 %d 次" % (tag, b.count(old))
    return b.replace(old, new)


# ═════════════ ① run_state.gd（LF）：角标触发后不画 ═════════════
RS = "scripts/run_state.gd"
rs = rd(RS)
rs = rep(rs, lf(
    "\t##   * 缺陷时钟（6084，R832）→ 本场**还差几张牌**触发。它的计数在引擎里，\n"
    "\t##     由战斗界面当第二参 `clock_left` 递进来；没有战斗上下文（图鉴 / 商店 / 奖励页）\n"
    "\t##     时是默认的 -1 → 不画。本场已触发过 → 「0」照画（跟火柴同口径：得让玩家\n"
    "\t##     看见这一场已经用光了）。\n"),
    lf(
    "\t##   * 缺陷时钟（6084，R832）→ 本场**还差几张牌**触发。它的计数在引擎里，\n"
    "\t##     由战斗界面当第二参 `clock_left` 递进来；没有战斗上下文（图鉴 / 商店 / 奖励页）\n"
    "\t##     时是默认的 -1 → 不画。\n"
    "\t##     ⚠️ R836（用户口径）：**触发之后本场就不再画角标**，直到下一场重新数 ——\n"
    "\t##        画「0」会被读成「还差 0 张、马上再来一次」，反而骗人。\n"),
    "rs.doc")
rs = rep(rs, lf(
    "\t\tDEFECT_CLOCK_BADGE_ID:\n"
    "\t\t\treturn str(clock_left) if clock_left >= 0 else \"\"\n"),
    lf(
    "\t\tDEFECT_CLOCK_BADGE_ID:\n"
    "\t\t\t# R836：0 也**不画**（本场已经触发过，这一场不会再来了）。\n"
    "\t\t\treturn str(clock_left) if clock_left > 0 else \"\"\n"),
    "rs.branch")
wr(RS, rs)

# ═════════════ ② ui_assets.gd（LF）：钟面取图口 ═════════════
UA = "scripts/ui_assets.gd"
ua = rd(UA)
ua = rep(ua, lf(
    "static func trap_fx(id: int) -> Texture2D:\n"),
    lf(
    "static func clock_face_path() -> String:\n"
    "\t## R836：缺陷时钟「时针转动」演出用的**大钟面**（无指针 —— 指针由 battle_scene 画，\n"
    "\t## 要连续旋转，贴图转会有像素偏移与描边锯齿）。\n"
    "\t## 与 UI 贴图分目录：它是战斗特效、不是界面元件（R669 陷阱特效的先例）。\n"
    "\t## 缺图返回 null → `_draw_clock_face_fallback()` 画程序化表盘，不空白不报错。\n"
    "\treturn \"res://assets/fx/clock_face.png\"\n"
    "\n"
    "\n"
    "static func clock_face() -> Texture2D:\n"
    "\t## R836：钟面**唯一取图口**；`_load()` 兼容已导入与刚落盘未导入的 PNG。\n"
    "\tif not _cache.has(\"clock_face\"):\n"
    "\t\t_cache[\"clock_face\"] = _load(clock_face_path())\n"
    "\treturn _cache[\"clock_face\"]\n"
    "\n"
    "\n"
    "static func trap_fx(id: int) -> Texture2D:\n"),
    "ua.face")
wr(UA, ua)

# ═════════════ ③ battle_scene.gd（CRLF）：动画 ═════════════
BS = "scripts/battle_scene.gd"
bs = rd(BS)

# 3a 成员 + 常量
bs = rep(bs, crlf(
    "var _bursts: Array = []         # {pos, start, dur, col, big}                 打击爆点（扩散环+火花）\n"),
    crlf(
    "var _bursts: Array = []         # {pos, start, dur, col, big}                 打击爆点（扩散环+火花）\n"
    "## R836：缺陷时钟「时针转动」演出 —— 棋盘正中的一只大钟面，指针转一整圈后卡住抖两下。\n"
    "## 时长 1.15s：引擎侧 `end_turn(true)` 是**同步**跑完的（丢手牌 + 起新回合同一帧），\n"
    "## 这段动画只负责把「时间被跳过去」演出来，不排队、不延迟、不碰时序。\n"
    "## `{pos, sc, start, dur}` —— 与 `_bursts` 同一套 `_fx_pos()` 取位（跟棋盘滚动补正）。\n"
    "const CLOCK_FX_MS := 1150\n"
    "const CLOCK_FX_D := 240.0       # 表盘直径（棋盘坐标，随棋盘缩放）\n"
    "var _clock_fx := {}\n"),
    "bs.member")

# 3b handler 里起动画
bs = rep(bs, crlf(
    "\t\t\t_bursts.append({\"pos\": Vector2(GRID_X + GRID_W * 0.5, GRID_Y + GRID_H * 0.5),\n"
    "\t\t\t\t\t\"start\": n, \"dur\": 780, \"col\": Color(\"e8d08a\"), \"big\": true})\n"
    "\t\t\t_say(\"⏳ 缺陷时钟：本场第 %d 张牌 → 回合结束，立即开始新的我方回合\" % int(data.get(\"at\", 0)))\n"),
    crlf(
    "\t\t\t_bursts.append({\"pos\": Vector2(GRID_X + GRID_W * 0.5, GRID_Y + GRID_H * 0.5),\n"
    "\t\t\t\t\t\"start\": n, \"dur\": 780, \"col\": Color(\"e8d08a\"), \"big\": true})\n"
    "\t\t\t# R836：棋盘正中浮起一只大钟面，指针转一整圈（用户要求「时针转动的小动画」）\n"
    "\t\t\t_start_clock_fx()\n"
    "\t\t\t_say(\"⏳ 缺陷时钟：本场第 %d 张牌 → 回合结束，立即开始新的我方回合\" % int(data.get(\"at\", 0)))\n"),
    "bs.handler")

# 3c 绘制调用
bs = rep(bs, crlf(
    "\t_draw_bursts()\n"
    "\t_draw_trap_fx()      # R669：陷阱触发素材图（压在卡牌之上、通用光带之下）\n"),
    crlf(
    "\t_draw_bursts()\n"
    "\t_draw_clock_fx()     # R836：缺陷时钟的时针转动（压在爆点之上）\n"
    "\t_draw_trap_fx()      # R669：陷阱触发素材图（压在卡牌之上、通用光带之下）\n"),
    "bs.draw")

# 3d 三个新函数（插在 _draw_trap_fx 之前）
FIG = crlf(
    "func _start_clock_fx() -> void:\n"
    "\t## R836：缺陷时钟的「时针转动」演出起点（用户口径：战斗区域正中）。\n"
    "\t## ⚠️ 与回合结算的关系写在这里，免得以后有人来「补齐时序」：\n"
    "\t##    引擎 `end_turn(true)` 是同步完成的（弃手牌 / 超负荷 / 起新回合都在同一帧里跑完），\n"
    "\t##    这一段动画**只是把它演出来**。不延迟换牌、不排队等动画 ——\n"
    "\t##    玩家看到的就是「钟开始转的那一下，手牌已经换了」，正是「同步进行」的意思。\n"
    "\t_clock_fx = {\"start\": _now(), \"dur\": CLOCK_FX_MS,\n"
    "\t\t\t\"pos\": Vector2(GRID_X + GRID_W * 0.5, GRID_Y + GRID_H * 0.5),\n"
    "\t\t\t\"sc\": _grid_scroll}\n"
    "\n"
    "\n"
    "func _draw_clock_fx() -> void:\n"
    "\t## R836：缺陷时钟的时针转动。三段节奏：\n"
    "\t##   0.00~0.16  钟面弹入（0.84 → 1.0）+ 金色光晕环\n"
    "\t##   0.16~0.74  指针顺时针转**整整一圈**（ease-out，末段越来越慢）\n"
    "\t##   0.74~1.00  卡住抖两下（坏掉的钟）+ 整体淡出\n"
    "\t## 指针用代码画：连续旋转贴图会有像素偏移与描边锯齿，角度也对不上表盘刻度。\n"
    "\tif _clock_fx.is_empty():\n"
    "\t\treturn\n"
    "\tvar t := float(_now() - int(_clock_fx.get(\"start\", 0))) / float(int(_clock_fx.get(\"dur\", 1)))\n"
    "\tif t < 0.0 or t >= 1.0:\n"
    "\t\treturn\n"
    "\tvar c := _fx_pos(_clock_fx)\n"
    "\t# 弹入 + 收尾淡出\n"
    "\tvar s := 1.0\n"
    "\tif t < 0.16:\n"
    "\t\tvar p := t / 0.16\n"
    "\t\ts = lerpf(0.84, 1.0, 1.0 - pow(1.0 - p, 3.0))\n"
    "\tvar a := 1.0\n"
    "\tif t > 0.86:\n"
    "\t\ta = maxf(0.0, 1.0 - (t - 0.86) / 0.14)\n"
    "\tvar d := CLOCK_FX_D * s\n"
    "\t# ① 外光晕：三层金色软环，往外越来越淡（把钟面从棋盘底里托出来）\n"
    "\tfor i in 3:\n"
    "\t\tvar gr := Color(\"e8d08a\")\n"
    "\t\tgr.a = 0.20 * a * (1.0 - float(i) * 0.3)\n"
    "\t\tdraw_arc(c, d * (0.5 + 0.040 * float(i + 1)), 0.0, TAU, 48, gr, 5.5 - float(i) * 1.6)\n"
    "\t# ② 表盘（缺图 → 程序化）\n"
    "\tvar tex := UiAssets.clock_face()\n"
    "\tif tex != null:\n"
    "\t\tdraw_texture_rect(tex, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false,\n"
    "\t\t\t\tColor(1.0, 1.0, 1.0, a))\n"
    "\telse:\n"
    "\t\t_draw_clock_face_fallback(c, d, a)\n"
    "\t# ③ 指针：从 12 点位置转一整圈回到 12 点，末段卡顿抖两下\n"
    "\tvar spin := clampf((t - 0.16) / 0.58, 0.0, 1.0)\n"
    "\tvar ang := -PI * 0.5 + TAU * (1.0 - pow(1.0 - spin, 2.2))\n"
    "\tif spin >= 1.0:\n"
    "\t\tvar jt := clampf((t - 0.74) / 0.26, 0.0, 1.0)\n"
    "\t\tang += sin(jt * 34.0) * 0.055 * (1.0 - jt)\n"
    "\tvar dir := Vector2(cos(ang), sin(ang))\n"
    "\tvar tip := c + dir * (d * 0.34)\n"
    "\tvar tail := c - dir * (d * 0.09)\n"
    "\t# 先深褐描边再压金芯 —— 与卡面同一套「细黑描边 + 平涂」\n"
    "\tdraw_line(tail, tip, Color(0.16, 0.13, 0.09, a), maxf(1.0, 6.0 * s), true)\n"
    "\tdraw_line(c - dir * (d * 0.06), tip - dir * 1.5, Color(0.85, 0.66, 0.25, a),\n"
    "\t\t\tmaxf(1.0, 3.2 * s), true)\n"
    "\t# ④ 中心轴帽\n"
    "\tdraw_circle(c, maxf(1.0, 6.4 * s), Color(0.16, 0.13, 0.09, a))\n"
    "\tdraw_circle(c, maxf(0.5, 4.2 * s), Color(0.94, 0.90, 0.82, a))\n"
    "\n"
    "\n"
    "func _draw_clock_face_fallback(c: Vector2, d: float, a: float) -> void:\n"
    "\t## R836：钟面素材缺失时的程序化表盘（暗底 + 金环 + 12 个刻度）。\n"
    "\t## 项目纪律：特效缺图必须能退化，不能黑屏也不能刷报错。\n"
    "\tdraw_circle(c, d * 0.5, Color(0.13, 0.11, 0.09, 0.88 * a))\n"
    "\tdraw_arc(c, d * 0.5, 0.0, TAU, 48, Color(0.85, 0.66, 0.25, a), 3.0)\n"
    "\tdraw_circle(c, d * 0.42, Color(0.94, 0.90, 0.82, 0.92 * a))\n"
    "\tfor i in 12:\n"
    "\t\tvar ta := -PI * 0.5 + TAU * float(i) / 12.0\n"
    "\t\tvar tv := Vector2(cos(ta), sin(ta))\n"
    "\t\tdraw_line(c + tv * (d * 0.33), c + tv * (d * 0.39),\n"
    "\t\t\t\tColor(0.16, 0.13, 0.09, a), 3.2 if i % 3 == 0 else 2.0)\n"
    "\n"
    "\n"
)
bs = rep(bs, crlf("func _draw_trap_fx() -> void:\n"), FIG + crlf("func _draw_trap_fx() -> void:\n"),
         "bs.funcs")
wr(BS, bs)

# ═════════════ ④ test_engine.gd（CRLF）：角标断言改成「不画」═════════════
TE = "scripts/test_engine.gd"
te = rd(TE)
te = rep(te, crlf(
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"0\",\n"
    "\t\t\t\"R832 角标：触发后画「0」（本场用光）\")\n"),
    crlf(
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"\",\n"
    "\t\t\t\"R836 角标：触发后本场**不画**（实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084, r832_e.defect_clock_left()))\n"),
    "te.badge1")
te = rep(te, crlf(
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"0\",\n"
    "\t\t\t\"R832 角标：再打 6 张仍画「0」\")\n"),
    crlf(
    "\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"\",\n"
    "\t\t\t\"R836 角标：再打 6 张仍然不画（实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084, r832_e.defect_clock_left()))\n"),
    "te.badge2")
# ⑥ 下一场：补一条「角标重新出现」
te = rep(te, crlf(
    "\tcheck(r832_e2.defect_clock_left() == 12,\n"
    "\t\t\t\"R832 缺陷时钟：下一场重新数到 12（实际 %d）\" % r832_e2.defect_clock_left())\n"),
    crlf(
    "\tcheck(r832_e2.defect_clock_left() == 12,\n"
    "\t\t\t\"R832 缺陷时钟：下一场重新数到 12（实际 %d）\" % r832_e2.defect_clock_left())\n"
    "\tcheck(RunState.relic_badge_text(6084, r832_e2.defect_clock_left()) == \"12\",\n"
    "\t\t\t\"R836 角标：下一场重新出现（画「12」，实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084, r832_e2.defect_clock_left()))\n"),
    "te.next")
wr(TE, te)

print("R836 补丁完成：run_state / ui_assets / battle_scene / test_engine")
