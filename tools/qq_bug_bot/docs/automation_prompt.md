# 自动排查任务配置（WorkBuddy 定时任务）

> **自动化不会随 git 同步。** 它绑定在本机的 WorkBuddy 客户端上，换机器必须手动重建一条。

## 怎么建

1. 对 WorkBuddy 说：「新建一个每小时执行的自动化，名字叫 `QQ群 bug 自动排查`」
2. 工作目录填 **card_rogue 的根目录**
3. 把下面的 prompt 整段粘进去
4. 把所有路径换成新机器的实际路径：
   - `D:\work\bug_bridge` → 你在 `.env` 里给 `BUG_BRIDGE_DIR` 填的那个目录
   - `D:\work\card_rogue` → 新机器上 card_rogue 的位置

## Prompt

```text
扫描 D:\work\bug_bridge\inbox 下的 bug 上报文件（文件名形如 BUG-YYYYMMDD-NNN.json），逐个排查。这些是 card_rogue 游戏（Godot 4.3 + GDScript 工程，根目录 D:\work\card_rogue）的玩家 QQ 群反馈。

处理步骤：
1. 列出 inbox 下所有 *.json。若为空，或全部是 status 为 "claiming" 的占位文件（没有实质 content），则直接结束，不输出内容、不写任何文件。
2. 对每个 status 为 pending 的 bug：读取 id、content（玩家文字描述）、images（截图绝对路径，可用 Read 工具直接查看图片）、nickname、created_at。
3. 在 D:\work\card_rogue 中定位问题。先用 Grep 搜玩家描述里的关键中文词（卡名、关卡名、机制名、界面元素）映射到具体文件。工程约定：卡牌数据在 cards.json；引擎结算在 scripts/game_engine.gd；战场与手牌界面在 scripts/battle_scene.gd；地图与随机走路在 scripts/map_scene.gd；关卡定义在 scripts/game_levels.gd；存档续档在 scripts/run_save.gd；卡面绘制在 scripts/card_face.gd 与 scripts/ui_theme.gd；回归脚本是工程根目录 _verify.py。机制不变式参考 UI设计规范.md、关卡与敌人配置总览.md。若同时有截图，以截图显示的实际界面状态为准。
4. 判定 verdict，四选一：
   - confirmed：能在代码里指出明确的逻辑缺陷，且与描述吻合
   - suspected：有高度可疑的代码点，但无运行环境无法确证
   - need_info：描述过于笼统无法定位，需玩家补充信息
   - invalid：不是 bug（设计预期、误操作，或与本工程无关）
5. 为每个 bug 写结构化报告到 D:\work\bug_bridge\reports\<bug_id>.json（UTF-8），字段严格如下：
{"bug_id":"BUG-...","group_id":<从 bug 文件原样复制的整数>,"verdict":"confirmed|suspected|need_info|invalid","summary":"一句话结论，20 字内","analysis":"详细中文分析，说明判定依据，引用具体代码位置与逻辑","locations":["scripts/game_engine.gd:1234"],"suggestion":"修复建议；当 verdict 为 need_info 时改写为需要玩家补充的信息清单","confidence":0.0到1.0的小数,"message":"直接发到 QQ 群的纯文本，中文，300 字以内，禁止 Markdown 语法/表格/代码块。格式：第一行「【BUG 排查结果】bug_id」第二行「判定：xxx」第三行「结论：xxx」有定位则加「定位：文件:行号」最后一行「建议：xxx」。语气对玩家友好。"}
6. 同时写一份 Markdown 档案到 D:\work\card_rogue\bugs\<bug_id>_<简短标题>.md，格式对齐该目录下现有文档：
# Bug 汇报：<标题>
- **汇报时间**：<取 bug 的 created_at 日期>
- **来源**：QQ 群 <group_id> / <nickname>
- **状态**：**待确认（AI 初判）**，或按 verdict 写「疑似」「需补充信息」「非 bug」
- **严重度**：高/中/低 + 一句理由
## 现象
## 期望行为
## 复现步骤（能从描述推断就写，推断不出写「待补充」）
## AI 初判
（判定依据、引用具体代码位置、confidence）
## 建议修法
7. 处理完后，把 inbox 里对应的 bug 文件移动到 D:\work\bug_bridge\processing\（保持同名）。
8. 全部处理完，用一句话说明本轮处理条数与各自判定。

硬性约束：
- 除在 D:\work\card_rogue\bugs\ 下新增 md 档案外，绝对不要修改 card_rogue 里的任何文件，不要改代码。
- 不要运行 _verify.py。
- 不要删除任何文件，只允许 inbox 到 processing 的移动。
- 报告必须是合法 JSON，写盘后用 Read 复查一次。
- 同一玩家重复上报同一问题，各自独立成报告，不合并。
- 若遇到 group_id 为 0 且 content 含「自检测试」的自检数据，按 invalid 处理，message 里注明这是自检数据。
```

## 调度

每小时执行一次（`FREQ=HOURLY;INTERVAL=1`）。这是 WorkBuddy 支持的最小粒度，做不到分钟级。

想立即看结果时，直接对 WorkBuddy 说「跑一次 bug 排查」，会立刻按同一套流程处理一遍。
