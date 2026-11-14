# -*- coding: utf-8 -*-
"""R688 效果卡文案统一（dry-run 默认；--write 才落盘）。

口径（全部对照 scripts/game_engine.gd 的实际结算写成）：
  * 可叠加 → 用 X 表述，尾巴统一「X 为本卡在效果区的张数。」（石肤按张数 ×2）
  * 不可叠加 → 尾巴统一「效果区多张本卡不可叠加。」
改动前 9078 的「诸如次元…不会触发此效果」按店长口径删掉，改成条件句「死亡并送去弃牌区」。
"""
import json
import re
import sys

ROOT = "E:/work/card_rogue/"
CARDS = ROOT + "cards.json"
CANON = ROOT + "i18n/zh_canonical.json"

SUF = "效果区多张本卡不可叠加。"
XT = "X 为本卡在效果区的张数。"

# id -> 新 effect_text（None = 不动）
NEW = {
    9002: "使用时，将一张「幽深回响」加入抽牌库。回合开始时，对随机敌人造成 6 点伤害，重复 X 次。" + XT,
    9013: "每回合开始时，所有友方单位力量 +1（每个单位最多累计 +4）。" + SUF,
    9015: "每 3 个回合召唤一只鸭子骑士。" + SUF,
    9024: "己方第 3、5、7 个回合开始时，使一个现存生命最高且没有双动的己方单位获得双动"
          "（永久；原本就能行动两次的单位不会被选中）。" + SUF,
    9036: "我方所有盟友造成的伤害 +X；从手牌使用盟友时，该盟友获得 +2X 生命。" + XT,
    9045: "每个己方盟友进入战场时，随机对一个敌人造成 4 点伤害。" + SUF,
    9049: "每回合开始时，所有友方单位力量 +2（永久）。" + SUF,
    9056: "每回合前 X 次使用效果牌时，将其一张复制加入抽牌库，并抽一张卡。" + XT,
    9058: "使用效果卡后，回复 X 点费用。" + XT,
    9059: "回合开始时，抽 X 张卡；这样抽到的效果卡费用 -1。" + XT,
    9061: "回合开始时，随机将 X 张效果卡加入你的手卡。" + XT,
    9062: "每当你使用一张效果卡，将 X 张乌鸦加入你的手卡，它们本回合费用为 0。" + XT,
    9065: "战斗结束后，回复自己 8 点生命。" + SUF,
    9066: "己方 HP 接下来受到的 X 次伤害，若达到 2 点或以上则变为 1。X 为本卡在效果区的张数 ×2。",
    9070: "**接通**的单位在自己攻击时不计算距离（全场可达）。" + SUF,
    9076: "每回合使用的第一张技能卡费用 -1、伤害 +1。" + SUF,
    9078: "每回合前 X 个死亡并送去弃牌区的己方盟友回到手卡，费用 -1。"
          "场上每有 1 个己方盟友，手卡中的这张卡费用 -1。" + XT,
    9091: "每使用一张卡，随机对一个敌人造成 2 点伤害。" + SUF,
    9092: "回合开始时多抽 1 张卡，如果这张卡费用为 0，则再抽 1 张。" + SUF,
    9099: "回合开始时，将一张荧光草加入你的手卡。" + SUF,
    9101: "自己的回合中每次自己没有手卡时，抽 1 张卡，这样抽到的 0 费卡本回合费用 +1。" + SUF,
    9110: "自己回合结束时，剩余费用每 2 点，下个回合开始时获得 1 点额外费用。" + SUF,
    9111: "自己回合结束时，对随机一个敌人造成 X 点伤害，X 为你本回合已使用的费用数。" + SUF,
    9112: "自己回合结束时，剩余费用每 3 点，将随机一个敌人击退 2 格。" + SUF,
    9113: "自己回合结束时，剩余费用每有 1 点，对所有敌人造成 2 点伤害。" + SUF,
    9114: "每回合抽牌之后，你强制从手牌中选择 1 张弃掉（不能不选），然后获得 2 点费用。" + SUF,
    9115: "每回合开始时，所有使魔鸭子力量 +1（永久）。" + SUF,
    9117: "每回合开始时，所有使魔鸭子力量 +1（永久）；每 2 回合在随机的空格上召唤一只使魔鸭子"
          "（玩家后排除外）。" + SUF,
    8045: "**回合开始时**，随机使**手牌**里的一张盟友或工事获得改造：攻击 +1、生命 +3。" + SUF,
    8070: "回合开始时，选 X 张手卡变成随机**被改造时有额外效果**的卡牌，并使其获得改造：生命 +2。" + XT,
    8077: "每次你的一张卡被改造时，对随机 **2** 个敌人造成 **3** 点伤害，重复 X 次。" + XT,
    8078: "友方单位入场时，获得改造，并获得「死亡」——它被破坏时，对距离 1 的随机一个敌人"
          "造成 **8** 点伤害。" + SUF,
    8079: "回合开始时，选卡组 X 张卡，把它们变成随机卡并加入手卡。" + XT,
    9143: "你每**变化**一张卡，回复**2**点费用。变化：战斗内将一张卡变成另一张卡。" + SUF,
    9147: "每过 3 回合，随机从量产型俄倪厄 / 量产型赫利俄斯中召唤一个到己方半场。" + SUF,
    9148: "回合开始时，选 X 张手卡消失，随机将 X 张卡牌加入你的手卡。" + XT,
    9125: "战斗**开始时**以及**每 3 个回合**，召唤一只鸭子暗杀者。" + SUF,
    9139: "己方每个回合开始时，随机破坏一个敌方单位。" + SUF,
    9175: "场上每有一个单位被破坏，抽 1 张卡。" + SUF,
    9178: "夜鸭不再虚弱：不再受「惧光」影响（奇数回合也不降攻击距离、移动速度与力量）。" + SUF,
    9180: "本场战斗结束后：奖励界面增加一条奖励，可以从卡组删除一张卡。此卡不可以从卡组删除。" + SUF,
    9181: "本场战斗结束后：获得额外的 40 金币。此卡不可以从卡组删除。" + SUF,
    9201: "每回合随机轰击一列：该列所有敌方单位受到 5 伤害；该列没有单位则改为直击玩家 HP。" + SUF,
    9202: "攻击启示者的单位受到 5 伤害。启示者每次受到技能伤害，向你的弃牌库加入一张「麻痹」"
          "（0 费诅咒 · 不能打出 · 回合结束仍在手牌就消失）。" + SUF,
    9203: "玩家每个回合开始时，随机召唤一只力量 +10 的量产型敌人。" + SUF,
    9209: "玩家回合开始时随机标记 5 个格子。敌方行动前，标记格上的玩家单位受到 5 点伤害，"
          "每回合此伤害 +1。" + SUF,
    9210: "每 2 个回合开始时，所有友方单位力量 +1，每个单位最多累计 +4。" + SUF,
    9211: "打出时：将一张「聚能炮击」加入手卡。此后你使用「聚能炮击」时，除主目标外，"
          "额外对一个随机其他敌方单位造成等量伤害。" + SUF,
    9212: "枭熊的生命在一半以上时，它受到的伤害 -1；生命降到一半或以下时获得「践踏」——"
          "它造成的伤害击杀单位时，溢出的伤害沿同列继续传下去，没有攻击到单位时不触发。" + SUF,
    9226: "被标记的敌人受到的所有伤害提升 50%（替代标记本身的加伤）。打出时若场上没有标记，"
          "随机标记一个格子。" + SUF,
    9230: "对被标记的敌人造成伤害时，使其本回合力量 -X。若场上没有标记，"
          "随机标记一个敌人所在的位置。" + XT,
    9231: "自己回合结束时，处于标记格的敌人受到 4X 点伤害。" + XT,
    9240: "敌方场上所有单位获得「次元」。己方第 12 个回合结束时，破坏己方场上所有单位。" + SUF,
}

