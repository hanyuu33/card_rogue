# QQ 群 Bug 汇报机器人

让群里的玩家用 `/bug` 直接汇报问题，机器人记录下来，WorkBuddy 每小时自动到 `card_rogue` 工程里定位原因，再把结论发回同一个群。

---

## 架构

```
QQ 群玩家  /bug 描述 + 截图
      │
      ▼
NapCat（协议端，登录 QQ）
      │  OneBot 11 / 反向 WebSocket
      ▼
NoneBot2 机器人（本项目）
      │  写文件
      ▼
D:\work\bug_bridge\inbox\BUG-20261020-001.json
      │
      ▼  WorkBuddy 定时任务（每小时，需客户端保持运行）
      │  读 bug → 在 card_rogue 工程里 Grep/读码定位 → 出判定
      ▼
D:\work\bug_bridge\reports\BUG-20261020-001.json
      │
      ▼  机器人每 20 秒轮询
QQ 群收到排查结论 → 报告移入 done/
```

两个进程**互不依赖**：机器人挂了不影响排查，WorkBuddy 没开也不影响收 bug，重启任意一方都不会丢数据。

---

## 目录结构

```
D:\work\card_rogue\tools\qq_bug_bot\              机器人本体
├── bot.py                       启动入口
├── .env                         运行配置（由 .env.example 复制）
├── requirements.txt
└── plugins\bug_report\
    ├── __init__.py              指令 + 回推循环
    └── bridge.py                文件桥接（可独立自测）

D:\work\bug_bridge\              双方共用的数据盘
├── inbox\                       待排查
│   └── images\                  玩家截图
├── processing\                  排查中
├── reports\                     结论待回推
└── done\                        已回推归档
```

---

## 前置条件

| 项目 | 说明 |
| --- | --- |
| Python | 3.10 及以上（本机已有 3.10 与 3.13） |
| 一个 QQ 号 | **强烈建议用小号**，第三方协议的账号有被风控的风险 |
| NapCat | 免费开源，用 NTQQ 协议登录，提供 OneBot 11 接口 |
| WorkBuddy | 定时任务由客户端执行，**排查期间需要客户端保持运行** |

---

## 第一步：装机器人环境

在 `D:\work\card_rogue\tools\qq_bug_bot` 下执行：

```bat
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
copy .env.example .env
```

如果 pip 卡住，去掉镜像参数直连官方源（本机清华镜像曾出现过 SSL EOF）。

`.env` 默认监听 `127.0.0.1:8080`，指令前缀为 `/`。

---

## 第二步：装 NapCat 并登录 QQ

