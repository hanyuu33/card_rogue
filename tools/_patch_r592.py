# -*- coding: utf-8 -*-
"""R592：把「组合一张卡」（含同义的组合入口卡）全部加上「次元」字段。

判据 = **能打开组合页的卡**，即 `_open_combo()` 的全部调用点：
  · 传授系 8084 / 8085 / 8086（TEACH_IDS）
  · 黑暗嵌合 9191 / 技术结合 9193（技能卡自带入口）
  · 宝石兽 9246（combo_trigger = death）/ 拼装工厂 9247（combo_trigger = turn_start）
共 7 张。9144 随心组装是「手牌变形」不是组合，不在判据内。

改两处：
  1. `affixes` 加 "次元"（原来就有的跳过）；
  2. `effect_text` 末尾追加字段说明句 —— 技能卡「打出后消失，不进弃牌区」，
     单位 / 工事「离场即消失，不进弃牌区」（与卡库既有次元卡同一措辞）。

⚠️ cards.json 是 CRLF，插入行必须显式写 \r\n。
"""
import io
import json
import sys

PATH = 'cards.json'
TAIL_SKILL = '字段「次元」：打出后消失，不进弃牌区。'
TAIL_UNIT = '字段「次元」：离场即消失，不进弃牌区。'

# id -> (中文名, 旧 effect_text, 追加句)
TARGETS = {
    8084: ('传授',
           '组合一张盟友/工事卡：从随机 6 张候选卡中拖 3 张，分别决定属性值、上半效果、下半效果；生成的卡带「组合」印记。',
           TAIL_SKILL),
    8085: ('影缚',
           '组合一张盟友/工事卡：从随机 6 张候选卡中拖 3 张，分别决定属性值、上半效果、下半效果；生成的卡带「组合」印记。',
           TAIL_SKILL),
    8086: ('重构',
           '组合一张盟友/工事卡：从随机 6 张候选卡中拖 3 张，分别决定属性值、上半效果、下半效果；生成的卡带「组合」印记。',
           TAIL_SKILL),
    9191: ('黑暗嵌合',
           '组合一张卡，使那张卡获得「保存」，对所有敌人造成那个力量值的伤害。',
           TAIL_SKILL),
    9193: ('技术结合',
           '以构装体为基础组合一张卡。',
           TAIL_SKILL),
    9246: ('宝石兽',
           '死亡时，组合一张卡。',
           TAIL_UNIT),
    9247: ('拼装工厂',
           '回合开始时，组合一张卡。',
           TAIL_UNIT),
}

CHECK_ONLY = '--check-only' in sys.argv


def block_bounds(text, cid):
    """返回 (start, end)，end 指向块尾 `\r\n    }` 之后。"""
    key = '"id": %d,' % cid
    idx = text.find(key)
    if idx < 0:
        return (-1, -1)
    start = text.rindex('\r\n    {', 0, idx)
    end = text.index('\r\n    }', idx) + len('\r\n    }')
    return (start, end)


def main():
    text = io.open(PATH, encoding='utf-8', newline='').read()
    before_affix = text.count('"次元"')
    ok = True
    report = []

    for cid in sorted(TARGETS):
        name, old_eff, tail = TARGETS[cid]
        start, end = block_bounds(text, cid)
        if start < 0:
            print('[FAIL] 找不到卡块 %d (%s)' % (cid, name))
            ok = False
            continue
        blk = text[start:end]

        # ---- ① effect_text ----
        old_line = '      "effect_text": "%s",\r\n' % old_eff
        if blk.count(old_line) != 1:
            print('[FAIL] %d %s：effect_text 锚点命中 %d 次（要求 1）'
                  % (cid, name, blk.count(old_line)))
            ok = False
            continue
        if '字段「次元」' in blk:
            print('[FAIL] %d %s：块内已经有次元说明句，别重复' % (cid, name))
            ok = False
            continue
        new_line = '      "effect_text": "%s%s",\r\n' % (old_eff, tail)
        blk = blk.replace(old_line, new_line, 1)

        # ---- ② affixes ----
        if '"affixes": []' in blk:
            blk = blk.replace('"affixes": []', '"affixes": ["次元"]', 1)
            how = '填空数组'
        elif '"affixes"' in blk:
            print('[FAIL] %d %s：affixes 已是非空，请人工确认' % (cid, name))
            ok = False
            continue
        else:
            anchor = '\r\n      "effect_text": '
            if blk.count(anchor) != 1:
                print('[FAIL] %d %s：affixes 插入锚点命中 %d 次'
                      % (cid, name, blk.count(anchor)))
                ok = False
                continue
            blk = blk.replace(anchor, '\r\n      "affixes": ["次元"],' + anchor, 1)
            how = '新增字段'
        report.append('  %d %-6s %s  追加「%s」' % (cid, name, how, tail))

        text = text[:start] + blk + text[end:]

    if not ok:
        print('补丁未写入（有锚点失败）')
        return 1

    # ---- 校验 ----
    try:
        data = json.loads(text)
    except Exception as exc:  # noqa: BLE001
        print('[FAIL] json 解析失败：%s' % exc)
        return 1
    by_id = {c['id']: c for c in data['cards']}

    for cid, (name, old_eff, tail) in TARGETS.items():
        c = by_id.get(cid)
        if c is None:
            print('[FAIL] 解析后找不到 %d' % cid)
            return 1
        if '次元' not in (c.get('affixes') or []):
            print('[FAIL] %d %s affixes 没有次元：%s' % (cid, name, c.get('affixes')))
            return 1
        if c.get('effect_text') != old_eff + tail:
            print('[FAIL] %d %s 文案不一致：%r' % (cid, name, c.get('effect_text')))
            return 1

    bare = text.count('\n') - text.count('\r\n')
    if bare != 0:
        print('[FAIL] 出现裸 LF %d 行' % bare)
        return 1

    print('七张卡校验通过（affixes + 文案）')
    for line in report:
        print(line)
    print('全库「次元」出现次数：%d → %d' % (before_affix, text.count('"次元"')))

    if CHECK_ONLY:
        print('--check-only：未写盘')
        return 0

    io.open(PATH, 'w', encoding='utf-8', newline='').write(text)
    print('已写入 cards.json')
    return 0


if __name__ == '__main__':
    sys.exit(main())
