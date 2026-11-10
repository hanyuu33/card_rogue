# 元素入场特效
- raw.png：ImageGen 原始透明二格素材，左土右火；全部保留。
- assets/fx/fx_primal_earth.png / fx_primal_fire.png：各取半幅等比缩至256×256，保留alpha。
- fire_live.png / earth_live.png：真实 battle.tscn 中的自动化验证场景截图（测试摆场，不是正常流程存档）。
- 土元素：先确定目标实例与分配值；飞行到达才扣血、出字、播放岩刺。
- 火元素：每段启动重新选择存活敌人；次数>6，飞行340→160ms，爆发/出字520→240ms。
- 所有段结束前暂存亡语；破坏表现逐次完成，亡语在整批完成后结算。复用现有破坏和亡语队列。
- 验证：tools/verify_primal_fx.gd（规则+实机场景，7连击、加速、分配、致死后亡语顺序）；scripts/test_engine.gd 全通过。
