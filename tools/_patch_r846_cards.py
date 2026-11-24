# -*- coding: utf-8 -*-
"""R846：暗影刺客七张卡数据调整（cards.json 定点改，保持原排版 + CRLF）。

只改指定卡块内部的字段，绝不整份重排 —— cards.json 的内联 dict 排版
（`"upper_effect": {"trigger": ..., "effects": []}`）用 json.dumps 还原不出来。
"""
import json
from pathlib import Path

P = Path("E:/work/card_rogue/cards.json")

# id -> [(old, new), ...]（都必须是**这张卡块内部**唯一的串）
EDITS = {
    # 影子猫：移速 5 → 2；效果从「取技能卡」改成「其他卡满 3 张 → 抽 2 张」
    8006: [('"move_speed": 5', '"move_speed": 2'),
           ("打出时，若包含这张卡本回合打出的卡达到 3 张，从抽牌库将一张随机技能卡加入手牌。",
            "打出时，若本回合已经使用过 3 张其他卡，抽 2 张牌。"),
           ('[{"type": "fetch_skill", "if_third": true}]',
            '[{"type": "draw_if_third", "value": 2}]')],
    # 地狱猫：初始力量 1 → 0（成长规则不变）
    8019: [('"power": 1', '"power": 0')],
    # 噩兆：新增「使用时若无标记 → 随机标记一个格子」
    9231: [("自己回合结束时，处于标记格的敌人受到 4X 点伤害。X 为本卡在效果区的张数。",
            "使用时，若场上没有标记，随机标记一个格子。"
            "自己回合结束时，处于标记格的敌人受到 4X 点伤害。X 为本卡在效果区的张数。")],
    # 回转：加单体伤害、要选目标
    9089: [("抽 X 张牌，X 为本回合你已使用的卡牌数，这些牌本回合结束不会丢弃。",
            "对一个目标造成 X 点伤害，抽 X 张牌，X 为本回合你已使用其他卡的张数。"
            "这些牌本回合结束不会丢弃。"),
           ('"target_mode": "none"', '"target_mode": "unit"')],
    # 闪躲：普通 → 稀有；改成对敌方单位降力
    9103: [('"rarity": 0', '"rarity": 1'),
           ("这个回合，所有友方单位获得嘲讽。",
            "使一个敌方单位力量 -X，X 为你本回合打出的牌数。"),
           ('"target_mode": "none"', '"target_mode": "unit"')],
    # 猫鼠游戏：5 费 → 4 费
    9190: [('"cost": 5', '"cost": 4')],
    # 暗影之刃：X 从「已花费用」改成「已使用卡牌张数」
    9111: [("X 为你本回合已使用的费用数。", "X 为你本回合已使用的卡牌张数。")],
}


def card_span(raw: str, cid: int) -> tuple:
    head = '      "id": %d,' % cid
    i = raw.find(head)
    assert i >= 0, "找不到 id %d" % cid
    assert raw.count(head) == 1, "id %d 出现多次" % cid
    j = raw.find('    }', i)
    assert j > i, "找不到 id %d 的结尾" % cid
    return i, j


def main():
    raw = P.read_bytes().decode("utf-8")
    assert "\r\n" in raw and "\n" not in raw.replace("\r\n", ""), "cards.json 不是纯 CRLF"

    for cid, pairs in EDITS.items():
        start, end = card_span(raw, cid)
        block = raw[start:end].replace("\r\n", "\n")
        for old, new in pairs:
            if old == new:
                continue
            n = block.count(old)
            assert n == 1, "卡 %d 里锚点命中 %d 次（应为 1）：%r" % (cid, n, old[:40])
            block = block.replace(old, new)
        raw = raw[:start] + block.replace("\n", "\r\n") + raw[end:]

    P.write_bytes(raw.encode("utf-8"))

    # 复核：JSON 仍可解析 + 快照逐字段断言
    d = json.loads(raw)
    by = {c["id"]: c for c in d["cards"]}
    assert len(d["cards"]) == 344, "卡数变了：%d" % len(d["cards"])
    cat = by[8006]
    assert cat["move_speed"] == 2 and "抽 2 张牌" in cat["effect_text"], cat
    assert cat["lower_effect"]["effects"][0]["type"] == "draw_if_third", cat["lower_effect"]
    assert by[8019]["power"] == 0, by[8019]
    assert by[9231]["effect_text"].startswith("使用时，若场上没有标记"), by[9231]
    rot = by[9089]
    assert rot["target_mode"] == "unit" and "造成 X 点伤害" in rot["effect_text"], rot
    dod = by[9103]
    assert dod["rarity"] == 1 and dod["target_mode"] == "unit", dod
    assert "嘲讽" not in dod["effect_text"], dod
    assert by[9190]["cost"] == 4, by[9190]
    assert "卡牌张数" in by[9111]["effect_text"], by[9111]
    print("CARDS_OK")


if __name__ == "__main__":
    main()
