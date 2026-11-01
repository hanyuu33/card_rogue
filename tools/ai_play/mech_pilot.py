# -*- coding: utf-8 -*-
"""机械之心专用自动打法。

为什么不用 autoplay.py 的通用策略
--------------------------------
机械之心的胜负手是**乘法**，不是单卡质量：
    改造工厂(8037) → 每回合给站在该格的己方单位 +1 层改造
    升级(8027)     → 一次性给一个单位 +2 力 / +10 血（还能再叠一层改造）
    集中突破(9162) → 10 + 4 × 场上改造层数
通用策略只会「按名字挑伤害牌」，既不会先落工厂，也不会等层数够了再集中突破，
所以在 76 血局里被拖成慢性死亡。这里把顺序写死。

判定口径（踩过的坑）
--------------------
* 手牌两次点击必须间隔 ≥0.34s，否则服务端「刚点过」直接拒（autoplay._click 已处理）。
* 改造层数只能从 state() 文本的「改造×N」里读——快照的 board 里没有这个字段。
* 盟友只能落 r3~r5；落 r2 会静默落空还照扣费。
* 打掉 hN 之后小于 N 的索引不变、大于 N 的左移 → 一次只打一张，打完重读快照。
"""
import io
import json
import os
import re
import sys
import time

import ai_cli
import autoplay as ap

# ⚠️ 保存**原始**实现：grind.py / advance.py 会把 ap.pick_reward 换成 mp.pick_reward，
# 这里若还写 ap.pick_reward(...) 兜底，就变成调用自己 → 无限递归（实测 RecursionError）。
_AP_PICK = ap.pick_reward

# 本回合「选中了却打不出去」的卡（卡 id）。
# 实测踩过：辅助刃(9164) 只能给**己方盟友**，可场上只剩木栅栏/城墙/改造工厂这些
# 工事与场地 → 服务端回「没有可指定的目标」。原逻辑 pending 不清、下一轮又去点它，
# 于是「选它→点它→被拒→取消→再选它」无限打转，整局卡死。
_BANNED = set()
# 本回合「选过、但点什么都没反应」的单位格。⚠️ 原来只能按**卡 id** 拉黑，
# 而单位行动失败时目标 id 是格子（r3c2）既不是 hN 也没 pending → cid 取不到，
# 拉黑等于没做，同一只工事被反复选中，一回合能白点上百次（实测 118 次）。
_DEAD_UNIT = set()
_LAST_UNIT = [None]
# 本回合「点了没反应」的目标格。⚠️ 原来只按卡 id / 单位格拉黑，可有些卡
# （如「自我修复」只认受伤单位）的候选目标格点上去一律无效，而失败时
# pending 已被清成 None → 无对象可拉黑，同一格被连点 6 次、整回合输出全废。
_BAD_TGT = set()
# 最后一次真正出过的卡 id：pending 被清空后仍能反查是哪张卡打不出去。
_LAST_CID = [None]

ALLY_ONLY = {9164}       # 辅助刃：只认「己方盟友」，给工事/场地一律「没有可指定的目标」

# 「送头即收益」类敌人（第二层）：我方每被它们打死 / 打中一个单位，对面就多一只兵。
#   9138 量产型赫菲斯托斯：**亲自击杀**我方单位 → 己方半场锻造一只 5/45 俄倪厄（践踏还会沿列穿）
#   9142 量产型阿尔戈斯  ：**攻击命中**我方单位 → 后排召唤一只 5/45 俄倪厄，移速 +1
#   9135 Boss 版赫菲斯托斯：同 9138
# 这类关里铺素体(1/1)/木栅栏(0/6) 等于给对面送兵，pilot 原来那套「低血炮灰挡刀」会自我毁灭
# （实测「量产铁砧」第 12 回合滚到 7 只 5/45，HP 归零）。
SPAWN_PUNISH = {9138, 9142, 9135}

# 减伤塔：在场时「其他」敌方单位受到的**技能伤害减半**（9137 量产型赫利俄斯）。
# 不拆它，所有技能卡都只有一半伤害；塔本身不减免，所以技能卡打塔是全额。
DAMAGE_TOWER = {9137}


def spawn_punish(snap):
    """敌方场上有没有「送头即收益」的单位 —— 有就本回合禁铺炮灰。"""
    return any((u.get("id") or 0) in SPAWN_PUNISH for u in ap.foe_units(snap))


def tower_first(snap, cid):
    """排序键片段：减伤塔排最前（够不够得着由调用方判断）。"""
    return 0 if (ap.unit_on(snap, cid) or {}).get("id") in DAMAGE_TOWER else 1


def face_worth(snap):
    """「直击敌方 HP」值不值得打。

    ⚠️ 不能无条件优先：实测无条件版会让 pilot 在第一层也去追血条，
    场上单位没人管，n30 直接被打死（这是我自己引入的回归）。
    只有「场上肉墙远比血条厚」时打脸才划算 —— 那种时候清场根本清不完：
      量产铁砧：三只 50 血 = 150 vs 血条 60 → 150 > 120 ✓ 该打脸
      第一层弓手与骑士：一只 5 血 vs 血条 60 → 5 > 120 ✗ 老实清场
    """
    b = snap.get("battle") or {}
    if b.get("hp_opp_infinite"):
        return False
    hp_opp = b.get("hp_opp") or 0
    total = sum((u.get("hp") or 0) for u in ap.foe_units(snap))
    return total > 2 * max(hp_opp, 1)

KILN = 9025              # 鸭子窑：工事 0 力 100 血，自己回合开始在四邻各孵一只陶瓷鸭，
#                          但「场上陶瓷鸭 >= 3」时停止孵化（R259 的防雪球闸）。
#                          它是**清场即胜**关卡里唯一真正要砸的目标 —— 小鸭子会被无限补，
#                          所以只要场面压到 <= 2 只，就该把火力全部转到窑上。
DUCKLING = 9026          # 陶瓷鸭（窑的产物，不进奖励池）


def kiln_focus(snap):
    """场上还剩 <= 2 只窑产小兵时，优先砸窑（此时窑每回合补 1 只，与小兵换血是纯亏）。"""
    fs = ap.foe_units(snap)
    if not any((u.get("id") or 0) == KILN for u in fs):
        return False
    others = [u for u in fs if (u.get("id") or 0) not in (KILN,)]
    return len(others) <= 2


