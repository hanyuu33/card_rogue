# -*- coding: utf-8 -*-
"""R761 补丁 1/9：player_class.gd —— 新增隐藏职业「吟游诗人」。

铁律：exact-replace + assert count==1，按字节读写（LF 不变）。
"""
import io

P = r"E:\work\card_rogue\scripts\player_class.gd"

with io.open(P, "rb") as f:
    b = f.read()


def rep(old, new, n=1):
    global b
    o = old.encode("utf-8")
    c = b.count(o)
    assert c == n, "命中 %d 次（期望 %d）：%r" % (c, n, old[:80])
    b = b.replace(o, new.encode("utf-8"))


# ---- 1. 常量区：加隐藏职业 ----
rep(
    'const MECH := "机械之心"          # R82：0 费素体滚雪球 + 「升级」改造场面\n',
    'const MECH := "机械之心"          # R82：0 费素体滚雪球 + 「升级」改造场面\n'
    '## R761：**隐藏职业**。默认玩家感知不到 —— 不在选人界面、不进图鉴、不进任何随机池；\n'
    '## 只有打开「特殊版本」开关（命令行 `-- --bard` / `PlayerClass.set_bard_enabled(true)` /\n'
    '## AI 对局桥的 `/mode {"bard":true}`）才会多出一枚可选头像。\n'
    '## 卡牌归属写在 cards.json 的 `class` 字段（"吟游诗人"），见 `is_hidden_class()`。\n'
    'const BARD := "吟游诗人"\n',
)

# ---- 2. 隐藏职业开关（放在 BASE_HP 之前）----
rep(
    '## 玩家初始最大生命的**基础值**（R182 起按职业加加成）。\n',
    '## ── 隐藏职业开关（R761）──\n'
    '## `-1` = 跟随命令行（默认）；`0` / `1` = 被 `set_bard_enabled()` 强制。\n'
    '## ⚠️ 判据**只在这一个函数里**：界面 / 卡池 / 图鉴全都读 `bard_enabled()`，\n'
    '##    别在别处再写一遍 `--bard in args`。\n'
    'static var _bard_forced := -1\n'
    'const BARD_ARG := "--bard"\n'
    '\n'
    '\n'
    'static func bard_enabled() -> bool:\n'
    '\t## 吟游诗人这个隐藏职业此刻是否**可见可玩**（特殊版本）。\n'
    '\t## 默认关：命令行没带 `-- --bard` 时玩家完全感知不到它。\n'
    '\tif _bard_forced >= 0:\n'
    '\t\treturn _bard_forced == 1\n'
    '\treturn BARD_ARG in OS.get_cmdline_user_args()\n'
    '\n'
    '\n'
    'static func set_bard_enabled(v: bool) -> void:\n'
    '\t## 开关的**唯一写入口**（AI 对局桥 `/mode`、测试注入）。\n'
    '\t## 生产代码里只有命令行那一条路径，不会自己打开。\n'
    '\t_bard_forced = 1 if v else 0\n'
    '\n'
    '\n'
    'static func is_hidden_class(cid: String) -> bool:\n'
    '\t## 是不是「隐藏职业」—— 图鉴 / 禁卡表 / 随机奖励池一律要把它筛掉。\n'
    '\t## 唯一判据口：`CardRepo` / `gallery_scene` 都读这里，不许各处比字符串。\n'
    '\treturn cid == BARD\n'
    '\n'
    '\n'
    '## 玩家初始最大生命的**基础值**（R182 起按职业加加成）。\n',
)

# ---- 3. ids() 注释 + all_ids / playable_ids ----
rep(
    '## 可选角色（顺序 = 角色选择界面的展示顺序）。\n'
    'static func ids() -> Array[String]:\n'
    '\treturn [DRUID, ROGUE, MECH]\n',
    '## **可见**角色（顺序 = 角色选择界面的展示顺序）。\n'
    '## R761：隐藏职业**永远不在这里** —— 这一份是「玩家看得见的三个」，\n'
    '## 图鉴职业下拉 / 禁卡表页签 / 随机摇人 / 解锁体系全都读它，于是吟游诗人\n'
    '## 天然进不去任何玩家可见的列表。要连隐藏职业一起处理请用 `all_ids()`。\n'
    'static func ids() -> Array[String]:\n'
    '\treturn [DRUID, ROGUE, MECH]\n'
    '\n'
    '\n'
    'static func hidden_ids() -> Array[String]:\n'
    '\t## 隐藏职业（R761 起只有吟游诗人）。\n'
    '\treturn [BARD]\n'
    '\n'
    '\n'
    'static func all_ids() -> Array[String]:\n'
    '\t## **全集**（可见 + 隐藏）。只给素材审计 / 存档校验 / 回归用 —— **别拿来画界面**。\n'
    '\tvar out := ids()\n'
    '\tout.append_array(hidden_ids())\n'
    '\treturn out\n'
    '\n'
    '\n'
    'static func playable_ids() -> Array[String]:\n'
    '\t## 此刻**真能开局选到**的职业：可见三个 + （开关打开时）吟游诗人。\n'
    '\t## 选人界面与 AI 对局桥的 `new_run` 读这一份；随机摇人仍走 `ids()`。\n'
    '\tvar out := ids()\n'
    '\tif bard_enabled():\n'
    '\t\tout.append(BARD)\n'
    '\treturn out\n',
)

