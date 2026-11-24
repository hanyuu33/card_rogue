# -*- coding: utf-8 -*-
"""R845：暗影刺客 11 张卡数据调整（cards.json 定点改，保持原排版 + CRLF）。

只改指定卡块内部的字段，绝不整份重排 —— cards.json 的内联 dict 排版（
`"upper_effect": {"trigger": ..., "effects": []}`）用 json.dumps 还原不出来。
"""
import json
from pathlib import Path

P = Path("E:/work/card_rogue/cards.json")

# id -> [(old, new), ...]（都必须是**这张卡块内部**唯一的串）
EDITS = {
    8066: [('"rarity": 2', '"rarity": 1')],   # 调整稀有度：史诗 → 稀有
    9088: [("对目标造成 3 点伤害，目标本回合失去 3 点力量。",
            "对目标造成 2 点伤害，目标本回合失去 3 点力量。")],
    9087: [("对目标造成 4 点伤害，随机将一张费用为 0 的技能卡从抽牌库加入手牌。",
            "对目标造成 5 点伤害，随机将一张费用为 0 的技能卡从抽牌库加入手牌。")],
    9119: [("对目标造成 4 点伤害，然后抽 1 张卡。",
            "对目标造成 5 点伤害，然后抽 1 张卡。")],
    9090: [("造成 5 点伤害，若目标处于满血状态则改为造成 12 点伤害。",
            "造成 4 点伤害，若目标处于满血状态则改为造成 10 点伤害。")],
    9121: [("对目标造成 8 点伤害，然后从**弃牌区任选一张卡**返回你的手卡。",
            "对目标造成 13 点伤害，然后从**弃牌区任选一张卡**返回你的手卡。")],
    9173: [("抽 5 张牌。这回合结束为止，你不能使用盟友和工事卡。",
            "抽 4 张牌。这回合结束为止，你不能使用盟友和工事卡。")],
    9091: [("每使用一张卡，随机对一个敌人造成 2 点伤害。效果区多张本卡不可叠加。",
            "同一个回合内每使用 3 张卡，对一个随机敌人造成 8 点伤害，"
            "并使其力量 -1。效果区多张本卡不可叠加。")],
    9233: [("每次对被标记的敌人造成伤害，此卡费用本局 -1。"
            "这张卡击杀单位时，这张卡回满生命。",
            "每次对被标记的敌人造成伤害，此卡费用本局 -1。"
            "这张卡击杀单位时，回复 2 点费用并抽 2 张牌。")],
    9176: [('"kind": "技能"', '"kind": "效果"'),
           ("随机打出抽牌库中 3 张费用 1 或以下的技能卡。",
            "接下来一次你受到的大于 1 的伤害变为 1，然后抽 2 张牌。")],
    8062: [("自己回合结束时，回复 X 点生命，X 为自己剩余费用（每 1 点剩余费用回复 1 点生命，不超过生命上限）。",
            "自己回合结束时，对所有敌人造成 X 点伤害，X 为自己剩余费用。"),
           ('[{"type": "heal_per_energy", "value": 1}]',
            '[{"type": "damage_per_energy", "value": 1}]')],
}


def card_span(raw: str, cid: int) -> tuple[int, int]:
    """返回这张卡对象在原文里的 [start, end) 区间。"""
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
        block = raw[start:end]
        for old, new in pairs:
            old_c = old.replace("\n", "\r\n")
            new_c = new.replace("\n", "\r\n")
            assert block.count(old_c) == 1, (cid, old[:30], block.count(old_c))
            block = block.replace(old_c, new_c)
        raw = raw[:start] + block + raw[end:]

    data = json.loads(raw)          # 语法必须仍然合法
    by_id = {c["id"]: c for c in data["cards"]}
    assert len(by_id) == 344, len(by_id)
    assert by_id[8066]["rarity"] == 1
    assert by_id[9176]["kind"] == "效果"
    assert by_id[8062]["lower_effect"]["effects"][0]["type"] == "damage_per_energy"
    assert by_id[9091]["cost"] == 3 and by_id[9091]["kind"] == "效果"

    P.write_bytes(raw.encode("utf-8"))
    print("OK cards.json", len(raw))
    for cid in EDITS:
        print(cid, by_id[cid]["name"], "|", by_id[cid].get("effect_text"))


if __name__ == "__main__":
    main()