def support_first(snap, cid):
    """辅助单位优先：0 力、血不厚的敌人不输出，只做治疗 / 增益 / 召唤。

    ⚠️ 实测「白魔法鸭护阵」：白魔法鸭 9021 每回合给伤势最重的友军回 5 点，
    而我方一回合总输出只有 8~13（两张攻击 4 + 一张炮击 9）—— 回血吃掉一半，
    于是永远清不完场，最后被磨死。**它每回合都在抵消我们的伤害，先拆它比跟
    肉盾换血划算得多。**
    """
    u = ap.unit_on(snap, cid) or {}
    if (u.get("id") or 0) == KILN:
        return 0 if kiln_focus(snap) else 2
    if (u.get("power") or 0) == 0 and (u.get("hp") or 0) <= 40:
        return 1
    return 2


def kiln_first(snap, cid):
    """排序键片段：能砸窑时，窑排最前。"""
    if not kiln_focus(snap):
        return 1
    return 0 if (ap.unit_on(snap, cid) or {}).get("id") == KILN else 1


SENTRY = 8026            # 构装体：3 费 3/8 射1 —— 这套牌里唯一能自主输出的盟友

_NAME_KIND = {v[0]: v[2] for v in ap.CARDS.values()}


def in_reach(u, f):
    """两个单位是否在射程内 —— 用**曼哈顿**距离，跟引擎一致。

    ⚠️ 原来写的是「行列差都 ≤ range」（切比雪夫），斜对角会被算短：
    单位 r3c2 射 2、敌人 r1c0 时它判「够得着」，引擎 `manhattan()` = 4 判够不着
    （game_engine.gd:5848），于是选单位 → 服务端只回「取消」→ 白扔一个动作位。
    """
    uc = u.get("cell") or [0, 0]
    fc = f.get("cell") or [0, 0]
    r = u.get("range") or 0
    return abs(uc[0] - fc[0]) + abs(uc[1] - fc[1]) <= r


def my_space(snap):
    """我方半场（r3~r5 × 3 列 = 9 格）还有没有空格。

    实测踩过：九格全站满时，手上的护盾生成器/城墙这类工事无处可落，
    服务端只回「再点一次 = 使用」，点下去却什么都不发生 → 永远确认不掉。
    """
    used = set()
    for u in ap.board(snap):
        if u.get("owner") == "self":
            used.add(ap.cell_id(u.get("cell")))
    return len(used) < 9


def ally_units(snap):
    """场上「只认盟友」的卡能指到的单位。

    先按 cards.json 的 kind 判；快照里取不到名字时退化成「射程 > 0」——
    机械之心的工事（木栅栏/城墙/护盾生成器）全部射 0，场地压根没有攻防。
    """
    out = []
    for u in ap.my_units(snap):
        k = _NAME_KIND.get(u.get("name", ""))
        if k == "盟友" or (k is None and u.get("range", 0) > 0):
            out.append(u)
    return out

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

FACTORY = 8037   # 改造工厂：场地，站在此格的己方单位每回合 +1 层改造
UPGRADE = 8027   # 升级：改造一个单位 +2/+10
BURST = 9162     # 集中突破：10 + 4×层数
SWEEP = 9172     # 激光扫射：全体 9
STRIKE = 8002    # 攻击：4 伤
BODY = 8025      # 素体：0 费 1/1，被改造时额外 +1 血
GUNWALL = 8001   # 木栅栏：0/6 工事，射 0 打不到人，纯粹当墙 + 叠层载体
COLOSSUS = 8074  # 量产型代达罗斯：入场让一张手卡变聚能炮击
SCRAP = 8071     # 报废：手牌其他所有卡变 0 费聚能炮击（9 伤 + 抽 1）

# ── 聚能炮击体系（R459 店长口径：先造产能，产能够了再堆配合）──
# 产能（能产出「聚能炮击」9145 的卡）：没有它们，下面那批配合卡全是废纸。
CANNON = 9145      # 聚能炮击：1 费 9 伤 + 抽 1 —— 单卡伤害密度是攻击(8002, 4 伤)的两倍多
RELOAD = 9146      # 填充：0 费把一张手卡变炮击（次元，打出后消失）
CLUSTER = 9166     # 集束炮台：入场往抽牌库塞 2 张炮击；每次被改造再从卡组捞 1 张进手
MASS_DD = 8074     # 量产型代达罗斯：入场选一张手卡变炮击（= COLOSSUS）
REFRACT = 9211     # 折射炮：加入一张炮击进手；此后每发炮击额外溅射一个敌方等量伤害
# 配合（放大炮击）：
MASS_MNEMO = 8075  # 量产型谟涅摩叙涅：**每回合一次**，炮击 +7 伤，抽到的卡再 -1 费
CANNON_MECH = 8073 # 聚能机兵：入场时本次对战每用过一张炮击 → +1 力
DAEDALUS = 8060    # 代达罗斯：嘲讽；每用过一张炮击 +3 血；本回合手卡炮击 0 费

CANNON_SRC = {SCRAP: 130, CANNON: 120, CLUSTER: 100, RELOAD: 95, MASS_DD: 90}
CANNON_AMP = {MASS_MNEMO: 140, REFRACT: 130, CANNON_MECH: 95, DAEDALUS: 90}

# 本局「见过」的炮击系卡 id（手牌 / 场上 / 奖励选过都算）。
# 卡组读不到明细（自由战斗的 state 不列卡组），所以按「抽到过就算握有」估算 ——
# 抽到一张炮击就说明牌库里还有，够用来判断阶段了。
# ⚠️ 必须落盘：advance.py / mech_pilot.py 每跑一次都是**新进程**，内存里的 set 会清零，
# 于是每次奖励都在「阶段一」，永远只会拿产能卡、从不拿配合卡。
_SEEN_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cannon_seen.json")


def _load_seen():
    try:
        with io.open(_SEEN_FILE, encoding="utf-8") as f:
            return set(int(x) for x in (json.load(f).get("seen") or []))
    except Exception:
        return set()


def _save_seen():
    try:
        with io.open(_SEEN_FILE, "w", encoding="utf-8") as f:
            json.dump({"seen": sorted(_CANNON_SEEN)}, f)
    except Exception:
        pass


_CANNON_SEEN = _load_seen()
# 本场战斗已打出的炮击张数（聚能机兵 8073 / 代达罗斯 8060 的乘数来源）。
# ai_bridge 不输出 state.self_cannon_plays，只能自己数（近似：选中即记 +1）。
# [张数, 上次看到的回合号] —— 回合回到 1 说明进了新战斗，计数清零。
_CANNON_PLAYS = [0, -1]

