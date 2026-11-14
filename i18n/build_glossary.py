# -*- coding: utf-8 -*-
"""非卡牌术语唯一表（R651 建立 / R652 删鸡煲 / R653 定 8027=Refit）。

只写 i18n/glossary.json，不碰游戏权威数据。用法：python i18n/build_glossary.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATH = ROOT / "i18n/glossary.json"
g = json.loads(PATH.read_text(encoding="utf-8"))

def t(en, ja, note=None):
    d = {"en": en, "ja": ja}
    if note:
        d["note"] = note
    return d

def named(items, id_key=None):
    out = {}
    for row in items:
        zh, en, ja = row[:3]
        meta = row[3] if len(row) > 3 else None
        d = t(en, ja)
        if isinstance(meta, dict):
            d.update(meta)
        elif meta:
            d["note"] = meta
        out[zh] = d
    return out

g["version"] = 2
for rule in [
    "合体仅指 9167 技能卡：Merge／合体；组合是 R614 三槽生成卡流程：Assemble／組み立てる。二者不得共用 Combine。",
    "道具是系统 relic：Relic／レリック；信物是难度 11 的第三层钥匙：Key Relic／キーレリック，二者分开记账，不得混译。",
    "地图「巧克力」与难度旧文案「行动力」均指向 RunState.chocolate，外译统一 Chocolate／チョコレート；不得另造 Action Points 与单位行动次数混淆。",
    "消耗区是本战斗消失卡的浏览区：Banished Cards／消滅置き場；不得套用 Exhaust 或 Discard。",
    "卡牌稀有度只有普通／稀有／史诗／初始／怪物／事件／诅咒；传奇是道具 tier，不得给卡牌另造传说稀有度。",
    "字段（AFFIX_DEFS）与附魔（ENCHANT_DEFS）是两个命名空间；名称与说明分别按各自真源翻译。",
    "同名剧情与成就共用译名；非卡牌专名若已有卡名译文，必须复用，不另起一套。",
    "即时道具只表示获得时立即结算，仍保留在 relics 列表；时机标注用 On pickup／入手時，不得写 Consumed on pickup／入手時に消費。",
    "区域定义（店长 2026-11-13 定，严格区分、禁止互相替换或互译）：卡组＝玩家完整卡组，即战斗中上方按钮查看的那个（本局构筑、跨战斗、含附魔；对应 RunState.deck_ids / Full Deck / デッキ全体）；抽牌库＝战斗中待抽的牌（右下角牌堆，UI 区域名就是「抽牌库」；本场剩余；对应 GameEngine.state.deck / Draw Pile / 山札）；弃牌区＝弃牌区，统一叫弃牌区（弃牌库／弃牌堆为旧写法）。描述按语义选词：跨战斗增删、选牌、整副统计写「卡组」；本场待抽区取牌、塞牌、随机改造写「抽牌库」。旧写法「抽牌堆／牌库」一律归一为「抽牌库」；不得把语义上的「卡组」改成「抽牌库」，也不得再把「抽牌库」写成「抽牌堆」。",
]:
    if rule not in g["rules"]:
        g["rules"].append(rule)
g["mechanics"].update(named([
    ("组合", "Assemble", "組み立てる", "R614 三槽组合生成卡流程，不是 affix"),
    ("升级", "Refit", "改修", "R653 定案：8027 卡名。机制「改造」仍为 Upgrade／改造；与 9187 的 advance（前进1格）、9200 的 advance a phase（进一阶）无关"),
    ("幻影", "Ephemeral", "幻影"),
    ("交换", "Swap", "入れ替え"),
    ("共享护盾", "Shared Shield", "共有シールド"),
    ("死亡", "Death", "死亡"),
    ("冰封", "Freeze", "氷結"),
    ("禁足", "Root", "移動不可"),
    ("惧光", "Light Phobia", "光恐怖"),
    ("铸造", "Casting", "鋳造", "与锻造 Forge 是不同机制"),
    ("附魔", "Enchant", "付呪"),
    ("字段", "Keyword", "キーワード"),
    ("起手", "Opening Hand", "初期手札"),
    ("伤害", "Damage", "ダメージ"),
    ("巧克力", "Chocolate", "チョコレート"),
    ("行动力", "Chocolate", "チョコレート", "难度旧文案别名；真源同为 RunState.chocolate"),
    ("最大生命", "Max Health", "最大HP"),
    ("生命上限", "Max Health", "最大HP"),
    ("道具", "Relic", "レリック"),
    ("信物", "Key Relic", "キーレリック"),
    ("关卡效果", "Level Effect", "ステージ効果"),
    ("消耗区", "Banished Cards", "消滅置き場"),
]))
g["names"]["合体"] = t("Merge", "合体", "仅 9167 卡名；引擎 MERGE_ID")
g["names"].update(named([
    ("普罗诺亚", "Pronoia", "プロノイア", "剧情称谓；与普罗诺亚之影分开登记"),
    ("谟涅摩叙涅", "Mnemosyne", "ムネモシュネ", "剧情称谓复用 8072 卡名"),
    ("巴兰", "Balan", "バラン", "剧情简称；全名 9237 = Balan-Alpha／バランα"),
    ("安西", "Anxi", "アンシー", "剧情简称；全名 9238 = Anxi-Beta／アンシーβ"),
    ("塔基尼", "Tachini", "タキニ", "剧情简称；全名 9239 = Tachini-Gamma／タキニγ"),
    ("卷卷", "Pippin", "ピピン", "R310 每层起点的豚鼠吟游诗人；西幻本土化译名，不用拼音"),
    ("豚鼠吟游诗人", "Guinea Pig Bard", "モルモットの吟遊詩人", "卷卷的身份牌"),
]))

g["rarities"] = named([
    ("普通", "Common", "コモン"), ("稀有", "Rare", "レア"),
    ("史诗", "Epic", "エピック"), ("初始", "Starter", "初期"),
    ("怪物", "Monster", "モンスター"), ("事件", "Event", "イベント"),
    ("诅咒", "Curse", "呪い"),
])
g["relic_kinds"] = named([
    ("即时", "Instant", "即時"), ("战斗", "Battle", "戦闘"),
    ("持续", "Persistent", "永続"),
])
g["relic_sources"] = named([
    ("初始", "Starting", "初期"), ("奖励", "Reward", "報酬"),
    ("事件", "Event", "イベント"), ("二层", "Layer 2", "第2層"),
    ("角色", "Class", "クラス"),
])
g["relic_tiers"] = named([
    ("一般", "Common", "一般", "道具 tier，与卡牌稀有度普通是不同枚举"),
    ("传奇", "Legendary", "伝説", "仅道具 tier，不是卡牌稀有度"),
])
g["key_relics"] = named([
    ("信物", "Key Relic", "キーレリック"),
    ("完美螺钉", "Perfect Screw", "完璧なネジ", {"id": 6061}),
    ("生命之种", "Seed of Life", "命の種", {"id": 6062}),
    ("屠戮匕首", "Slaughter Dagger", "殺戮の短剣", {"id": 6063}),
])
g["difficulties"] = named([
    ("轻松", "Relaxed", "気楽"), ("微恙", "Mild Ailment", "微恙"),
    ("严酷", "Harsh", "過酷"), ("顽强", "Tenacious", "頑強"),
    ("稀缺", "Scarcity", "欠乏"), ("疲惫", "Fatigue", "疲労"),
    ("凶暴", "Ferocious", "凶暴"), ("贫瘠", "Barren", "不毛"),
    ("匆忙", "Haste", "急ぎ"), ("虚弱", "Weakened", "虚弱"),
    ("噩梦", "Nightmare", "悪夢"), ("上锁", "Locked", "施錠"),
])
g["difficulty_notes"] = named([
    ("无", "None", "なし"),
    ("篝火回复生命值降低", "Reduced Campfire Healing", "篝火のHP回復量が低下"),
    ("战斗胜利不再回复生命值", "No Healing after Battle Victories", "戦闘勝利時にHPを回復しない"),
    ("敌人更加顽强", "Enemies Are Tougher", "敵がさらに頑強になる"),
    ("稀有卡牌获取概率降低", "Lower Rare Card Chance", "レアカードの入手確率低下"),
    ("行动力低时疲惫", "Fatigue at Low Chocolate", "チョコレート低下時に疲労"),
    ("敌人更加凶猛", "Enemies Are More Ferocious", "敵がさらに凶暴になる"),
    ("金钱减少", "Less Gold", "ゴールド減少"),
    ("行动力降低", "Less Chocolate", "チョコレート減少"),
    ("虚弱", "Weakened", "虚弱"),
    ("精英出现增多", "More Elites", "エリートの出現増加"),
    ("第三层上锁", "Layer 3 Locked", "第3層が施錠"),
])
g["rooms"] = named([
    ("战斗", "Battle", "戦闘"), ("精英战斗", "Elite Battle", "エリート戦"),
    ("随机事件", "Random Event", "ランダムイベント"),
    ("片刻休息", "Rest Stop", "休息"),
    ("不确定的命运", "Uncertain Fate", "不確かな運命"),
    ("宝箱", "Chest", "宝箱"), ("大宝箱", "Large Chest", "大宝箱"),
    ("神秘商店", "Mysterious Shop", "謎の商店"),
    ("起点", "Starting Point", "起点"), ("首领战", "Boss Battle", "ボス戦"),
    ("精英", "Elite", "エリート"), ("休息", "Rest", "休息"),
    ("篝火", "Campfire", "キャンプファイア"),
    ("未知房间", "Unknown Room", "不明な部屋"),
    ("迷雾", "Fog of War", "フォッグ・オブ・ウォー"),
    ("通路", "Path", "通路"), ("当前房间", "Current Room", "現在の部屋"),
    ("已探索", "Explored", "探索済み"), ("未探索", "Unexplored", "未探索"),
    ("入夜", "Nightfall", "夜が来る"),
    ("第一层", "Layer 1", "第1層"), ("第二层", "Layer 2", "第2層"),
    ("第三层", "Layer 3", "第3層"),
])
g["statuses"] = named([
    ("冰封", "Frozen", "氷結"), ("眩晕", "Stunned", "スタン"),
    ("沉睡", "Asleep", "睡眠"), ("禁足", "Rooted", "移動不可"),
    ("中毒", "Poisoned", "毒"), ("护盾", "Shield", "シールド"),
    ("护甲", "Armor", "装甲"), ("额外行动", "Extra Action", "追加行動"),
    ("光环", "Aura", "オーラ"), ("孤军", "Alone", "孤軍"),
    ("自我修复", "Self-Repair", "自己修復"), ("守护", "Guard", "守護"),
    ("锻造", "Forge", "鍛造"), ("铸造", "Casting", "鋳造"),
    ("阶段", "Phase", "段階"), ("惧光", "Light Phobia", "光恐怖"),
    ("供能", "Power Supply", "供給"),
    ("免疫", "Immune", "免疫"),
])
g["enchantments"] = named([
    ("费用 -1", "Cost -1", "コスト-1"),
    ("伤害 +10", "Damage +10", "ダメージ+10"),
    ("次元之力", "Dimensional Power", "次元の力"),
    ("保存", "Preserve", "保存"),
    ("起手", "Opening Hand", "初期手札"),
    ("抽牌 +1", "Draw +1", "ドロー+1"),
    ("契约核心", "Contract Core", "契約コア", "动态数值名；与事件契约的核心区分"),
])
g["zones"] = named([
    ("完整卡组", "Full Deck", "デッキ全体", "本局构筑，跨战斗"),
    ("卡组", "Deck", "デッキ", "玩家完整卡组（战斗中上方按钮查看的那个）：本局构筑、跨战斗、含附魔；不是战斗中待抽区"),
    ("抽牌库", "Draw Pile", "山札", "战斗中待抽的牌（右下角牌堆，UI 区域名「抽牌库」）；本场剩余；不是完整卡组"),
    ("抽牌堆", "Draw Pile", "山札", "历史误用词；canonical 层已不用，显示层 PHRASE_FIXES 一律收口为「抽牌库」"),
    ("弃牌区", "Discard Pile", "捨て札置き場", "统一叫弃牌区；弃牌库／弃牌堆为旧写法"),
    ("消耗区", "Banished Cards", "消滅置き場", "void_count 对应的本战斗消失卡"),
    ("手牌", "Hand", "手札"),
])
g["rewards"] = named([
    ("获得奖励", "Rewards", "報酬を獲得"),
    ("待领奖励", "Pending Rewards", "未受取報酬"),
    ("追加奖励", "Bonus Rewards", "追加報酬"),
    ("卡牌奖励", "Card Reward", "カード報酬"),
    ("卡牌奖励（三选一）", "Card Reward (Choose 1 of 3)", "カード報酬（3枚から1枚選択）"),
    ("道具奖励", "Relic Reward", "レリック報酬"),
    ("奖励道具", "Reward Relic", "報酬レリック"),
    ("领取全部道具", "Claim All Relics", "全レリックを受け取る"),
    ("普通过关奖励", "Normal Victory Reward", "通常クリア報酬"),
    ("Boss过关奖励", "Boss Victory Reward", "ボスクリア報酬"),
    ("史诗卡牌奖励", "Epic Card Reward", "エピックカード報酬"),
    ("三选一", "Choose 1 of 3", "3択"), ("二选一", "Choose 1 of 2", "2択"),
    ("放弃这组", "Skip This Group", "このグループを見送る"),
    ("不可放弃", "Cannot Skip", "見送り不可"),
    ("放弃这次删卡", "Skip Card Removal", "今回のカード削除を見送る"),
    ("放弃这次兑换", "Skip This Exchange", "今回の交換を見送る"),
])
g["ui"] = named([
    ("开始冒险", "Start Adventure", "冒険を始める"),
    ("继续游戏", "Continue", "続きから"), ("百科", "Codex", "百科"),
    ("对战记录", "Battle Records", "対戦記録"), ("设置", "Settings", "設定"),
    ("鸣谢", "Credits", "クレジット"), ("退出", "Quit", "終了"),
    ("返回标题", "Back to Title", "タイトルへ戻る"),
    ("返回地图", "Return to Map", "マップへ戻る"),
    ("返回百科", "Back to Codex", "百科へ戻る"),
    ("查看故事", "Stories", "ストーリーを見る"),
    ("卡牌图鉴", "Card Codex", "カード図鑑"),
    ("玩家卡牌图鉴", "Player Card Codex", "プレイヤーカード図鑑"),
    ("敌人图鉴", "Enemy Codex", "敵図鑑"),
    ("查看卡组", "View Deck", "デッキを見る"),
    ("回合结束", "End Turn", "ターン終了"),
    ("我方回合", "Your Turn", "自分のターン"),
    ("敌方回合", "Enemy Turn", "敵のターン"),
    ("战斗记录", "Battle Log", "戦闘ログ"),
    ("胜利", "Victory", "勝利"), ("失败", "Defeat", "敗北"),
    ("查看奖励", "View Rewards", "報酬を見る"),
    ("进入下一层", "Next Layer", "次の層へ"),
    ("再来一局", "Play Again", "もう一度"),
    ("全部", "All", "すべて"), ("无归属", "Unaffiliated", "所属なし"),
    ("公用初始", "Shared Starter", "共通初期"),
    ("玩家", "Player", "プレイヤー"), ("敌方", "Enemy", "敵"),
    ("确认", "Confirm", "確定"), ("确定", "Confirm", "確定"),
    ("取消", "Cancel", "キャンセル"), ("返回", "Back", "戻る"),
    ("完成", "Done", "完了"), ("详情", "Details", "詳細"),
    ("搜索", "Search", "検索"),
    ("已解锁", "Unlocked", "解放済み"), ("未解锁", "Locked", "未解放"),
    ("已达成", "Completed", "達成済み"), ("未达成", "Incomplete", "未達成"),
    ("已领取", "Claimed", "受取済み"), ("已放弃", "Skipped", "見送り済み"),
    ("已处理", "Resolved", "処理済み"), ("已耗尽", "Depleted", "消耗済み"),
    ("未获得", "Not Acquired", "未入手"), ("已获得", "Acquired", "入手済み"),
    ("已售罄", "Sold Out", "売り切れ"), ("购买", "Buy", "購入"),
    ("离开商店", "Leave Shop", "商店を出る"), ("离开", "Leave", "離れる"),
    ("休息", "Rest", "休息"), ("烤肉", "Roast Meat", "肉を焼く"),
    ("领取", "Claim", "受け取る"), ("放弃", "Skip", "見送る"),
    ("跳过", "Skip", "スキップ"), ("刷新", "Reroll", "リロール"),
    ("附魔", "Enchant", "付呪"), ("删除卡牌", "Remove Card", "カードを削除"),
    ("音效", "Sound Effects", "効果音"), ("音效音量", "SFX Volume", "効果音音量"),
    ("音乐", "Music", "音楽"), ("音乐音量", "Music Volume", "音楽音量"),
    ("全屏", "Fullscreen", "フルスクリーン"),
    ("本局种子", "Current Run Seed", "現在のランのシード"),
    ("下一局种子", "Next Run Seed", "次のランのシード"),
    ("开", "On", "オン"), ("关", "Off", "オフ"),
    ("复制种子", "Copy Seed", "シードをコピー"),
    ("语言", "Language", "言語"), ("难度", "Difficulty", "難易度"),
    ("当前难度", "Current Difficulty", "現在の難易度"),
    ("角色", "Class", "クラス"), ("职业", "Class", "クラス"),
    ("选择角色", "Choose Class", "クラスを選択"),
])

g["relics"] = named([
    ("类固醇", "Steroids", "ステロイド", {"id": 6001}),
    ("源数之力", "Numeron Force", "ヌメロン・フォース", {"id": 6002, "note": "《游戏王》专名"}),
    ("失忆药水", "Amnesia Potion", "健忘のポーション", {"id": 6004}),
    ("鸭蹼", "Duck Webbing", "アヒルの水かき", {"id": 6005}),
    ("鸭嘴", "Duck Bill", "アヒルのくちばし", {"id": 6006}),
    ("鸭翼", "Duck Wing", "アヒルの翼", {"id": 6007}),
    ("鸭绒", "Duck Down", "アヒルの綿毛", {"id": 6008}),
    ("鸭之眼", "Eye of the Duck", "アヒルの目", {"id": 6009}),
    ("鸭之低语", "Whisper of the Duck", "アヒルのささやき", {"id": 6010}),
    ("烤肉", "Barbecue", "バーベキュー", {"id": 6011, "note": "道具名；篝火动作烤肉另译 Roast Meat"}),
    ("一袋米抗几楼", "One Bag of Pain", "痛みを感じろ", {"id": 6012, "note": "佩恩台词谐音梗；英文保留 pain／米的双关"}),
    ("叠加态的鸭", "Superposition Duck", "重ね合わせ状態のアヒル", {"id": 6013}),
    ("黄桃罐头", "Canned Yellow Peaches", "黄桃缶", {"id": 6014}),
    ("鸭语耳环", "Duckspeak Earrings", "アヒル語の耳飾り", {"id": 6015}),
    ("冰淇淋与汽水", "Ice Cream & Soda", "アイスクリームとソーダ", {"id": 6016}),
    ("重鸭", "Heavy Duck", "ヘビーアヒル", {"id": 6017}),
    ("生蛋鸭", "Egg-Laying Duck", "産卵アヒル", {"id": 6018, "note": "复用既有卡名"}),
    ("鸭梨", "Duck Pear", "アヒル梨", {"id": 6019, "note": "鸭梨／压力谐音"}),
    ("奥秘护符", "Arcane Charm", "秘術の護符", {"id": 6020}),
    ("栅栏修复术", "Fence Mending", "柵修復術", {"id": 6021}),
    ("荒野形态", "Wild Shape", "野生の姿", {"id": 6022}),
    ("幻影斗篷", "Cloak of Illusions", "幻影のマント", {"id": 6023}),
    ("鸭血", "Duck Blood", "アヒルの血", {"id": 6024}),
    ("机械核心", "Mechanical Core", "機械のコア", {"id": 6025}),
    ("鹰哨", "Eagle Whistle", "鷹の笛", {"id": 6026}),
    ("苹果", "Apple", "リンゴ", {"id": 6027}),
    ("牛奶", "Milk", "牛乳", {"id": 6028}),
    ("止血绷带", "Styptic Bandage", "止血包帯", {"id": 6029}),
    ("行囊", "Traveler's Pack", "旅の行囊", {"id": 6030}),
    ("勇气徽章", "Badge of Courage", "勇気の徽章", {"id": 6031}),
    ("陶罐", "Clay Pot", "陶罐", {"id": 6032}),
    ("兼修", "Dual Training", "兼修", {"id": 6033}),
    ("附魔大师", "Enchantment Master", "付呪の達人", {"id": 6034}),
    ("泉水", "Spring Water", "泉水", {"id": 6035}),
    ("思想钢印", "Thought Brand", "思想の刻印", {"id": 6036}),
    ("荆棘指环", "Thorn Ring", "茨の指輪", {"id": 6037}),
    ("圣餐", "Sacrament", "聖餐", {"id": 6038}),
    ("雕像", "Statue", "彫像", {"id": 6039}),
    ("水晶骰子", "Crystal Die", "水晶のダイス", {"id": 6040}),
    ("不锈钢盆", "Stainless Steel Basin", "ステンレス盆", {"id": 6041}),
    ("风妖精", "Wind Fairy", "風の妖精", {"id": 6042}),
    ("快速符文", "Haste Rune", "迅速のルーン", {"id": 6043}),
    ("储物箱", "Storage Chest", "収納箱", {"id": 6044}),
    ("lucky 7", "Lucky 7", "ラッキー7", {"id": 6045}),
    ("爆米花", "Popcorn", "ポップコーン", {"id": 6046}),
    ("惊奇盒子", "Surprise Box", "びっくり箱", {"id": 6047}),
    ("洞窟绳", "Cave Rope", "洞窟のロープ", {"id": 6048}),
    ("鹿首标本", "Stag Head Trophy", "鹿の頭の剥製", {"id": 6049}),
    ("采集刀", "Gathering Knife", "採集ナイフ", {"id": 6050}),
    ("火柴", "Matchstick", "マッチ", {"id": 6051}),
    ("竖琴", "Harp", "ハープ", {"id": 6052}),
    ("骑士剑", "Knight's Sword", "騎士の剣", {"id": 6053}),
    ("暗动力", "Dark Drive", "暗黒動力", {"id": 6054}),
    ("烟斗", "Smoking Pipe", "パイプ", {"id": 6055}),
    ("冒险笔记", "Adventure Notes", "冒険ノート", {"id": 6056}),
    ("燧石", "Flint", "火打ち石", {"id": 6057}),
    ("咒缚", "Cursebind", "呪縛", {"id": 6058}),
    ("核心", "Core", "コア", {"id": 6059}),
    ("三个机器人", "Three Robots", "3体のロボット", {"id": 6060}),
    ("正义背刺", "Righteous Backstab", "正義の背刺", {"id": 6064}),
    ("机械臂", "Mechanical Arm", "機械アーム", {"id": 6065}),
    ("记忆药水", "Memory Potion", "記憶のポーション", {"id": 6067}),
])

g["levels"] = named([
    ("洞穴", "Cavern", "洞窟"),
    ("鸭子骑士来袭", "Duck Knight Attack", "アヒル騎士の襲来"),
    ("巫师的召唤", "Wizard's Summons", "魔術師の召喚"),
    ("寒冰防线", "Frost Defense Line", "氷の防衛線"),
    ("亡灵军团", "Undead Legion", "アンデッド軍団"),
    ("龙族巢穴", "Dragon's Lair", "ドラゴンの巣窟"),
    ("机甲巨兵", "Colossal Mech", "巨大機甲"),
    ("远古虚骨龙", "Ancient Hollowbone Dragon", "古の虚骨竜"),
    ("恶魔鸭", "Demon Duck", "悪魔アヒル"),
    ("恶魔鸭（复仇）", "Demon Duck (Vengeance)", "悪魔アヒル（復讐）"),
    ("机械巨鸭", "Mechanical Mega Duck", "機械巨鴨"),
    ("叛逃机械", "Rogue Machines", "叛離した機械"),
    ("鸭之暗面", "Dark Side of the Duck", "鴨の暗黒面"),
    ("赫菲斯托斯工坊", "Hephaestus's Workshop", "ヘファイストスの工房"),
    ("启示者", "The Revelator", "啓示者"),
    ("废料场", "Scrapyard", "スクラップ置き場"),
    ("骑士军团", "Knight Legion", "騎士軍団"),
    ("使魔鸭群", "Familiar Duck Flock", "使い魔アヒルの群れ"),
    ("骑士冲锋", "Knight Charge", "騎士の突撃"),
    ("队长与巫师", "Captain and Wizard", "隊長と魔術師"),
    ("弓手与骑士", "Archer and Knight", "弓兵と騎士"),
    ("爆炎鸭阵", "Blastflame Duck Formation", "爆炎アヒル陣"),
    ("白魔法鸭护阵", "White Magic Duck Ward", "白魔法アヒル護陣"),
    ("夜鸭阵", "Night Duck Formation", "夜のアヒル陣"),
    ("永夜鸭群", "Eternal Night Duck Flock", "永夜のアヒル群"),
    ("哈气骑士团", "Hissing Knight Order", "威嚇の騎士団"),
    ("赫尔墨斯的试炼", "Trial of Hermes", "ヘルメスの試練"),
    ("母舰空袭", "Mothership Airstrike", "母艦空襲"),
    ("执法者的审判", "Enforcer's Judgment", "執行者の審判"),
    ("阿斯克勒庇厄斯的试炼", "Trial of Asclepius", "アスクレピオスの試練"),
    ("普罗诺亚之影", "Shade of Pronoia", "プロノイアの影"),
    ("鸭子窑", "Duck Kiln", "アヒル窯"),
    ("太阳熔炉", "Solar Forge", "太陽の熔炉"),
    ("百臂工场", "Hecatoncheires Workshop", "百臂の工場"),
    ("量产流水线", "Mass-Production Line", "量産ライン"),
    ("量产铁砧", "Mass-Produced Anvils", "量産の金床"),
    ("百眼动员", "Argus Mobilization", "百眼の動員"),
    ("双机炮阵", "Twin Cannon Formation", "双機砲陣"),
    ("巨炮防线", "Great Cannon Line", "巨砲防衛線"),
    ("钢铁要塞", "Steel Fortress", "鋼鉄の要塞"),
    ("鸭子队长登场", "Enter the Duck Captain", "アヒル隊長登場"),
])

g["events"] = named([
    ("鸭鸭低语", "Duck Whispers", "アヒルのささやき", {"key": "whisper"}),
    ("挣扎", "Struggle", "足掻き", {"key": "struggle"}),
    ("鸭之凝视", "Gaze of the Duck", "アヒルの眼差し", {"key": "gaze"}),
    ("鸭梨山大", "Mount Duckpear", "アヒル梨山", {"key": "pear", "note": "压力山大谐音"}),
    ("绝赞五换一", "Fantastic Five-for-One", "絶賛5枚交換", {"key": "hero"}),
    ("苹果与医生", "An Apple and the Doctor", "リンゴと医者", {"key": "apple_doctor"}),
    ("奥秘之泉", "Arcane Spring", "秘術の泉", {"key": "arcane"}),
    ("遗忘之泉", "Spring of Oblivion", "忘却の泉", {"key": "oblivion"}),
    ("鸭鸭工匠", "Duck Artisan", "アヒル職人", {"key": "smith"}),
    ("卡片商人", "Card Merchant", "カード商人", {"key": "card_merchant"}),
    ("湖中仙女", "Lady of the Lake", "湖の乙女", {"key": "lake_lady"}),
    ("占卜室", "Divination Room", "占いの間", {"key": "divination"}),
    ("赏月", "Moon Viewing", "月見", {"key": "moon"}),
    ("熔炉", "Furnace", "熔炉", {"key": "furnace"}),
    ("契约的核心", "Heart of the Contract", "契約の核心", {"key": "core_contract"}),
    ("洞穴", "Cavern", "洞窟", {"key": "cave"}),
    ("雪豹出现", "A Snow Leopard Appears", "雪豹現る", {"key": "snow_leopard"}),
    ("冒险家的遗物", "Adventurer's Relic", "冒険者の遺物", {"key": "adventurer"}),
    ("武术大师", "Martial Arts Master", "武術の達人", {"key": "martial"}),
    ("飞行器", "Flying Machine", "飛行機械", {"key": "flyer"}),
    ("运送委托", "Delivery Request", "配送依頼", {"key": "delivery"}),
    ("委托完成", "Delivery Complete", "依頼完了", {"key": "delivery_done"}),
    ("卡牌宝箱", "Card Chest", "カード宝箱", {"key": "treasure"}),
    ("宝箱层", "Treasure Floor", "宝箱フロア", {"key": "relic_chest"}),
])

g["stories"] = named([
    ("游移的音准", "Wandering Pitch", "揺れる音程", {"id": "episode1"}),
    ("鸭鸭王国的请托", "Request from the Duck Kingdom", "アヒル王国からの依頼", {"id": "episode2"}),
    ("委托之外", "Beyond the Request", "依頼の外で", {"id": "episode3"}),
    ("一个声音", "A Voice", "一つの声", {"id": "episode4"}),
    ("新的委托", "A New Request", "新たな依頼", {"id": "episode5"}),
    ("轰鸣之后", "After the Roar", "轟音のあと", {"id": "episode6"}),
    ("苏醒", "Awakening", "目覚め", {"id": "profile1"}),
    ("量产型", "Mass-Produced", "量産型", {"id": "profile2"}),
    ("机械巨鸭", "Mechanical Mega Duck", "機械巨鴨", {"id": "profile3"}),
    ("闲谈", "Idle Chat", "雑談", {"id": "profile4"}),
    ("通缉令", "Wanted Notice", "指名手配", {"id": "profile5"}),
])
g["achievements"] = named([
    ("森林的伙伴们", "Friends of the Forest", "森の仲間たち", {"id": "ach_first_run"}),
    ("沼泽的引路者", "Guide of the Marsh", "沼の導き手", {"id": "ach_clear"}),
    ("委托之外", "Beyond the Request", "依頼の外で", {"id": "ach_rogue_run"}),
    ("一个声音", "A Voice", "一つの声", {"id": "ach_mech_run"}),
    ("新的委托", "A New Request", "新たな依頼", {"id": "ach_boss_seen_two"}),
    ("轰鸣之后", "After the Roar", "轟音のあと", {"id": "ach_episode6"}),
    ("苏醒", "Awakening", "目覚め", {"id": "ach_profile1"}),
    ("量产型", "Mass-Produced", "量産型", {"id": "ach_profile2"}),
    ("机械巨鸭", "Mechanical Mega Duck", "機械巨鴨", {"id": "ach_profile3"}),
    ("闲谈", "Idle Chat", "雑談", {"id": "ach_profile4"}),
    ("通缉令", "Wanted Notice", "指名手配", {"id": "ach_profile5"}),
    ("初次启程", "First Journey", "初めての旅", {"id": "FIRST_STEP"}),
    ("直面恐惧", "Face Your Fears", "恐怖に向き合う", {"id": "FIRST_BOSS"}),
    ("深入腹地", "Into the Heartland", "奥地へ", {"id": "LAYER2_CLEAR"}),
    ("完整通关", "Full Clear", "完全クリア", {"id": "FULL_CLEAR"}),
    ("森林的加冕", "Coronation of the Forest", "森の戴冠", {"id": "CLEAR_FOREST"}),
    ("影中的圆满", "Fulfillment in the Shadows", "影の円満", {"id": "CLEAR_ROGUE"}),
    ("机械的觉醒", "Awakening of the Machine", "機械の覚醒", {"id": "CLEAR_MECH"}),
    ("越难越勇", "Braver with Every Trial", "難しいほど勇ましく", {"id": "CLEAR_HARD"}),
])

# 结构化真源覆盖：新增内容漏进术语表时直接失败。
relics = json.loads((ROOT / "relics.json").read_text(encoding="utf-8-sig"))["relics"]
stories = json.loads((ROOT / "stories.json").read_text(encoding="utf-8-sig"))
levels_text = (ROOT / "scripts/game_levels.gd").read_text(encoding="utf-8")
layers_text = (ROOT / "scripts/game_layers.gd").read_text(encoding="utf-8")
card_data = (ROOT / "scripts/card_data.gd").read_text(encoding="utf-8")
run_state = (ROOT / "scripts/run_state.gd").read_text(encoding="utf-8")
map_scene = (ROOT / "scripts/map_scene.gd").read_text(encoding="utf-8")

def block_between(text, start, end):
    return re.search(re.escape(start) + r"(.*?)" + re.escape(end), text, re.S).group(1)

def check(section, expected):
    actual = set(g[section])
    expected = set(expected)
    assert actual == expected, "%s missing=%s extra=%s" % (section, sorted(expected - actual), sorted(actual - expected))
    print("%s: %d OK" % (section, len(actual)))

check("relics", [r["name"] for r in relics])
check("relic_kinds", [r["kind"] for r in relics])
check("relic_sources", [r["source"] for r in relics])
check("relic_tiers", [r["tier"] for r in relics])
check("levels", re.findall(r"^\s*\"name\": \"([^\"]+)\"", levels_text, re.M))
event_block = block_between(layers_text, "const EVENT_NAMES := {", "\n}")
check("events", [v for k, v in re.findall(r"\"([^\"]+)\": \"([^\"]+)\"", event_block)])
check("stories", [x["title"] for x in stories["episodes"] + stories["profiles"]])
check("achievements", [x["name"] for x in stories["achievements"]] + ["初次启程", "直面恐惧", "深入腹地", "完整通关", "森林的加冕", "影中的圆满", "机械的觉醒", "越难越勇"])
check("difficulties", re.findall(r"\"([^\"]+)\"", block_between(run_state, "const DIFFICULTY_NAMES", "## 各档位")))
check("difficulty_notes", re.findall(r"\"([^\"]*)\"", block_between(run_state, "const DIFFICULTY_TEXTS", "## R224：全局规则")))
check("enchantments", re.findall(r"\"label\": \"([^\"]+)\"", block_between(card_data, "const ENCHANT_DEFS", "\n}" )
))
check("rooms", re.findall(r"\"[^\"]+\": \"([^\"]+)\"", block_between(map_scene, "const ENTER_LABELS", "\n}")) + ["精英", "休息", "篝火", "未知房间", "迷雾", "通路", "当前房间", "已探索", "未探索", "入夜", "第一层", "第二层", "第三层"])
check("rarities", re.findall(r"\"([^\"]+)\"", block_between(card_data, "const RARITY_NAMES", "\n## 卡面边框色")))

# 每个条目都必须有两种译文；id 与 key 一旦登记必须与真源一致。
for section, entries in g.items():
    if not isinstance(entries, dict) or section in ("brand",):
        continue
    for zh, entry in entries.items():
        if isinstance(entry, dict) and ("en" in entry or "ja" in entry):
            assert entry.get("en") and entry.get("ja"), "%s/%s translation empty" % (section, zh)
for r in relics:
    assert g["relics"][r["name"]]["id"] == r["id"]
for key, zh in re.findall(r"\"([^\"]+)\": \"([^\"]+)\"", event_block):
    assert g["events"][zh]["key"] == key
for x in stories["episodes"] + stories["profiles"]:
    assert g["stories"][x["title"]]["id"] == x["id"]
for x in stories["achievements"]:
    assert g["achievements"][x["name"]]["id"] == x["id"]
# 同名剧情／成就不得译成两套。
for x in stories["achievements"]:
    if x["name"] in g["stories"]:
        assert (g["achievements"][x["name"]]["en"], g["achievements"][x["name"]]["ja"]) == (g["stories"][x["name"]]["en"], g["stories"][x["name"]]["ja"])
# 同名关卡／事件与专名也不得漂移。
for zh in set(g["levels"]) & set(g["events"]):
    assert (g["levels"][zh]["en"], g["levels"][zh]["ja"]) == (g["events"][zh]["en"], g["events"][zh]["ja"])

PATH.write_text(json.dumps(g, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print("wrote", PATH, "sections", len(g))
