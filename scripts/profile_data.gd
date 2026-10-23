class_name ProfileData
extends RefCounted
## 玩家档案（R346）—— 跨局的**账号级**进度：成就统计 / 剧情解锁 / 卡牌与道具解锁 / 禁卡表。
##
## 与 RunSave 的分工（别混）：
##   * `RunSave` = **这一局**的存档（`user://run_save.sav`）：开新局就作废；
##   * `ProfileData` = **这个玩家**的存档（`user://profile.json`）：开新局、结束、通关、失败，
##     进度都留着 —— 剧情解锁、卡牌/道具解锁、禁卡表全在这里。
##
## 数据形状（一个 JSON 对象，`__format__` 是版本号）：
##   stats            成就统计计数器 {stat_key: int}
##   unlocked_stories 条件已达成、可以在故事界面查看的剧情 id
##   read_stories     已经**点开看过**的剧情 id（看过的才会发放卡牌 / 道具）
##   unlocked_cards   已解锁的卡牌 id（这些卡才会进奖励池）
##   unlocked_relics  已解锁的道具 id（这些道具才会进奖励池）
##   banned_cards     玩家禁掉的卡牌 id（本局奖励池里不再出现）
##
## ── 统计键（新加统计**只在这里登记**，别在各处散着拼字符串）──
##   `boss_kill:<关卡名>`   击败该 Boss 的次数
##   `clear:<职业>:<难度>`  用该职业通关该难度的次数（结局那一下才记）
##   `card_play:<卡 id>`    累计使用该卡的次数
##   `kind_play:<卡类>`     累计使用该类卡的次数（盟友 / 技能 / 工事 / 效果 / 场地）
##   `relic_got:<道具 id>`  获得该道具的次数（首次 = 1，「首次获得」判据就是 >= 1）
##   `battle_win` / `elite_win` / `boss_win` / `run_win`   各类胜场
##
## ⚠️ **写盘纪律**：`bump()` 只改内存 + 置脏，`flush()` 才落盘 —— 战斗中每打一张牌都写文件
##    太浪费。`flush()` 的调用点 = 战斗结算 / 剧情解锁 / 禁卡变更 / 回标题。
## ⚠️ **测试与出图必须 `set_test_mode()`**：否则会把玩家真实进度写脏（见 test_engine 顶部）。

const PATH := "user://profile.json"
const TEST_PATH := "user://profile_test.json"
const FORMAT := 1

## 统计键前缀（与上方注释同源，代码里拼键时用这些常量）
const K_BOSS_KILL := "boss_kill:"
const K_CLEAR := "clear:"
const K_CARD_PLAY := "card_play:"
const K_KIND_PLAY := "kind_play:"
const K_RELIC_GOT := "relic_got:"
const K_BATTLE_WIN := "battle_win"
const K_ELITE_WIN := "elite_win"
const K_BOSS_WIN := "boss_win"
const K_RUN_WIN := "run_win"

static var stats: Dictionary = {}
static var unlocked_stories: Array[String] = []
static var read_stories: Array[String] = []
static var unlocked_cards: Array[int] = []
static var unlocked_relics: Array[int] = []
static var banned_cards: Array[int] = []

static var _loaded := false
static var _dirty := false
static var _path := PATH


# ------------------------------------------------------------ 生命周期

static func set_test_mode() -> void:
	## 测试 / 出图专用：换成独立文件、从零开始，**全程不碰玩家真实进度**。
	## ⚠️ 必须在测试脚本入口第一行调用 —— 引擎里的 `bump()` 会在跑用例途中就触发。
	_path = TEST_PATH
	_loaded = true
	_dirty = false
	clear_memory()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


static func clear_memory() -> void:
	## 只清内存（不删文件）—— 测试里「清空后重新加载」用。
	stats = {}
	unlocked_stories = []
	read_stories = []
	unlocked_cards = []
	unlocked_relics = []
	banned_cards = []
	_dirty = false


static func reset_all() -> void:
	## 真的把档案清空（设置页的「清空进度」与测试用）。文件也删掉。
	clear_memory()
	_loaded = true
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


static func ensure_loaded() -> void:
	## 首次访问时读盘。没有档案 / 档案损坏 / 版本不符 → 一律按**空档案**处理（不崩）。
	if _loaded:
		return
	_loaded = true
	clear_memory()
	if not FileAccess.file_exists(_path):
		return
	var root: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not (root is Dictionary):
		push_warning("ProfileData：档案解析失败，按空档案处理")
		return
	var d: Dictionary = root
	if int(d.get("__format__", 0)) != FORMAT:
		push_warning("ProfileData：档案版本 %d 与 %d 不符，按空档案处理"
				% [int(d.get("__format__", 0)), FORMAT])
		return
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k: Variant in (st as Dictionary).keys():
			stats[str(k)] = int((st as Dictionary)[k])
	unlocked_stories = _str_array(d.get("unlocked_stories", []))
	read_stories = _str_array(d.get("read_stories", []))
	unlocked_cards = _int_array(d.get("unlocked_cards", []))
	unlocked_relics = _int_array(d.get("unlocked_relics", []))
	banned_cards = _int_array(d.get("banned_cards", []))