LAYER_RE = re.compile(r"改造×(\d+)")


def cannon_stock():
    """(产能数, 配合数) —— 本局已握有的炮击系卡。"""
    src = len(_CANNON_SEEN & set(CANNON_SRC))
    amp = len(_CANNON_SEEN & set(CANNON_AMP))
    return src, amp


def cannon_ready():
    """够不够格转「拿配合卡」。

    店长口径：**先有产出炮击的能力，或有报废，才去拿配合卡**。
    反过来的代价很实在 —— 拿着谟涅摩叙涅(8075)却没炮击可打，等于白占一张手牌；
    它只有 0/10 工事身材，连当墙都勉强。
    """
    src, _ = cannon_stock()
    return src >= 2 or SCRAP in _CANNON_SEEN


def remember_cannon(snap):
    """从手牌与场上更新「已见过的炮击系卡」。"""
    ids = set()
    for h in ap.hand(snap):
        ids.add(h.get("id") or 0)
    for u in ap.my_units(snap):
        ids.add(u.get("id") or 0)
    fresh = ids & (set(CANNON_SRC) | set(CANNON_AMP))
    if not fresh <= _CANNON_SEEN:
        _CANNON_SEEN.update(fresh)
        _save_seen()
    # 回合号回到 1 = 新的一场战斗，炮击计数重来（聚能机兵要按本场重新算力）
    turn = (snap.get("battle") or {}).get("turn")
    if turn == 1 and _CANNON_PLAYS[1] != 1:
        _CANNON_PLAYS[0] = 0
    _CANNON_PLAYS[1] = turn


def layers():
    """场上己方单位的最高改造层数（集中突破的乘数）。"""
    try:
        txt = ai_cli.state()
    except Exception:
        return 0
    if not isinstance(txt, str):
        return 0
    best = 0
    for m in LAYER_RE.finditer(txt):
        best = max(best, int(m.group(1)))
    return best


def hand_by_idx(snap):
    return {(h.get("index") if "index" in h else 0): h for h in ap.hand(snap)}


def playable(snap):
    d = ap.hints(snap)
    out = []
    hb = hand_by_idx(snap)
    for k, v in d.items():
        if k.startswith("h") and k[1:].isdigit() and "选中手牌" in v:
            out.append(int(k[1:]))
    return out


def pick_hand(snap, lay):
    """返回 (hN, 理由, card_id)；None 表示这回合没牌想打。"""
    idxs = playable(snap)
    if not idxs:
        return None, "", 0
    hb = hand_by_idx(snap)
    def _usable(i):
        cid = (hb.get(i) or {}).get("id", 0)
        if cid in _BANNED:
            return False
        # 只认盟友的卡：场上连一个盟友都没有时，选中→确认服务端都回 ok，
        # 卡却不出、手牌不变，pick_hand 下一轮又选它 —— 实测这样空转几十次。
        if cid in ALLY_ONLY and not ally_units(snap):
            return False
        # 送头惩罚关：素体 1/1、木栅栏 0/6 每死一个就给对面添一只 5/45（甚至更多），
        # 一律不出。这条比「铺场挡刀」优先 —— 挡一刀换来一只兵，净亏到崩盘。
        if cid in (BODY, GUNWALL) and spawn_punish(snap):
            return False
        # 要落场的卡：半场占满时无处可放，点了也白点
        k = _NAME_KIND.get(ap.card_info(cid)[0], "")
        if k in ("盟友", "工事", "场地") and not my_space(snap):
            return False
        return True

    idxs = [i for i in idxs if _usable(i)]
    remember_cannon(snap)
    if not idxs:
        return None, "", 0
    mine = ap.my_units(snap)
    foes = ap.foe_units(snap)
    energy = (snap.get("battle") or {}).get("energy", 0)
    d = ap.hints(snap)

    def info(i):
        h = hb.get(i) or {}
        return h.get("id", 0), h.get("cost", 0)

    have = {info(i)[0]: i for i in idxs}
    affordable = {cid: i for cid, i in have.items() if info(i)[1] <= energy}
    # 「能不能直接打敌方血条」—— 炮击分支与攻击分支都要用，提前算一次。
    can_face = any("直击敌方 HP" in v for v in d.values()) and face_worth(snap)

    # 1) 工厂没铺优先铺（这是整套乘法的地基）
    if FACTORY in have and not any(u.get("power", 0) > 0 and u.get("range", 0) == 0
                                     and u.get("hp", 0) > 6 for u in mine):
        if FACTORY in affordable:
            return "h%d" % affordable[FACTORY], "铺改造工厂", FACTORY

    # 1.5) 报废：手牌越满越值（把其他所有卡变成 0 费聚能炮击 = 9 伤 + 抽 1）
    #      场上有效谟涅摩叙涅(8075) 时门槛降到 3 张 —— 每张 0 费炮击都能吃到 +7，
    #      一张牌换一整把手牌爆发，这是这套牌最高的单回合上限。
    _mnemo_on = any((u.get("id") or 0) == MASS_MNEMO for u in mine)
    if SCRAP in affordable and len(ap.hand(snap)) >= (3 if _mnemo_on else 4) and energy >= 3:
        return "h%d" % affordable[SCRAP], "报废→全体聚能炮击", SCRAP

    # 1.6) 聚能炮击本身：1 费 9 伤 + 抽 1。
    #      比攻击卡(8002, 1 费 4 伤)伤害密度高一倍还带回牌，有敌人就先轰它。
    if CANNON in affordable and (foes or can_face):
        _CANNON_PLAYS[0] += 1
        return "h%d" % affordable[CANNON], "聚能炮击", CANNON

    # 2) 层数够了就打集中突破（挑能打死的，否则挑最疼的）
    if BURST in affordable and lay >= 2 and foes:
        return "h%d" % affordable[BURST], "集中突破（%d 层）" % lay, BURST

    # 3) 多敌先扫射
    if SWEEP in affordable and len(foes) >= 2:
        return "h%d" % affordable[SWEEP], "激光扫射（%d 敌）" % len(foes), SWEEP

    # 4) 升级（+2 力 +10 血）是**长期**收益，不能抢当回合的输出。
    #    ⚠️ R474：原来只要场上有盟友就先打升级，每回合吞 2 费 = 2 张攻击 = 8 伤，
    #    实测单场掉血从 32 涨到 55（三局跑到第一场就把血打空）。现在只有手里有
    #    集中突破（要吃改造层数）才提前，其余排到攻击之后（见 5.6）。
    if UPGRADE in affordable and ally_units(snap) and BURST in have:
        return "h%d" % affordable[UPGRADE], "升级载体（喂集中突破）", UPGRADE

    # 5) 攻击牌就是这套牌的主输出（4 伤 ×7 张，配快速符文每打一张再 +10%）。
    #    **有敌人就砸**。原来写成「残血 ≤4 才补刀」，结果整场都在铺单位不打脸，
    #    七张攻击烂在手里直到被打死（连输五局的直接原因）。
    if STRIKE in affordable and (foes or can_face):
        weak = min(foes, key=lambda u: (u.get("hp", 999), -u.get("power", 0))) if foes else None
        return ("h%d" % affordable[STRIKE],
                "攻击 %s" % (weak.get("name", "") if weak else "敌方血条"), STRIKE)

    # 5.5) 聚能机兵：入场时「本次对战每用过一张炮击 +1 力」—— **越晚下越强**，
    #      打过 2 发以上炮击再落才是 3/8 起跳的输出单位，早下就是一只 1/8 白板。
    if CANNON_MECH in affordable and _CANNON_PLAYS[0] >= 2:
        return ("h%d" % affordable[CANNON_MECH],
                "聚能机兵（已打 %d 发炮击）" % _CANNON_PLAYS[0], CANNON_MECH)

    # 5.6) 攻击打完了还有余费，再升级 —— 这时它不抢输出，纯赚。
    if UPGRADE in affordable and ally_units(snap):
        return "h%d" % affordable[UPGRADE], "余费升级", UPGRADE

    # 6) 铺载体（集束炮台排最前：它入场就往牌库塞 2 张炮击，等于把产能翻倍）
    walls = [u for u in ap.my_units(snap) if u.get("range", 0) == 0]
    for cid, why in ((CLUSTER, "落集束炮台"), (BODY, "落素体"), (SENTRY, "落构装体"),
                     (GUNWALL, "落木栅栏"), (COLOSSUS, "落代达罗斯")):
        if cid == GUNWALL and len(walls) >= 2:
            continue          # 0 攻的墙两个够挡了，再多就把半场堵死（9 格满 → 卡死）
        if cid in affordable:
            return "h%d" % affordable[cid], why, cid

    # 7) 剩下能出的都出了（0 费素体先）
    for i in sorted(idxs, key=lambda i: info(i)[1]):
        cid, cost = info(i)
        if cost <= energy:
            return "h%d" % i, "出 %s" % ap.card_info(cid)[0], cid
    return None, "", 0


