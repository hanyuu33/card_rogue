# -*- coding: utf-8 -*-
"""R830：首饰盒 6088 —— test_engine.gd 补丁（CRLF）。

加 _test_r830() + 主函数调用点 + 翻面 5 处断言。exact-replace + assert count==1。
"""
PATH = "E:/work/card_rogue/scripts/test_engine.gd"
CRLF = "\r\n"


def read():
    return open(PATH, "rb").read().decode("utf-8")


data = read()

repls = [
    # ① 主函数调用点
    (
        "\t_test_r829()\r\n\r\n\tprint(\"== 结果：",
        "\t_test_r829()\r\n\t_test_r830()\r\n\r\n\tprint(\"== 结果：",
    ),
    # ② 5 处断言翻面
    (
        "\tcheck(relic_repo.initial_ids().size() == 10 and relic_repo.get_relic(6001) != null\r",
        "\tcheck(relic_repo.initial_ids().size() == 11 and relic_repo.get_relic(6001) != null\r",
    ),
    (
        "\t\t\t\"道具库：10 个初始道具全部加载（+ 栅栏修复术 6021 / 行囊 6030 / 勇气徽章 6031 / "
        "陶罐 6032 / R341 惊奇盒子 6047 · 洞窟绳 6048 / R745 工具箱 6068）\")\r",
        "\t\t\t\"道具库：11 个初始道具全部加载（+ 栅栏修复术 6021 / 行囊 6030 / 勇气徽章 6031 / "
        "陶罐 6032 / R341 惊奇盒子 6047 · 洞窟绳 6048 / R745 工具箱 6068 / R830 首饰盒 6088）\")\r",
    ),
    (
        "\tcheck(r244_init.size() == 10 and r244_init.has(6030) and not r244_init.has(6003),\r",
        "\tcheck(r244_init.size() == 11 and r244_init.has(6030) and not r244_init.has(6003),\r",
    ),
    (
        "\t\t\t\"R244 初始道具池：移除鸡煲 6003、加入行囊 6030（R745 后共 10 个）\")\r",
        "\t\t\t\"R244 初始道具池：移除鸡煲 6003、加入行囊 6030（R830 后共 11 个）\")\r",
    ),
    (
        "\tcheck(icon577_src_ok and icon577_repo.all_relics().size() == 82,\r",
        "\tcheck(icon577_src_ok and icon577_repo.all_relics().size() == 83,\r",
    ),
    (
        "\t\t\t\"R577b 保真锁：82 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / "
        "墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / "
        "R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / "
        "海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087）\")\r",
        "\t\t\t\"R577b 保真锁：83 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / "
        "墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / "
        "R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / "
        "海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087 / "
        "R830 +首饰盒 6088）\")\r",
    ),
    (
        "\tcheck(r810_repo.all_relics().size() == 82, \"R824 数据层：道具总数 82 件（+鸭子闹钟 6085 / "
        "R826 音乐盒 6086 / R829 这是礼帽 6087）\")\r",
        "\tcheck(r810_repo.all_relics().size() == 83, \"R824 数据层：道具总数 83 件（+鸭子闹钟 6085 / "
        "R826 音乐盒 6086 / R829 这是礼帽 6087 / R830 首饰盒 6088）\")\r",
    ),
]

for old, new in repls:
    c = data.count(old)
    assert c == 1, "锚点出现 %d 次（期望 1）：%r" % (c, old[:60])
    data = data.replace(old, new, 1)

# ③ 文件末尾追加 _test_r830()（前导一个空行，凑成函数间两个空行）
fn_lines = [
    "func _test_r830() -> void:",
    "\t## R830（店长口径）：新增一层初始道具「首饰盒」6088 —— 获得即随机一张史诗卡加入卡组。",
    "\tvar repo := CardRepo.load_json()",
    "\tvar rrepo := RelicRepo.load_json()",
    "",
    "\t# ── ① 数据层：6088 在库 · 即时 · 初始 · 一般 ──",
    "\tvar r830_jb := rrepo.get_relic(6088)",
    "\tcheck(r830_jb != null and r830_jb.relic_name == \"首饰盒\"",
    "\t\t\tand r830_jb.kind == \"即时\" and r830_jb.source == \"初始\" and r830_jb.tier == \"一般\",",
    "\t\t\t\"R830 数据：6088 首饰盒（即时 · 初始 · 一般）\")",
    "\tcheck(r830_jb.desc.contains(\"史诗\") and r830_jb.desc.contains(\"卡组\"),",
    "\t\t\t\"R830 文案：写着史诗 / 卡组（%s）\" % r830_jb.desc)",
    "",
    "\t# ── ② 池子：首饰盒进初始池，不进奖励 / 事件 / 二层起始 ──",
    "\tcheck(rrepo.initial_ids().has(6088), \"R830 池：首饰盒在一层初始池\")",
    "\tcheck(not rrepo.reward_ids().has(6088) and not rrepo.event_ids().has(6088)",
    "\t\t\tand not rrepo.layer2_ids().has(6088), \"R830 池：不进奖励 / 事件 / 二层起始池\")",
    "\tcheck(DemoScope.allows_relic(6088), \"R830 试玩版：6088 在 demo_scope 基线里\")",
    "",
    "\t# ── ③ 逻辑：获得即随机一张史诗卡加入卡组 ──",
    "\tRunState.deck_ids = [8001, 8002]",
    "\tRunState.ensure_deck_mods()",
    "\tvar r830_deck0 := RunState.deck_ids.size()",
    "\tRunState.gain_relic(RunState.JEWELRY_BOX_RELIC_ID)",
    "\tvar r830_last := RunState.deck_ids[RunState.deck_ids.size() - 1]",
    "\tvar r830_c := repo.get_card(r830_last)",
    "\tcheck(RunState.deck_ids.size() == r830_deck0 + 1 and r830_c != null and r830_c.rarity == 2,",
    "\t\t\t\"R830 首饰盒：获得即随机一张史诗卡加入卡组（%s）\"",
    "\t\t\t% (r830_c.card_name if r830_c != null else \"?\"))",
    "",
]
fn = "\r\n" + CRLF.join(fn_lines) + "\r\n"
data += fn

open(PATH, "w", encoding="utf-8", newline="\n").write(data)

data = read()
print("=== 验证 ===")
print("_test_r830 调用:", data.count("\t_test_r830()"))
print("func _test_r830:", data.count("func _test_r830()"))
print("CRLF=%d 裸LF=%d" % (data.count("\r\n"), data.count("\n") - data.count("\r\n")))
print("initial_ids == 11:", data.count("initial_ids().size() == 11"))
print("r244_init == 11:", data.count("r244_init.size() == 11"))
print("all_relics == 83:", data.count("all_relics().size() == 83"))
print("末尾:", repr(data[-20:]))
