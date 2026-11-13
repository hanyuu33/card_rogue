extends RefCounted
## 运行时语言与界面文案（R660）。
##
## 只负责**界面骨架**：标题页 / 设置页 / 首次语言选择。卡牌、道具、事件正文仍由
## `i18n/*.json` 的翻译流水线处理，本文件**不读也不改**那些文件，避免和并行翻译互相覆盖。
##
## 新增语言只改两处：
##   1. `LANGUAGES` 加一条 `{code, native, en}`（列表顺序就是界面顺序）；
##   2. `TEXT` 里给需要的 key 补该语言的译文。缺译自动回退 en → zh → key，
##      所以语言可以先出现在选择列表里，再逐条补文案，不会崩、不会空白。
##
## 为什么不用 Godot `tr()`：当前翻译正文是运行时 JSON，不是 `.translation` 资源；
## 这里用显式 key 查表，既方便逐条核对，也避免 `TranslationServer` 在本版本被空表拖成全空。

const DEFAULT_LANG := "zh"
const FALLBACK_LANG := "en"

## 语言注册表（唯一来源）。`native` 用该语言自己的写法，永远不翻译。
const LANGUAGES := [
	{"code": "zh", "native": "中文", "en": "Chinese (Simplified)"},
	{"code": "en", "native": "English", "en": "English"},
	{"code": "ja", "native": "日本語", "en": "Japanese"},
]