# 机械之心拿卡的优先级：引擎 > 爆发 > 引擎零件 > 其它。
# 通用 pick_reward 只看名字里有没有「改造 / 攻击」，会把 3 费的凑数盟友排在
# 改造工厂前面，实测两次都在 Boss 前没铺成工厂，伤害只有十几点。
REWARD_PRIORITY = {
    "改造工厂": 85,      # 叠改造的地基，但炮击线优先级更高（见 CANNON_SRC / CANNON_AMP）
    "集中突破": 80,
    "机器鸟": 70,
    "批量传输": 60,
    "复制术": 55,
    "护盾生成器": 55,
    "堡垒": 50,
    "升级": 45,
    "激光扫射": 40,
    "重甲战车": 25,
}
# ⚠️ 「填充」「报废」不在上表：它们属于 CANNON_SRC，分值随阶段变（见 reward_score）。

# 名字 → id（奖励页只给名字，选中后要把卡记进 _CANNON_SEEN）。
_NAME2ID = {v[0]: k for k, v in ap.CARDS.items() if v[0]}
# 同名多卡（8002 攻击 / 90xx 各种「攻击」）会互相覆盖，判分要用全集
_NAME2IDS = {}
for _cid, _t in ap.CARDS.items():
    if _t and _t[0]:
        _NAME2IDS.setdefault(_t[0], []).append(_cid)

# ── 抓牌打分（R474：从「一票否决」改成「温和偏好 + 探索」）──────────────────
# 上一版口径是硬锁：产能没 ready 时配合卡只给 5 分（vs 产能 130），牌路等于只允许
# 一种。后果是牌组很窄、遇到不吃这套的关只能绕，而且**没机会发现别的强牌**。
# 现在分三段，谁都能被拿，只是有偏好：
#   1) base    —— 卡本身的通用价值（类型 / 费用 / 文本关键词 / 稀有度）
#   2) bonus   —— 体系协同（炮击链 / 改造引擎链），**只加分，不压别人**
#   3) explore —— 这张牌还没拿过就 +10（逼自己多试牌）；拿烂了 -6 让位
_PICKED_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".picked.json")


def _load_picked():
    try:
        with io.open(_PICKED_FILE, encoding="utf-8") as f:
            return {int(k): int(v) for k, v in (json.load(f) or {}).items()}
    except Exception:  # noqa: BLE001
        return {}


def _save_picked():
    try:
        with io.open(_PICKED_FILE, "w", encoding="utf-8") as f:
            json.dump({str(k): v for k, v in _PICKED.items()}, f, indent=0)
    except Exception:  # noqa: BLE001
        pass


def _load_rarity():
    try:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "cards.json")
        with io.open(os.path.abspath(p), encoding="utf-8") as f:
            return {int(c["id"]): int(c.get("rarity") or 0) for c in json.load(f)["cards"]}
    except Exception:  # noqa: BLE001
        return {}


_PICKED = _load_picked()
_RARITY = _load_rarity()

