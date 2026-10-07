# card_rogue Git 仓库使用手册（双机开发 · 随仓库分发版）

> 本文件**已提交进仓库根目录**（`GIT_使用手册.md`）。
> 另一台电脑只要 `git clone` 一次，这份手册就自动出现在它的工程目录里——
> **不需要从 WorkBuddy 资料库 / 工作空间获取**。
>
> 如果你是在另一台电脑上第一次看到这份文件：直接跳到 **第 2 节**，
> 照着做就能把整个仓库拉下来开始工作。所有命令在 Windows 的 **Git Bash** 里执行。

## 1. 仓库信息（速查）

| 项目 | 值 |
|---|---|
| 工程 | card_rogue —— Godot 4.3 卡牌肉鸽（三角色：森林精魄 / 暗影刺客 / 机械之心） |
| 仓库地址（克隆用） | `git@github.com:hanyuu33/card_rogue.git` |
| 网页地址 | https://github.com/hanyuu33/card_rogue |
| 可见性 | **私有**（仅本人 GitHub 账号可见） |
| 默认分支 | `main` |
| 当前最新提交 | `f371ccd`（R101+R102）；更早 `f2f24e4`(R100) / `ebc7514`(手册R99) / `eb4635a`(R99) / `6bba751`(手册R98) / `208e694`(R98) / `7173260`(R97) / `04eaf71`(手册) / `e6dc5bb`(R96) / `bbca24b`(R95) / `0391a24`(R92) / `1ef3d04`(首提交) |
| 入库文件数 | 约 188+（源码 + 素材；`.godot/` 缓存、`dist/` 产物、运行日志均排除） |
| 认证方式 | **SSH 密钥**（GitHub 自 2021-08 起不接受账号密码推送，只认 SSH 或 PAT） |
| 当前基线 | **engine 2279✓ / reward 26✓ / replay 28✓ / smoke 21 通过**（R102） |
| 卡库规模 | **181 张**（玩家 147 / 敌方 34；其中机械之心 28） |

> ⚠️ 完整提交历史随时用 `git log --oneline` 看，上面只列关键节点。

## 2. 新电脑第一次接入（三步）

### 2.1 准备 Git

本机若没装 Git，可先用内置的便携版（免安装）：

```bash
export PATH="/c/Users/<你的用户名>/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:/c/Users/<你的用户名>/.workbuddy/binaries/PortableGit/versions/1.2.0/cmd:$PATH"
git --version
```