const TEXT := {
	# ---- 标题页 ----
	"title.start": {"zh": "开始对战", "en": "Start Run", "ja": "冒険を始める"},
	"title.continue": {"zh": "继续游戏", "en": "Continue", "ja": "続きから"},
	"title.continue_short": {"zh": "继续", "en": "Resume", "ja": "続ける"},
	"title.codex": {"zh": "百科", "en": "Compendium", "ja": "図鑑"},
	"title.records": {"zh": "对战记录", "en": "Run History", "ja": "対戦記録"},
	"title.settings": {"zh": "设置", "en": "Settings", "ja": "設定"},
	"title.credits": {"zh": "鸣谢", "en": "Credits", "ja": "クレジット"},
	"title.quit": {"zh": "退出", "en": "Quit", "ja": "終了"},
	"title.tip_records": {"zh": "每局的最终结果（通关 / 失败 / 中断）",
			"en": "Final result of each run (victory / defeat / abandoned)",
			"ja": "各冒険の最終結果（クリア／敗北／中断）"},
	"title.tip_settings": {"zh": "音效 / 音乐 / 全屏 / 语言",
			"en": "Sound / music / fullscreen / language",
			"ja": "効果音／音楽／全画面／言語"},
	"title.tip_credits": {"zh": "引擎 / 音乐署名（PeriTune）",
			"en": "Engine / music credits (PeriTune)",
			"ja": "エンジン／音楽クレジット（PeriTune）"},
	"title.footer_godot": {"zh": "Godot 4.3 自包含副本",
			"en": "Godot 4.3 self-contained build",
			"ja": "Godot 4.3 同梱ビルド"},
	"title.footer_dev": {"zh": "肉鸽开发版", "en": "Roguelike Dev Build",
			"ja": "ローグライク開発版"},

	# ---- 设置页 ----
	"settings.title": {"zh": "设 置", "en": "SETTINGS", "ja": "設 定"},
	"settings.autosave": {"zh": "所有设置自动保存", "en": "All settings save automatically",
			"ja": "設定は自動保存されます"},
	"settings.back_title": {"zh": "返回标题", "en": "Back to Title", "ja": "タイトルへ"},
	"settings.back_battle": {"zh": "返回战斗", "en": "Back to Battle", "ja": "戦闘に戻る"},
	"settings.sfx": {"zh": "音效", "en": "Sound Effects", "ja": "効果音"},
	"settings.sfx_desc": {"zh": "点击 / 出牌 / 攻击等提示音",
			"en": "Clicks, cards, attacks and other cues",
			"ja": "クリック・カード・攻撃などの通知音"},
	"settings.sfx_vol": {"zh": "音效音量", "en": "SFX Volume", "ja": "効果音の音量"},
	"settings.sfx_vol_desc": {"zh": "点 − / + 调整", "en": "Use − / + to adjust",
			"ja": "− / + で調整"},
	"settings.music": {"zh": "音乐", "en": "Music", "ja": "音楽"},
	"settings.music_desc": {"zh": "背景音乐（标题 / 地图 / 战斗各自换曲）",
			"en": "Background music (title / map / battle)",
			"ja": "BGM（タイトル・マップ・戦闘で切り替え）"},
	"settings.music_vol": {"zh": "音乐音量", "en": "Music Volume", "ja": "音楽の音量"},
	"settings.music_vol_desc": {"zh": "点 − / + 调整", "en": "Use − / + to adjust",
			"ja": "− / + で調整"},
	"settings.fullscreen": {"zh": "全屏", "en": "Fullscreen", "ja": "全画面"},
	"settings.fullscreen_desc": {"zh": "关掉则使用窗口模式（默认窗口）",
			"en": "Off uses windowed mode (default)",
			"ja": "オフでウィンドウ表示（既定）"},
	"settings.on": {"zh": "开", "en": "On", "ja": "オン"},
	"settings.off": {"zh": "关", "en": "Off", "ja": "オフ"},
	"settings.language": {"zh": "语言", "en": "Language", "ja": "言語"},
	"settings.language_changed": {"zh": "语言已切换", "en": "Language changed",
			"ja": "言語を切り替えました"},
	# ---- 设置页按类分页（R660c）----
	"settings.tab_audio": {"zh": "音频", "en": "Audio", "ja": "オーディオ"},
	"settings.tab_display": {"zh": "画面", "en": "Display", "ja": "画面"},
	"settings.tab_language": {"zh": "语言", "en": "Language", "ja": "言語"},
	"settings.tab_run": {"zh": "对局", "en": "Run", "ja": "プレイ"},
	"settings.language_note": {"zh": "点一行立刻生效，整页文字跟着换。",
			"en": "Pick a row to apply it at once — this page switches with it.",
			"ja": "行を選ぶとすぐ反映され、この画面の表示も切り替わります。"},
	"settings.foe_speed": {"zh": "敌人行动速度", "en": "Enemy Speed",
			"ja": "敵の行動速度"},
	"settings.foe_speed_desc": {"zh": "点一下循环 1× / 1.5× / 2×，和战斗里那个按钮同一份设置",
			"en": "Tap to cycle 1× / 1.5× / 2× (same as the battle button)",
			"ja": "タップで 1× / 1.5× / 2× を循環（戦闘中と同じ設定）"},
	"settings.copy": {"zh": "复制", "en": "Copy", "ja": "コピー"},
	"settings.copied": {"zh": "已复制种子 %s", "en": "Seed copied: %s",
			"ja": "シードをコピーしました %s"},
	"settings.no_seed": {"zh": "还没有可复制的种子：先开一局，或在下面填「下一局种子」",
			"en": "No seed to copy yet. Start a run or enter a Next Run Seed below.",
			"ja": "コピーできるシードがありません。冒険を始めるか、下の「次のシード」に入力してください。"},
	"settings.seed_title": {"zh": "随机种子", "en": "Random Seed", "ja": "ランダムシード"},
	"settings.seed_current": {"zh": "本局种子：%s", "en": "Current run seed: %s",
			"ja": "今回のシード：%s"},
	"settings.seed_none": {"zh": "本局种子：—（当前没有进行中的对局）",
			"en": "Current run seed: — (no run in progress)",
			"ja": "今回のシード：—（進行中の冒険なし）"},
	"settings.seed_next": {"zh": "下一局种子", "en": "Next Run Seed", "ja": "次のシード"},
	"settings.seed_current_random": {"zh": "当前：随机", "en": "Current: random",
			"ja": "現在：ランダム"},
	"settings.seed_current_code": {"zh": "当前：%s", "en": "Current: %s", "ja": "現在：%s"},
	"settings.seed_placeholder": {"zh": "留空 = 随机（10 位）",
			"en": "Blank = random (10 chars)", "ja": "空欄＝ランダム（10桁）"},
	"settings.seed_tip": {"zh": "留空 = 每局随机；填入 10 位大写字母 / 数字 → 下一局用同一种子（用一次自动清空）",
			"en": "Blank = random. 10 A-Z/0-9 = fixed next seed (cleared after use).",
			"ja": "空欄＝ランダム。英数字10桁で次のシードを固定（1回で消去）。"},
	"settings.seed_footer": {"zh": "提示：种子决定整局的地图 / 掉落 / 摇卡；同一种子新开一局可复现同一局。",
			"en": "Tip: the seed fixes the map, drops and card rolls. Start a new run with the same seed to replay it.",
			"ja": "ヒント：シードはマップ・ドロップ・カード抽選を固定します。同じシードで同じ冒険を再現できます。"},

	# ---- 首次语言选择 ----
	"language.kicker": {"zh": "LANGUAGE", "en": "LANGUAGE", "ja": "LANGUAGE"},
	"language.title": {"zh": "选择语言", "en": "Choose Your Language",
			"ja": "言語を選択"},
	"language.subtitle": {"zh": "游戏内文字会立刻切换", "en": "In-game text updates immediately",
			"ja": "ゲーム内の表示がすぐに切り替わります"},
	"language.confirm": {"zh": "进入游戏", "en": "Enter Game", "ja": "ゲームを始める"},
	"language.note": {"zh": "之后可以随时在设置里更改",
			"en": "You can change this anytime in Settings",
			"ja": "あとから設定でいつでも変更できます"},
	"language.scroll_hint": {"zh": "滚轮或拖动浏览更多语言",
			"en": "Scroll or drag to browse more languages",
			"ja": "スクロールまたはドラッグで他の言語を表示"},
}


