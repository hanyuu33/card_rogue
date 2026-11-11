# -*- coding: utf-8 -*-
"""R577b UI 补丁：道具文字展示 → 无背景小图标（可重跑，先干跑再 --write）。

纪律：
  · 二进制精确替换 + assert count == 1；统一先把 CRLF 折成 LF 做替换，写盘时再折回去。
  · 干跑汇总**所有**不匹配（不一次只撞一个）。
  · 四处界面都保留「缺图 → 回退到原文字绘制」，不因缺图空白。
"""
import sys
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_道具图标_R577"
LOG = []
MISS = []

# 本轮涉及的文件里，这两个是 CRLF（项目工程纪律）
CRLF_FILES = {"scripts/battle_scene.gd", "scripts/test_engine.gd"}


def load(p: str) -> str:
    b = (ROOT / p).read_bytes()
    assert b.count(b"\n") == b.count(b"\r\n") or b.count(b"\r\n") == 0, p + " 行尾混杂"
    return b.decode("utf-8").replace("\r\n", "\n")


def save(p: str, text: str) -> None:
    out = text.replace("\n", "\r\n") if p in CRLF_FILES else text
    (ROOT / p).write_bytes(out.encode("utf-8"))


def exact(text: str, old: str, new: str, tag: str) -> str:
    n = text.count(old)
    if n != 1:
        MISS.append("%s exact count=%d" % (tag, n))
        return text
    LOG.append("exact  %s" % tag)
    return text.replace(old, new, 1)


def lines_between(text: str, first: str, last: str, new: str, tag: str) -> str:
    """把 [含 first 的行, 含 last 的行] 整段换成 new（new 以 \n 结尾）。"""
    L = text.split("\n")
    i = [k for k, l in enumerate(L) if first in l]
    if len(i) != 1:
        MISS.append("%s first count=%d [%s]" % (tag, len(i), first[:60]))
        return text
    i = i[0]
    j = [k for k, l in enumerate(L) if last in l and k >= i]
    if len(j) != 1:
        MISS.append("%s last count=%d [%s]" % (tag, len(j), last[:60]))
        return text
    j = j[0]
    LOG.append("block  %s (%d lines -> %d)" % (tag, j - i + 1, len(new.rstrip("\n").split("\n"))))
    L[i:j + 1] = new.rstrip("\n").split("\n")
    return "\n".join(L)


# ---------------------------------------------------------------- 1. UiAssets
UI_ASSETS_OLD = "static func div_orb_glass() -> Texture2D:\n"
UI_ASSETS_NEW = '''static func relic_icon_path(id: int) -> String:
	## R577b：道具图标文件名（128x128 无背景 PNG）。文件名即契约 —— 换图只覆盖
	## assets/ui/relic_icon_<id>.png，别在别处另写一份路径。
	return path_for("relic_icon_%d" % id)


static func relic_icon(id: int) -> Texture2D:
	## R577b：道具小图标**唯一取图口**。缺图返回 null → 调用方必须回退到原来的文字
	## 绘制（项目既有纪律：没导入 / 导出包读不到 png 时游戏照常可玩）。
	## 三样信物（6061~6063）不入 relics.json，沿用 R543 的 key_icon_*.png。
	if id == 6061 or id == 6062 or id == 6063:
		return key_relic_icon(id)
	return get_tex("relic_icon_%d" % id)


static func div_orb_glass() -> Texture2D:
'''

# ---------------------------------------------------------------- 2. 地图右侧堆叠
MAP_NEW = '''		# R577b：右侧堆叠方式不变（仍是两列 98x26 槽位 / 滚动 / 悬停浮窗），
		# 槽里改放无背景小图标；缺图才回退到原来的文字（导出包照常可玩）。
		var tex := UiAssets.relic_icon(int(RunState.relics[i]))
		if tex == null:
			# R343：传奇道具名走亮金（底是来源色 18% 覆在地图上，属深底）。
			draw_string(_font_bold, rect.position + Vector2(14, 18), rel.relic_name,
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18, UiTheme.FS_LABEL,
					Color("8d8577") if spent else rel.name_color(UiTheme.PAGE_INK))
		else:
			var s := minf(rect.size.y - 4.0, 22.0)
			var ir := Rect2(rect.position + Vector2((rect.size.x - s) * 0.5,
					(rect.size.y - s) * 0.5), Vector2(s, s))
			draw_texture_rect(tex, ir, false,
					Color(0.52, 0.52, 0.55, 0.85) if spent else Color.WHITE)
'''