# ---- 4a. 副标题 ----
rep(
    '\t\tMECH:\n'
    '\t\t\treturn "拆解重组 · 用「升级」把单位越堆越强"\n'
    '\treturn ""\n',
    '\t\tMECH:\n'
    '\t\t\treturn "拆解重组 · 用「升级」把单位越堆越强"\n'
    '\t\tBARD:\n'
    '\t\t\treturn "弦上生风 · 借他人之力奏自己的歌"\n'
    '\treturn ""\n',
)

# ---- 4b. 介绍 ----
rep(
    '\t\t\t\t+ "可以留到合适的时机再逐个「升级」，养成难以击破的硬块。\\n起手偏慢，一旦成型就很难被单个点破。"\n'
    '\treturn ""\n',
    '\t\t\t\t+ "可以留到合适的时机再逐个「升级」，养成难以击破的硬块。\\n起手偏慢，一旦成型就很难被单个点破。"\n'
    '\t\tBARD:\n'
    '\t\t\t## R761：隐藏职业。打法取向 = 借牌 —— 自己的卡很少，靠「招募」把别职业盟友\n'
    '\t\t\t## 拉进手牌，再由初始道具「诗」把这些外来的盟友喂成主力。\n'
    '\t\t\treturn ("借力打力。自己的卡只有两张杜鹃，主力全靠「招募」从别的职业借来，"\n'
    '\t\t\t\t\t+ "再用「诗」给这些外来盟友加力量、顺便回费。\\n自己的底子薄，"\n'
    '\t\t\t\t\t+ "手牌一旦断档就会很难受。")\n'
    '\treturn ""\n',
)

# ---- 5. 赠品道具 ----
rep(
    '\t\tMECH:\n'
    '\t\t\treturn 6025\n'
    '\treturn -1\n',
    '\t\tMECH:\n'
    '\t\t\treturn 6025\n'
    '\t\tBARD:\n'
    '\t\t\treturn 6069   # R761「诗」：每回合第一次用别职业盟友回 1 费 + 别职业盟友力量 +2\n'
    '\treturn -1\n',
)

# ---- 6. 专属初始卡 ----
rep(
    '\t\tMECH:\n'
    '\t\t\treturn [8026, 8026, 8027]   # 构装体 ×2 + 升级 ×1\n'
    '\treturn []\n',
    '\t\tMECH:\n'
    '\t\t\treturn [8026, 8026, 8027]   # 构装体 ×2 + 升级 ×1\n'
    '\t\tBARD:\n'
    '\t\t\t## R761：杜鹃 ×2（3 费 3/1/1/8 盟友，同时充当「基础盟友」那两张）+ 招募 ×1。\n'
    '\t\t\t## 合计 5 木栅栏 + 5 攻击 + 2 杜鹃 + 1 招募 = 13 张，与其它职业同宽。\n'
    '\t\t\treturn [9263, 9263, 9264]\n'
    '\treturn []\n',
)

# ---- 7. 基础盟友替换 ----
rep(
    '\tmatch cid:\n'
    '\t\tROGUE:\n'
    '\t\t\treturn 8005\n'
    '\t\tMECH:\n'
    '\t\t\treturn -1\n'
    '\treturn 8003\n',
    '\tmatch cid:\n'
    '\t\tROGUE:\n'
    '\t\t\treturn 8005\n'
    '\t\tMECH:\n'
    '\t\t\treturn -1\n'
    '\t\tBARD:\n'
    '\t\t\t## R761：吟游诗人不用别职业的基础盟友 —— 那两张位置由它自己的杜鹃占掉\n'
    '\t\t\t## （杜鹃同样 3 费 3/1/1/8，见 `bonus_deck_of`）。\n'
    '\t\t\treturn -1\n'
    '\treturn 8003\n',
)

# ---- 8. 初始生命加成 ----
rep(
    '\t\tMECH:\n'
    '\t\t\treturn 16\n'
    '\treturn 0\n',
    '\t\tMECH:\n'
    '\t\t\treturn 16\n'
    '\t\tBARD:\n'
    '\t\t\treturn 14   # R761：底子薄但比刺客厚一点（64 血）\n'
    '\treturn 0\n',
)

with io.open(P, "wb") as f:
    f.write(b)
print("player_class.gd OK")