_KIND_BASE = {"盟友": 48, "技能": 50, "效果": 52, "工事": 45, "场地": 42, "诅咒": 4}
_HOT_WORDS = (
    ("造成", 10), ("点伤害", 10), ("抽", 9), ("能量", 10), ("减", 6),
    ("召唤", 9), ("生成", 8), ("加入手牌", 8), ("回复", 8), ("治疗", 8),
    ("护甲", 7), ("护盾", 7), ("嘲讽", 7), ("改造", 7), ("复制", 6),
)
# 改造 / 引擎链（按名字）：这些是「越滚越强」的地基，给一点协同分。
ENGINE_CHAIN = {
    "改造工厂": 14, "机器鸟": 12, "集中突破": 12, "集体改造": 10,
    "系统升级": 8, "护盾生成器": 8, "堡垒": 8, "复制术": 8,
}
# ⚠️ 手册顺位（tools/ai_play/memory/战斗-机械之心.md）：纯关键词评分**算不出乘法件**。
# 实例：`侦察塔` 文本里没有「造成 / 伤害」这类词，只有「改造」+7 → 70 分，
# 低于全卡表中位数 74，比一张普通 3 费盟友还低，永远轮不到它；
# 可它是「每层改造 → 射程内敌人受伤 +1」的乘法核心，手册钉为 T0。
# 所以：**实战验证过的顺位必须写进代码**，否则策略文件只是给人看的。
MANUAL_ORDER = {
    "侦察塔": 22,      # T0 乘法件：每层改造 → 射程内敌人受伤 +1
    "共享护盾": 20,    # T0：我方 HP 伤害改由它承受 = 整场不死
    "批量传输": 10,    # T1：手牌全体改造 +1/+4 并抽 1，一次喂满层数
    "激发": 10,        # T1：每次改造对 2 敌 3 伤，改造流的天生平A
    "加厚装甲": 8,     # T1：1 费最便宜的层数
}


def card_value(cid):
    """单张卡的通用估值（约 30~95）。奖励页 / 商店 / 记忆统计共用这一个口。"""
    cid = int(cid)
    name, cost, kind, text = ap.card_info(cid)
    if not name:
        return 40
    v = _KIND_BASE.get(kind, 45)
    for w, sc in _HOT_WORDS:
        if w in (text or ""):
            v += sc
    try:
        c = int(cost)
    except Exception:  # noqa: BLE001
        c = 3
    v += 8 if c <= 2 else (3 if c == 3 else (-5 if c >= 5 else 0))
    r = _RARITY.get(cid, 0)
    v += 6 if r >= 4 else (4 if r == 3 else 0)
    # 体系协同（只加分）
    if cid in CANNON_SRC:
        v += 16
    if cid in CANNON_AMP:
        v += 12 if cannon_ready() else 6
    for nm, sc in ENGINE_CHAIN.items():
        if nm in name:
            v += sc
    for nm, sc in MANUAL_ORDER.items():
        if nm in name:
            v += sc
    # 探索
    n = _PICKED.get(cid, 0)
    v += 10 if n == 0 else (-6 if n >= 3 else 0)
    return v


def reward_score(hint):
    """一张奖励卡的分值（越大越想要）。

    R474 改口径：**不再一票否决**。上一版「产能没 ready 时配合卡只给 5 分」把牌路
    锁死成一种，拿不到炮击链的局就只能硬亏。现在走 card_value() 的通用估值 +
    体系协同，谁都能被拿；探索加分让没试过的牌浮上来，慢慢攒抓牌经验。
    """
    best = 0
    for nm, ids in _NAME2IDS.items():
        if nm and nm in hint:
            for cid in ids:
                best = max(best, card_value(cid))
    if best:
        return best
    for name, w in REWARD_PRIORITY.items():   # 兜底：卡表还没登记的卡
        if name in hint:
            best = max(best, w)
    return best


def pick_reward(snap, d):
    """奖励页：聚能炮击两阶段策略 > 原引擎表 > 通用策略。"""
    cands = [k for k in d if k.startswith("rw") and "c" in k[2:]]
    if cands:
        def score(k):
            return -reward_score(d[k])
        cands.sort(key=score)
        if score(cands[0]) < 0:
            picked = d[cands[0]]
            # 奖励页一次能给好几张卡，第二张的评分要看见第一张 —— 先把选中的记账。
            for nm, ids in _NAME2IDS.items():
                if nm and nm in picked:
                    for cid in ids:
                        if cid in (set(CANNON_SRC) | set(CANNON_AMP)):
                            _CANNON_SEEN.add(cid)
                            _save_seen()
                        _PICKED[cid] = _PICKED.get(cid, 0) + 1
                    _save_picked()
                    break
            return cands[0], "拿 %s（%d 分）" % (picked, reward_score(picked))
        return _AP_PICK(snap, d)
    return _AP_PICK(snap, d)


