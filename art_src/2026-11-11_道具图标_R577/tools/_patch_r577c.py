# -*- coding: utf-8 -*-
"""R577c：拆掉给文字准备的横条槽，道具图标直接放大铺满正方形格。

店长口径（2026-11-11）：「不应该保留原本的框，直接用图标，并且大小也放大点」。

- 地图：两列 46x46 图标格（原 98x26 横条），去掉底板 / 边框 / 来源色条；
  悬停只给一圈柔和浅底光晕，不是常驻框。
- 战斗：容量区域固定 232（12 格，smoke 契约），绘制底板按实际行数收拢；3 列 44x44 图标格（原 98x26），
  同样去掉每格底板 / 边框 / 色条；R314 呼吸高亮改走青白圆环。
- 缺图回退文字的两条分支保留（导出包照常可玩），但只在缺图时才画临时浅底。

⚠️ 行尾：map_scene.gd / 归档脚本 = LF；battle_scene.gd / test_engine.gd = CRLF。
   往 CRLF 插 GDScript 一律显式写 \r\n，补丁后核对 CRLF 计数。
⚠️ 可重跑：常量已落地就整体跳过，不会重复插入。
"""
import shutil
import sys
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")


def crlf(s: str) -> str:
    return s.replace("\n", "\r\n")


def rep(s: str, old: str, new: str, label: str) -> str:
    assert s.count(old) == 1, (label, s.count(old))
    return s.replace(old, new, 1)


