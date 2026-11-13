class_name GameBrand

## R660：只给 `title_text_localized()` 用来判断当前界面语言。
## l10n.gd 不反向依赖本文件，不会成环。
const L10n = preload("res://scripts/l10n.gd")

## 品牌 / 标题配置（R578）：**游戏名的唯一来源**。
##
## 想改名字（比如上 Steam 时换成正式名 / 加英文名）时，**只改这里**就够了 ——
## 窗口标题、标题页大标题、底部版本串、鸣谢页抬头全部从这里取。
## （R579：标题页副标题已移除 —— 名字之外只剩大标题 / 底部署名，
##  别再把「肉鸽版 · v1.0」这类字样塞回来，店长明确不要。）
## （R607 店长口径再收紧：**全游戏不设副标题** —— 任何界面都不给游戏名加第二行，
##  包括标题主视觉里也不要画英文副标。R605 曾把 QUACKILL 画进 title_art，
##  因按钮遮挡且属于副标题，已撤掉；`tools/_compose_r604_art.py` 现默认不画英文，
##  要画必须显式 `--with-en`。窗口标题的「中文名 (English)」是 OS 层标题栏，
##  不是游戏内副标题，保留 —— 它也是 Steam 截图识别英文名的唯一现场。）
##
## ⚠️ 但有三件事这个文件管不到，改名前必须一起处理：
##   1. `export_presets.cfg` 的 `application/product_name` + `package/name`
##      —— 决定导出的 exe 文件名 / Android 应用名，改这里不会跟着变。
##   2. `project.godot` 的 `config/name` —— **决定 `user://` 存档目录名**！
##      目录名一变，老玩家的 profile.json / run_save.sav 看起来就「消失」了
##      （实际是躺在旧目录里）。**已经发布过的版本绝不要动它**，
##      真要改必须配一段存档迁移代码。
##   3. Steamworks 后台的商店名 / AppID —— 那侧是独立配置。
## 这三条已由 test_engine 的 R578 源码锁钉住（防止被顺手改掉）。

# ------------------------------------------------------------ 名字

## 中文名（正式名）。留空会退化成 "Untitled"，不会画出空标题。
const NAME_CN := "嘎嘎乱杀"

## 英文名。留空 = 不展示；上 Steam 后填商店英文名，窗口标题会变成「中文名 (English)」。
const NAME_EN := "Quackill"

## 厂牌署名（R604）：片头卡 + Steamworks 后台的 Developer 字段要填同一个名字。
## R604b 定案：`risusumai`（店长敲定）—— 全小写单词，片头只出一行英文；
## 中文侧不再另起名，省掉一个要多查一次的商标。
const STUDIO_CN := ""

## 厂牌英文名。片头按温和字距逐字浮现；留空则只出中文。
const STUDIO_EN := "risusumai"

## 版本号（单一来源）：右下角版本串从这里取。
const VERSION := "1.0"

## 右下角版本串模板。`{v}` → VERSION。
const FOOTER := "v{v}-rogue · 肉鸽开发版"

# ------------------------------------------------------------ 排版

## 标题页大标题字号（与 title.tscn 的 theme_override font_size 保持一致；
## 名字太长时 title_scene 会自动往下缩，这个值是**起点**）。
const TITLE_FONT_SIZE := 64

## 中文短名是否逐字加空格（「嘎嘎乱杀」→「嘎 嘎 乱 杀」的中式标题排版）。
const TITLE_SPACED := true


# ------------------------------------------------------------ 取值接口

static func studio_text() -> String:
	## 片头卡上的厂牌署名（中文优先）。两边都空时返回空串，片头自动跳过这一行。
	if STUDIO_CN != "":
		return STUDIO_CN
	return STUDIO_EN


static func display_name() -> String:
	## 正式名（中文优先）。空字符串时给个不会画崩的兜底。
	if NAME_CN == "":
		return "Untitled"
	return NAME_CN


static func window_title() -> String:
	## 窗口标题栏文字。有英文名时带上它 —— Steam 版的窗口标题最好和商店名对得上。
	if NAME_EN == "":
		return display_name()
	return "%s (%s)" % [display_name(), NAME_EN]


static func spaced(s: String) -> String:
	## 中式标题排版：字与字之间插一个空格。
	## **只对「全 CJK、2~6 字、无空格」生效**；英文 / 长名 / 已带空格的原样返回，
	## 否则 "CardRogue" 会变成 "C a r d R o g u e"。
	var n := s.length()
	if n < 2 or n > 6:
		return s
	for i in n:
		var ch := s.substr(i, 1)
		if ch == " ":
			return s
		var c := s.unicode_at(i)
		# CJK 部首扩展 ~ CJK 统一表意文字末尾
		if c < 0x2E80 or c > 0x9FFF:
			return s
	var out := ""
	for i in n:
		if i > 0:
			out += " "
		out += s.substr(i, 1)
	return out


static func title_text() -> String:
	## 标题页大标题文字。
	if not TITLE_SPACED:
		return display_name()
	return spaced(display_name())


static func footer_text() -> String:
	## 右下角版本串。
	return FOOTER.replace("{v}", VERSION)


static func title_text_localized() -> String:
	## R660：按**当前界面语言**取大标题。非中文用英文名，中文走 `title_text()`。
	## 仍然是**一行**、不是副标题 —— 只是换掉主标题本体的文字，R607 口径不变。
	## ⚠️ 英文名只在这里读：`title_scene.gd` 里出现 `NAME_EN` 会踩 R607 源码锁
	## （「标题页不另起第二行」）。品牌名要露脸也必须从 GameBrand 出去。
	if L10n.current() != "zh" and NAME_EN != "":
		return spaced(NAME_EN)
	return title_text()