def choose(snap, pending, lay):
    d = ap.hints(snap)

    # 选卡页（量产型代达罗斯 / 各种「选一张」）——先确认，别再选牌
    if "pok" in d:
        # 「已选 0 张」时点确认会被拒（还没选任何卡）→ 先选第 0 项再确认。
        if "已选 0" in d["pok"]:
            pn = [k for k in d if re.fullmatch(r"p\d+", k)]
            if pn:
                return pn[0], "选卡页取第 0 项", None
        return "pok", "选卡页确认", None

    # 鲸鱼之怒（消失区取回）：wp0/wp1/wp2 = 可取的卡，pcancel = 结束取牌。
    # 原来一个分支都没有 → 整场战斗停在这一页，回合循环空转到上限，
    # 外层 roam 还当没打完，同一场重入八次（掉血恒 0）。
    wp = [k for k in d if re.fullmatch(r"wp\d+", k) and k not in _BAD_TGT]
    if wp:
        def _wp_key(k):
            m = re.search(r"「([^」]+)」", d[k])
            nm = m.group(1) if m else ""
            ids = _NAME2IDS.get(nm) or []
            sc = max([card_value(c) for c in ids] or [0])
            return (-sc, int(k[2:]))
        wp.sort(key=_wp_key)
        return wp[0], "鲸鱼之怒取回 %s" % d[wp[0]][:16], None
    if "pcancel" in d:
        return "pcancel", "结束取牌", None
    r, why = pick_reward(snap, d)
    if r:
        return r, why, None
    if "leave" in d:
        return "leave", "战斗结束，离开", None

    b = snap.get("battle") or {}
    if b.get("side") != "self":
        return None, "", pending

    # 目标格（技能施法 / 放置）
    tgt = [k for k in d if "目标格" in d[k] or "放到这里" in d[k]]
    if tgt and _BAD_TGT:
        tgt = [k for k in tgt if k not in _BAD_TGT]
        if not tgt:
            # 候选目标格全试过都点不动（卡的条件没有格满足）→ 本回合拉黑这张卡，
            # 立刻取消退出选中态。否则 pick_hand 会再选它，死点到硬闸。
            bad = pending or _LAST_CID[0]
            if bad:
                _BANNED.add(bad)
            return "cancel", "目标格全点不动 → 取消", None
    if tgt:
        foes = [k for k in tgt if (ap.unit_on(snap, k) or {}).get("owner") == "opponent"]
        mine = [k for k in tgt if (ap.unit_on(snap, k) or {}).get("owner") == "self"]
        if pending == UPGRADE:
            if mine:
                # 优先射程 > 0 的单位：木栅栏射 0，实测被养到 56 攻 / 改造×51
                # 依然够不着任何人，伤害全烂在墙上（「鸭子骑士来袭」就是死在这）。
                mine.sort(key=lambda k: (0 if (ap.unit_on(snap, k) or {}).get("range", 0) > 0 else 1,
                                         -ap.unit_on(snap, k).get("power", 0),
                                         ap.unit_on(snap, k).get("hp", 0)))
                return mine[0], "升级 %s" % d[mine[0]][:16], None
        # 直击敌方 HP：血条型关卡的唯一正解。
        # 第二层「量产铁砧」「百眼动员」场上动辄 45~50 血 ×3~7 只，
        # 靠 4 伤攻击卡清场永远清不完（实测磨到第 9~12 回合被打死）；
        # 而这类关的胜利条件里 `hp_opponent <= 0` 是独立一条 —— 直接打后排血条才推得动。
        # ⚠️ 这些格的 hint 是「直击敌方 HP」而**格子上没有单位**，
        #    原来靠 `unit_on(...).owner == "opponent"` 过滤，全部被漏掉 → 只能取消。
        face = [k for k in tgt if "直击敌方 HP" in d[k]]
        if face and face_worth(snap):
            face.sort(key=lambda k: (int(k[1]), int(k[3:])) if len(k) > 3 else (0, 0))
            return face[0], "直击敌方 HP %s" % face[0], None
        if foes:
            # 有减伤塔先打塔：它在场时其他单位技能伤害减半，磨小兵是纯亏。
            foes.sort(key=lambda k: (support_first(snap, k),
                                     kiln_first(snap, k),
                                     tower_first(snap, k),
                                     ap.unit_on(snap, k).get("hp", 999),
                                     -ap.unit_on(snap, k).get("power", 0)))
            return foes[0], "打 %s" % d[foes[0]][:16], pending
        if pending == FACTORY:
            # 场地铺在最靠前、最靠中的我方格，后面好往上站人
            cells = sorted(tgt, key=lambda k: (abs(int(k[1]) - 3), abs(int(k[3:]) - 1)))
            return cells[0], "场地 %s" % cells[0], None
        if mine:
            mine.sort(key=lambda k: (0 if (ap.unit_on(snap, k) or {}).get("range", 0) > 0 else 1,
                                     -ap.unit_on(snap, k).get("power", 0),
                                     ap.unit_on(snap, k).get("hp", 0)))
            return mine[0], "增益 %s" % d[mine[0]][:16], None
        # 落子：提示是「把「素体」放到这里」，满场贴 r4c1 放，离工厂最近好叠层。
        place = [k for k in tgt if "放到这里" in d[k]]
        if place:
            # 摆位第一原则：**先堵住有敌人的那一列**。
            # ⚠️ 原来固定往「r3 + 中间列」顶，三列里另外两列是空的 —— 敌人从空列一路
            # 走到 r4 直接打脸。实测一回合被清空 45~62 血：血 45 满着进战斗、判负后
            # 外部血量还显示 45，看起来像「掉 0 血却输了」，骗了好几轮。
            # 挡住一列 = 那一列的敌人必须先拆墙才能过来，这才是真正的减伤。
            foe_cols = {(f.get("cell") or [0, 0])[1] for f in ap.foe_units(snap)}
            place.sort(key=lambda k: (0 if int(k[3:]) in foe_cols else 1,
                                      abs(int(k[1]) - 3), abs(int(k[3:]) - 1)))
            hit = int(place[0][3:]) in foe_cols
            return place[0], "放置 %s%s" % (place[0], "（堵敌列）" if hit else ""), None
        if "cancel" in d:
            return "cancel", "无有效目标，取消", None

    # 再点一次确认
    use = [k for k in d if "再点一次" in d[k]]
    if use:
        return use[0], "确认出牌", pending

    # 战斗内**选卡页**（p0 / p1 …）：`填充`（0 费把一张手牌变聚能炮击）就走这条路。
    # 之前没有这个分支，点了「填充」进入选卡页后 choose 又把「填充」自己返回，
    # 界面对 h1 没反应 → 连点 3 次被拉黑，整张产能核心卡等于不存在（实测 Boss 战
    # 每回合只剩 13 伤，而对面 100 血）。挑「最该被换掉」的那张：木栅栏 / 攻击 先变。
    psel = [k for k in d if re.fullmatch(r"p\d+", k)]
    if psel:
        def _junk_rank(k):
            for i, nm in enumerate(("木栅栏", "攻击", "素体", "构装体", "升级")):
                if "「%s」" % nm in d[k]:
                    return i
            return 99
        psel.sort(key=lambda k: (_junk_rank(k), int(k[1:])))
        return psel[0], "选卡页 %s（%s）" % (psel[0], d[psel[0]][:14]), pending
    if "pok" in d:
        return "pok", "确认选择", pending

    # 出牌优先：费用每回合归零，攒着就是浪费。
    # 原先「单位行动」排在最前，单位一白选就吃掉整回合（连输三局的真正原因）。
    pick, why, cid = pick_hand(snap, lay)
    if pick and pick not in _BAD_TGT:
        _LAST_CID[0] = cid or None
        return pick, why, cid

    # 单位行动
    mu = [k for k in d if "选中我方单位" in d[k]]
    if mu:
        # 够不着敌人时点单位只会弹出「取消」——白扔一个动作位，
        # 实测会连点到硬闸强制收回合，整回合等于没打（n30 连输三局的主因）。
        # 敌人移 1~2 会自己走进来，我们等着就行。
        # ⚠️ 只选**这一只自己**够得着敌人的单位：原来只判「场上任意一对能打到」，
        # 选中的那只却够不着 → 服务端只给「取消」，白扔一个动作位（日志里连点 3 次
        # 无进展反复出现）。挑攻击力最高的可打单位，一只都没有就干脆不选。
        cand = [u for u in ap.my_units(snap)
                if ap.cell_id(u["cell"]) in mu
                and ap.cell_id(u["cell"]) not in _DEAD_UNIT   # 本回合已确认动不了
                and ap.cell_id(u["cell"]) not in _BAD_TGT    # 本回合点过没反应
                and (u.get("acts_left", 1) or 0) > 0      # 已横置的单位点了只会回「取消」
                and (u.get("power") or 0) > 0             # 0 力 = 工事，走过去也只是白点
                and any(in_reach(u, f) for f in ap.foe_units(snap))]
        if cand:
            cand.sort(key=lambda u: (-(u.get("range") or 0), -(u.get("power") or 0)))
            _LAST_UNIT[0] = ap.cell_id(cand[0]["cell"])
            return ap.cell_id(cand[0]["cell"]), "选单位", pending
    # 已经选中某只单位、但硬闸确认它动不了（_DEAD_UNIT）→ 先退出选中态。
    # 否则接下来的 hints 全是它的「攻击 XX / 移动到这里」，choose 会一直点同一格，
    # 点到连点 4~5 次才被硬闸拦（2026-11-01 实测 62 次空转里有一半是这条）。
    if _LAST_UNIT[0] and _LAST_UNIT[0] in _DEAD_UNIT and "cancel" in d:
        return "cancel", "单位动不了 → 取消选择", pending
    atk = [k for k in d if d[k].startswith("攻击") or "直击敌方 HP" in d[k]]
    if atk:
        atk = [k for k in atk if k not in _BAD_TGT] or atk
        # 打脸 > 减伤塔 > 能秒的 > 血最少
        worth = face_worth(snap)
        atk.sort(key=lambda k: (0 if (worth and "直击敌方 HP" in d[k]) else 1,
                                support_first(snap, k),
                                kiln_first(snap, k),
                                tower_first(snap, k),
                                (ap.unit_on(snap, k) or {}).get("hp", 999),
                                -(ap.unit_on(snap, k) or {}).get("power", 0)))
        return atk[0], "攻击 %s" % atk[0], pending
    mv = [k for k in d if "移动到这里" in d[k]]
    if mv:
        # 只有当「我方每个单位的射程都够不着任何敌人」时才推进一格。
        # 敌人移 1~2，两三个回合会自己走进我方射程；主动移动实测净亏：
        # 单位在 r3/r4 之间横移打转，白送回合挨打（连输两场都栽在这）。
        us = ap.my_units(snap)
        fs = ap.foe_units(snap)
        reach = max([(u.get("range") or 0) for u in us] or [0])
        far = all(abs((u.get("cell") or [0, 0])[0] - (f.get("cell") or [0, 0])[0]) > reach
                  for u in us for f in fs)
        if far and fs:
            mv.sort(key=lambda k: (int(k[1]), int(k[3:])))
            return mv[0], "推进 %s" % mv[0], pending

    if "end" in d:
        return "end", "结束回合", pending
    if "cancel" in d:
        return "cancel", "取消", pending
    return None, "", pending


