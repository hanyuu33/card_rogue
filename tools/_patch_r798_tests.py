# -*- coding: utf-8 -*-
"""R798（续）：只补 test_engine.gd 的 R543 测试块 —— 备份 / 恢复 skipped_relics + 两条断言。

run_state.gd 那半边已由 _patch_r798_keychoice.py 落地，这里重打测试（并行线 commit
把上一版测试 hunk 冲掉了）。
"""
import io

ROOT = "E:/work/card_rogue/"
CR = "\r\n"


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


p = "scripts/test_engine.gd"
s = read(p)

# 3a) 备份 skipped_relics
OLD3 = '\tvar r543_pending_bak: Array = RunState.pending_rewards.duplicate(true)' + CR
NEW3 = (OLD3
        + CR
        + '\tvar r543_skipped_bak: Array[int] = RunState.skipped_relics.duplicate()' + CR)
s = sub1(s, OLD3, NEW3, "backup")

# 3b) 取候选 id + 两条断言
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

# 3c) 恢复 skipped_relics
OLD5 = '\tRunState.pending_rewards = r543_pending_bak' + CR
NEW5 = (OLD5
        + CR
        + '\tRunState.skipped_relics = r543_skipped_bak' + CR)
s = sub1(s, OLD5, NEW5, "restore")

write(p, s)
print("[ok] test_engine.gd")