# ---------------------------------------------------------------- 3. 战斗右侧堆叠
BATTLE_NEW = '''		# R577b：槽位几何 / 堆叠 / 呼吸高亮全部不变，格子里改放无背景小图标；
		# 缺图才回退到 R309 那套文字（项目既有纪律：导出包照常可玩）。
		var tex := UiAssets.relic_icon(int(ids[i]))
		if tex == null:
			# R309：**不描边**（outline = -1）—— 8~10 号字上 2px 描边会把笔画糊掉，
			# 「雕像（3）」这种带括号的名字尤其看不清。
			# R343：传奇道具名走**暗金**（底是来源色向白混 62% 的浅实色 → 亮金会糊），
			# 普通道具仍是原来的深棕。判据在 `RelicData.name_color()`，这里不写特例。
			var label := RunState.relic_display_name(ids[i], engine.state.self_card_plays)
			var label_size := 13
			while label_size > 9 and _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > rect.size.x - 18:
				label_size -= 1
			_draw_string_center(_font_bold, label_size,
					label,
					Vector2(rect.position.x + 12.0 + (rect.size.x - 12.0) / 2,
							rect.position.y + 14.0),
					Color("9a9488") if rspent else rel.name_color(Color("4a3c14")), -1)
		else:
			var s := minf(rect.size.y - 4.0, 22.0)
			var ir := Rect2(rect.position + Vector2((rect.size.x - s) * 0.5,
					(rect.size.y - s) * 0.5), Vector2(s, s))
			draw_texture_rect(tex, ir, false,
					Color(0.52, 0.52, 0.55, 0.85) if rspent else Color.WHITE)
'''

# ---------------------------------------------------------------- 4. 奖励页
RP_ENTRY_OLD = '''	var bonus_tex := _bonus_entry_tex(e)
	if bonus_tex != null:
		# 缩略图就是 64px（`_bonus_entry_tex` 里按同一尺寸生成）→ 1:1 贴，最清晰
		var s := 64.0
		_root.draw_texture_rect(bonus_tex,
				Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	_row_badge(center, _entry_color(e))
'''
RP_ENTRY_NEW = '''	var bonus_tex := _bonus_entry_tex(e)
	if bonus_tex != null:
		# 缩略图就是 64px（`_bonus_entry_tex` 里按同一尺寸生成）→ 1:1 贴，最清晰
		var s := 64.0
		_root.draw_texture_rect(bonus_tex,
				Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	# R577b：道具条目换用那件道具自己的图标（与金币 / 最大生命同一套 64px 缩略）。
	if str(e.get("kind", "")) == "relic":
		var rtex := UiAssets.relic_icon(int(e.get("id", 0)))
		if rtex != null:
			var s2 := 64.0
			_root.draw_texture_rect(rtex,
					Rect2(center - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false)
			return
	_row_badge(center, _entry_color(e))
'''

RP_KEY_OLD = '''	tex = UiAssets.key_relic_icon(
			RunState.SEED_RELIC_ID if opt == 1 else -relic_id)
'''
RP_KEY_NEW = '''	# R577b：左格改用「那件奖励道具」自己的图标 —— 旧写法把 -relic_id 传给
	# key_relic_icon 恒返回 null，所以二选一左格一直空着；右格信物仍走 R543 的图。
	tex = UiAssets.relic_icon(RunState.SEED_RELIC_ID if opt == 1 else relic_id)
'''

RP_DETAIL_OLD = '''	_root.draw_string(_font_bold, Vector2(r.position.x + 180, r.position.y + 40),
			"「%s」" % _entry_name(e), HORIZONTAL_ALIGNMENT_LEFT, 520,
			UiTheme.FS_HEADING, _entry_name_color(e, UiTheme.INK_900))
'''
RP_DETAIL_NEW = '''	# R577b：领取详情标题左侧放这件道具的大图标（缺图就只留标题）。
	if str(e.get("kind", "")) == "relic":
		var icon577_tex := UiAssets.relic_icon(int(e.get("id", 0)))
		if icon577_tex != null:
			# 贴在标题**右侧**（「← 返回列表」按钮占着 x+PAD..+154，左侧会压按钮）
			var icon577_tw := _font_bold.get_string_size("「%s」" % _entry_name(e),
					HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_HEADING).x
			_root.draw_texture_rect(icon577_tex,
					Rect2(r.position.x + 180 + icon577_tw + 14.0,
							r.position.y + 6, 56.0, 56.0), false)
	_root.draw_string(_font_bold, Vector2(r.position.x + 180, r.position.y + 40),
			"「%s」" % _entry_name(e), HORIZONTAL_ALIGNMENT_LEFT, 520,
			UiTheme.FS_HEADING, _entry_name_color(e, UiTheme.INK_900))
'''

