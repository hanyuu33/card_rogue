"""QQ 群 bug 汇报插件。

群友发 /bug + 文字/截图 -> 落盘到 inbox/ -> WorkBuddy 定时排查 -> 机器人把结论推回原群。

指令：
  /bug <描述>       汇报问题，可附截图
  /bugstatus <编号> 查单条进度
  /buglist          看整体队列
"""

from __future__ import annotations

import asyncio
from datetime import datetime

import httpx
import nonebot
from nonebot import get_driver, logger, on_command
from nonebot.adapters.onebot.v11 import Bot, GroupMessageEvent, Message
from nonebot.params import CommandArg
from nonebot.plugin import PluginMetadata

from .bridge import Bridge

__plugin_meta__ = PluginMetadata(
    name="bug_report",
    description="群内 bug 汇报，配合 WorkBuddy 定时自动排查并回推结论",
    usage="/bug <描述> 汇报问题（可带截图）\n/bugstatus <编号> 查进度\n/buglist 查看队列",
    type="application",
    supported_adapters={"~onebot.v11"},
)

bridge = Bridge()

VERDICT_TEXT = {
    "confirmed": "已确认",
    "suspected": "疑似，需人工确认",
    "need_info": "信息不足，需补充",
    "invalid": "未认定为 bug",
}

REPORT_INTERVAL_SEC = 20

bug_cmd = on_command("bug", aliases={"反馈", "报bug"}, priority=5, block=True)
status_cmd = on_command("bugstatus", aliases={"bug状态"}, priority=5, block=True)
list_cmd = on_command("buglist", aliases={"bug列表"}, priority=5, block=True)


# ------------------------------------------------------------------ 汇报


@bug_cmd.handle()
async def _handle_bug(bot: Bot, event: GroupMessageEvent, args: Message = CommandArg()) -> None:
    text = args.extract_plain_text().strip()
    image_segs = [seg for seg in args if seg.type == "image"]

    if not text and not image_segs:
        await bug_cmd.finish(
            "请在指令后面写清问题哦，比如：\n"
            "/bug 第二层打完 boss 后卡在结算界面\n"
            "光发截图也可以，我会先记下来。"
        )

    bug_id = bridge.next_id()

    saved: list[str] = []
    if image_segs:
        async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
            for index, seg in enumerate(image_segs):
                url = str(seg.data.get("url") or seg.data.get("file") or "")
                if not url.startswith(("http://", "https://")):
                    # 本地路径形式（file 段给的是文件名），拿不到就跳过
                    logger.debug(f"[bug_report] {bug_id} 截图无可用 URL，跳过")
                    continue
                try:
                    resp = await client.get(url)
                    if resp.status_code == 200 and resp.content:
                        ext = ".png" if ".png" in url.lower() else ".jpg"
                        saved.append(bridge.save_image(bug_id, index, resp.content, ext))
                    else:
                        logger.warning(f"[bug_report] {bug_id} 截图下载异常 HTTP {resp.status_code}")
                except Exception as exc:  # noqa: BLE001
                    logger.warning(f"[bug_report] {bug_id} 截图下载失败: {exc}")

    bug = {
        "id": bug_id,
        "group_id": event.group_id,
        "user_id": event.user_id,
        "nickname": event.sender.card or event.sender.nickname or str(event.user_id),
        "content": text,
        "images": saved,
        "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "status": "pending",
    }
    bridge.write_bug(bug)
    logger.info(f"[bug_report] 收到 {bug_id} / 群 {event.group_id} / {bug['nickname']}")

    brief = text if len(text) <= 60 else text[:60] + "…"
    lines = [f"收到啦，编号 {bug_id}"]
    if brief:
        lines.append(f"问题：{brief}")
    if saved:
        lines.append(f"已保存截图 {len(saved)} 张")
    lines.append("已进入排查队列，出结论会直接发到本群。")
    await bug_cmd.finish("\n".join(lines))


# ------------------------------------------------------------------ 查询


@status_cmd.handle()
async def _handle_status(bot: Bot, event: GroupMessageEvent, args: Message = CommandArg()) -> None:
    bug_id = args.extract_plain_text().strip().upper()
    if not bug_id:
        await status_cmd.finish("用法：/bugstatus BUG-20261020-001")
    data = bridge.find(bug_id)
    if not data:
        await status_cmd.finish(f"没找到 {bug_id} 的记录呢，编号是不是抄错了？")

    lines = [bug_id]
    verdict = data.get("verdict")
    if verdict:
        lines.append(f"判定：{VERDICT_TEXT.get(str(verdict), str(verdict))}")
    elif data.get("status") == "claiming":
        lines.append("状态：正在登记")
    else:
        lines.append("状态：排队中，还没出结论")
    if data.get("summary"):
        lines.append(f"结论：{data['summary']}")
    if data.get("suggestion"):
        lines.append(f"建议：{data['suggestion']}")
    await status_cmd.finish("\n".join(lines))


@list_cmd.handle()
async def _handle_list(bot: Bot, event: GroupMessageEvent) -> None:
    s = bridge.stats()
    await list_cmd.finish(
        f"待排查 {s['pending']} 条 · 排查中 {s['processing']} 条 · "
        f"待推送 {s['reports']} 条 · 已归档 {s['done']} 条"
    )


# ------------------------------------------------------------------ 回推

_reporter_started = False


@get_driver().on_startup
async def _start_reporter() -> None:
    global _reporter_started
    if _reporter_started:
        return
    _reporter_started = True
    asyncio.create_task(_report_loop())
    logger.info(f"[bug_report] 结论回推已启动，每 {REPORT_INTERVAL_SEC}s 扫描一次 reports/")


async def _report_loop() -> None:
    while True:
        await asyncio.sleep(REPORT_INTERVAL_SEC)
        try:
            await _flush_reports()
        except Exception as exc:  # noqa: BLE001
            logger.warning(f"[bug_report] 回推循环异常: {exc}")


async def _flush_reports() -> None:
    reports = bridge.pending_reports()
    if not reports:
        return
    bots = nonebot.get_bots()
    if not bots:
        return
    bot = next(iter(bots.values()))

    for path in reports:
        data = Bridge.load(path)
        if not data:
            bridge.ack_report(path)
            continue
        group_id = data.get("group_id")
        if not group_id:
            bridge.ack_report(path)
            continue
        try:
            await bot.send_group_msg(group_id=int(group_id), message=_format_report(data))
        except Exception as exc:  # noqa: BLE001
            logger.warning(f"[bug_report] 推送 {path.name} 失败: {exc}")
            continue
        bridge.ack_report(path)
        logger.info(f"[bug_report] 已回推 {path.name} -> 群 {group_id}")


def _format_report(data: dict) -> str:
    """优先用自动排查写好的 message；没有就按结构化字段拼一条。"""
    preset = data.get("message")
    if isinstance(preset, str) and preset.strip():
        return preset.strip()

    bug_id = str(data.get("bug_id") or data.get("id") or "?")
    verdict = VERDICT_TEXT.get(str(data.get("verdict")), "已处理")
    parts = [f"【BUG 排查结果】{bug_id}", f"判定：{verdict}"]
    if data.get("summary"):
        parts.append(f"结论：{data['summary']}")
    if data.get("suggestion"):
        parts.append(f"建议：{data['suggestion']}")
    locations = data.get("locations") or []
    if locations:
        parts.append("定位：" + "、".join(str(x) for x in locations[:3]))
    return "\n".join(parts)


__all__ = ["bridge", "_format_report"]
