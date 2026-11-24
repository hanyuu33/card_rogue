# -*- coding: utf-8 -*-
"""撤掉 R756 探针（与 _probe_r756_lastwin.py 对称）。"""
import io

P = "scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()
crlf = "\r\n" in s
if crlf:
    s = s.replace("\r\n", "\n")

probe = """		print("[PROBE] run_end run_finished=%s boss=%s next_layer=%d pending=%d panel_open=%s"
				% [RunState.run_finished, _run_boss_win, _run_next_layer,
				RunState.pending_reward_count(),
				_reward_panel.is_open() if _reward_panel != null else "null"])
"""
assert s.count(probe) == 1, "probe %d" % s.count(probe)
s = s.replace(probe, "")

start = s.find('	if "--lastwin2" in args and engine != null:')
end = s.find('	if "--runclear" in args and engine != null:', start)
assert start > 0 and end > start, "block %d %d" % (start, end)
s = s[:start] + s[end:]

if crlf:
    s = s.replace("\n", "\r\n")
io.open(P, "w", encoding="utf-8", newline="").write(s)
print("probe removed")