RENAME = {9002: "幽深回响"}


def block_span(txt, cid):
    """返回 cards.json 里某张卡对象的 [start, end)。"""
    m = re.search(r'\r?\n(\s*)\{\r?\n\s*"id": %d,' % cid, txt)
    if not m:
        return None
    start = m.start() + 1
    depth = 0
    i = start
    in_str = False
    esc = False
    while i < len(txt):
        ch = txt[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return start, i + 1
        i += 1
    return None


def sub_obj_text(txt, cid, new_text):
    span = block_span(txt, cid)
    if span is None:
        raise SystemExit("找不到卡块 id=%d" % cid)
    a, b = span
    blk = txt[a:b]
    m = re.search(r'("effect_text": ")((?:[^"\\]|\\.)*)(")', blk)
    if not m:
        raise SystemExit("卡块无 effect_text id=%d" % cid)
    old = json.loads('"' + m.group(2) + '"')
    blk2 = blk[:m.start(2)] + json.dumps(new_text, ensure_ascii=False)[1:-1] + blk[m.end(2):]
    return txt[:a] + blk2 + txt[b:], old


def main():
    write = "--write" in sys.argv
    raw = open(CARDS, "rb").read().decode("utf-8")
    crlf = raw.count("\r\n")
    lf = raw.count("\n")
    print("cards.json CRLF=%d LF=%d BOM=%s" % (crlf, lf, open(CARDS, "rb").read(3) == b"\xef\xbb\xbf"))

    d = json.load(open(CARDS, encoding="utf-8-sig"))
    by_id = {c["id"]: c for c in d["cards"]}
    out = raw
    report = []
    for cid, new in NEW.items():
        out, old = sub_obj_text(out, cid, new)
        if old == new:
            report.append((cid, "同文", ""))
            continue
        delta = len(new) - len(old)
        report.append((cid, "改 %+d 字" % delta, old[:26] + "…"))
    # 改名
    for cid, nm in RENAME.items():
        span = block_span(out, cid)
        a, b = span
        blk = out[a:b]
        m = re.search(r'("name": ")((?:[^"\\]|\\.)*)(")', blk)
        blk2 = blk[:m.start(2)] + nm + blk[m.end(2):]
        out = out[:a] + blk2 + out[b:]

    # 9002 字段：trait 减伤 → 幽深回响；value 2 → 6（每口伤害，卡面唯一来源）
    a, b = block_span(out, 9002)
    blk = out[a:b]
    assert blk.count('"减伤"') == 1, "9002 trait 锚点不唯一"
    blk = blk.replace('"减伤"', '"幽深回响"')
    assert blk.count('"value": 2,') == 1, "9002 value 锚点不唯一"
    blk = blk.replace('"value": 2,', '"value": 6,')
    out = out[:a] + blk + out[b:]

    for row in report:
        print("  %s %s %s" % row)

    # 校验
    d2 = json.loads(out)
    print("JSON 解析 OK，卡数 %d" % len(d2["cards"]))
    for cid, new in NEW.items():
        got = [c for c in d2["cards"] if c["id"] == cid][0]["effect_text"]
        if got != new:
            raise SystemExit("写回不一致 id=%d" % cid)
    print("57 张里改 %d 张，CRLF 前=%d 后=%d" % (len(NEW), crlf, out.count("\r\n")))

    if not write:
        print("[dry-run] 未落盘")
        return
    open(CARDS, "wb").write(out.encode("utf-8"))
    print("已写入 cards.json")


if __name__ == "__main__":
    main()