static func has_language(code: String) -> bool:
	for d: Dictionary in LANGUAGES:
		if str(d.get("code", "")) == code:
			return true
	return false


static func normalize(code: String) -> String:
	## 未知 / 空 code 一律回默认中文；设置文件被手改也不会让界面空掉。
	var c := code.strip_edges().to_lower()
	return c if has_language(c) else DEFAULT_LANG


static func language_entry(code: String) -> Dictionary:
	for d: Dictionary in LANGUAGES:
		if str(d.get("code", "")) == code:
			return d
	return LANGUAGES[0]


static func native_name(code: String) -> String:
	return str(language_entry(normalize(code)).get("native", "中文"))


static func english_name(code: String) -> String:
	return str(language_entry(normalize(code)).get("en", "Chinese (Simplified)"))


static func system_language() -> String:
	## 首次启动的默认高亮：系统是日文就日文、中文就中文，其余先给英文。
	## 不自动落盘 —— 玩家点「进入游戏」才算完成首次选择。
	var loc := OS.get_locale().to_lower()
	if loc.begins_with("ja"):
		return "ja"
	if loc.begins_with("zh"):
		return "zh"
	return "en"


static func current() -> String:
	GameSettings.ensure_loaded()
	return normalize(GameSettings.language)


static func t(key: String, lang := "") -> String:
	## 查表：指定语言 → 该语言 → en → zh → key。`lang` 为空时用当前设置。
	## 显式指定但未注册的 code（例如未来语言先加了列表、文案还没补）→ 英文兜底；
	## 设置文件里存到未知值时 `current()` 会回落到中文，保证界面永远有字。
	var code := current()
	if lang != "":
		code = lang.strip_edges().to_lower()
		if not has_language(code):
			code = FALLBACK_LANG
	var row: Dictionary = TEXT.get(key, {})
	if row.has(code):
		return str(row[code])
	if row.has(FALLBACK_LANG):
		return str(row[FALLBACK_LANG])
	if row.has(DEFAULT_LANG):
		return str(row[DEFAULT_LANG])
	return key


static func tf(key: String, args: Array, lang := "") -> String:
	## 带 `%s` 的文案统一走这里，避免调用方自己拼语言分支。
	return t(key, lang) % args
