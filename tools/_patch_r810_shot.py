# -*- coding: utf-8 -*-
"""R810 出图钩子：--r810sun 把四件新道具铺进栏 + 演一次太阳指环的回合开始特效。"""
import io

P = "E:/work/card_rogue/scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()


def sub(old, new):
    global s
    old, new = old.replace("\n", "\r\n"), new.replace("\n", "\r\n")
    assert s.count(old) == 1, (old[:60], s.count(old))
    s = s.replace(old, new)


sub('''	if _shot_pending and "--dragshot" in _demo_args:
		_demo_dragshot()          # R117 临时演示：钉住一次拖拽（见函数注释）''',
'''	if _shot_pending and "--r810sun" in _demo_args and _demo_frame == 12:
		# R810 出图：四件新道具铺进右栏（新月耳饰带角标「3」），并塞两只敌人保证
		# 「全体 3 点」有目标可打（关卡本身可能只有一只）。
		RunState.relics = [6081, 6082, 6083, 6084]
		engine.self_relics = [6081, 6082, 6083, 6084]
		RunState.crescent_battles = 0
		for _rc: Vector2i in [Vector2i(1, 0), Vector2i(1, 2)]:
			if engine.state.unit_at(_rc) == null:
				engine.state.place(repo.get_card(1011), _rc, GameEngine.SIDE_OPPONENT)
	if _shot_pending and "--r810sun" in _demo_args and _demo_frame == _shot_frame - 15:
		# 提前 15 帧（≈250ms）触发：截图那一刻正好在「冲击环扩散中」。
		engine._sun_ring_tick()
	if _shot_pending and "--dragshot" in _demo_args:
		_demo_dragshot()          # R117 临时演示：钉住一次拖拽（见函数注释）''')

io.open(P, "w", encoding="utf-8", newline="").write(s)
print("SHOT HOOK OK, CRLF:", "\r\n" in s)
