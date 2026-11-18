extends SceneTree
## R789 探针：验证 `content/` 覆盖层（热更通道）。
##
## 覆盖四件事，缺一不可：
##   1. 没有覆盖目录时，读到的就是 pck 基线（331 张卡，卡名不变）；
##   2. 放一份改过卡名的 cards.json → 覆盖生效，数量仍为 331（整份替换，不是合并）；
##   3. 覆盖文件坏掉（语法错 / `{"cards": []}`）→ 自动回落基线，不崩；
##   4. 译文 JSON 同样走覆盖（改一句文案 = 一个十几 KB 的文件）。
##
## 只读仓库文件；临时目录写在 `user://patch_probe`，跑完删掉，不碰玩家存档。

const CARD_ID := 8001
const MARK_ZH := "OVERRIDE_ZH"
const MARK_EN := "OVERRIDE_EN"

var _ok := 0
var _bad := 0


func _initialize() -> void:
	## 目录名故意带空格 + 中文：Steam 默认装在 "Program Files (x86)" 这类路径下，
	## 覆盖层必须能吃下空格与非 ASCII。
	var tmp := ProjectSettings.globalize_path("user://patch probe dir").replace("\\", "/")
	_rm_rf(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)

	# ---- 1) 基线 ----
	var base := CardRepo.load_json()
	var base_count := base.all_cards().size()
	var base_name := ""
	if base.get_card(CARD_ID) != null:
		base_name = base.get_card(CARD_ID).card_name
	_check("基线卡牌 331 张", base_count == 331, str(base_count))
	_check("基线卡名非空", base_name != "", base_name)

	# ---- 2) 覆盖 cards.json ----
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://cards.json"))
	if raw is Dictionary:
		for c: Variant in (raw as Dictionary).get("cards", []):
			if c is Dictionary and int((c as Dictionary).get("id", 0)) == CARD_ID:
				(c as Dictionary)["name"] = MARK_ZH
		_write(tmp.path_join("cards.json"), JSON.stringify(raw, "  "))

	OS.set_environment(DataPaths.ENV_ROOT, tmp)
	DataPaths.reset_root()
	var ov := CardRepo.load_json()
	var ov_name := ""
	if ov.get_card(CARD_ID) != null:
		ov_name = ov.get_card(CARD_ID).card_name
	_check("覆盖生效（卡名）", ov_name == MARK_ZH, ov_name)
	_check("覆盖后仍是 331 张", ov.all_cards().size() == 331, str(ov.all_cards().size()))

	# ---- 3) 坏文件回落 ----
	_write(tmp.path_join("cards.json"), "{ this is not json")
	var broken := CardRepo.load_json()
	_check("坏 JSON 回落基线", broken.all_cards().size() == 331 and broken.get_card(CARD_ID).card_name == base_name,
			"%d / %s" % [broken.all_cards().size(), broken.get_card(CARD_ID).card_name])

	_write(tmp.path_join("cards.json"), "{\"cards\": []}")
	var empty := CardRepo.load_json()
	_check("空结构回落基线", empty.all_cards().size() == 331, str(empty.all_cards().size()))

	# ---- 4) 译文 JSON 覆盖 ----
	var en: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/cards_en.json"))
	if en is Dictionary:
		var trows: Variant = (en as Dictionary).get("cards", {})
		if trows is Dictionary and (trows as Dictionary).has(str(CARD_ID)):
			(trows as Dictionary)[str(CARD_ID)]["name"] = MARK_EN
		DirAccess.make_dir_recursive_absolute(tmp.path_join("i18n"))
		_write(tmp.path_join("i18n/cards_en.json"), JSON.stringify(en, "  "))
		# 先让设置读一次盘：ensure_loaded 只在首次调用时加载，
		# 否则紧接着的 language() 会把下面赋的值覆盖回 settings.cfg 里的 zh。
		GameSettings.ensure_loaded()
		GameSettings.language = "en"
		GameI18n.reset_cache()
		var got := GameI18n.card_name(CARD_ID, "FALLBACK")
		_check("译文覆盖生效", got == MARK_EN, got)

	# ---- 5) 收尾：清掉覆盖，回到基线 ----
	GameSettings.language = "zh"
	GameI18n.reset_cache()
	OS.set_environment(DataPaths.ENV_ROOT, "")
	DataPaths.reset_root()
	_rm_rf(tmp)
	var after := CardRepo.load_json()
	var after_name := ""
	if after.get_card(CARD_ID) != null:
		after_name = after.get_card(CARD_ID).card_name
	_check("移除覆盖后回到基线", after_name == base_name and after.all_cards().size() == base_count,
			"%s / %d" % [after_name, after.all_cards().size()])

	print("CONTENT OVERRIDE: %d pass / %d fail" % [_ok, _bad])
	quit(0 if _bad == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if ok:
		_ok += 1
		print("  ✓ ", label)
	else:
		_bad += 1
		print("  ✗ ", label, "  -> ", detail)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_bad += 1
		print("  ✗ 写不进去：", path)
		return
	f.store_string(text)
	f.close()


func _rm_rf(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var child := path.path_join(name)
		if d.current_is_dir():
			_rm_rf(child)
		else:
			DirAccess.remove_absolute(child)
		name = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(path)