static func save() -> bool:
	ensure_loaded()
	var root := {
		"__format__": FORMAT,
		"stats": stats,
		"unlocked_stories": unlocked_stories,
		"read_stories": read_stories,
		"unlocked_cards": unlocked_cards,
		"unlocked_relics": unlocked_relics,
		"banned_cards": banned_cards,
	}
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_warning("ProfileData：无法写入档案 " + _path)
		return false
	f.store_string(JSON.stringify(root, "\t"))
	f.close()
	_dirty = false
	return true


static func flush() -> void:
	## 有改动才落盘（战斗结算等关键节点调用一次即可）。
	if _dirty:
		save()


# ------------------------------------------------------------ 统计

static func bump(key: String, n := 1) -> void:
	## 统计计数器 +n（n 可以为负，但界面里只有加）。
	if key == "" or n == 0:
		return
	ensure_loaded()
	stats[key] = int(stats.get(key, 0)) + n
	_dirty = true


static func set_stat_max(key: String, v: int) -> void:
	## 「历史最高」类统计（最高单场伤害等）：只往上抬，不往下压。
	if key == "":
		return
	ensure_loaded()
	if v <= int(stats.get(key, 0)):
		return
	stats[key] = v
	_dirty = true


static func stat(key: String) -> int:
	ensure_loaded()
	return int(stats.get(key, 0))


static func stat_sum(prefix: String) -> int:
	## 前缀合计：`boss_kill:` 这类「任意一只 Boss」的判据。
	## ⚠️ 必须前缀**精确匹配** —— `card_play:80` 不该把 `card_play:8001` 算进来，
	## 所以键一律写成 `前缀 + 主键 + 结束`，比较时逐键 starts_with 即可（键本身含分隔符）。
	ensure_loaded()
	if prefix == "":
		return 0
	var total := 0
	for k: Variant in stats.keys():
		if str(k).begins_with(prefix):
			total += int(stats[k])
	return total


static func stat_of(key: String, prefix: String) -> int:
	## 成就条件的统一取值口：有精确键就用精确键，否则用前缀合计。
	return stat(key) if key != "" else stat_sum(prefix)


# ------------------------------------------------------------ 剧情

static func unlock_story(id: String) -> bool:
	if id == "":
		return false
	ensure_loaded()
	if unlocked_stories.has(id):
		return false
	unlocked_stories.append(id)
	_dirty = true
	return true


static func is_story_unlocked(id: String) -> bool:
	ensure_loaded()
	return unlocked_stories.has(id)


static func mark_story_read(id: String) -> bool:
	if id == "":
		return false
	ensure_loaded()
	if read_stories.has(id):
		return false
	read_stories.append(id)
	_dirty = true
	return true


static func is_story_read(id: String) -> bool:
	ensure_loaded()
	return read_stories.has(id)


# ------------------------------------------------------------ 卡牌 / 道具解锁

static func unlock_card(id: int) -> bool:
	ensure_loaded()
	if id <= 0 or unlocked_cards.has(id):
		return false
	unlocked_cards.append(id)
	_dirty = true
	return true


static func unlock_relic(id: int) -> bool:
	ensure_loaded()
	if id <= 0 or unlocked_relics.has(id):
		return false
	unlocked_relics.append(id)
	_dirty = true
	return true


static func is_card_unlocked(id: int) -> bool:
	ensure_loaded()
	return unlocked_cards.has(id)


static func is_relic_unlocked(id: int) -> bool:
	ensure_loaded()
	return unlocked_relics.has(id)


# ------------------------------------------------------------ 成就 → 剧情

static func check_achievements(repo: StoryRepo) -> Array[String]:
	## 遍历全部成就定义：条件达成且还没解锁 → 解锁它挂的剧情。
	## 返回**本次新解锁**的剧情 id（界面据此弹提示）。幂等，随便多调。
	var out: Array[String] = []
	if repo == null:
		return out
	ensure_loaded()
	for ach: Dictionary in repo.achievements:
		if not _ach_done(ach):
			continue
		for ep: Variant in (ach.get("episodes", []) as Array):
			var eid := str(ep)
			if unlock_story(eid):
				out.append(eid)
	return out


static func _ach_done(ach: Dictionary) -> bool:
	var need := int(ach.get("min", 1))
	var got := stat_of(str(ach.get("stat", "")), str(ach.get("stat_prefix", "")))
	return got >= need


static func achievement_progress(ach: Dictionary) -> int:
	return stat_of(str(ach.get("stat", "")), str(ach.get("stat_prefix", "")))


