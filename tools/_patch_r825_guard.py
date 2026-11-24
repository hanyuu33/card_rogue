# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"E:/work/card_rogue/scripts/test_engine.gd")
raw = p.read_bytes()
text = raw.decode("utf-8").replace("\r\n", "\n")
old = 'r825_reward_src.contains("if RunState.claim_all_relic_rewards() > 0:\\n\\t\\t\\t\\t_save_reward_checkpoint()")'
new = 'r825_reward_src.contains("if RunState.claim_all_relic_rewards() > 0:\\n\\t\\t\\t\\t\\t_save_reward_checkpoint()")'
assert text.count(old) == 1
text = text.replace(old, new)
p.write_bytes(text.replace("\n", "\r\n").encode("utf-8"))
print("R825 GUARD INDENT OK")
