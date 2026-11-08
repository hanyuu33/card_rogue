extends SceneTree
## 关卡数据导出（通用工具，不带轮次后缀）。
##
## 用法：
##   godot --headless --script tools/dump_levels.gd --path . -- --out _levels_dump.json
##   （不传 --out 时默认写 res://_levels_dump.json）
##
## 为什么要有这个脚本：关卡数据住在 `scripts/game_levels.gd`（GDScript 字面量），
## Python 侧无法可靠解析；而**任何文档 / 表格都必须以代码为唯一数据源**，
## 所以这里把 `builtin_levels()` / `cave_level()` / 各层抽取池原样导成 JSON，
## 再由 `_leveltable.py` 排版成 md + html。
##
## 导出前做的两件事：
##   1. 补派生字段：`index`（列表序号）、`tier_name`、`enemy_hp_final`（走 `enemy_hp_of()`，
##      含精英 +10 / Boss +20 与整体 ×2 —— 文档里显示的必须是**玩家真正看到的那条血条**）；
##   2. 递归把 `Vector2i` 转成 `[x, y]`（JSON 不支持 Vector2i，直接 stringify 会失败）。

const GL = preload("res://scripts/game_levels.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := {}
	var levels: Array = []
	var idx := 0
	for lvl: Dictionary in GL.builtin_levels():
		idx += 1
		var d: Dictionary = lvl.duplicate(true)
		d["index"] = idx
		d["tier_name"] = GL.tier_name(int(d.get("tier", -1)))
		d["enemy_hp_final"] = GL.enemy_hp_of(d)
		levels.append(d)
	out["levels"] = levels

	var cave: Dictionary = GL.cave_level().duplicate(true)
	cave["tier_name"] = GL.tier_name(int(cave.get("tier", -1)))
	cave["enemy_hp_final"] = GL.enemy_hp_of(cave)
	out["cave"] = cave

	# 彩蛋 Boss「恶魔鸭（复仇）」（R73）：同样**不进** builtin_levels / boss_pool，
	# 只由 RunState 在第一层摇到「恶魔鸭」且 50% 命中时顶替第二层 Boss。
	# 和洞穴一样属于「定义里有、池子里没有」，文档必须列出来，否则总数对不上。
	var revenge: Dictionary = GL.revenge_boss().duplicate(true)
	revenge["tier_name"] = GL.tier_name(int(revenge.get("tier", -1)))
	revenge["enemy_hp_final"] = GL.enemy_hp_of(revenge)
	out["revenge"] = revenge

	# 各层抽取池：普通 / 精英 / Boss（第三层另有「精英专用池」）
	# ⚠️ Boss 要导**两套**：`boss_pool()` = 本层所有可摇的 Boss（开局从中摇 1 只），
	# `boss_level()` = 确定性兜底（同层多 Boss 时只返回第一个）。只导后者会让人误以为
	# 第一层只有「远古虚骨龙」一只 Boss。
	var pools := {}
	for layer in [1, 2, 3]:
		pools["normal_%d" % layer] = _keys(GL.normal_pool(layer))
		pools["elite_%d" % layer] = _keys(GL.elite_pool(layer))
		pools["boss_all_%d" % layer] = _keys(GL.boss_pool(layer))
		pools["boss_default_%d" % layer] = _keys(GL.boss_level(layer))
	pools["third_elite"] = _keys(GL.third_elite_pool())
	out["pools"] = pools

	# 常量口径（文档里要解释「敌方 HP 是怎么算出来的」）
	out["consts"] = {
		"elite_hp_bonus": GL.ENEMY_HP_ELITE_BONUS,
		"boss_hp_bonus": GL.ENEMY_HP_BOSS_BONUS,
		"hp_multiplier": GL.ENEMY_HP_MULTIPLIER,
	}

	var path := "res://_levels_dump.json"
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--out" and i + 1 < argv.size():
			path = argv[i + 1]
			if not path.begins_with("res://") and not path.begins_with("user://"):
				path = "res://" + path
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("dump_levels：无法写入 %s" % path)
		quit(1)
		return
	f.store_string(JSON.stringify(_clean(out), "  "))
	f.close()
	print("WROTE %s  levels=%d  pools=%d" % [path, levels.size(), (out["pools"] as Dictionary).size()])
	quit()


func _keys(a) -> Array:
	## 池里可能混着 Dictionary（正常）—— 统一取 key，另有 boss_level 返回单个字典。
	var out := []
	if a is Dictionary:
		out.append(str(a.get("key", "")))
		return out
	for x in a:
		if x is Dictionary:
			out.append(str(x.get("key", "")))
	return out


func _clean(v):
	## JSON 不支持 Vector2i / Vector2 —— 转成 [x, y]；其余原样递归。
	if v is Vector2i:
		return [v.x, v.y]
	if v is Vector2:
		return [v.x, v.y]
	if v is Array:
		var a := []
		for x in v:
			a.append(_clean(x))
		return a
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[str(k)] = _clean(v[k])
		return d
	return v
