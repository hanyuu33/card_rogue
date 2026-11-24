# -*- coding: utf-8 -*-
"""R798：大宝箱二选一 —— 摆上来就算「出现过」，没拿的那件本局不再随机出来。

改动：
 1) run_state.gd  claim_key_choice()：不论拿道具还是拿种子，候选道具一律登记
    skipped_relics（原来只有 skip_key_choice 那条「放弃」路才登记）。
 2) run_state.gd  skip_key_choice()：注释指向同一口径。
 3) test_engine.gd  R543 测试块：备份 / 恢复 skipped_relics，并补 R798 断言。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def sub1(s, old, new, tag):
    n = s.count(old)
    assert n == 1, "%s: count=%d" % (tag, n)
    return s.replace(old, new, 1)


# ---------------- 1) run_state.gd : claim_key_choice ----------------
p = "scripts/run_state.gd"
s = read(p)

OLD = (
    'static func claim_key_choice(idx: int, take_key: bool) -> bool:\n'
    '\t## R543：二选一领取 —— `take_key = true` 拿「生命之种」信物，否则拿「奖励道具」。\n'
    '\t## 成功后该条置为 claimed。奖励道具走 gain_relic、信物走 gain_key。\n'
    '\tif idx < 0 or idx >= pending_rewards.size():\n'
    '\t\treturn false\n'
    '\tvar e: Dictionary = pending_rewards[idx]\n'
    '\tif str(e.get("kind", "")) != "relic_or_key":\n'
    '\t\treturn false\n'
    '\tif str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:\n'
    '\t\treturn false\n'
    '\tif take_key:\n'
    '\t\tgain_key(int(e.get("key_id", SEED_RELIC_ID)))\n'
    '\telse:\n'
    '\t\tvar rid := int(e.get("relic_id", -1))\n'
    '\t\tif rid > 0:\n'
    '\t\t\tgain_relic(rid)\n'
    '\te["state"] = REWARD_CLAIMED\n'
    '\treturn true\n'
)

NEW = (
    'static func claim_key_choice(idx: int, take_key: bool) -> bool:\n'
    '\t## R543：二选一领取 —— `take_key = true` 拿「生命之种」信物，否则拿「奖励道具」。\n'
    '\t## 成功后该条置为 claimed。奖励道具走 gain_relic、信物走 gain_key。\n'
    '\t## R798（用户口径「道具如果在大宝箱二选一没有拿，也算出现过，后续不会再重复出现」）：\n'
    '\t## **摆上二选一就算出现过** —— 不论玩家最后拿了哪一边，候选道具都登记进\n'
    '\t## `skipped_relics`（本局后续不再随机出来）。原来只有「放弃」那条路登记\n'
    '\t## （`skip_key_choice`），选了种子时落选的那件会留在池子里、过几层又摇出来一次。\n'
    '\t## ⚠️ 选道具那条分支同样登记：`gain_relic` 之后它已在 `relics` 里、池子本来就摇不到，\n'
    '\t##    两边都记是为了「失去道具」类效果之后也不会复活（口径只有一句：出现过就不再出现）。\n'
    '\tif idx < 0 or idx >= pending_rewards.size():\n'
    '\t\treturn false\n'
    '\tvar e: Dictionary = pending_rewards[idx]\n'
    '\tif str(e.get("kind", "")) != "relic_or_key":\n'
    '\t\treturn false\n'
    '\tif str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:\n'
    '\t\treturn false\n'
    '\tvar rid := int(e.get("relic_id", -1))\n'
    '\tif rid > 0 and not skipped_relics.has(rid):\n'
    '\t\tskipped_relics.append(rid)\n'
    '\tif take_key:\n'
    '\t\tgain_key(int(e.get("key_id", SEED_RELIC_ID)))\n'
    '\telif rid > 0:\n'
    '\t\tgain_relic(rid)\n'
    '\te["state"] = REWARD_CLAIMED\n'
    '\treturn true\n'
)

s = sub1(s, OLD, NEW, "claim_key_choice")

# ---------------- 2) skip_key_choice 注释指向同一口径 ----------------
OLD2 = '\t## R543：二选一放弃 —— 什么都不拿，奖励道具登记进 skipped（本局不再随机出来）。\n'
NEW2 = ('\t## R543：二选一放弃 —— 什么都不拿，奖励道具登记进 skipped（本局不再随机出来）。\n'
        '\t## R798：登记口径与 `claim_key_choice` **完全一致** —— 三条出口（拿道具 / 拿种子 /\n'
        '\t## 作废放弃）都会把那件候选道具记成「出现过」，本局不再摇到它。\n')
s = sub1(s, OLD2, NEW2, "skip_key_choice doc")

write(p, s)
print("[ok] run_state.gd")

# ---------------- 3) test_engine.gd ----------------
p = "scripts/test_engine.gd"
s = read(p)
CR = "\r\n"

# 3a) 备份
OLD3 = '\tvar r543_pending_bak: Array = RunState.pending_rewards.duplicate(true)' + CR
NEW3 = (OLD3
        + CR
        + '\tvar r543_skipped_bak: Array[int] = RunState.skipped_relics.duplicate()' + CR)
s = sub1(s, OLD3, NEW3, "backup")

# 3b) 取候选 id + 补断言（领种子那条）
OLD4 = ('\tvar r543_idx := RunState.pending_rewards.find(r543_last)' + CR
        + CR
        + '\tcheck(RunState.claim_key_choice(r543_idx, true)' + CR
        + CR
        + '\t\t\tand RunState.has_key(RunState.SEED_RELIC_ID)' + CR
        + CR
        + '\t\t\tand str(r543_last.get("state", "")) == RunState.REWARD_CLAIMED,' + CR
        + CR
        + '\t\t\t"R543 大宝箱：二选一领种子 → 信物入账、条目置 claimed")' + CR)
NEW4 = ('\tvar r543_idx := RunState.pending_rewards.find(r543_last)' + CR
        + CR
        + '\tvar r543_cand := int(r543_last.get("relic_id", -1))' + CR
        + CR
        + '\tcheck(RunState.claim_key_choice(r543_idx, true)' + CR
        + CR
        + '\t\t\tand RunState.has_key(RunState.SEED_RELIC_ID)' + CR
        + CR
        + '\t\t\tand str(r543_last.get("state", "")) == RunState.REWARD_CLAIMED,' + CR
        + CR
        + '\t\t\t"R543 大宝箱：二选一领种子 → 信物入账、条目置 claimed")' + CR
        + CR
        + '\tcheck(r543_cand > 0 and RunState.skipped_relics.has(r543_cand)' + CR
        + CR
        + '\t\t\tand not RunState.has_relic(r543_cand),' + CR
        + CR
        + '\t\t\t"R798 二选一没拿道具也算出现过 → 候选道具登记 skipped_relics（本局不再随机出来）、不入道具栏")' + CR
        + CR
        + '\tvar r543_tier := RelicData.TIER_NORMAL' + CR
        + CR
        + '\tif not RelicRepo.load_json().reward_ids(RelicData.TIER_NORMAL).has(r543_cand):' + CR
        + CR
        + '\t\tr543_tier = RelicData.TIER_LEGENDARY' + CR
        + CR
        + '\tcheck(not RunState._reward_pool(r543_tier, []).has(r543_cand),' + CR
        + CR
        + '\t\t\t"R798 已出现的候选道具从抽取池里剔除（同一件不会第二次摆上二选一）")' + CR)
s = sub1(s, OLD4, NEW4, "assert")

# 3c) 恢复
OLD5 = '\tRunState.pending_rewards = r543_pending_bak' + CR
NEW5 = (OLD5
        + CR
        + '\tRunState.skipped_relics = r543_skipped_bak' + CR)
s = sub1(s, OLD5, NEW5, "restore")

write(p, s)
print("[ok] test_engine.gd")
