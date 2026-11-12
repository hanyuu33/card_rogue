extends SceneTree
## 图鉴内存探针（R613 排查「安卓点图鉴闪退」）
##
## 目的：量化「把图鉴里的卡图全走一遍」会在 `CardFace._art_cache` 里常驻多少纹理内存。
## 该缓存是 `static` —— 场景切走也不释放，所以这个数字等于「进去一次就永久吃掉的量」。
##
## 用法（无需联网、不写存档）：
##   Godot_v4.3-stable_win64_console.exe --headless --path . --script res://tools/probe_gallery_mem.gd
##
## 判据：安卓 app 进程常驻上限通常在 512MB 上下（低端机更低）。
##      纹理单独占 ---- 见输出 ---- 一旦逼近上限，切场景时的瞬时峰值就会 OOM 闪退。

func _initialize() -> void:
	var repo := CardRepo.load_json()
	var cards := repo.all_cards()
	var total_bytes := 0
	var loaded := 0
	var nulls := 0
	var t0 := Time.get_ticks_msec()
	for c in cards:
		var tex: Texture2D = CardFace.art_for(c.id)
		if tex == null:
			nulls += 1
			continue
		loaded += 1
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		total_bytes += w * h * 4
	var dt := Time.get_ticks_msec() - t0

	print("--------------------------------------------------")
	print("卡牌总数            = %d" % cards.size())
	print("成功取到卡图        = %d" % loaded)
	print("取不到（null）      = %d" % nulls)
	print("_art_cache 条目数   = %d" % CardFace._art_cache.size())
	print("纹理解码合计        = %.1f MB   (RGBA, w*h*4)" % (total_bytes / 1048576.0))
	print("全部加载耗时        = %d ms" % dt)
	print("--------------------------------------------------")
	print("提示：纹理常驻 + 字体动态图集 + 其他场景资源 = 进程峰值。")
	print("      若实测接近设备上限，则「进图鉴即闪退」= OOM，不是代码空引用。")
	quit()