# ---------------------------------------------------------------- 5. 起点三选一
PICK_NEW = '''		# R577b：三选一卡片也用那件道具的图标（缺图就不画，名字 / 说明照旧）。
		var ptex := UiAssets.relic_icon(int(RunState.relic_choice[i]))
		if ptex != null:
			draw_texture_rect(ptex,
					Rect2(rect.position + Vector2((rect.size.x - 56.0) * 0.5, 40.0),
							Vector2(56.0, 56.0)), false)
		# R343：传奇道具名走亮金（面板是深底）。
		draw_string(_font_bold, rect.position + Vector2(0, 112), rel.relic_name,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, UiTheme.FS_HEADING,
				rel.name_color(Color("f2ead0")))
		# 描述（字符级换行）
		var y := 150.0
'''

# ---------------------------------------------------------------- 6. 事件提及
EVENT_OLD = '''		if dfont != null:
			_tip_layer.draw_string(dfont,
					Vector2(rr.position.x, rr.position.y + dfont.get_ascent(dfs)),
					str(h["ref"]["token"]), HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, mcol)
		var col := UiTheme.ACCENT_GOLD
'''
EVENT_NEW = '''		if dfont != null:
			_tip_layer.draw_string(dfont,
					Vector2(rr.position.x, rr.position.y + dfont.get_ascent(dfs)),
					str(h["ref"]["token"]), HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, mcol)
		# R577b：这条提及指向道具时，名字右侧紧跟那件道具的小图标。
		# 只画在浮层上，**不动 Label 排版**（R122 以来的老契约）。
		if str(h["ref"].get("kind", "")) == "relic":
			var itex := UiAssets.relic_icon(int(h["ref"].get("id", 0)))
			if itex != null:
				var isz := float(dfs) * 0.9
				_tip_layer.draw_texture_rect(itex,
						Rect2(rr.end.x + 3.0,
								rr.position.y + (rr.size.y - isz) * 0.5,
								isz, isz), false)
		var col := UiTheme.ACCENT_GOLD
'''

# ---------------------------------------------------------------- 7. 测试断言
TEST_ANCHOR = "	# ==== R556：场地卡「毒沼」8082 —— 中毒（回合结束伤害）====\n"
TEST_BLOCK = '''	# ==== R577b：道具小图标（无背景 PNG）+ 界面分发 + 源码锁 ====
	# ① 数据层：60 件道具逐件都有图标（素材断言一律用 ResourceLoader.exists，
	#    导出包里 png 会被 .ctex 取代，FileAccess.file_exists 会假红）。
	var icon577_repo := RelicRepo.load_json()
	var icon577_missing: Array[int] = []
	var icon577_src := FileAccess.get_file_as_string("res://relics.json")
	var icon577_src_ok := true
	for icon577_r: RelicData in icon577_repo.all_relics():
		if not ResourceLoader.exists(UiAssets.relic_icon_path(icon577_r.id)):
			icon577_missing.append(icon577_r.id)
		# 保真锁：回到源头文本核对 id，别让派生列表漂走（R565 口径）
		if not icon577_src.contains('"id": %d' % icon577_r.id):
			icon577_src_ok = false
	check(icon577_missing.is_empty(),
			"R577b 数据层：relics.json 每件道具都有 relic_icon_<id>.png（缺 %s）" % str(icon577_missing))
	check(icon577_src_ok and icon577_repo.all_relics().size() == 60,
			"R577b 保真锁：60 件道具的 id 都能在 relics.json 源文本里找到")
	# ② 取图口：首末两件 + 信物回退
	var icon577_t1 := UiAssets.relic_icon(6001)
	check(icon577_t1 != null and icon577_t1.get_size() == Vector2(128, 128)
			and UiAssets.relic_icon(6060) != null,
			"R577b 取图口：首末两件道具都取到 128x128 图标")
	check(UiAssets.relic_icon(6062) != null,
			"R577b 取图口：信物 6062 回退到 R543 的 key_icon_seed")
	# ③ 界面分发 + 源码锁（四处都走唯一取图口，且缺图仍回退文字）
	var icon577_ms := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
	var icon577_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	var icon577_rp := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	var icon577_es := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	check_src(icon577_ms.contains("UiAssets.relic_icon(") and icon577_ms.contains("if tex == null:"),
			"R577b 源码：地图右侧堆叠换图标且缺图回退文字")
	check_src(icon577_bs.contains("UiAssets.relic_icon(") and icon577_bs.contains("if tex == null:"),
			"R577b 源码：战斗右侧堆叠换图标且缺图回退文字")
	check_src(icon577_rp.contains("UiAssets.relic_icon("),
			"R577b 源码：奖励领取页（列表 / 详情 / 二选一）走图标口")
	check_src(icon577_es.contains("UiAssets.relic_icon("),
			"R577b 源码：事件里提到道具的名字带图标")
'''

