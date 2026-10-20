"""文件桥接层：机器人 <-> WorkBuddy 自动排查 之间唯一的交互面。

设计约束：
  1. 只用标准库，不依赖 nonebot，方便单独跑测试。
  2. 所有写盘走「临时文件 + replace」，避免 WorkBuddy 读到半个 JSON。
  3. bug id 在分配时就落占位文件，防止并发重号。

目录约定（root 默认 D:\\work\\bug_bridge）：
  inbox/         机器人写入，WorkBuddy 每小时扫描
  inbox/images/  群友截图
  processing/    WorkBuddy 认领后移入
  reports/       WorkBuddy 产出结论，机器人轮询回推
  done/          回推完成归档
"""

from __future__ import annotations

import json
import os
import threading
from datetime import datetime
from pathlib import Path

DEFAULT_ROOT = r"D:\work\bug_bridge"

ID_PREFIX = "BUG"
ID_PATTERN = "BUG-*-*.json"


class Bridge:
    """负责 bug 文件与报告的落盘、读取、归档。"""

    def __init__(self, root: str | None = None) -> None:
        # 优先级：显式参数 > BUG_BRIDGE_DIR > 默认值。
        # bot.py 启动时已用 python-dotenv 把 .env 读进 os.environ，所以改 .env 就生效；
        # 单独跑 tools/simulate.py 时不会加载 .env，此时只能靠系统环境变量或默认值。
        self.root = Path(root or os.environ.get("BUG_BRIDGE_DIR") or DEFAULT_ROOT)
        self.inbox = self.root / "inbox"
        self.images = self.inbox / "images"
        self.processing = self.root / "processing"
        self.reports = self.root / "reports"
        self.done = self.root / "done"
        for directory in (self.inbox, self.images, self.processing, self.reports, self.done):
            directory.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()

    # ---------------------------------------------------------------- 写入

    def next_id(self) -> str:
        """分配 BUG-YYYYMMDD-NNN。

        分配的同时立刻写一个占位文件，这样即使在 await 之间切走协程，
        后来的调用也会看到这个 id 已被占用，不会重号。
        """
        day = datetime.now().strftime("%Y%m%d")
        with self._lock:
            used: set[int] = set()
            for directory in (self.inbox, self.processing, self.done):
                for path in directory.glob(f"{ID_PREFIX}-{day}-*.json"):
                    try:
                        used.add(int(path.stem.rsplit("-", 1)[-1]))
                    except (ValueError, IndexError):
                        continue
            seq = 1
            while seq in used:
                seq += 1
            bug_id = f"{ID_PREFIX}-{day}-{seq:03d}"
            placeholder = self.inbox / f"{bug_id}.json"
            placeholder.write_text(
                json.dumps({"id": bug_id, "status": "claiming"}, ensure_ascii=False),
                encoding="utf-8",
            )
            return bug_id

    def write_bug(self, bug: dict) -> Path:
        """正式写入 bug，覆盖 next_id 留下的占位文件。"""
        bug_id = str(bug.get("id") or "").strip()
        if not bug_id:
            raise ValueError("bug 缺少 id")
        path = self.inbox / f"{bug_id}.json"
        tmp = self.inbox / f".{bug_id}.json.tmp"
        tmp.write_text(json.dumps(bug, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(path)
        return path

    def save_image(self, bug_id: str, index: int, data: bytes, ext: str = ".jpg") -> str:
        """保存群友截图，返回绝对路径（写进 bug 的 images 字段）。"""
        if not ext.startswith("."):
            ext = "." + ext
        path = self.images / f"{bug_id}_{index:02d}{ext}"
        path.write_bytes(data)
        return str(path)

    # ---------------------------------------------------------------- 读取

    def find(self, bug_id: str) -> dict | None:
        """按 id 在四个目录里找记录（先 bug，后报告）。"""
        for directory in (self.inbox, self.processing, self.done, self.reports):
            path = directory / f"{bug_id}.json"
            if path.exists():
                return self.load(path)
        return None

    def pending_reports(self) -> list[Path]:
        """还没回推到群里等报告，按 bug id 排序保证先后顺序稳定。"""
        return sorted(self.reports.glob("BUG-*.json"))

    def stats(self) -> dict[str, int]:
        return {
            "pending": len(list(self.inbox.glob("BUG-*.json"))),
            "processing": len(list(self.processing.glob("BUG-*.json"))),
            "reports": len(list(self.reports.glob("BUG-*.json"))),
            "done": len(list(self.done.glob("BUG-*.json"))),
        }

    @staticmethod
    def load(path: Path) -> dict | None:
        """读 JSON，坏文件返回 None 由调用方决定怎么处理。"""
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            return None
        return data if isinstance(data, dict) else None

    # ---------------------------------------------------------------- 归档

    def ack_report(self, path: Path) -> None:
        """回推成功后把报告移进 done/，失败就留在原地等下一轮。"""
        with self._lock:
            try:
                path.replace(self.done / path.name)
            except OSError:
                pass


def _self_test() -> None:
    """最小自检：分配 id -> 写 bug -> 出报告 -> 归档。"""
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        bridge = Bridge(tmp)
        first = bridge.next_id()
        second = bridge.next_id()
        assert first == "BUG-" + datetime.now().strftime("%Y%m%d") + "-001", first
        assert second.endswith("-002"), second

        bridge.write_bug({"id": first, "group_id": 1, "content": "测试"})
        assert bridge.find(first)["content"] == "测试"
        assert bridge.stats()["pending"] == 2  # second 仍是占位文件

        report = bridge.reports / f"{first}.json"
        report.write_text(json.dumps({"bug_id": first, "group_id": 1}), encoding="utf-8")
        assert len(bridge.pending_reports()) == 1
        bridge.ack_report(report)
        assert bridge.stats()["done"] == 1

    print("bridge self-test ok")


if __name__ == "__main__":
    _self_test()
