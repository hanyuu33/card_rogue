# -*- coding: utf-8 -*-
"""R805：event_scene.gd 实装「诡异洋房」haunted_house（第二层事件）。保持 LF。

选项 1 探索 = 一件随机传奇道具 + 一组史诗卡牌 → **当场开奖励页领取**
（直连 `_reward_panel.open()`，不经过战斗胜利面板）
＋ 一张诅咒「诅咒娃娃」入卡组；选项 2 离开。
"""
import io

P = "E:/work/card_rogue/scripts/event_scene.gd"
d = open(P, "rb").read().decode("utf-8")
assert d.count("\r\n") == 0, "event_scene.gd 不是纯 LF"


def rep(old, new, cnt=1):
    global d
    assert d.count(old) == cnt, "锚点命中 %d 次（应 %d）：%r" % (d.count(old), cnt, old[:80])
    d = d.replace(old, new)


# ① 文案常量
rep(
    "# R573：蓝色大肥鱼事件已删除。只留一句旧存档兜底文案，不发任何奖励。\n",
    "# R805 诡异洋房（haunted_house，第二层专属）：\n"
    "#   选项 1 探索 → 当场开一次奖励页（一件随机**传奇**道具 + 一组**史诗**卡牌三选一）\n"
    "#   ＋ 一张诅咒「诅咒娃娃」9276 强制进卡组；选项 2 离开。\n"
    "#   收益是全场最高那一档，代价是**贯穿整局**的每回合掉血 —— 所以只在第二层登记。\n"
    "const HAUNTED_CURSE_ID := 9276   # 诅咒娃娃（诅咒 · 不可打出 · 保存）\n"
    "\n"
    'const HAUNTED_DESC := """林道尽头立着一栋两层的旧洋房。窗框的漆掉得差不多了，\n'
    "玻璃却一块没碎，里面透出昏黄的光。\n"
    "门虚掩着，没有风，也没有脚步声——可那盏灯是亮着的。\n"
    "门楣上钉着一块掉了色的木牌：此屋无人。\n"
    "楼上有扇窗关着窗帘，光却从缝里漏出来，慢慢地、很有规律地晃。\n"
    '"""\n'
    "\n"
    'const HAUNTED_TAKEN_DESC := """门在你身后自己合上了。\n'
    "壁炉是冷的，茶几上摊着几只布袋和几张写满字的卡，\n"
    "像是有人收拾到一半就匆匆离开了。\n"
    "你把东西收进怀里的时候，楼上传来一声很轻的响动——\n"
    "像是有谁把一只脚从床上放了下来。\n"
    "等你走出门口回头，窗台上多了一只布娃娃，正对着你的方向坐着。\n"
    '"""\n'
    "\n"
    "# R573：蓝色大肥鱼事件已删除。只留一句旧存档兜底文案，不发任何奖励。\n"
)

# ② 状态变量
rep(
    'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）\n',
    'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）\n'
    "var _house_done := false        # R805 诡异洋房：本次是否已探索（探索过就只剩离开）\n"
    'var _house_result := ""         # R805 诡异洋房：收尾那行结果（重绘要能复现）\n'
)

# ③ 判据函数（放在 _is_choco_factory 之后）
rep(
    'func _is_bluefish() -> bool:\n',
    'func _is_haunted_house() -> bool:\n'
    '\t## R805 诡异洋房（第二层专属事件）。\n'
    '\treturn _is_event_node() and _pending_kind() == "haunted_house"\n'
    '\n'
    '\n'
    'func _is_bluefish() -> bool:\n'
)

# ④ _is_treasure 的兜底排除（漏了会把洋房当成小宝箱）
rep(
    "\t\t\tand not _is_flyer() and not _is_statue() and not _is_sword() \\\n"
    "\t\t\tand not _is_choco_factory()\n",
    "\t\t\tand not _is_flyer() and not _is_statue() and not _is_sword() \\\n"
    "\t\t\tand not _is_choco_factory() and not _is_haunted_house()\n"
)

# ⑤ _kind() 分支
rep(
    '\tif _is_choco_factory():\n'
    '\t\treturn "factory"\n'
    '\tif _is_treasure():\n',
    '\tif _is_choco_factory():\n'
    '\t\treturn "factory"\n'
    '\tif _is_haunted_house():\n'
    '\t\treturn "haunted_house"\n'
    '\tif _is_treasure():\n'
)

# ⑥ 主题色：危险组（暗红）—— 它的代价是持续掉血
rep(
    '\t\t"struggle", "gaze", "oblivion", "furnace", "core_contract":\n',
    '\t\t"struggle", "gaze", "oblivion", "furnace", "core_contract", "haunted_house":\n'
)

# ⑦ _ready 里的界面铺排
rep(
    "\telif _is_choco_factory():\n"
    "\t\tevent_name.text = \"巧 克 力 工 厂\"\n",
    "\telif _is_haunted_house():\n"
    "\t\tevent_name.text = \"诡 异 洋 房\"\n"
    "\t\tdesc.text = HAUNTED_TAKEN_DESC if _house_done else HAUNTED_DESC\n"
    "\t\tif _house_done:\n"
    "\t\t\t_collapse_to_leave()\n"
    "\t\t\tresult_label.text = _house_result\n"
    "\t\t\tresult_label.add_theme_color_override(\"font_color\", Color(\"a98ad4\"))\n"
    "\t\telse:\n"
    "\t\t\trest_btn.visible = true\n"
    "\t\t\trest_btn.text = \"推门进去（传奇道具 ＋ 史诗卡牌，代价是「诅咒娃娃」）\"\n"
    "\t\t\trest_btn.disabled = false\n"
    "\t\t\tbbq_btn.visible = false\n"
    "\t\t\talt_btn.visible = false\n"
    "\t\t\tleave_btn.visible = true\n"
    "\t\t\tleave_btn.text = \"掉头离开（这栋房子不该有人住）\"\n"
    "\t\t\tleave_btn.disabled = false\n"
    "\t\t\tresult_label.text = \"\"\n"
    "\telif _is_choco_factory():\n"
    "\t\tevent_name.text = \"巧 克 力 工 厂\"\n"
)

