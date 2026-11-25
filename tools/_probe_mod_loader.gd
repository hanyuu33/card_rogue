extends SceneTree
## R816 探针：mod 层（多目录增量合并）。
##
## 与 R789 的 `_probe_content_override.gd` 是两条链：那条验证「官方热更整份替换」，
## 这条验证「mod 增量合并」。两条都绿，外部内容层才算完整。
##
## 验证清单（缺一条都算没做完）：
##   1. 没有 mod 目录时读到的就是 pck 基线（350 张）
##   2. 单个 mod 新增一张卡 → 347，基线卡不动
##   3. 两个 mod 各加一张 → 350（**可共存**，谁也不用交出整份 cards.json）
##   4. mod 只写 `{id,name}` → 深合并，同卡其余字段仍取基线值
##   5. priority 大的后加载 → 同 id 覆盖时赢
##   6. 坏 mod.json → 该目录跳过，其余 mod 与基线不受影响
##   7. 坏 cards.json → 只跳过这一份，别的 mod 仍生效
##   8. requires 缺依赖 → 该 mod 整条剔除
##   9. i18n 嵌套 dict 深合并：只改一句，其余译名仍在
##  10. 素材覆盖：mod 图生效，且高 priority 的图压过低 priority
##  11. 编辑器 / 回归默认不扫 user://mods
##  12. 全部卸载后回到 350
##
## 不碰玩家存档；临时目录在 user://probe_mods，跑完删掉。

const CARD_ID := 8001                # 基线里的一张玩家卡（只改名字，看其余字段是否还在）
const NEW_A := 90001                 # mod 段（官方卡号段到 9xxx 为止，mod 从 90000 起）
const NEW_B := 90002
const NEW_C := 90003
const NEW_D := 90004

var _ok := 0
var _bad := 0
var _root := ""
var _cfg := ""


