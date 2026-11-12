extends SceneTree
## R633：禁卡是否真的生效 —— 只读探针（不写盘、不改档案）。
## 用法：godot --headless --path . --script res://tools/probe_r633_ban.gd
##
## 检查四件事：
##   ① 档案里到底有没有禁卡（ProfileData.banned_by_class）
##   ② 开局快照 RunState.run_bans 有没有取到
##   ③ 局外 / 局内两种状态下，reward_pool_for() 里还有没有禁卡
##   ④ 商店 / 事件 / 关卡奖励这些「给卡口」用的是不是同一个池

const CardRepo = preload("res://scripts/card_repo.gd")
const ProfileData = preload("res://scripts/profile_data.gd")
const RunState = preload("res://scripts/run_state.gd")
const PlayerClass = preload("res://scripts/player_class.gd")


func _init() -> void:
	var repo = CardRepo.load_json()
	ProfileData.ensure_loaded()
	print("=== ① 档案禁卡表 ===")
	var all_bans := {}
	for cls: String in PlayerClass.ids():
		var b: Array = ProfileData.bans_of(cls)
		print("  %s → %s" % [cls, str(b)])
		for id: int in b:
			all_bans[id] = cls
	print("  合计 %d 张" % all_bans.size())

	print("=== ② 三职业各自的开局快照（模拟 start_run 后立即读） ===")
	for cls: String in PlayerClass.ids():
		var snap: Array = ProfileData.bans_of(cls)
		print("  %s：bans_of=%s" % [cls, str(snap)])

	print("=== ③ 局外口径（run_active=false → is_banned_any） ===")
	var cid := PlayerClass.DRUID
	for id: int in all_bans.keys():
		var in_pool := false
		for c: Variant in repo.reward_pool_for(cid):
			if c.id == id:
				in_pool = true
				break
		print("  %d %s 在 %s 奖励池里？ %s（is_card_banned=%s）"
				% [id, _name_of(repo, id), cid, str(in_pool), str(RunState.is_card_banned(id))])

	print("=== ④ 各「给卡口」的池来源（源码口径，人工核对用） ===")
	print("  CardReward.roll → repo.reward_pool_for()（禁卡已过）")
	print("  商店 refresh → 见 shop 函数")
	quit()


func _name_of(repo, id: int) -> String:
	var c: Variant = repo.get_card(id)
	return "" if c == null else str(c.card_name)
