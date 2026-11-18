extends SceneTree
## R789 探针：验证 `content/` 覆盖层（热更通道）。
##
## 覆盖四件事，缺一不可：
##   1. 没有覆盖目录时，读到的就是 pck 基线（332 张卡，卡名不变）；
##   2. 放一份改过卡名的 cards.json → 覆盖生效，数量仍为 332（整份替换，不是合并）；
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
	_check("基线卡牌 332 张", base_count == 332, str(base_count))
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
	_check("覆盖后仍是 332 张", ov.all_cards().size() == 332, str(ov.all_cards().size()))

	# ---- 3) 坏文件回落 ----
	_write(tmp.path_join("cards.json"), "{ this is not json")
	var broken := CardRepo.load_json()
	_check("坏 JSON 回落基线", broken.all_cards().size() == 332 and broken.get_card(CARD_ID).card_name == base_name,
			"%d / %s" % [broken.all_cards().size(), broken.get_card(CARD_ID).card_name])

	_write(tmp.path_join("cards.json"), "{\"cards\": []}")
	var empty := CardRepo.load_json()
	_check("空结构回落基线", empty.all_cards().size() == 332, str(empty.all_cards().size()))

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

	# ---- 4b) 素材覆盖：替换 / 新增 / 坏图 ----
	# 图片是体积最大的一类，必须能「改一张只下一个文件」，否则每次换卡图都是重下整包。
	var card_pic := "res://assets/pics/%d.png" % CARD_ID
	var base_tex := DataPaths.load_texture(card_pic)
	var base_size := base_tex.get_size() if base_tex != null else Vector2.ZERO
	_check("基线卡图可读", base_tex != null, str(base_size))

	var art_dir := tmp.path_join("assets/pics")
	DirAccess.make_dir_recursive_absolute(art_dir)
	var probe_img := Image.create(7, 5, false, Image.FORMAT_RGBA8)
	probe_img.fill(Color(1, 0, 0, 1))
	probe_img.save_png(art_dir.path_join("%d.png" % CARD_ID))
	_check("覆盖图被识别为存在", DataPaths.has_asset_override(card_pic))
	var ov_tex := DataPaths.load_texture(card_pic)
	_check("覆盖图生效（尺寸 7x5）", ov_tex != null and ov_tex.get_size() == Vector2(7, 5),
			str(ov_tex.get_size()) if ov_tex != null else "null")
	_check("CardFace 认覆盖图", CardFace._pic_exists(card_pic))

	# 新增：基线里没有的图也能直接读到（新卡图不用重导 pck）
	var fresh := "res://assets/ui/_probe_fresh.png"
	DirAccess.make_dir_recursive_absolute(tmp.path_join("assets/ui"))
	probe_img.save_png(tmp.path_join("assets/ui/_probe_fresh.png"))
	_check("新增图判存", DataPaths.asset_exists(fresh))
	_check("新增图可读", DataPaths.load_texture(fresh) != null)

	# 坏图：写垃圾字节 → 回落基线，不能崩、不能变空白
	_write(art_dir.path_join("%d.png" % CARD_ID), "not a png at all")
	var fallback_tex := DataPaths.load_texture(card_pic)
	_check("坏图回落基线", fallback_tex != null and fallback_tex.get_size() == base_size,
			str(fallback_tex.get_size()) if fallback_tex != null else "null")

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


func _check(label: String, ok: bool, detail := "") -> void:
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