func _initialize() -> void:
	_root = ProjectSettings.globalize_path("user://probe_mods").replace("\\", "/")
	_rm_rf(_root)
	DirAccess.make_dir_recursive_absolute(_root)
	# 启停配置也要隔离：否则探针会写脏玩家真实的 user://mods.cfg。
	_cfg = _root.path_join("probe_mods.cfg")
	OS.set_environment(ModRegistry.ENV_CFG, _cfg)

	# ---- 0) 基线 ----
	var base := CardRepo.load_json()
	var base_count := base.all_cards().size()
	var proto := _proto_card()
	var base_card := base.get_card(CARD_ID)
	_check("基线 350 张", base_count == 350, str(base_count))
	_check("基线原型卡可读", not proto.is_empty() and base_card != null, str(proto.size()))
	var base_cost := base_card.cost if base_card != null else -1
	var base_power := base_card.power if base_card != null else -1

	# ---- 11) 编辑器默认不扫 user://mods ----
	OS.set_environment(ModRegistry.ENV_MODS, "")
	OS.set_environment(DataPaths.ENV_ROOT, "")
	DataPaths.reset_root()
	_check("未设环境变量时不扫 mod（编辑器口径）", ModRegistry.load_order().is_empty(),
			str(ModRegistry.load_order().size()))

	OS.set_environment(ModRegistry.ENV_MODS, _root)
	DataPaths.reset_root()

	# ---- 1) 空 mod 根 ----
	_check("空 mod 根 = 基线 350", CardRepo.load_json().all_cards().size() == 350,
			str(CardRepo.load_json().all_cards().size()))

	# ---- 2) 单 mod 加一张 ----
	_mk("mod_a", {"id": "a", "name": "A", "priority": 10}, {
		"cards.json": {"cards": [_clone(proto, NEW_A, "PROBE_A")]},
	})
	DataPaths.reset_root()
	var r2 := CardRepo.load_json()
	_check("单 mod 加卡后 351", r2.all_cards().size() == 351, str(r2.all_cards().size()))
	_check("新卡 id 读得到", r2.get_card(NEW_A) != null)
	_check("新卡名字正确", r2.get_card(NEW_A).card_name == "PROBE_A" if r2.get_card(NEW_A) != null else "null")

	# ---- 3) 两个 mod 共存 ----
	_mk("mod_b", {"id": "b", "name": "B", "priority": 20}, {
		"cards.json": {"cards": [_clone(proto, NEW_B, "PROBE_B")]},
	})
	DataPaths.reset_root()
	var r3 := CardRepo.load_json()
	_check("两个 mod 共存 = 352", r3.all_cards().size() == 352, str(r3.all_cards().size()))
	_check("A 的卡还在", r3.get_card(NEW_A) != null)
	_check("B 的卡也在", r3.get_card(NEW_B) != null)

	# ---- 4) 只写 id + name → 深合并，不吞字段 ----
	_mk("mod_c", {"id": "c", "name": "C", "priority": 30}, {
		"cards.json": {"cards": [{"id": CARD_ID, "name": "RENAMED_ONLY"}]},
	})
	DataPaths.reset_root()
	var r4 := CardRepo.load_json()
	var c4 := r4.get_card(CARD_ID)
	_check("深合并：名字变了", c4 != null and c4.card_name == "RENAMED_ONLY",
			c4.card_name if c4 != null else "null")
	_check("深合并：cost 仍是基线值", c4 != null and c4.cost == base_cost,
			"%d / %d" % [c4.cost if c4 != null else -1, base_cost])
	_check("深合并：power 仍是基线值", c4 != null and c4.power == base_power,
			"%d / %d" % [c4.power if c4 != null else -1, base_power])
	_check("深合并后总数仍是 352", r4.all_cards().size() == 352, str(r4.all_cards().size()))

	# ---- 5) priority 仲裁 ----
	_mk("mod_lo", {"id": "lo", "name": "LO", "priority": 40}, {
		"cards.json": {"cards": [{"id": CARD_ID, "name": "FROM_LOW"}]},
	})
	_mk("mod_hi", {"id": "hi", "name": "HI", "priority": 90}, {
		"cards.json": {"cards": [{"id": CARD_ID, "name": "FROM_HIGH"}]},
	})
	DataPaths.reset_root()
	var r5 := CardRepo.load_json()
	_check("priority 高的后加载并赢", r5.get_card(CARD_ID).card_name == "FROM_HIGH",
			r5.get_card(CARD_ID).card_name)

	# ---- 6) 坏清单 ----
	_mk("mod_bad_manifest", {"name": "没有 id"}, {})
	_mk("mod_broken_json", {"id": "broken"}, {"cards.json": "{ this is not json"})
	DataPaths.reset_root()
	var r6 := CardRepo.load_json()
	_check("坏清单目录被跳过", r6.all_cards().size() == 352, str(r6.all_cards().size()))
	## problems 只记「清单层」问题（坏清单 / 缺依赖 / 重复 id）。
	## 坏 cards.json 属于数据层，由 DataPaths 自己 push_warning，刻意不进这里 ——
	## 分层清楚，将来管理页才能分开显示「这个 mod 装坏了」和「这个 mod 的数据有一处跳过了」。
	_check("坏清单被记进 problems", ModRegistry.problems().size() == 1,
			str(ModRegistry.problems()))

	# ---- 7) 坏 cards.json 只伤自己 ----
	_mk("mod_d", {"id": "d", "priority": 50}, {
		"cards.json": {"cards": [_clone(proto, NEW_C, "PROBE_C")]},
	})
	DataPaths.reset_root()
	_check("坏 mod 不影响新 mod", CardRepo.load_json().get_card(NEW_C) != null)
	_check("坏 mod 不影响 A 的卡", CardRepo.load_json().get_card(NEW_A) != null)

	# ---- 8) 缺依赖 ----
	_mk("mod_needs", {"id": "needs", "priority": 60, "requires": ["not_installed"]}, {
		"cards.json": {"cards": [_clone(proto, NEW_D, "PROBE_D")]},
	})
	DataPaths.reset_root()
	var r8 := CardRepo.load_json()
	_check("缺依赖的 mod 被剔除", r8.get_card(NEW_D) == null)
	_check("剔除后总数不变（353 = 350 + A/B/C）", r8.all_cards().size() == 353, str(r8.all_cards().size()))

	# ---- 9) i18n 深合并 ----
	## 先切到 en 再取基线：zh 分支下 card_name 走的是原文，拿不到英文表。
	GameSettings.ensure_loaded()
	GameSettings.language = "en"
	GameI18n.reset_cache()
	var en_base := _en_name(CARD_ID)
	var en_other := _en_name(8002)
	_mk("mod_i18n", {"id": "i18n", "priority": 70}, {
		"i18n/cards_en.json": {"cards": {str(CARD_ID): {"name": "MODDED_EN"}}},
	})
	DataPaths.reset_root()
	GameI18n.reset_cache()
	var en_now := _en_name(CARD_ID)
	_check("i18n 深合并：改动生效", en_now == "MODDED_EN", en_now)
	_check("i18n 深合并：别的卡译文没丢", _en_name(8002) == en_other,
			"%s / %s" % [_en_name(8002), en_other])
	_check("i18n 基线值确实不同（防假绿）", en_base != "MODDED_EN", en_base)

	# ---- 10) 素材覆盖 + 高 priority 压制 ----
	var pic := "res://assets/pics/%d.png" % CARD_ID
	var base_tex := DataPaths.load_texture(pic)
	var base_size := base_tex.get_size() if base_tex != null else Vector2.ZERO
	_check("基线卡图可读", base_tex != null, str(base_size))
	_mk_png("mod_a", "assets/pics/%d.png" % CARD_ID, 7, 5)
	DataPaths.reset_root()
	var t_a := DataPaths.load_texture(pic)
	_check("mod 图生效（7x5）", t_a != null and t_a.get_size() == Vector2(7, 5),
			str(t_a.get_size()) if t_a != null else "null")
	_mk_png("mod_hi", "assets/pics/%d.png" % CARD_ID, 3, 4)
	DataPaths.reset_root()
	var t_hi := DataPaths.load_texture(pic)
	_check("高 priority 的图压过低 priority（3x4）", t_hi != null and t_hi.get_size() == Vector2(3, 4),
			str(t_hi.get_size()) if t_hi != null else "null")

	# ---- 11b) 启停（R818）----
	# 停用 = 不进 load_order，但仍在 all_mods 里（设置页还要能列出来再打开）。
	var before_off := CardRepo.load_json().all_cards().size()
	_check("启停：停用前是 353", before_off == 353, str(before_off))
	ModRegistry.set_enabled("a", false)
	DataPaths.reset_root()
	var r_off := CardRepo.load_json()
	_check("停用后 A 的卡消失", r_off.get_card(NEW_A) == null)
	_check("停用后总数 352", r_off.all_cards().size() == 352, str(r_off.all_cards().size()))
	_check("停用后 all_mods 仍列得出它", _has_mod("a"), str(ModRegistry.all_mods().size()))
	_check("is_enabled(a) = false", not ModRegistry.is_enabled("a"))
	_check("cfg 已落盘", FileAccess.file_exists(_cfg), _cfg)
	# 重新启用：配置写回 + 数据层重算，卡要原样回来
	ModRegistry.set_enabled("a", true)
	DataPaths.reset_root()
	var r_on := CardRepo.load_json()
	_check("重新启用后回到 353", r_on.all_cards().size() == 353, str(r_on.all_cards().size()))
	_check("is_enabled(a) = true", ModRegistry.is_enabled("a"))

	# ---- 12) 全部卸载 ----
	OS.set_environment(ModRegistry.ENV_MODS, "")
	OS.set_environment(ModRegistry.ENV_CFG, "")
	OS.set_environment(DataPaths.ENV_ROOT, "")
	DataPaths.reset_root()
	GameSettings.language = "zh"
	GameI18n.reset_cache()
	_rm_rf(_root)
	var after := CardRepo.load_json()
	_check("卸载后回到 350", after.all_cards().size() == 350, str(after.all_cards().size()))
	_check("卸载后卡名回基线", after.get_card(CARD_ID).card_name == base_card.card_name,
			after.get_card(CARD_ID).card_name)

	print("MOD LOADER: %d pass / %d fail" % [_ok, _bad])
	quit(0 if _bad == 0 else 1)