def low_hp(snap, ratio=0.15):
    """血量低到「再挨一下就死」的量级。"""
    b = snap.get("battle") or {}
    hp = b.get("hp_self") or 0
    mx = snap.get("max_hp") or 66
    try:
        mx = float(mx)
    except Exception:  # noqa: BLE001
        mx = 66.0
    return hp <= max(1.0, mx * ratio)


# 这一场还打不打得完？判据不能是「我快没血了」—— 实测 18/66 血（27%）撞「白魔法鸭护阵」
# 三只 30 血骑士，pilot 照打，结果一回合被磨穿整局报废。真正的判据是
# **剩下的血凑不够拆完对面**：敌方总血池远大于当前血量时，这一场就是拆不动的。
FOE_POOL_X = 4.0      # 对面血池 > 我血量的 4 倍 → 拆不动
LOW_HP_X = 0.25       # 或血已掉到 25% 以下 → 不恋战


def cannot_finish(snap):
    b = snap.get("battle") or {}
    hp = b.get("hp_self") or 0
    try:
        mx = float(snap.get("max_hp") or 66)
    except Exception:  # noqa: BLE001
        mx = 66.0
    foes = ap.foe_units(snap)
    if not foes or hp <= 0:
        return False
    pool = sum((u.get("hp") or 0) for u in foes)
    # ⚠️ 对面只剩一丝血（一回合能收掉）时不该撤 —— 实测 15 血对着一只 2 血残兵按了
    # 撤退，白扔一场胜利和它的奖励。所以低血这条也要 pool 还有一点厚度。
    if pool <= 6:
        return False
    return hp <= mx * LOW_HP_X or (hp <= mx * 0.45 and pool > hp * FOE_POOL_X)


