extends SceneTree
## R821 探针：运行时 RelicRepo 读到的猴爪 / 机械臂描述到底是什么。
## 用途：分辨「数据没改」还是「用户装的是旧包」。

func _init() -> void:
	var repo := RelicRepo.load_json()
	for id in [6066, 6065]:
		var r: RelicData = repo.get_relic(id)
		if r == null:
			print("PROBE %d = <missing>" % id)
		else:
			print("PROBE %d name=[%s] tier=[%s]" % [id, r.relic_name, r.tier])
			print("PROBE %d desc=[%s]" % [id, r.desc])
	print("PROBE lang=", GameI18n.language())
	print("PROBE content_root=[", DataPaths.content_root(), "]")
	quit()
