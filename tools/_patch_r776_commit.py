# -*- coding: utf-8 -*-
"""R776 隔离提交：工作区里混着并行会话的 9269 彩虹诗，只提交我这一份。

做法：先把六个文件的「我的版本」换进工作区 → pathspec 提交 → 立刻还原「合并版本」。
还原前比对 md5：若期间对方又写过，就保留对方的内容，绝不覆盖。
"""
import hashlib
import os
import shutil
import subprocess

REPO = "E:/work/card_rogue"
MINE = "E:/tmp/r776_mine"
MERGED = "E:/tmp/r776_merged"

FILES = [
    "cards.json",
    "i18n/cards_en.json",
    "i18n/cards_ja.json",
    "i18n/zh_canonical.json",
    "scripts/game_engine.gd",
    "scripts/test_engine.gd",
]
TOOLS = [
    "tools/_patch_r776_data.py",
    "tools/_patch_r776_engine.py",
    "tools/_patch_r776_tests.py",
    "tools/_patch_r776_fix.py",
]

MSG = """R776：激励乐章（吟游诗人 1 费普通技能）+ 管风琴（4 费史诗工事）

卡面：
* 9267 激励乐章：本回合场上所有盟友力量 +4；原本职业不属于自己的盟友改为 +6。
* 9268 管风琴：0 力量 / 射程 7 / 19 生命。攻击时，从卡组将一张随机技能卡加入手卡，
  该卡本回合费用 -1。在场时，每使用一张技能卡，对所有敌人造成 3 点伤害。

实现口径：
* 「本回合」走 Placement.atk_buff_turn（end_turn 统一清零），不是 totem_atk 那层持续 buff；
  「其他职业」复用 _other_class_card() 唯一判据（有归属 + 非当前职业，公用卡不算）。
* 管风琴的攻击触发复用 _fetch_skill_card()（赤狐 9034 的唯一口），不另写取牌逻辑；
  挂在 attack() 与 attack_hp() 尾部，与咏唱者 / 祭坛同一排。
* 「每使用一张技能卡」挂在 _note_card_played()（出牌唯一收尾口），与疾风 / 潜影者同一排；
  场上每台各结算一份；伤害是定值 3，不套 _spell_dmg（卡面写死，被光环抬成 4 就不是这张卡）。
* 射程 7 是「攻击时」的前提：0 力量也能攻击，只有 0 射程不能（引擎既有口径）。

计数同步：图鉴 329 / 玩家 251 / 吟游诗人 5 / R226 技能 106（能造成伤害仍 42 张）。
新增 32 条断言：力量分层 +4/+6、回合结束清零、空场吃费、攻击取技能卡并 -1、
技能触发 3 伤、盟友不触发、两台叠算、离场失效、en/ja 译文。"""


def md5(path):
    with open(path, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def main():
    before = {}
    for f in FILES:
        dst = os.path.join(REPO, f)
        before[f] = md5(dst)
        shutil.copyfile(os.path.join(MINE, f), dst)
    print("[1] 我的版本已换入工作区")

    subprocess.run(["git", "-C", REPO, "add"] + TOOLS, check=True)
    print("[2] 工具脚本已挂进 index")

    r = subprocess.run(["git", "-C", REPO, "commit", "-m", MSG, "--"] + FILES + TOOLS,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("[3] commit exit", r.returncode)
    print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip())
        print("!! 提交失败，开始还原")
    else:
        print(r.stderr.strip())

    for f in FILES:
        cur = os.path.join(REPO, f)
        if md5(cur) == md5(os.path.join(MINE, f)):
            shutil.copyfile(os.path.join(MERGED, f), cur)
            print("[4] RESTORED", f)
        else:
            print("[4] PARALLEL_WROTE_KEEP_CURRENT", f)


main()