def run(max_turns=80, verbose=True):
    for _ in range(max_turns):
        snap = ai_cli.snapshot()
        d = ap.hints(snap)
        # 撤退：血量已经撑不到拆完对面时，留着这一局比这一场奖励值。
        # 洞窟绳只对非 Boss 战开门（Boss 战没有 flee 提示），所以这里只判提示在不在 ——
        # 没带绳子就自然跳过，不会误伤。数量条件也不要（一只 100 血的窑同样能拖死我们）。
        if "flee" in d and cannot_finish(snap):
            if verbose:
                pool = sum((u.get("hp") or 0) for u in ap.foe_units(snap))
                print("  ⚑ 打不完，撤退（%s 血 / 对面血池 %d，%d 只）" % (
                    (snap.get("battle") or {}).get("hp_self"), pool,
                    len(ap.foe_units(snap))))
            ai_cli.act("flee")
            time.sleep(1.2)
            return ai_cli.snapshot()
        if snap.get("scene") != "battle":
            print("场景切走：%s" % snap.get("scene"))
            return snap
        b = snap.get("battle") or {}
        if b.get("side") != "self":
            ai_cli.wait()
            time.sleep(0.2)
            continue
        lay = layers()
        acted = 0
        pending = None
        _BANNED.clear()
        _DEAD_UNIT.clear()
        _LAST_UNIT[0] = None
        _prev_t, _prev_sig, _stuck = None, None, 0
        _clicks = {}
        _BAD_TGT.clear()
        ended = False
        dead = 0     # 本回合「连点 3 次都打不出去」的牌数（≥4 才认定没牌可打）
        while acted < 40:
            snap = ai_cli.snapshot()
            d = ap.hints(snap)
            if "leave" in d:
                # 同上：结算面板建好之前只有 leave，奖励还没入队。
                # 盲点会把卡牌奖励整组丢掉 —— 先等一拍再看，有奖励就回去领。
                time.sleep(1.5)
                d2 = ap.hints(ai_cli.snapshot())
                if any(k.startswith("rw") for k in d2):
                    print("结算奖励入队，先领")
                    continue
                print("本场结束")
                return snap
            if (snap.get("battle") or {}).get("side") != "self":
                break
            t, why, pending = choose(snap, pending, lay)
            if not t:
                break
            if t == "end":
                ai_cli.act("end")
                ended = True
                if verbose:
                    print("  → 结束回合（层数 %d）" % lay)
                time.sleep(0.5)
                ai_cli.wait()
                time.sleep(0.2)
                break
            # 硬闸：同一目标一回合内点满 3 次还没推进 → 这张卡就是打不出去
            # （半场占满 / 只认盟友而场上没有 / 该卡本身无合法目标）。
            # 前面两道软闸都靠 pending 与可选目标指纹，实测会漏；这道不看原因只看结果。
            _clicks[t] = _clicks.get(t, 0) + 1
            if _clicks[t] >= 3:
                # ⚠️ 拉黑的对象必须是「这张手牌」，不能只 add(pending)：
                # 「出 XX」这类只选卡不选目标的路径 pending 是 None，add(None) 等于
                # 什么都没拉黑，下一轮照样选同一张 —— 整晚的输出低就是这条：
                # 一张牌打不出去 → 立刻 break 结束整个回合，剩下的费全浪费，
                # 于是每回合只能打 1~2 张 4 伤攻击卡，永远拆不动 30 血的敌人。
                # ⚠️ 不能用 `pending or _LAST_CID[0]` 兜底：单位行动失败时 pending
                # 是 None，一兜就变成「把刚出掉的卡再 ban 一遍」（无效操作），
                # 而真正动不了的那只单位反而没人管 → 同一格连点到 6 次。
                cid_hit = pending
                if not cid_hit:
                    m = re.fullmatch(r"h(\d+)", t)
                    if m:
                        hb = (snap.get("battle") or {}).get("hand") or []
                        i = int(m.group(1))
                        if 0 <= i < len(hb):
                            cid_hit = hb[i].get("id")
                if cid_hit:
                    _BANNED.add(cid_hit)
                if re.fullmatch(r"h\d+", t):
                    # 按**槽位**再封一道：同名卡一抓五张，只按卡 id 拉黑的话，
                    # 下一轮 h1 换一张同名木栅栏又会被选中，照样连点到 6 次。
                    _BAD_TGT.add(t)
                if pending and not re.fullmatch(r"h\d+", t):
                    # 任何「非手牌」的待选目标（目标格 / wp0 取回条目）连点 3 次
                    # 都没推进 → 本回合不再选它。原来只认 r\d+c\d+，wp0 这类
                    # 新界面的键没有分支也没人记账，会一直原地打转。
                    _BAD_TGT.add(t)
                elif _LAST_UNIT[0]:
                    # 没有卡 id 说明这是「单位行动」路径：把那只单位拉黑，
                    # 否则下一轮 choose 又会把它选出来，一直点到回合结束。
                    _DEAD_UNIT.add(_LAST_UNIT[0])
                    _LAST_UNIT[0] = None
                if verbose:
                    print("  ! %s 连点 %d 次打不出去 → 本回合禁选 %s" % (
                        t, _clicks[t], ap.card_info(cid_hit)[0] if cid_hit else "?"))
                    # 诊断：把这一瞬间界面暴露的全部可点目标打出来。缺了它只能猜
                    # 「为什么这张牌出不去」（2026-11-01 自我修复/重启/合体 全军覆没时就是瞎猜）。
                    print("    hints: %s" % " | ".join(
                        "%s=%s" % (k, str(v).replace("\n", " ")[:26]) for k, v in d.items()))
                if "cancel" in d:
                    try:
                        ai_cli.act("cancel")
                    except Exception:
                        pass
                    time.sleep(0.25)
                pending = None
                dead = dead + 1
                # 只有「连着 4 张牌都打不出去」才是真的没牌可打；单张失败只跳过它。
                if dead < 4:
                    continue
                if verbose:
                    print("  ! 本回合 4 张都打不出去 → 结束回合")
                if "end" in ap.hints(ai_cli.snapshot()):
                    ai_cli.act("end")
                    ended = True
                    time.sleep(0.5)
                    ai_cli.wait()
                break

            # 同一目标、同一批可选目标连点两次都没改变局面 → 这张卡根本打不出去
            # （没有合法目标 / 半场占满），拉黑并退出选中态，别耗满 acted 上限。
            _sig = tuple(sorted(d.keys()))
            if t == _prev_t and _sig == _prev_sig:
                _stuck += 1
            else:
                _stuck = 0
            _prev_t, _prev_sig = t, _sig
            if _stuck >= 2 and pending:
                _BANNED.add(pending)
                if verbose:
                    print("  ! 连点无效，本回合禁选 %s" % ap.card_info(pending)[0])
                try:
                    ai_cli.act("cancel")
                except Exception:
                    pass
                time.sleep(0.2)
                pending = None
                continue
            if not ap._click(t, why, verbose):
                # 打不出去（没有合法目标 / 只认盟友而场上全是工事）→ 本回合拉黑它，
                # 立刻 cancel 退出选中态再继续，否则会一直「选它→点它→被拒」空转。
                if pending:
                    _BANNED.add(pending)
                    if verbose:
                        print("  ! 打不出去，本回合禁选 %s" % ap.card_info(pending)[0])
                    try:
                        ai_cli.act("cancel")
                    except Exception:
                        pass
                    time.sleep(0.25)
                    pending = None
                    continue
                break
            acted += 1
            dead = 0
            time.sleep(0.1)
        # 回合兜底：不管从哪条路 break 出来（连点撤销 / 打不出去 / acted 用满），
        # 都必须真的结束回合。⚠️ 不结束的话外层 for 会从头再开一回合，pilot 就
        # **永远停在同一个回合里空转** —— 敌方连行动的机会都没有，一路转到游戏判负。
        # 实测整局就是这么废的：血 66 全满、金币归零、直接回标题，而日志里只出现过
        # 1 次「结束回合」。
        if not ended:
            d2 = ap.hints(ai_cli.snapshot())
            if "end" in d2:
                ai_cli.act("end")
                if verbose:
                    print("  ⚑ 回合没结束 → 强制结束回合")
                time.sleep(0.5)
                ai_cli.wait()
                time.sleep(0.2)
        if "leave" in ap.hints(ai_cli.snapshot()):
            return ai_cli.snapshot()
    print("回合数上限")
    return ai_cli.snapshot()


if __name__ == "__main__":
    s = run(verbose="-q" not in sys.argv)
    ap.settle_rewards(verbose=True)
    print("---")
    print(ai_cli.state())