static func claim_episode(repo: StoryRepo, episode_id: String) -> Dictionary:
	## 「在故事界面点开看完」→ 标记已读 + 发放这一段的卡牌 / 道具解锁。
	## 返回 `{ok, cards: Array[int], relics: Array[int], reason}`。
	## ⚠️ **只有看过才发奖励**（用户口径：解锁时点查看故事，之后才解锁卡牌/道具）——
	##    所以 `mark_story_read()` 和发放必须在同一处，不能拆开。
	var res := {"ok": false, "cards": [], "relics": [], "reason": ""}
	if repo == null:
		res["reason"] = "剧情数据缺失"
		return res
	if not is_story_unlocked(episode_id):
		res["reason"] = "条件还没达成"
		return res
	if is_story_read(episode_id):
		res["reason"] = "已经看过了"
		return res
	var ep := repo.episode(episode_id)
	if ep.is_empty():
		res["reason"] = "没有这一段"
		return res
	ensure_loaded()
	var cards: Array[int] = []
	var relics: Array[int] = []
	var g: Variant = ep.get("grants", {})
	if g is Dictionary:
		for v: Variant in ((g as Dictionary).get("cards", []) as Array):
			var cid := int(v)
			if unlock_card(cid):
				cards.append(cid)
		for v2: Variant in ((g as Dictionary).get("relics", []) as Array):
			var rid := int(v2)
			if unlock_relic(rid):
				relics.append(rid)
	mark_story_read(episode_id)
	flush()
	res["ok"] = true
	res["cards"] = cards
	res["relics"] = relics
	return res


# ------------------------------------------------------------ 禁卡

static func ban_quota(repo: CardRepo) -> Dictionary:
	## 每档稀有度的**禁卡额度** = 该档「已通过剧情解锁」的卡牌张数（用户口径：
	## 「根据解锁的卡牌的张数和稀有度，获得等量张数的 ban 掉等稀有度卡牌的权利」）。
	## 返回 {rarity: int}，只含 0/1/2 三档（奖励池只有这三档）。
	var out := {0: 0, 1: 0, 2: 0}
	if repo == null:
		return out
	ensure_loaded()
	for id: int in unlocked_cards:
		var c := repo.get_card(id)
		if c == null or c.rarity > 2:
			continue
		out[c.rarity] = int(out.get(c.rarity, 0)) + 1
	return out


static func banned_by_rarity(repo: CardRepo) -> Dictionary:
	var out := {0: 0, 1: 0, 2: 0}
	if repo == null:
		return out
	ensure_loaded()
	for id: int in banned_cards:
		var c := repo.get_card(id)
		if c == null:
			continue
		out[c.rarity] = int(out.get(c.rarity, 0)) + 1
	return out


static func is_banned(id: int) -> bool:
	ensure_loaded()
	return banned_cards.has(id)


static func can_ban(card_id: int, repo: CardRepo) -> bool:
	## 能不能再禁这一张：卡在奖励池里、还没禁、该档还有剩余额度。
	if repo == null:
		return false
	var c := repo.get_card(card_id)
	if c == null or c.rarity > 2 or c.traits.has("测试"):
		return false
	if is_banned(card_id):
		return false
	var quota := ban_quota(repo)
	var used := banned_by_rarity(repo)
	return int(used.get(c.rarity, 0)) < int(quota.get(c.rarity, 0))


static func toggle_ban(card_id: int, repo: CardRepo) -> bool:
	## 点一下切禁 / 取消禁。返回**操作后**是否处于「已禁」。
	## 取消禁永远允许；加禁要走额度判定。
	ensure_loaded()
	if is_banned(card_id):
		banned_cards.erase(card_id)
		_dirty = true
		flush()
		return false
	if not can_ban(card_id, repo):
		return false
	banned_cards.append(card_id)
	_dirty = true
	flush()
	return true


static func clear_bans() -> void:
	ensure_loaded()
	if banned_cards.is_empty():
		return
	banned_cards = []
	_dirty = true
	flush()


static func ban_summary(repo: CardRepo) -> String:
	## 禁卡额度的一行摘要（禁卡界面标题下 + 无额度时的说明都读它）。
	## 口径写成「已禁 / 名额」：两个数字同档比较时，先说已用多少、再说总共多少。
	var quota := ban_quota(repo)
	var used := banned_by_rarity(repo)
	var parts: Array[String] = []
	for r in [0, 1, 2]:
		parts.append("%s 已禁 %d / 名额 %d" % [CardData.RARITY_NAMES[r],
				int(used.get(r, 0)), int(quota.get(r, 0))])
	return " · ".join(parts)


static func ban_total_quota(repo: CardRepo) -> int:
	var quota := ban_quota(repo)
	return int(quota.get(0, 0)) + int(quota.get(1, 0)) + int(quota.get(2, 0))


# ------------------------------------------------------------ 工具

static func _int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v: Variant in a:
			out.append(int(v))
	return out


static func _str_array(a: Variant) -> Array[String]:
	var out: Array[String] = []
	if a is Array:
		for v: Variant in a:
			out.append(str(v))
	return out
