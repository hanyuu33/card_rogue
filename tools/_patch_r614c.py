"""R614c：给商店 / 奖励卡补两枚出图钩子，用来实机核验「组合」词条查得到。

  shop_scene.gd     `--combodemo`   第一行头一张换成 8084「传授」，并「选中查看」
  reward_panel.gd   `--combocards`  三选一固定成 8084 / 8085 / 8086 三张传授

用法：
  python tools/_patch_r614c.py --check-only
  python tools/_patch_r614c.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(rel):
    p = ROOT / rel
    raw = p.read_bytes().decode("utf-8")
    crlf = raw.count("\r\n")
    text = raw.replace("\r\n", "\n")
    return p, text, crlf


def save(p, text, crlf):
    out = text.replace("\n", "\r\n") if crlf > 0 else text
    p.write_bytes(out.encode("utf-8"))
    raw = p.read_bytes().decode("utf-8")
    print("  -> %s  crlf=%d bare=%d" % (
        p.name, raw.count("\r\n"), raw.count("\n") - raw.count("\r\n")))


def patch_shop(check):
    p, text, crlf = load("scripts/shop_scene.gd")
    anchor = (
        "\t# R432 出图：`--off N` 把第一行第 N 张**强制设为五折** —— 五折本身是 20% 概率，\n")
    assert text.count(anchor) == 1, "shop 锚点命中 %d 次" % text.count(anchor)
    add = (
        "\t# R614 出图：`--combodemo` 把第一行头一张换成 8084「传授」并「选中查看」——\n"
        "\t# 它的两个可查词条正好是**字段「次元」+ 机制「组合」**（正文「从全职业卡池组合一张卡。」）。\n"
        "\t# 组合卡只从特定事件 / 传授来，商店货架靠自然摇基本摇不到，等于没有核验手段。\n"
        "\t# 只换卡不 `_sync_shop_state()`：演示卡不该被写进货架存档。\n"
        "\t# 出图：`shop.tscn -- --screenshot --shop --combodemo`\n"
        "\tif \"--combodemo\" in args:\n"
        "\t\tvar dc6: CardData = _repo.get_card(8084)\n"
        "\t\tif dc6 != null and not _row1.is_empty():\n"
        "\t\t\t_row1[0][\"card\"] = dc6\n"
        "\t\t\t_sel_row1 = 0\n"
        "\t\t_ask_redraw()\n")
    if not check:
        text = text.replace(anchor, add + anchor, 1)
        save(p, text, crlf)
    print("[shop_scene.gd] --combodemo 锚点命中 1 处")


def patch_reward(check):
    p, text, crlf = load("scripts/reward_panel.gd")
    anchor = (
        "\tif \"--r444\" in args:\n"
        "\t\tfor i in RunState.pending_rewards.size():\n"
        "\t\t\tvar en4: Dictionary = RunState.pending_rewards[i]\n"
        "\t\t\tif str(en4.get(\"kind\", \"\")) == \"cards\":\n"
        "\t\t\t\ten4[\"candidates\"] = [8055, 9031, 9080]\n")
    assert text.count(anchor) == 1, "reward 锚点命中 %d 次" % text.count(anchor)
    add = (
        "\t# R614 出图：`--combocards` 把三选一固定成三张**传授**（正文「从全职业卡池组合\n"
        "\t# 一张卡。」，各自带「次元」字段）—— 核验奖励卡浮窗能同时查到「组合」与「次元」。\n"
        "\t# 出图：`battle.tscn -- --screenshot --r119cards --combocards --shotframe 600`\n"
        "\tif \"--combocards\" in args:\n"
        "\t\tfor i in RunState.pending_rewards.size():\n"
        "\t\t\tvar en5: Dictionary = RunState.pending_rewards[i]\n"
        "\t\t\tif str(en5.get(\"kind\", \"\")) == \"cards\":\n"
        "\t\t\t\ten5[\"candidates\"] = [8084, 8085, 8086]\n")
    if not check:
        text = text.replace(anchor, anchor + add, 1)
        save(p, text, crlf)
    print("[reward_panel.gd] --combocards 锚点命中 1 处")


if __name__ == "__main__":
    check = "--check-only" in sys.argv
    print("%s R614c" % ("[dry] 检查" if check else "[write] 写入"))
    patch_shop(check)
    patch_reward(check)
    print("done")
