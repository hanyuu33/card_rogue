# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"E:/work/card_rogue/scripts/test_engine.gd")
raw = p.read_bytes()
crlf = b"\r\n" in raw
text = raw.decode("utf-8").replace("\r\n", "\n")
old = "\tvar r825_idx := RunState.queue_relic_reward(6005)\n"
new = "\tRunState.queue_relic_reward(6005)\n\tvar r825_idx := RunState.pending_rewards.size() - 1\n"
assert text.count(old) == 1
text = text.replace(old, new)
p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
print("R825 TEST FIX OK")
