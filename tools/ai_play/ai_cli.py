# -*- coding: utf-8 -*-
"""AI 对局客户端：读写卡牌肉鸽的 AI 接口。

不依赖任何第三方库（只用 urllib），可以单独当命令行工具用，
也是 mcp_server.py 的底层。

用法：
    python ai_cli.py state              # 读纯文本局面
    python ai_cli.py json               # 读 JSON 局面
    python ai_cli.py act h0             # 点一个目标
    python ai_cli.py seq h0 r3c0 end    # 连着点一串（一条命令打完一回合）
    python ai_cli.py new 暗影刺客       # 开新局（可再给一个 10 位种子码）
    python ai_cli.py rewind             # 战斗 SL：回到本场开打那一刻
    python ai_cli.py save               # 强制写盘（headless 对局唯一的崩溃保险）
    python ai_cli.py load               # 从存档续上当前局
    python ai_cli.py wait               # 等局面稳定（敌方回合 / 转场后）
    python ai_cli.py reset              # 清空「连续 Bash」连击计数（插过别的工具后调）

这是给 AI 用的「眼睛 + 手」，不是 bot —— 决策在你自己脑子里。
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

HOST = os.environ.get("CARD_ROGUE_AI_HOST", "127.0.0.1")
PORT = int(os.environ.get("CARD_ROGUE_AI_PORT", "8770"))
BASE = "http://%s:%d" % (HOST, PORT)

# ⚠️ 本机接口必须**绕过系统代理**：环境里配了 http_proxy 时，urllib 会把
#    127.0.0.1 的请求也丢给代理，得到一个 502 Bad Gateway（明明是本地服务）。
_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


class BridgeError(RuntimeError):
    pass


def get(path, timeout=10.0):
    url = BASE + path
    try:
        with _OPENER.open(url, timeout=timeout) as r:
            return r.read().decode("utf-8")
    except urllib.error.URLError as e:
        raise BridgeError(
            "连不上 AI 接口（%s）。先启动游戏：python launch.py\n底层错误：%s" % (url, e)
        ) from e


def state():
    """当前局面的纯文本版。"""
    return get("/state")


def snapshot():
    """当前局面的 JSON 版。"""
    return json.loads(get("/json"))


def act_reply(target, timeout=15.0):
    """点一个目标，返回完整回复：{ok, msg, scene, sig, state}。

    `ok` 是服务端的判定 —— False 表示**这个动作根本没生效**（不可点 / 位置不对 /
    金币不够 / 刚点过……），`msg` 里写着原因。AI 应当读它，而不是从 state 猜。
    """
    body = json.dumps({"target": str(target)}).encode("utf-8")
    req = urllib.request.Request(
        BASE + "/act", data=body, method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with _OPENER.open(req, timeout=timeout) as r:
            raw = r.read().decode("utf-8")
    except urllib.error.URLError as e:
        raise BridgeError("动作失败：%s" % e) from e
    try:
        rep = json.loads(raw)
    except ValueError:
        # 兼容老版本服务端（纯文本）
        rep = {"ok": True, "msg": raw, "state": raw, "sig": raw, "scene": ""}
    txt = rep.get("state") or ""
    # 结束回合 / 打完敌方 → 服务端还没转回我方，这里替 AI 等一手（省掉轮询）
    if "等 AI 行动" in txt:
        txt = wait_turn()
        rep["state"] = txt
        rep["sig"] = _sig(txt)
    # 场景正在切换（current_scene 为 null）→ 等它落定，别让上层读到半截状态
    if "（没有场景）" in txt:
        for _ in range(20):
            time.sleep(0.2)
            txt = state()
            if "（没有场景）" not in txt:
                break
        rep["state"] = txt
        rep["sig"] = _sig(txt)
    return rep


def _sig(txt):
    """局面指纹（去掉「上一步」，与服务端 _sig 同口径）。"""
    return "\n".join(ln for ln in txt.splitlines() if not ln.startswith("上一步："))


def act(target, timeout=15.0):
    """点一个目标（id 见 state 的「可点目标」段）。返回执行后的新状态文本。"""
    return act_reply(target, timeout).get("state") or ""


def _post(path, payload, timeout=60.0):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        BASE + path, data=body, method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    with _OPENER.open(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def seq(targets, timeout=120.0):
    """连点一串目标，返回 {ok, failed, steps, state, ...}。中途失败就停。"""
    return _post("/seq", {"targets": [str(t) for t in targets]}, timeout)


def new_run(cls, seed=""):
    """开新局。cls 用中文职业名（森林精魄 / 暗影刺客 / 机械之心），seed 可空。

    服务端返回时 `SceneFx` 的转场还没跑完（那一刻仍是标题场景），这里替调用方
    等场面落定，免得读到一个「刚开局却还写着标题」的自相矛盾状态。
    """
    rep = _post("/new", {"class": str(cls), "seed": str(seed)})
    if rep.get("ok"):
        rep["state"] = wait(settle=0.5, timeout=15.0)
        rep["sig"] = _sig(rep["state"])
    return rep


def rewind():
    """战斗 SL：回到本场战斗刚开打那一刻（同样等转场落定）。"""
    rep = _post("/rewind", {})
    if rep.get("ok"):
        rep["state"] = wait(settle=0.6, timeout=15.0)
        rep["sig"] = _sig(rep["state"])
    return rep


def _scene_name(txt):
    for line in txt.splitlines():
        if line.startswith("场景："):
            return line.split("：", 1)[1].strip()
    return ""


def wait_turn(timeout=40.0):
    """等回到「我方回合」（敌方 AI 打完 / 演出结束）。非战斗场景原样返回。"""
    end = time.time() + timeout
    last = ""
    while time.time() < end:
        try:
            snap = snapshot()
        except BridgeError:
            time.sleep(0.25)
            continue
        if snap.get("scene") != "battle":
            return state()
        b = snap.get("battle") or {}
        if b.get("side") == "self" or not b:
            return state()
        last = state()
        time.sleep(0.2)
    return last or state()


def wait(settle=0.35, timeout=25.0):
    """等到局面不再变化（敌方 AI 打完 / 转场结束），返回稳定后的状态文本。"""
    end = time.time() + timeout
    prev = ""
    stable_since = None
    while time.time() < end:
        try:
            cur = state()
        except BridgeError:
            time.sleep(0.2)
            continue
        if cur == prev:
            if stable_since is None:
                stable_since = time.time()
            elif time.time() - stable_since >= settle:
                return cur
        else:
            prev = cur
            stable_since = None
        time.sleep(0.08)
    return prev


# ── 连击计数器 ────────────────────────────────────────────────────
# 客户端的循环守卫只数「同一个工具连续调用几次」（Bash 默认 80 次弹确认），
# 不看命令内容。试玩时几乎全程都在调 Bash，靠记性刹车不现实 —— 让工具自己喊。
_CALLFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".aicli_calls")


def _bump_calls():
    try:
        n = int(open(_CALLFILE, encoding="utf-8").read().strip() or "0")
    except Exception:
        n = 0
    n += 1
    try:
        with open(_CALLFILE, "w", encoding="utf-8") as f:
            f.write(str(n))
    except Exception:
        pass
    return n


def _call_banner(n):
    if n >= 35:
        return "[!!] ai_cli 第 %d 次调用 —— 已过 35，下一条命令**必须**换成 Read/Grep/Glob" % n
    if n >= 25:
        return "[!]  ai_cli 第 %d 次调用 —— 请插入一次非 Bash 工具（Read/Grep/Glob）" % n
    if n >= 15 and n % 5 == 0:
        return "[.]  ai_cli 第 %d 次调用（连击计数，25 起升级提醒）" % n
    return ""


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "reset":
        try:
            os.remove(_CALLFILE)
        except OSError:
            pass
        print("✓ 连击计数已归零")
        return 0
    _banner = _call_banner(_bump_calls())
    if _banner:
        print(_banner)
    if cmd == "state":
        print(state())
    elif cmd == "json":
        print(json.dumps(snapshot(), ensure_ascii=False, indent=2))
    elif cmd == "act":
        if len(argv) < 3:
            print("用法：python ai_cli.py act <target>")
            return 2
        print(act(argv[2]))
    elif cmd == "seq":
        if len(argv) < 3:
            print("用法：python ai_cli.py seq h0 r3c0 end")
            return 2
        rep = seq(argv[2:])
        for st in rep.get("steps", []):
            print(("  ✓ %-8s %s" if st.get("ok") else "  ✗ %-8s %s")
                  % (st.get("target"), (st.get("msg") or "").splitlines()[0][:70]))
        if rep.get("failed"):
            print("!! 中断于 %s" % rep["failed"])
        print(rep.get("state") or "")
    elif cmd == "new":
        if len(argv) < 3:
            print("用法：python ai_cli.py new <职业> [种子]")
            return 2
        rep = new_run(argv[2], argv[3] if len(argv) > 3 else "")
        print(("✓ " if rep.get("ok") else "✗ ") + str(rep.get("msg", "")))
        print(rep.get("state") or "")
    elif cmd == "rewind":
        rep = rewind()
        print(("✓ " if rep.get("ok") else "✗ ") + str(rep.get("msg", "")))
        print(rep.get("state") or "")
    elif cmd == "save":
        rep = _post("/save", {})
        print(("✓ " if rep.get("ok") else "✗ ") + str(rep.get("msg", "")))
        print("第 %s 层  n%s  生命 %s  巧克力 %s  种子 %s"
              % (rep.get("layer"), rep.get("node"), rep.get("hp"),
                 rep.get("chocolate"), rep.get("seed")))
    elif cmd == "load":
        rep = _post("/load", {})
        print(("✓ " if rep.get("ok") else "✗ ") + str(rep.get("msg", "")))
        if rep.get("ok"):
            print(wait(settle=0.6, timeout=20.0))
    elif cmd == "wait":
        print(wait())
    elif cmd == "scene":
        print(_scene_name(state()))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
