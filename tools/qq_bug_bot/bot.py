"""NoneBot2 启动入口。

用法：
    python bot.py

前提：
    1. 已复制 .env.example 为 .env 并按需修改
    2. NapCat 已登录 QQ，且配置了「反向 WebSocket 客户端」指向
       ws://127.0.0.1:8080/onebot/v11/ws
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# 固定工作目录，保证 load_plugins("plugins") 与 .env 的相对路径总能找到
BASE_DIR = Path(__file__).resolve().parent
os.chdir(BASE_DIR)

# 把 .env 灌进 os.environ：NoneBot 的 BaseSettings 只读 .env、不回写进程环境，
# 少了这一步，插件里的 os.environ.get("BUG_BRIDGE_DIR") 永远读不到 .env 的值
load_dotenv(BASE_DIR / ".env", override=False)

import nonebot  # noqa: E402
from nonebot.adapters.onebot.v11 import Adapter as OneBotV11Adapter  # noqa: E402

nonebot.init()

driver = nonebot.get_driver()
driver.register_adapter(OneBotV11Adapter)

nonebot.load_plugins("plugins")

if __name__ == "__main__":
    nonebot.run()