# ---------------------------------------------------------------- 8. 命名说明
DOC_NOTE = '''
2026-11-11（R577b）：relic_icon_<id>.png —— 60 件道具的小图标，128 × 128 无背景透明 PNG
  （粗黑描边 / 平涂两级明暗 / 低饱和冷灰蓝；codex 纯文生图批量产出，后期边缘 flood-fill 去白底）。
  · 使用处：地图右侧道具栏、战斗右侧道具栏、奖励列表条目 / 领取详情 / 大宝箱二选一、
    起点道具三选一、事件文案里「」提到道具的名字右侧。
  · 唯一取图口 `UiAssets.relic_icon(id)`；缺图一律回退到原来的文字绘制，不因缺图空白。
  · ⚠️ 三样信物（6061~6063）**不是道具**，仍用 R543 的 key_icon_{screw,seed,dagger}.png；
    `relic_icon()` 对这三个 id 会自动回退到 R543 的图。
  · 源图 / prompt / 去背脚本归档在 art_src/2026-11-11_道具图标_R577/。
'''


def main() -> int:
    # 已落地则跳过：本补丁是一次性替换（锚点在落地后就不存在了），重跑不该破坏文件。
    if "static func relic_icon_path" in load("scripts/ui_assets.gd"):
        print("R577b 补丁已落地，跳过（不会重复插入）")
        return 0
    write = "--write" in sys.argv
    result = {}

    p = "scripts/ui_assets.gd"
    result[p] = exact(load(p), UI_ASSETS_OLD, UI_ASSETS_NEW, "ui_assets 新增 relic_icon 口")

    p = "scripts/map_scene.gd"
    result[p] = lines_between(load(p),
            "\t\t# R343：传奇道具名走亮金（底是来源色 18% 覆在地图上，属深底）。",
            '\t\t\t\tColor("8d8577") if spent else rel.name_color(UiTheme.PAGE_INK))',
            MAP_NEW, "map_scene 右侧堆叠换图标")

    p = "scripts/battle_scene.gd"
    result[p] = lines_between(load(p),
            "\t\t# R309：**不描边**（outline = -1）—— 8~10 号字上 2px 描边会把笔画糊掉，",
            '\t\t\t\tColor("9a9488") if rspent else rel.name_color(Color("4a3c14")), -1)',
            BATTLE_NEW, "battle_scene 右侧堆叠换图标")

    p = "scripts/reward_panel.gd"
    t = load(p)
    t = exact(t, RP_ENTRY_OLD, RP_ENTRY_NEW, "reward 列表条目图标")
    t = exact(t, RP_KEY_OLD, RP_KEY_NEW, "reward 二选一左格图标")
    t = exact(t, RP_DETAIL_OLD, RP_DETAIL_NEW, "reward 领取详情图标")
    result[p] = t

    p = "scripts/relic_pick_scene.gd"
    result[p] = lines_between(load(p),
            "\t\t# R343：传奇道具名走亮金（面板是深底）。",
            "\t\tvar y := 116.0",
            PICK_NEW, "relic_pick 三选一图标")

    p = "scripts/event_scene.gd"
    result[p] = exact(load(p), EVENT_OLD, EVENT_NEW, "event 提及名字带图标")

    p = "scripts/test_engine.gd"
    result[p] = exact(load(p), TEST_ANCHOR, TEST_BLOCK + TEST_ANCHOR, "test_engine R577b 断言")

    p = "assets/ui/图片命名说明.txt"
    t = load(p)
    if "R577b）：relic_icon_" in t:
        MISS.append("doc 已追加过（避免重复）")
        result[p] = t
    else:
        LOG.append("append 图片命名说明 R577b 小节")
        result[p] = t + DOC_NOTE

    print("=== 干跑 / %s ===" % ("写盘" if write else "检查"))
    for line in LOG:
        print(" ", line)
    for line in MISS:
        print(" !!", line)
    if MISS:
        print("MISMATCH %d 处，未写盘" % len(MISS))
        return 1
    if write:
        for path, text in result.items():
            save(path, text)
        print("WROTE %d files" % len(result))
    else:
        print("全部锚点唯一，加 --write 落盘")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