# ---------------------------------------------------------------- helpers

## 从基线 cards.json 里捞一张完整卡当原型，避免手工写全字段。
func _proto_card() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://cards.json"))
	if not (raw is Dictionary):
		return {}
	for c: Variant in (raw as Dictionary).get("cards", []):
		if c is Dictionary and int((c as Dictionary).get("id", 0)) == CARD_ID:
			return c
	return {}


func _clone(proto: Dictionary, id: int, card_name: String) -> Dictionary:
	var d: Dictionary = proto.duplicate(true)
	d["id"] = id
	d["name"] = card_name
	return d


func _en_name(cid: int) -> String:
	return GameI18n.card_name(cid, "__MISSING__")


func _mk(name: String, manifest: Variant, files: Dictionary) -> void:
	var dir := _root.path_join(name)
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("mod.json"), JSON.stringify(manifest, "  "))
	for rel: String in files.keys():
		var p := dir.path_join(rel)
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		var v: Variant = files[rel]
		if v is String:
			_write(p, v)
		else:
			_write(p, JSON.stringify(v, "  "))


func _mk_png(mod_name: String, rel: String, w: int, h: int) -> void:
	var p := _root.path_join(mod_name).path_join(rel)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	img.save_png(p)


func _has_mod(id: String) -> bool:
	for m: Dictionary in ModRegistry.all_mods():
		if str(m["id"]) == id:
			return true
	return false


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
