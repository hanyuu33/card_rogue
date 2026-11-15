extends SceneTree
## Steam 成就自检工具（R740）
##
## 目的：一条命令验完「插件装了没 / Steamworks 连上没 / 后台成就名对不对 /
## 能不能真的解锁」，把 Steam 接入从「凭感觉」变成可回归的检查项。
##
## 用法（在项目根执行）：
##   Godot.exe --headless --path . --script res://tools/steam_selftest.gd
##   Godot.exe --headless --path . --script res://tools/steam_selftest.gd -- --appid 480
##   Godot.exe --headless --path . --script res://tools/steam_selftest.gd -- --unlock
##
##   --appid N  临时指定 AppID（本地调试用；不传则走 SteamAchievements 的三级回落）
##   --hooks    再走一遍生产钩子（6 个 note_*），打印「事件 → 成就」映射（需 Steamworks 已连上）
##   --unlock   真的对这 N 个成就调 setAchievement + storeStats，并读回校验
##              ⚠️ 会污染当前登录账号的成就状态，只在测试 App（如 480）或自有 App 的
##                 开发分支上用；Steamworks 后台可用 Reset All Stats 清。
##
## 退出码：0 全绿 / 1 插件没加载 / 2 Steamworks 没连上 / 3 后台成就名对不上 / 4 解锁失败
##
## 注意：本文件在 `tools/` 下，已在 export_presets.cfg 的 exclude_filter 里，不会进发行包。

const SA_PATH := "res://scripts/steam_achievements.gd"

## 代码侧应有的成就条数（R740：8 → 9，新增 CLEAR_APEX）。
## 只用来提醒「加了成就别忘了同步后台与文档」，不参与解锁逻辑。
const EXPECTED_COUNT := 9