# ⑧ _on_main 分支（放最前：其余分支都以 kind 判据互斥，谁先都行，这里紧邻 cave）
rep(
    "\tif _is_cave():\n\t\t_cave_explore()\n\t\treturn\n",
    "\tif _is_haunted_house():\n"
    "\t\t_explore_haunted_house()\n"
    "\t\treturn\n"
    "\tif _is_cave():\n"
    "\t\t_cave_explore()\n"
    "\t\treturn\n"
)

# ⑨ 主体逻辑，插在 _setup_factory_button 之前
rep(
    "func _setup_factory_button() -> void:\n",
    "func _explore_haunted_house() -> void:\n"
    "\t## R805 诡异洋房 · 选项 1「探索」。三件事一次做完：\n"
    "\t##   ① 一件随机**传奇**道具入队（`roll_legendary_relic()`，池空返回 -1）；\n"
    "\t##   ② 一组**史诗**卡牌三选一入队（`queue_card_reward(\"epic\")`，100% 史诗档）；\n"
    "\t##   ③ 一张「诅咒娃娃」**直接进卡组** —— 它不是奖励，是代价，所以**不入队**，\n"
    "\t##      玩家没有「不领」这个选项。\n"
    "\t## 然后当场 `_reward_panel.open()`：**这里就是「没有战斗胜利标记的奖励页」**——\n"
    "\t## 战斗那边的入口是 `battle_scene._present_win_panel()`（金框大字「战斗胜利」+ 金币，\n"
    "\t## 点「查看奖励」才开窗），事件页直接开窗，那一整块根本不经过。\n"
    "\t## ⚠️ 必须先入队再 open：`open()` 读的就是 `RunState.pending_rewards`，空队列开出来是空页。\n"
    "\t## ⚠️ 不在这里替玩家领：关窗时没领的条目跟着地图左上「✦ 待领奖励」走（R695 口径）。\n"
    "\tif _house_done:\n"
    "\t\t_on_leave()\n"
    "\t\treturn\n"
    "\t_house_done = true\n"
    "\t_claim_reward(rest_btn)\n"
    "\t_collapse_to_leave()\n"
    "\tvar relic_id := RunState.roll_legendary_relic()\n"
    "\tvar relic_name := \"\"\n"
    "\tif relic_id > 0:\n"
    "\t\tRunState.queue_relic_reward(relic_id)\n"
    "\t\tvar rd := RelicRepo.load_json().get_relic(relic_id)\n"
    "\t\trelic_name = rd.relic_name if rd != null else str(relic_id)\n"
    "\tRunState.queue_card_reward(\"epic\", [] as Array[String], \"event\")\n"
    "\tRunState.add_card(HAUNTED_CURSE_ID)\n"
    "\tdesc.text = HAUNTED_TAKEN_DESC\n"
    "\tif relic_id > 0:\n"
    "\t\t_house_result = (\"「%s」和一组史诗卡牌已放进待领奖励——在上面弹出的奖励页里挑；\"\n"
    "\t\t\t\t% relic_name) + \"「诅咒娃娃」已加入卡组，它不会走。\"\n"
    "\telse:\n"
    "\t\t_house_result = (\"传奇道具已经全部拿过了，屋里只剩那组史诗卡牌——\"\n"
    "\t\t\t\t+ \"「诅咒娃娃」照样钻进你的卡组，它不会走。\")\n"
    "\tresult_label.text = _house_result\n"
    "\tresult_label.add_theme_color_override(\"font_color\", Color(\"a98ad4\"))\n"
    "\tif _reward_panel != null:\n"
    "\t\t_reward_panel.open()\n"
    "\t_redraw()\n"
    "\n"
    "\n"
    "func _setup_factory_button() -> void:\n"
)

# ⑩ _refresh 白名单（漏登记会被当成休息处，按钮文案被刷成「在这里休息」）
rep(
    "\t\t\tor _is_core_contract() or _is_flyer() or _is_statue() or _is_sword() \\\n"
    "\t\t\tor _is_choco_factory():\n",
    "\t\t\tor _is_core_contract() or _is_flyer() or _is_statue() or _is_sword() \\\n"
    "\t\t\tor _is_choco_factory() or _is_haunted_house():\n"
)

# ⑪ 演示参数（截图验证用）
rep(
    '\t\tif args[i] == "--sword":  # R793 演示：伪装 run 林中的剑事件（截图验证）\n',
    '\t\tif args[i] == "--house":  # R805 演示：伪装 run 诡异洋房事件（截图验证）\n'
    "\t\t\tRunState.run_active = true\n"
    "\t\t\tRunState.pending_node = {\"type\": \"event\"}\n"
    '\t\t\tRunState.pending_event = "haunted_house"\n'
    '\t\tif args[i] == "--sword":  # R793 演示：伪装 run 林中的剑事件（截图验证）\n'
)

io.open(P, "wb").write(d.encode("utf-8"))
print("ok lines=%d crlf=%d" % (d.count("\n"), d.count("\r\n")))
