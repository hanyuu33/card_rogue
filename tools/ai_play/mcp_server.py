# -*- coding: utf-8 -*-
"""卡牌肉鸽 · AI 对局 MCP 服务器

把游戏里的 AI 接口包装成 MCP 工具，任何支持 MCP 的 AI 客户端都能
**直接读局面、直接下指令**，全程不需要截图。

    python mcp_server.py        # stdio 传输（MCP 客户端自己会这样调）

工具：
    game_state  纯文本局面（推荐：一次读完就能决策）
    game_json   同一份局面的 JSON（脚本用）
    game_act    点一个带编号的目标
    game_wait   等局面稳定（敌方回合 / 转场）
    game_launch 启动或关闭游戏进程

⚠️ 本进程的 stdout 是 JSON-RPC 通道，任何调试输出都必须走 stderr。
"""
import json
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ai_cli  # noqa: E402
import launch  # noqa: E402

SERVER_INFO = {"name": "card-rogue-ai", "version": "1.0.0"}
PROTOCOL = "2024-11-05"

TOOLS = [
    {
        "name": "game_state",
        "description": (
            "读取当前局面（纯文本）。一次调用就给出：所在场景、生命/金币/卡组/道具，"
            "以及最关键的「可点目标」清单 —— 每个目标都有稳定 id（如 h0 手牌、"
            "r3c1 棋盘格、n12 地图房间、s1000 商店商品、b0 界面按钮）。"
            "战斗时还会给出双方场面、手牌每张的费用与可用性、费用与牌库数量。"
            "**决策所需的一切都在这里，不需要截图。**"
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "game_json",
        "description": "同一份局面的 JSON 版（字段化，适合脚本或需要精确数值时用）。",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "game_act",
        "description": (
            "点一个目标。这是**唯一**的操作入口 —— 出牌、移动、攻击、选技能目标、"
            "选卡、买商品、走进房间、点界面按钮，全都是「点一个目标」。"
            "target 取自 game_state 里「可点目标」段的方括号内 id。"
            "返回执行后的新局面。"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {
                    "type": "string",
                    "description": "目标 id，如 h0（手牌）、r3c1（棋盘格）、end（结束回合）、"
                                   "n12（地图房间）、s1000（商店商品）、b0（界面按钮）",
                }
            },
            "required": ["target"],
        },
    },
    {
        "name": "game_wait",
        "description": "等局面稳定（敌方 AI 行动完毕 / 转场结束），返回稳定后的局面。",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "game_launch",
        "description": (
            "启动游戏（带 AI 接口）或关闭它。headless=true 时不显示窗口。"
            "游戏已经在跑就直接返回。"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "enum": ["start", "stop"],
                           "description": "start 启动 / stop 关闭"},
                "headless": {"type": "boolean", "description": "是否无窗口运行"},
                "port": {"type": "integer", "description": "接口端口，默认 8770"},
            },
            "required": ["action"],
        },
    },
]


def _text(s):
    return {"content": [{"type": "text", "text": str(s)}], "isError": False}


def _err(s):
    return {"content": [{"type": "text", "text": str(s)}], "isError": True}


def call_tool(name, args):
    try:
        if name == "game_state":
            return _text(ai_cli.state())
        if name == "game_json":
            return _text(json.dumps(ai_cli.snapshot(), ensure_ascii=False, indent=2))
        if name == "game_act":
            target = str(args.get("target", "")).strip()
            if not target:
                return _err("缺 target 参数")
            return _text(ai_cli.act(target))
        if name == "game_wait":
            return _text(ai_cli.wait_turn())
        if name == "game_launch":
            action = str(args.get("action", "start"))
            if action == "stop":
                launch.stop()
                return _text("已关闭游戏")
            port = int(args.get("port") or launch.DEFAULT_PORT)
            rc = launch.launch(port, headless=bool(args.get("headless", True)))
            os.environ["CARD_ROGUE_AI_PORT"] = str(port)
            ai_cli.PORT = port
            ai_cli.BASE = "http://%s:%d" % (ai_cli.HOST, port)
            if rc != 0:
                return _err("启动失败（看 .ai_bridge.log）")
            return _text("游戏已启动，接口 127.0.0.1:%d\n\n%s" % (port, ai_cli.state()))
        return _err("没有这个工具：%s" % name)
    except ai_cli.BridgeError as e:
        return _err(str(e))
    except Exception as e:  # noqa: BLE001
        traceback.print_exc(file=sys.stderr)
        return _err("工具执行失败：%s" % e)


def handle(msg):
    method = msg.get("method")
    mid = msg.get("id")
    params = msg.get("params") or {}
    if method == "initialize":
        return {"jsonrpc": "2.0", "id": mid, "result": {
            "protocolVersion": params.get("protocolVersion", PROTOCOL),
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": SERVER_INFO,
        }}
    if method == "notifications/initialized":
        return None
    if method == "ping":
        return {"jsonrpc": "2.0", "id": mid, "result": {}}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": mid, "result": {"tools": TOOLS}}
    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        return {"jsonrpc": "2.0", "id": mid, "result": call_tool(name, args)}
    if mid is None:
        return None
    return {"jsonrpc": "2.0", "id": mid,
            "error": {"code": -32601, "message": "未知方法：%s" % method}}


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        try:
            out = handle(msg)
        except Exception as e:  # noqa: BLE001
            traceback.print_exc(file=sys.stderr)
            mid = msg.get("id")
            out = {"jsonrpc": "2.0", "id": mid,
                   "error": {"code": -32603, "message": str(e)}}
        if out is not None:
            sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