正式用建议安装 [Git for Windows](https://git-scm.com/download/win)，装完就不用再配 PATH。

### 2.2 配置 SSH 密钥（每台电脑各配一把，不要复制私钥）

```bash
mkdir -p ~/.ssh
ssh-keygen -t ed25519 -C "nekonyaa33@gmail.com" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

把输出的**整行**公钥（以 `ssh-ed25519` 开头、到你邮箱结束）复制，打开
https://github.com/settings/ssh/new → Title 随便填 → 粘贴 → **Add SSH key**。

验证连通：

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh -T git@github.com
```

看到 `Hi hanyuu33! You've successfully authenticated` 即成功。

> 🔑 **为什么每台机器各配一把而非复制私钥**：任何一台机器丢失/重装时，
> 只在 GitHub 上吊销那一把即可，不影响另一台。复制私钥则一处泄露全盘失守。

### 2.3 克隆工程

```bash
cd /d/work
git clone git@github.com:hanyuu33/card_rogue.git
cd card_rogue
git config core.autocrlf false
git config core.quotepath false
```

> ⚠️ **`core.autocrlf false` 必须设**：本工程行尾是分开管制的
> （`cards.json`、`game_levels.gd`、`field_state.gd` 为 CRLF，其余 `.gd` 与 `relics.json` 为 LF）。
> 一旦让 Git 自动改写行尾，回归测试会成片报错。
> `core.quotepath false` 让中文文件名正常显示（否则 `玩法说明.txt` 会变成八进制乱码）。

克隆完顺手验证一下能跑：

```bash
python _verify.py
```

看到 `engine 2279✓ / reward 26✓ / replay 28✓ / smoke 21` 即环境一致。

## 3. 每天的双机工作流

| 时机 | 操作 |
|---|---|
| **开工**（落机第一件事） | `git pull` |
| 改动过程中 | 随时 `git status`、`git diff` 看改了什么 |
| **收工 / 换机前** | `git add -A` → `git commit -m "说明"` → `git push` |
| 到另一台电脑 | 再 `git pull`，继续改 |

```bash
git pull
# ... 改代码、跑测试 ...
git add -A
git commit -m "R97：新增某某卡（engine 2205✓）"
git push
```

**铁律：同一时间只在一台机器上改工程。**
换机前**必须 push**，落机后**先 pull**。漏了 pull 就动手改，是产生冲突的唯一常见原因。

如果 `git pull` 提示冲突：不要硬推。先 `git status` 看冲突文件，打开处理后再
`git add -A && git commit && git push`；实在拿不准就 `git merge --abort` 退回重来。

## 4. 提交前自检

1. 跑回归：`python _verify.py`
   当前基线（R102）：**engine 2279✓ / reward 26✓ / replay 28✓ / smoke 21 通过**（判绿看中文收尾串）。
   ⚠️ 每加一张新卡，卡数基线断言会变（`_verify.py` 会报 ✗），这是**正常的**，按实际数字更新断言即可。
2. 确认没有把缓存和产物提交进去：`git status --short`，正常只应看到源码类文件。
   `.godot/`、`dist/`、`_e.txt`、调试截图都已在 `.gitignore` 里，不该出现。
3. 大改（加卡、改机制）单独一个提交，说明里写清轮次与断言数，方便日后回滚定位。

## 5. 出错了怎么救

这才是上 Git 最大的价值 —— 之前 `card_data.gd` 被误删时没有版本控制，只能整份重建。

| 场景 | 命令 |
|---|---|
| 改坏了某个文件，想还原到上次提交 | `git checkout -- scripts/card_data.gd` |
| 误删了文件 | `git checkout -- <文件路径>`（或 `git restore <文件路径>`） |
| 找回更早某个版本的文件 | `git log --oneline` 找哈希 → `git checkout 1ef3d04 -- scripts/card_data.gd` |
| 看某次提交改了什么 | `git show <哈希>` |
| 撤销某次已推送的提交（保留历史，推荐） | `git revert <哈希>` → `git push` |
| 本地提交还没推送，想撤回 | `git reset --soft HEAD~1`（保留改动） |
| 看当前改动 | `git status`、`git diff` |
| 临时切到另一台机，改动还没做完 | 也照样 commit（`git commit -m "wip"`）+ push，别留未提交状态换机 |

## 6. 常用命令速查

| 命令 | 作用 |
|---|---|
| `git status -sb` | 简洁看状态（含与远端的 ahead/behind） |
| `git log --oneline -10` | 最近 10 条提交 |
| `git diff` | 未暂存的改动 |
| `git diff --stat` | 改了哪些文件、各改多少 |
| `git add -A` | 暂存全部改动 |
| `git commit -m "说明"` | 提交 |
| `git push` | 推送到 GitHub |
| `git pull` | 拉取远端最新 |
| `git stash` / `git stash pop` | 临时收起 / 取回未提交改动 |
| `git checkout -b 分支名` | 开新分支做实验 |

## 7. 本机已知的两个坑（来自开发机，提前告知省得踩）

1. **`git fetch` 可能建不出 `.git/refs/remotes/origin/`**：命令返回成功、还打印
   `[new branch] main -> origin/main`，但引用没落盘，`git rev-parse origin/main` 报
   `ambiguous argument`。绕法：用 Python 手工建目录并写引用文件
   （文件 `.git/refs/remotes/origin/main`，内容 = 完整 40 位提交哈希 + 换行）。
   同源问题：本机 shell 的 `mkdir -p` 会**静默失败**（返回 0 但目录不存在），
   与 `ls` / `head` / `dirname` 偶尔集体 `command not found` 属同一类环境异常。
2. **中文路径被转义**：`git ls-tree` 输出里 `玩法说明.txt` 会显示成八进制转义，
   直接 grep 匹配不上，看着像「文件没入库」。设 `git config core.quotepath false` 解决
   （第 2.3 节已包含这一步）。

## 8. 与资料库网盘备份的关系（双保险）

| 手段 | 管什么 | 特点 |
|---|---|---|
| **Git 仓库** | 源码增量、完整历史、随时回滚、双机同步 | 主力。每次提交都是还原点 |
| **资料库网盘整包** | `card_rogue_<轮次>_<日期>.tar.gz` | 额外打包了 `.workbuddy/memory/` 开发笔记（**不在 Git 仓库内**），换机后 AI 能立刻接上上下文 |

推荐换机时**两个都做**：先 `git push`，再让 WorkBuddy 打包上传一份归档。
Git 保证代码可回滚，网盘包保证开发记忆不丢。
（网盘归档由 WorkBuddy「资料库」能力生成，不在这份手册范围内。）

## 9. 换机交接清单

- [ ] 本机：`git status -sb` 确认没有未提交改动（或已 `git commit -m "wip"`）
- [ ] 本机：`python _verify.py` 确认回归是绿的
- [ ] 本机：`git push`
- [ ] 本机（可选）：让 WorkBuddy 打包上传一份资料库归档
- [ ] 另一台电脑：`git pull`
- [ ] 另一台电脑：`python _verify.py` 确认基线一致，再开始改
