# -*- coding: utf-8 -*-
"""R860 收尾：HANDOFF 追加记录，还原被回归覆盖的 mana 日志。"""
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

entry = (
    "\n## 2026-11-24 R860 道具平衡调整\n"
    "- 刺墙 6073：反伤由 5 下调为 4（`SPIKE_WALL_DMG`），工事 / 玩家 HP 两条触发共用；"
    "relics.json 与 zh/en/ja/es 四语 desc、R793 图标 README 同步。\n"
    "- 兵 6071：由「本场第一个盟友双动」改为「第三个盟友双动」。"
    "引擎 `_pawn_first_ally_done` 布尔换成 `_pawn_ally_used` 计数（`PAWN_AT:= 3`），"
    "`Placement.first_ally_twice` 更名 `pawn_ally_twice`，`start_game` 归零；"
    "板甲 / 圣剑注释同步说明判据差异。\n"
    "- 测试：`_test_r792` 放 3 张龙裔验证「1、2 单动，3 双动」；"
    "`_test_r793` / `_test_r796` 的 -5 断言全部改为 -4。\n"
    "- 验证：四个改动 .gd 的 `--check-only` 全过；`python _verify.py` 十套全绿"
    "（engine 7350✓ / 0✗，reward 26✓，smoke 77✓）。\n"
    "- 仅纳入相关源文件与 HANDOFF.md；工作区原有未跟踪素材、草稿与本次补丁脚本未提交。\n"
)

p = os.path.join(ROOT, "HANDOFF.md")
b = open(p, "rb").read()
e = entry.replace("\n", "\r\n").encode("utf-8")
assert b.count(e) == 0, "entry already present"
open(p, "ab").write(e)
print("HANDOFF.md appended")

mana = "art_src/2026-11-05_handoff_completion/mana_headless.log"
subprocess.check_call(["git", "show", "HEAD:" + mana], cwd=ROOT,
                      stdout=open(os.path.join(ROOT, mana), "wb"))
print("mana_headless.log restored to HEAD (regression artifact)")
