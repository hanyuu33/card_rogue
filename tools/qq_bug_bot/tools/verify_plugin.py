"""插件加载验证：不连 QQ、不启动服务，只确认插件与指令能正常注册。

在装好依赖的虚拟环境里跑：
    .venv\\Scripts\\python.exe tools\\verify_plugin.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
sys.path.insert(0, str(ROOT))

import nonebot  # noqa: E402
from nonebot.adapters.onebot.v11 import Adapter  # noqa: E402


def main() -> int:
    nonebot.init()
    nonebot.get_driver().register_adapter(Adapter)
    nonebot.load_plugins("plugins")

    names = [plugin.name for plugin in nonebot.get_loaded_plugins()]
    print(f"已加载插件：{names}")
    if "bug_report" not in names:
        print("[FAIL] bug_report 插件未加载")
        return 1

    plugin = nonebot.get_plugin("bug_report")
    assert plugin is not None and plugin.module is not None

    formatter = getattr(plugin.module, "_format_report", None)
    if formatter is None:
        print("[FAIL] _format_report 缺失")
        return 1

    # 分支一：自动排查直接给了现成文案
    preset = {"message": "【BUG 排查结果】BUG-20261020-001\n判定：已确认"}
    assert formatter(preset) == preset["message"], "预置 message 未原样返回"

    # 分支二：只有结构化字段，需要拼装
    built = formatter(
        {
            "bug_id": "BUG-20261020-002",
            "verdict": "confirmed",
            "summary": "Boss 死亡未推进阶段",
            "suggestion": "补一次 _check_battle_end()",
            "locations": ["scripts/battle_scene.gd:1872"],
        }
    )
    print("---- 拼装结果 ----")
    print(built)
    for token in ("BUG-20261020-002", "已确认", "Boss 死亡未推进阶段", "battle_scene.gd:1872"):
        if token not in built:
            print(f"[FAIL] 拼装结果缺少 {token}")
            return 1

    # 桥接目录就绪检查
    bridge = getattr(plugin.module, "bridge", None)
    if bridge is None:
        print("[FAIL] bridge 未初始化")
        return 1
    print(f"桥接目录：{bridge.root} · {bridge.stats()}")

    print("[OK] 插件加载、指令注册、报告格式化、桥接目录全部正常")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