def main() -> int:
    ms_p = ROOT / "scripts" / "map_scene.gd"
    bs_p = ROOT / "scripts" / "battle_scene.gd"
    te_p = ROOT / "scripts" / "test_engine.gd"

    ms_b = ms_p.read_bytes()
    bs_b = bs_p.read_bytes()
    te_b = te_p.read_bytes()
    if b"const RELIC_BADGE_W := 46.0" in ms_b:
        print("R577c 补丁已落地，跳过（不会重复插入）")
        return 0

    # 备份（_bk_ 前缀，别删）
    for p in (ms_p, bs_p, te_p):
        shutil.copyfile(p, ROOT / ("_bk_%s_before_r577c.gd" % p.stem))

    # ---------------- ① map_scene.gd（LF） ----------------
    assert ms_b.count(b"\r\n") == 0
    ms = ms_b.decode("utf-8")

    ms = rep(ms,
        "## 右侧两列：从右列向下排，再排左列；超过容量在两列内滚动，不遮地图。\n"
        "const RELIC_BADGE_W := 98.0\n"
        "const RELIC_BADGE_H := 26.0\n"
        "const RELIC_STEP_X := 104.0    # 徽章宽 98 + 6 间隙\n"
        "const RELIC_STEP_Y := 30.0     # 徽章高 26 + 4 间隙\n",
        "## 右侧两列：从右列向下排，再排左列；超过容量在两列内滚动，不遮地图。\n"
        "## R577c（店长口径）：不再保留给文字准备的横条槽 —— 图标本身就是格子，\n"
        "## 正方形 46x46 直接铺在地图上，无底板 / 无边框 / 无来源色条。\n"
        "const RELIC_BADGE_W := 46.0\n"
        "const RELIC_BADGE_H := 46.0\n"
        "const RELIC_STEP_X := 52.0     # 图标 46 + 6 间隙\n"
        "const RELIC_STEP_Y := 52.0     # 图标 46 + 6 间隙\n",
        "map/常量")

    old_draw = (
        "\t\t# R367：已耗尽的画灰（边框 / 色块 / 名称一起压暗），一眼能看出「这件用完了」。\n"
        "\t\tvar spent := RunState.is_relic_spent(int(RunState.relics[i]))\n"
        "\t\tvar scol := Color(\"6a7078\") if spent else rel.badge_color()\n"
        "\t\tMapMaterial.draw(self, rect)\n"
        "\t\tdraw_rect(rect, scol, false, 1.4)\n"
        "\t\tvar chip := Rect2(rect.position + Vector2(5, 5), Vector2(7, rect.size.y - 10))\n"
        "\t\tdraw_rect(chip, scol, true)\n"
        "\t\tdraw_rect(chip, Color(0, 0, 0, 0.55), false, 1.0)\n"
        "\t\t# R577b：右侧堆叠方式不变（仍是两列 98x26 槽位 / 滚动 / 悬停浮窗），\n"
        "\t\t# 槽里改放无背景小图标；缺图才回退到原来的文字（导出包照常可玩）。\n"
        "\t\tvar tex := UiAssets.relic_icon(int(RunState.relics[i]))\n"
        "\t\tif tex == null:\n"
        "\t\t\t# R343：传奇道具名走亮金（底是来源色 18% 覆在地图上，属深底）。\n"
        "\t\t\tdraw_string(_font_bold, rect.position + Vector2(14, 18), rel.relic_name,\n"
        "\t\t\t\t\tHORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18, UiTheme.FS_LABEL,\n"
        "\t\t\t\t\tColor(\"8d8577\") if spent else rel.name_color(UiTheme.PAGE_INK))\n"
        "\t\telse:\n"
        "\t\t\tvar s := minf(rect.size.y - 4.0, 22.0)\n"
        "\t\t\tvar ir := Rect2(rect.position + Vector2((rect.size.x - s) * 0.5,\n"
        "\t\t\t\t\t(rect.size.y - s) * 0.5), Vector2(s, s))\n"
        "\t\t\tdraw_texture_rect(tex, ir, false,\n"
        "\t\t\t\t\tColor(0.52, 0.52, 0.55, 0.85) if spent else Color.WHITE)\n")
    new_draw = (
        "\t\t# R367：已耗尽的画灰，一眼能看出「这件用完了」。\n"
        "\t\tvar spent := RunState.is_relic_spent(int(RunState.relics[i]))\n"
        "\t\tvar is_hover := hover_ok and rect.has_point(_mouse)\n"
        "\t\t# R577c：只在悬停时给一圈柔和浅底光晕（不是常驻框），让图标在地图纹理上更醒目。\n"
        "\t\tif is_hover:\n"
        "\t\t\tdraw_circle(rect.get_center(), rect.size.x * 0.68,\n"
        "\t\t\t\t\tColor(1.0, 0.98, 0.88, 0.32))\n"
        "\t\t# R577c：去掉文字横条槽，图标直接占满 46x46 正方形格；\n"
        "\t\t# 缺图才回退到原来的文字（导出包照常可玩）。\n"
        "\t\tvar tex := UiAssets.relic_icon(int(RunState.relics[i]))\n"
        "\t\tif tex == null:\n"
        "\t\t\t# 缺图兜底：临时浅底 + 缩小名字，仅在这条分支出现。\n"
        "\t\t\tdraw_rect(rect, Color(0.90, 0.88, 0.82, 0.92), true)\n"
        "\t\t\tvar fs := 11\n"
        "\t\t\twhile fs > 7 and _font_bold.get_string_size(rel.relic_name,\n"
        "\t\t\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 6:\n"
        "\t\t\t\tfs -= 1\n"
        "\t\t\tdraw_string(_font_bold,\n"
        "\t\t\t\t\trect.position + Vector2(0, rect.size.y * 0.5 + fs * 0.35),\n"
        "\t\t\t\t\trel.relic_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs,\n"
        "\t\t\t\t\tColor(\"8d8577\") if spent else rel.name_color(UiTheme.PAGE_INK))\n"
        "\t\telse:\n"
        "\t\t\tdraw_texture_rect(tex, rect, false,\n"
        "\t\t\t\t\tColor(0.52, 0.52, 0.55, 0.85) if spent else Color.WHITE)\n")
    ms = rep(ms, old_draw, new_draw, "map/绘制段")
    # ⚠️ 信物栏（_draw_key_relics）里有一模一样的 hover 判据，锚点必须带上
    #    上一段「图标占满 rect」的绘制，才只命中道具栏这一处。
    ms = rep(ms,
        "\t\t\tdraw_texture_rect(tex, rect, false,\n"
        "\t\t\t\t\tColor(0.52, 0.52, 0.55, 0.85) if spent else Color.WHITE)\n"
        "\t\tif hover_ok and rect.has_point(_mouse):\n\t\t\thovered = i\n",
        "\t\t\tdraw_texture_rect(tex, rect, false,\n"
        "\t\t\t\t\tColor(0.52, 0.52, 0.55, 0.85) if spent else Color.WHITE)\n"
        "\t\tif is_hover:\n\t\t\thovered = i\n",
        "map/hover 收口")
    assert ms.count("if tex == null:") >= 1
    ms_p.write_bytes(ms.encode("utf-8"))
    print("map_scene.gd patched (LF)")

    # ---------------- ② battle_scene.gd（CRLF） ----------------
    bs = bs_b.decode("utf-8")
    bs_crlf0 = bs.count("\r\n")
    bs = rep(bs,
        crlf("func _relic_zone_rect() -> Rect2:\n\treturn Rect2(794, 348, 338, 176)\n"),
        crlf("func _relic_zone_rect() -> Rect2:\n"
             "\t## R577c：容量契约 —— 固定装得下 3 列 x 4 行 = 12 格 44x44 图标\n"
             "\t## （test_smoke 的「第 12 个徽章不越界」锁的就是这条，不跟着件数缩）。\n"
             "\t## 视觉上不留空白：_draw_relic_bar() 另算 draw_z，只把底板画到实际行数。\n"
             "\treturn Rect2(794, 348, 338, 232)\n"),
        "battle/zone")
    bs = rep(bs,
        crlf("\treturn Rect2(z.position + Vector2(14 + (i % 3) * 104, 34 + int(i / 3) * 32), Vector2(98, 26))\n"),
        crlf("\treturn Rect2(z.position + Vector2(14 + (i % 3) * 104, 34 + int(i / 3) * 48), Vector2(44, 44))\n"),
        "battle/rect")
    # 容量契约用 z（固定 12 格），绘制底板另用 draw_z 按当前行数收拢，避免空白。
    bs = rep(bs,
        crlf("\tvar ids := _relic_bar_ids()\n"
             "\tvar z := _relic_zone_rect()\n"
             "\tBattleHudMaterial.draw(self, z)\n"
             "\t_draw_string_center(_font_bold, 14, \"道具 %d\" % ids.size(),\n"
             "\t\t\tVector2(z.position.x + z.size.x / 2, z.position.y + 16.0), Color(\"7a6230\"), -1)\n"),
        crlf("\tvar ids := _relic_bar_ids()\n"
             "\tvar z := _relic_zone_rect()\n"
             "\t# R577c：底板只画到当前实际行数，避免只拿 3 件道具时留出一大块空白。\n"
             "\t# 输入命中 / 容量契约仍用 z（固定 12 格），两者分开，不互相牵连。\n"
             "\tvar draw_rows := clampi(ceili(float(mini(ids.size(), 12)) / 3.0), 1, 4)\n"
             "\tvar draw_z := Rect2(z.position, Vector2(z.size.x, 40.0 + draw_rows * 48.0))\n"
             "\tBattleHudMaterial.draw(self, draw_z)\n"
             "\t_draw_string_center(_font_bold, 14, \"道具 %d\" % ids.size(),\n"
             "\t\t\tVector2(draw_z.position.x + draw_z.size.x / 2, draw_z.position.y + 16.0), Color(\"7a6230\"), -1)\n"),
        "battle/底板收拢")
    bs = rep(bs,
        crlf("\t\t\t\tVector2(z.position.x + 6.0, z.position.y + z.size.y + 20.0), Color(\"d9a8ff\"))\n"),
        crlf("\t\t\t\tVector2(draw_z.position.x + 6.0, draw_z.position.y + draw_z.size.y + 20.0), Color(\"d9a8ff\"))\n"),
        "battle/低语贴底板")

    b0 = bs.index(crlf("func _draw_relic_bar() -> void:"))
    r0 = bs.index(crlf("\t\tvar rspent := RunState.is_relic_spent(int(ids[i]))"), b0)
    r1 = bs.index("\t# 道具太多装不下 → 末位换成", r0)
    old_seg = bs[r0:r1]
    assert old_seg.count("draw_rect(chip") == 2, old_seg.count("draw_rect(chip")
    assert old_seg.count("UiAssets.relic_icon(") == 1
    new_seg = crlf(
        "\t\tvar rspent := RunState.is_relic_spent(int(ids[i]))\n"
        "\t\tvar scol := Color(\"8a8f98\") if rspent else rel.badge_color()\n"
        "\t\t# R577c（店长口径）：去掉每件道具的横条底 / 边框 / 来源色块，图标本身就是格子。\n"
        "\t\t# R314 呼吸高亮改走「图标外一圈青白光环」，不再依赖矩形外框。\n"
        "\t\tif engine.relic_highlight(ids[i]):\n"
        "\t\t\tvar lit_ph := 0.5 + 0.5 * sin(float(_now()) / 220.0)\n"
        "\t\t\tvar lit_col := Color(0.56, 0.92, 1.0)\n"
        "\t\t\tvar cc := rect.get_center()\n"
        "\t\t\tdraw_circle(cc, rect.size.x * 0.66,\n"
        "\t\t\t\t\tColor(lit_col.r, lit_col.g, lit_col.b, 0.18 + 0.20 * lit_ph))\n"
        "\t\t\tdraw_arc(cc, rect.size.x * 0.63, 0.0, TAU, 40,\n"
        "\t\t\t\t\tColor(lit_col.r, lit_col.g, lit_col.b, 0.72 + 0.24 * lit_ph), 2.2, true)\n"
        "\t\t# R577b 的唯一取图口不变；缺图才回退到 R309 那套文字（导出包照常可玩）。\n"
        "\t\tvar tex := UiAssets.relic_icon(int(ids[i]))\n"
        "\t\tif tex == null:\n"
        "\t\t\tdraw_rect(rect, Color(\"d9d7cf\") if rspent else scol.lerp(Color.WHITE, 0.62), true)\n"
        "\t\t\t# R309：**不描边**（outline = -1）—— 8~10 号字上 2px 描边会把笔画糊掉，\n"
        "\t\t\t# 「雕像（3）」这种带括号的名字尤其看不清。\n"
        "\t\t\t# R343：传奇道具名走**暗金**（底是来源色向白混 62% 的浅实色 → 亮金会糊），\n"
        "\t\t\t# 普通道具仍是原来的深棕。判据在 `RelicData.name_color()`，这里不写特例。\n"
        "\t\t\tvar label := RunState.relic_display_name(ids[i], engine.state.self_card_plays)\n"
        "\t\t\tvar label_size := 13\n"
        "\t\t\twhile label_size > 9 and _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > rect.size.x - 18:\n"
        "\t\t\t\tlabel_size -= 1\n"
        "\t\t\t_draw_string_center(_font_bold, label_size,\n"
        "\t\t\t\t\tlabel,\n"
        "\t\t\t\t\tVector2(rect.position.x + 12.0 + (rect.size.x - 12.0) / 2,\n"
        "\t\t\t\t\t\t\trect.position.y + rect.size.y * 0.5 + 4.0),\n"
        "\t\t\t\t\tColor(\"9a9488\") if rspent else rel.name_color(Color(\"4a3c14\")), -1)\n"
        "\t\telse:\n"
        "\t\t\tdraw_texture_rect(tex, rect, false,\n"
        "\t\t\t\t\tColor(0.52, 0.52, 0.55, 0.85) if rspent else Color.WHITE)\n")
    bs = bs[:r0] + new_seg + bs[r1:]
    assert bs.count("if tex == null:") >= 1
    assert bs.count("\r\n") > bs_crlf0 - 100   # 行数变少属正常，但不能出现裸 LF
    assert bs.count("\n") == bs.count("\r\n"), "battle_scene.gd 出现裸 LF"
    bs_p.write_bytes(bs.encode("utf-8"))
    print("battle_scene.gd patched (CRLF, %d -> %d lines)" % (bs_crlf0, bs.count("\r\n")))

    # ---------------- ③ test_engine.gd 源码锁断言（CRLF） ----------------
    te = te_b.decode("utf-8")
    te_crlf0 = te.count("\r\n")
    anchor = crlf("\t# ==== R556：场地卡「毒沼」8082 —— 中毒（回合结束伤害）====\n")
    block = crlf(
        "\t# ==== R577c：拆掉文字横条槽，图标直接放大铺满正方形格 ====\n"
        "\tvar icon577c_m0 := icon577_ms.find(\"func _draw_relics()\")\n"
        "\tvar icon577c_m1 := icon577_ms.find(\"func _draw_relic_tip(\")\n"
        "\tvar icon577c_b0 := icon577_bs.find(\"func _draw_relic_bar()\")\n"
        "\tvar icon577c_b1 := icon577_bs.find(\"func _draw_cost_zone()\")\n"
        "\tvar icon577c_mseg := icon577_ms.substr(icon577c_m0, icon577c_m1 - icon577c_m0)\n"
        "\tvar icon577c_bseg := icon577_bs.substr(icon577c_b0, icon577c_b1 - icon577c_b0)\n"
        "\tcheck_src(icon577c_m0 >= 0 and icon577c_m1 > icon577c_m0\n"
        "\t\t\tand icon577c_b0 >= 0 and icon577c_b1 > icon577c_b0,\n"
        "\t\t\t\"R577c 源码锁：两处绘制段边界可取\")\n"
        "\tcheck_src(icon577c_mseg.contains(\"draw_texture_rect(tex, rect, false,\")\n"
        "\t\t\tand not icon577c_mseg.contains(\"MapMaterial.draw(\")\n"
        "\t\t\tand not icon577c_mseg.contains(\"draw_rect(chip\")\n"
        "\t\t\tand not icon577c_mseg.contains(\"draw_rect(rect, scol, false\"),\n"
        "\t\t\t\"R577c 源码：地图道具栏图标占满正方形格、不再有槽底板/边框/色条\")\n"
        "\tcheck_src(icon577_ms.contains(\"const RELIC_BADGE_W := 46.0\")\n"
        "\t\t\tand icon577_ms.contains(\"const RELIC_BADGE_H := 46.0\")\n"
        "\t\t\tand icon577_ms.contains(\"const RELIC_STEP_Y := 52.0\"),\n"
        "\t\t\t\"R577c 数据：地图图标格 46x46、行距 52（不再是文字横条槽）\")\n"
        "\tcheck_src(icon577c_bseg.contains(\"draw_texture_rect(tex, rect, false,\")\n"
        "\t\t\tand not icon577c_bseg.contains(\"draw_rect(chip\")\n"
        "\t\t\tand not icon577c_bseg.contains(\"draw_rect(rect, scol, false\"),\n"
        "\t\t\t\"R577c 源码：战斗右栏图标占满正方形格、不再有槽底板/边框/色条\")\n"
        "\tcheck_src(icon577_bs.contains(\"Rect2(794, 348, 338, 232)\")\n"
        "\t\t\tand icon577_bs.contains(\"Vector2(44, 44)\")\n"
        "\t\t\tand icon577_bs.contains(\"var draw_z := Rect2(z.position,\"),\n"
        "\t\t\t\"R577c 数据：战斗右栏容量 12 格、每格 44x44，底板按行数收拢\")\n")
    te = rep(te, anchor, block + anchor, "test_engine/插入点")
    assert te.count("\n") == te.count("\r\n"), "test_engine.gd 出现裸 LF"
    te_p.write_bytes(te.encode("utf-8"))
    print("test_engine.gd +6 条断言 (CRLF, %d -> %d lines)" % (te_crlf0, te.count("\r\n")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