var _fail := 0
var _steam: Object = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var do_unlock := args.has("--unlock")
	var override_appid := _arg_int(args, "--appid")

	print("================================================================")
	print(" Steam 成就自检 | engine ", Engine.get_version_info().string)
	print("================================================================")

	# ---- 1. 插件是否加载 ----
	if not Engine.has_singleton("Steam"):
		print("[FAIL] GodotSteam 未加载：Engine.has_singleton(\"Steam\") == false")
		print("       检查 addons/godotsteam/ 是否存在，且 .godot/extension_list.cfg 里有它")
		print("       （编辑器打开一次工程会自动写入；CI/无头环境需手写该行）")
		_quit(1)
		return
	_steam = Engine.get_singleton("Steam")
	print("[ok] GodotSteam 已加载，Steam 单例可用（%d 个方法）" % _steam.get_method_list().size())

	# ---- 2. 代码侧成就名单（从常量表读，不手写副本，避免两处不同步）----
	var sa: GDScript = load(SA_PATH)
	var expected := _collect_api_names(sa)
	print("[..] 代码侧成就 %d 个：" % expected.size())
	for api in expected:
		print("       - ", api)
	if expected.size() != EXPECTED_COUNT:
		print("[WARN] 预期 %d 个，实际 %d 个 —— 若这是有意增删，请同步 release/steam_achievements.md"
			% [EXPECTED_COUNT, expected.size()])

	# ---- 3. 初始化 Steamworks（走生产同一条路：SteamAchievements.init）----
	if override_appid > 0:
		sa.set_app_id_override(override_appid)
		print("[..] AppID 已临时覆盖为 %d" % override_appid)
	sa.init()
	var ready: bool = sa.is_ready()
	print("[%s] Steamworks 状态：%s" % ["ok" if ready else "FAIL", sa.status_text()])
	if not ready:
		print("       常见原因：Steam 客户端没开（status 2）/ AppID 无效或未配置（status 79）")
		print("       本地自测可加 -- --appid 480（Valve 公开测试 App）")
		_quit(2)
		return

	var real_appid := int(_steam.call("getAppID"))
	print("[ok] 实际 AppID = %d，登录账号 = %s" % [real_appid, str(_steam.call("getPersonaName"))])

	# ---- 4. 后台成就名单 vs 代码名单 ----
	var num := int(_steam.call("getNumAchievements"))
	var backend: Array[String] = []
	for i in num:
		backend.append(str(_steam.call("getAchievementName", i)))
	print("[..] Steamworks 后台成就 %d 个" % num)

	var missing: Array[String] = []
	for api in expected:
		if backend.has(api):
			var disp := str(_steam.call("getAchievementDisplayAttribute", api, "name"))
			var hidden := str(_steam.call("getAchievementDisplayAttribute", api, "hidden"))
			print("       [ok] %-12s 显示名=%-12s hidden=%s" % [api, disp, hidden])
		else:
			missing.append(api)
			print("       [!!] %-12s 后台查无此成就（API Name 大小写/拼写要对齐）" % api)

	if not missing.is_empty():
		print("[FAIL] 后台缺 %d 个成就：%s" % [missing.size(), ", ".join(missing)])
		_quit(3)
		return
	print("[ok] %d 个成就名全部命中后台" % expected.size())

	# ---- 4.5 可选：走一遍生产钩子，确认「哪个事件解锁哪条」----
	if args.has("--hooks"):
		OS.set_environment("QUACKILL_STEAM_TRACE", "1")
		print("[..] 逐个调用生产钩子（trace 已开）")
		sa.note_first_step()
		sa.note_first_boss()
		sa.note_layer2_clear()
		sa.note_game_clear(PlayerClass.DRUID, 0)
		sa.note_game_clear(PlayerClass.ROGUE, SteamAchievements.HARD_DIFF)
		sa.note_game_clear(PlayerClass.MECH, 0)
		print("[ok] 钩子调用完毕（上面 8 行 trace 即事件→成就映射）")

	# ---- 5. 可选：真解锁 + 读回 ----
	if do_unlock:
		print("[..] 开始解锁（--unlock）")
		var bad := 0
		for api in expected:
			var ok := bool(_steam.call("setAchievement", api))
			print("       %s setAchievement(%s) -> %s" % ["[ok]" if ok else "[!!]", api, str(ok)])
			if not ok:
				bad += 1
		var stored := bool(_steam.call("storeStats"))
		print("       storeStats() -> %s" % str(stored))
		for api in expected:
			var r: Variant = _steam.call("getAchievementAndUnlockTime", api)
			if r is Dictionary:
				var d: Dictionary = r
				var got := str(d.get("achieved", d.get("ret", "?")))
				print("       readback %-12s achieved=%s unlock_time=%s" % [api, got, str(d.get("unlock_time", "?"))])
		if bad > 0:
			print("[FAIL] 有 %d 个 setAchievement 调用失败（后台缺该成就 / Steamworks 未登录）" % bad)
			_quit(4)
			return
		print("[ok] %d 个成就解锁调用全部成功" % expected.size())

	if _steam.has_method("steamShutdown"):
		_steam.call("steamShutdown")
	print("================================================================")
	print(" 结论：Steam 接入自检通过（%d 个成就全部就位）" % expected.size())
	print("================================================================")
	_quit(0)


func _collect_api_names(sa: GDScript) -> Array[String]:
	## 从 `API_*` 常量里取成就名（常量表是唯一真源，工具不再抄一份）。
	var out: Array[String] = []
	var consts: Dictionary = sa.get_script_constant_map()
	for k in consts:
		var key := str(k)
		if key.begins_with("API_"):
			out.append(str(consts[k]))
	out.sort()
	return out


func _arg_int(args: PackedStringArray, name: String) -> int:
	var i := args.find(name)
	if i >= 0 and i + 1 < args.size():
		var v := args[i + 1]
		return int(v) if v.is_valid_int() else 0
	return 0


func _quit(code: int) -> void:
	_fail = code
	quit(code)
