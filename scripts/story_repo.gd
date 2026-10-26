class_name StoryRepo
extends RefCounted
## 剧情与成就定义（R346）—— 从 `stories.json` 读取，**只做数据**，不碰界面。
##
## 一份 `stories.json` 里两组东西：
##   episodes      剧情段。[{id, chapter, title, text: [行], grants: {cards, relics}}]
##                 `grants` = 看完之后**加入奖励池**的 id（不是发到手里，R355 用户口径）——
##                 所以这里点到的卡 / 道具必须在 cards.json / relics.json 里标 `locked: true`，
##                 否则它本来就在池子里，「解锁」对玩家没有任何意义（test_engine R355 有守卫）。
##   achievements  成就。[{id, name, hint, stat | stat_prefix, min, episodes: [剧情 id]}]
##
## 三段状态（`episode_state()` 的唯一判定口）：
##   locked  条件还没达成 / **这一段根本没写正文**（R359）
##           —— 列表里显示「？？？」与条件提示（没正文时不写进度，只有锁图标）
##   ready   条件已达成、还没点开看过 —— 可以点开看
##   read    已经看过（卡牌 / 道具已加入奖励池）
##
## ⚠️ 「解锁」与「看过」是**两步**：条件达成只让条目亮起来（`unlocked_stories`），
##    玩家点开看过之后才发卡牌/道具（`read_stories`）。用户口径：
##    「解锁时在故事界面点击查看故事解锁，之后可以解锁一些卡牌/道具加入奖励池」。
##
## ⚠️ 现在是**空壳期**：剧情正文全部为空（列表显示 `episodeX-？？？`），
##    `grants` 也全空 —— 框架先通，内容后填（填内容不用改一行代码）。

const PATH := "res://stories.json"

const STATE_LOCKED := "locked"
const STATE_READY := "ready"
const STATE_READ := "read"

var episodes: Array = []
var achievements: Array = []

var _ep := {}      # episode id -> 定义
var _ach := {}     # achievement id -> 定义
var _ep_ach := {}  # episode id -> achievement 定义（一段剧情只由一个成就开启）


static func load_json(path: String = PATH) -> StoryRepo:
	var repo := StoryRepo.new()
	if not FileAccess.file_exists(path):
		push_warning("stories.json 不存在：" + path)
		return repo
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		push_error("stories.json 解析失败")
		return repo
	var d: Dictionary = data
	var eps: Variant = d.get("episodes", [])
	if eps is Array:
		for e: Variant in (eps as Array):
			if not (e is Dictionary):
				continue
			var ed: Dictionary = e
			repo.episodes.append(ed)
			repo._ep[str(ed.get("id", ""))] = ed
	var achs: Variant = d.get("achievements", [])
	if achs is Array:
		for a: Variant in (achs as Array):
			if not (a is Dictionary):
				continue
			var ad: Dictionary = a
			repo.achievements.append(ad)
			repo._ach[str(ad.get("id", ""))] = ad
			for ep: Variant in (ad.get("episodes", []) as Array):
				repo._ep_ach[str(ep)] = ad
	return repo


func episode(id: String) -> Dictionary:
	var v: Variant = _ep.get(id, {})
	return v if v is Dictionary else {}


func achievement(id: String) -> Dictionary:
	var v: Variant = _ach.get(id, {})
	return v if v is Dictionary else {}


func achievement_for_episode(ep_id: String) -> Dictionary:
	## 开启这一段剧情的成就（一条剧情只挂一个成就；找不到 → 空字典 = 不受任何条件限制）。
	var v: Variant = _ep_ach.get(ep_id, {})
	return v if v is Dictionary else {}


func has_content(ep_id: String) -> bool:
	## 这一段有没有**正文**（R359）：`text` 里至少一行非空字符串。
	## 空壳期的占位段落（`text: []`）一律算「没做」—— 点开只能看到
	## 「（这一段故事还没有写。）」，那不该算一段可以看的故事。
	var ep := episode(ep_id)
	for v: Variant in (ep.get("text", []) as Array):
		if str(v).strip_edges() != "":
			return true
	return false


