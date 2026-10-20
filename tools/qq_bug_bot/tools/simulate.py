"""离线自检：不装 QQ、不开机器人，也能确认桥接目录与文件流转是否正常。

用法：
    python tools/simulate.py           # 临时目录自检，不污染真实队列
    python tools/simulate.py --push    # 往真实 inbox 丢一条测试反馈（会被真的排查一次）
    python tools/simulate.py --stat    # 只打印真实队列统计
"""

from __future__ import annotations

import importlib.util
import sys
import tempfile
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
BRIDGE_FILE = PROJECT_ROOT / "plugins" / "bug_report" / "bridge.py"


def _load_bridge():
    """直接按文件加载 bridge.py，绕开 plugins 包的 __init__（那会牵进 nonebot）。"""
    spec = importlib.util.spec_from_file_location("bug_bridge", BRIDGE_FILE)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"无法加载 {BRIDGE_FILE}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.Bridge


Bridge = _load_bridge()


def offline_check() -> bool:
    with tempfile.TemporaryDirectory() as tmp:
        bridge = Bridge(tmp)

        first = bridge.next_id()
        second = bridge.next_id()
        assert first != second, "id 重复"
        assert first.endswith("-001"), f"序号应从 001 开始，得到 {first}"
        assert second.endswith("-002"), f"序号应递增，得到 {second}"

        bridge.write_bug(
            {
                "id": first,
                "group_id": 10001,
                "user_id": 20002,
                "nickname": "自检",
                "content": "临时目录自检",
                "images": [],
                "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                "status": "pending",
            }
        )
        loaded = bridge.find(first)
        assert loaded is not None and loaded["content"] == "临时目录自检", "写盘后读回不一致"

        report = bridge.reports / f"{first}.json"
        report.write_text(f'{{"bug_id": "{first}", "group_id": 10001}}', encoding="utf-8")
        assert len(bridge.pending_reports()) == 1, "报告未被识别为待回推"
        bridge.ack_report(report)
        assert not report.exists(), "回推归档后原文件应消失"
        assert (bridge.done / f"{first}.json").exists(), "归档文件缺失"

        print(f"[OK] 临时目录自检通过：{first} / {second}")
        return True


def print_stat() -> None:
    bridge = Bridge()
    stat = bridge.stats()
    print(f"桥接目录：{bridge.root}")
    print(
        f"待排查 {stat['pending']} · 排查中 {stat['processing']} · "
        f"待回推 {stat['reports']} · 已归档 {stat['done']}"
    )


def push_real() -> None:
    bridge = Bridge()
    bug_id = bridge.next_id()
    bridge.write_bug(
        {
            "id": bug_id,
            "group_id": 0,
            "user_id": 0,
            "nickname": "自检",
            "content": "【自检测试】这条是 simulate.py 造的数据，用来验证链路，不是真实反馈。",
            "images": [],
            "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
            "status": "pending",
        }
    )
    print(f"[OK] 已写入 {bridge.inbox / (bug_id + '.json')}")
    print("注意：它会被自动排查真的处理一次，验证完可以删掉 processing/reports/done 里的同名文件。")


def main() -> int:
    args = set(sys.argv[1:])
    if "--push" in args:
        push_real()
        print_stat()
        return 0
    if "--stat" in args:
        print_stat()
        return 0
    offline_check()
    print_stat()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
