class_name GameBrand
## 品牌 / 标题配置（R578）：**游戏名的唯一来源**。
##
## 想改名字（比如上 Steam 时换成正式名 / 加英文名）时，**只改这里**就够了 ——
## 窗口标题、标题页大标题、副标题、底部版本串、鸣谢页抬头全部从这里取。
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
const NAME_CN := "卡牌肉鸽"

## 英文名。留空 = 不展示；上 Steam 后填商店英文名，窗口标题会变成「中文名 (English)」。
const NAME_EN := ""

## 副标题模板。`{v}` 会被 VERSION 替换，想改文案只动这一行。
const SUBTITLE := "肉鸽版 · v{v}"

## 版本号（单一来源）：副标题、右下角版本串都从这里取。
const VERSION := "1.0"

## 右下角版本串模板。`{v}` → VERSION。
const FOOTER := "v{v}-rogue · 肉鸽开发版"

# ------------------------------------------------------------ 排版

## 标题页大标题字号（与 title.tscn 的 theme_override font_size 保持一致；
## 名字太长时 title_scene 会自动往下缩，这个值是**起点**）。
const TITLE_FONT_SIZE := 64

## 中文短名是否逐字加空格（「卡牌肉鸽」→「卡 牌 肉 鸽」的中式标题排版）。
const TITLE_SPACED := true


# ------------------------------------------------------------ 取值接口

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


static func subtitle() -> String:
	## 副标题（带版本号）。
	return SUBTITLE.replace("{v}", VERSION)


static func footer_text() -> String:
	## 右下角版本串。
	return FOOTER.replace("{v}", VERSION)