func episode_state(ep_id: String) -> String:
	# R359：**没写正文的段落默认上锁**（用户口径「没有写的故事，没有上锁，应该默认上锁」）。
	# 玩家档案里很可能已经有它的解锁记录（成就在空壳期就达成了，episode2~6 全是这样），
	# 但「条件够了」不等于「有东西可看」—— 列表里给金色亮点、点开却是空占位，比锁更糟。
	# ⚠️ 只影响**显示判定**，不动 `unlocked_stories` 的记账：将来把正文填进 stories.json，
	#    条件早就达成的玩家会立刻变成 ready（不用再补一次性迁移）。
	if not has_content(ep_id):
		return STATE_LOCKED
	if ProfileData.is_story_read(ep_id):
		return STATE_READ
	if ProfileData.is_story_unlocked(ep_id):
		return STATE_READY
	return STATE_LOCKED


func episode_label(ep: Dictionary) -> String:
	## 列表里的显示名：`episodeX-？？？`（章节名 + 标题）。
	## 内容还没写的时候标题就是「？？？」，写完之后把 title 换成真标题即可。
	return "%s-%s" % [str(ep.get("chapter", "?")), str(ep.get("title", "？？？"))]


func requirement_text(ep_id: String) -> String:
	## 未达成时显示的条件提示：成就的 hint + 进度（`0 / 1`）。
	## 成就没写 hint → 一句兜底，别让界面空着。
	# R359：没正文的段落不显示「已达成（1/1）」这种进度 —— 状态既然锁着，
	# 写一条「条件已满」的提示只会让人以为坏了。锁图标已经说明一切。
	if not has_content(ep_id):
		return ""
	var ach := achievement_for_episode(ep_id)
	if ach.is_empty():
		return ""
	var hint := str(ach.get("hint", ""))
	if hint == "":
		hint = "达成某个条件"
	var need := int(ach.get("min", 1))
	var got := mini(ProfileData.achievement_progress(ach), need)
	return "%s（%d / %d）" % [hint, got, need]


func episode_text_lines(ep_id: String) -> Array[String]:
	## 剧情正文（一行一句）。空 → 返回一句占位，界面不用各处判空。
	var out: Array[String] = []
	var ep := episode(ep_id)
	for v: Variant in (ep.get("text", []) as Array):
		out.append(str(v))
	if out.is_empty():
		out.append("（这一段故事还没有写。）")
	return out


func episode_grants(ep_id: String) -> Dictionary:
	## 看完**解锁进奖励池**的东西：`{cards: Array[int], relics: Array[int]}`。
	## ⚠️ 不是「发到手里」的清单 —— 界面上要说「加入奖励池」，不要说「获得」（R355）。
	var ep := episode(ep_id)
	var g: Variant = ep.get("grants", {})
	if not (g is Dictionary):
		return {"cards": [], "relics": []}
	return g


func grant_count(ep_id: String) -> int:
	var g := episode_grants(ep_id)
	return (g.get("cards", []) as Array).size() + (g.get("relics", []) as Array).size()


func unlock_notice(ids: Array) -> String:
	## R389：把「刚解锁的剧情 id」变成一句提示（空串 = 不用提示）。
	##
	## ⚠️ 只算**有正文**的段落：空壳期的 episode3~6 条件达成也会进 `unlocked_stories`
	##    （成就在空壳期就能达成），但界面上它们是 `locked` 的「？？？」——
	##    弹一句「解锁了剧情」再点进去只看得到占位，比不提示更糟。
	## 多段只报数量，一段报章节名（结算面板的副标题行只有 280px 宽）。
	var ready: Array[String] = []
	for v: Variant in ids:
		var eid := str(v)
		if has_content(eid):
			ready.append(eid)
	if ready.is_empty():
		return ""
	if ready.size() == 1:
		return "✦ 新剧情解锁：%s" % episode_label(episode(ready[0]))
	return "✦ 新剧情解锁 %d 段（主界面查看）" % ready.size()