1. 到 [NapNeko/NapCatQQ](https://github.com/NapNeko/NapCatQQ) 的 Releases 下载 Windows 版本（`NapCat.Shell` 一键包最省事）。
2. 解压后运行启动脚本，按提示扫码登录机器人 QQ。
3. 启动日志会打印 WebUI 地址（默认 `http://127.0.0.1:6099`）和一次性 token，用它登录后台。

> 如果已有 QQ NT 客户端，也可以用 NapCat 的注入方式；首次使用推荐独立一键包，避免污染日常 QQ。

---

## 第三步：配置 NapCat 连接

进入 WebUI → **网络配置** → 新建 → 选 **WebSocket 客户端**：

| 字段 | 值 |
| --- | --- |
| 名称 | `nonebot` |
| URL | `ws://127.0.0.1:8080/onebot/v11/ws` |
| 消息格式 | `array` |
| 心跳间隔 | `30000` |
| 重连间隔 | `3000` |

保存并启用。此时机器人还没启动，连接会失败重试，正常。

---

## 第四步：启动机器人

```bat
cd /d D:\work\card_rogue\tools\qq_bug_bot
.venv\Scripts\python.exe bot.py
```

看到 `Bot ... connected` 和 `[bug_report] 结论回推已启动` 就成功了。
把机器人拉进群，发一条 `/bug 测试一下`，群里应立刻收到带编号的回执。

---

## 第五步：确认自动排查已就绪

WorkBuddy 里已有一条定时任务「QQ群 bug 自动排查」，每小时整点扫描一次 `inbox`。可以在自动化列表里确认状态为运行中。

想立刻验证，不必等整点：直接对 WorkBuddy 说「跑一次 bug 排查」，它会立刻执行同一套流程。

---

## 群指令

| 指令 | 作用 |
| --- | --- |
| `/bug 描述文字` | 汇报问题，可同时带多张截图 |
| `/bug`（只发图） | 也接受，先存档 |
| `/bugstatus BUG-20261020-001` | 查单条进度与结论 |
| `/buglist` | 查看队列统计 |

回执形如：

```
收到啦，编号 BUG-20261020-003
问题：第二层打完 boss 后卡在结算界面
已保存截图 1 张
已进入排查队列，出结论会直接发到本群。
```

排查结论形如：

```
【BUG 排查结果】BUG-20261020-003
判定：已确认
结论：Boss 死亡后未推进 phase，结算界面不触发
定位：scripts/battle_scene.gd:1872
建议：在 boss 死亡回调里补一次 _check_battle_end()
```

---

## 数据格式

`inbox/BUG-xxx.json`（机器人写）：

```json
{
  "id": "BUG-20261020-001",
  "group_id": 123456789,
  "user_id": 987654321,
  "nickname": "群友昵称",
  "content": "第二层打完 boss 后卡住",
  "images": ["D:\\work\\bug_bridge\\inbox\\images\\BUG-20261020-001_00.jpg"],
  "created_at": "2026-10-20T19:30:12+08:00",
  "status": "pending"
}
```

`reports/BUG-xxx.json`（WorkBuddy 写）：

```json
{
  "bug_id": "BUG-20261020-001",
  "group_id": 123456789,
  "verdict": "confirmed",
  "summary": "Boss 死亡未推进阶段",
  "analysis": "详细判定依据……",
  "locations": ["scripts/battle_scene.gd:1872"],
  "suggestion": "补一次 _check_battle_end()",
  "confidence": 0.75,
  "message": "直接发群的纯文本"
}
```

`verdict` 四档：`confirmed` 已确认 / `suspected` 疑似 / `need_info` 需补充信息 / `invalid` 非 bug。

同时会在 `D:\work\card_rogue\bugs\` 下生成一份 Markdown 档案（`BUG-xxx_标题.md`），格式对齐你在该目录已有的 bug 记录（现象 / 期望行为 / 复现步骤 / AI 初判 / 建议修法），方便后续修复时直接在末尾追加处理记录。

---

## 不装 QQ 也能测

```bat
:: 默认：临时目录自检，不碰真实队列
.venv\Scripts\python.exe tools\simulate.py

:: 只看真实队列统计
.venv\Scripts\python.exe tools\simulate.py --stat

:: 往真实 inbox 丢一条测试反馈（会被真的排查一次）
.venv\Scripts\python.exe tools\simulate.py --push
```

默认模式会验证 id 递增、写盘读回、报告归档三件事，跑完打印 `[OK]` 即说明桥接层正常。

---

## 常见问题

**群里发 `/bug` 没反应**
- 机器人是否真的在群里，且没被禁言
- `.env` 的 `COMMAND_START` 是否包含 `/`
- 如果群里还有其他机器人抢指令，改用 `@机器人 /bug ...`

**日志报 `WebSocket connection failed`**
- NapCat 的 URL 是否写成了 `ws://127.0.0.1:8080/onebot/v11/ws`（注意 `/onebot/v11/ws` 后缀不能少）
- 机器人是否已启动

**收到回执但一直没结论**
- WorkBuddy 客户端是否在运行（关掉就不会执行定时任务）
- `inbox` 里的文件 `status` 是否为 `pending`

**截图没存下来**
- 部分客户端给的图片地址是本地文件名而非 http 链接，这种情况会跳过，但文字描述仍会照常记录

**结论重复发到群里**
- 正常情况下报告推送成功后立即移入 `done`，不会重发；若 NapCat 断线导致发送失败，会下一轮重试

**想改排查频率**
- 在 WorkBuddy 自动化列表里编辑「QQ群 bug 自动排查」的周期。注意最小粒度是 1 小时，做不到分钟级

---

## 换一台机器部署

代码在 `tools\qq_bug_bot`，跟着 card_rogue 仓库走，拉下来即可。

1. 装环境：

   ```bat
   cd tools\qq_bug_bot
   python -m venv .venv
   .venv\Scripts\python.exe -m pip install -r requirements.txt
   copy .env.example .env
   ```

2. 改 `.env` 里的 `BUG_BRIDGE_DIR`，指到本机想放数据的目录（盘符不同必须改）。
   `bot.py` 启动时会用 python-dotenv 把 `.env` 读进进程环境，改完即生效，不用动代码。

3. 装 NapCat，配置 `ws://127.0.0.1:8080/onebot/v11/ws`（同第三步）。

4. **重建定时任务**：自动化绑定本机，不随 git 同步。按 `docs\automation_prompt.md`
   建一条，并把里面所有 `D:\work\...` 换成新机器的实际路径。

5. 双击 `start_bot.bat` 启动。

> `bug_bridge\` 与 `.venv\` 都不入库：前者是运行数据，后者是本机环境，各机器各留一份。

---

## 风险提示

- 第三方协议端的账号存在被腾讯风控的可能，**务必用不重要的号码**，不要用主号。
- 机器人只读取群消息中的指令，其余聊天内容不落盘、不上传。
- 自动排查结论由 AI 生成，`confidence` 低于 0.6 的建议人工复核后再答复玩家。
