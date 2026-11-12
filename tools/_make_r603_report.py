#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R603 改名验收页：中《嘎嘎乱杀》/ 英 Quackill。图片 base64 内嵌。"""
import base64, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOT = os.path.join(ROOT, "_review", "r603_title.png")
OUT = os.path.join(ROOT, "_preview", "r603_title_rename.html")


def b64(p):
    with open(p, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


img = b64(SHOT)

ROWS = [
    ("scripts/game_brand.gd", "LF",
     'NAME_CN := "卡牌肉鸽" → "嘎嘎乱杀"<br>NAME_EN := "" → "Quackill"',
     "名字的唯一来源：窗口标题 / 大标题 / 版本串 / 鸣谢页抬头全部跟着变"),
    ("scripts/test_engine.gd", "CRLF",
     "1 条 R578 锁 → 拆成 2 条<br>「无英文名时窗口标题=中文名」→「含中文名」+「含英文名」",
     "英文名填了值，旧锁必然失败，必须同步改口径"),
    ("export_presets.cfg", "LF",
     'application/product_name ×2 → "Quackill"<br>package/name ×2 → "嘎嘎乱杀"',
     "Windows 导出 exe 用英文名（Steam 上传/海外玩家安全）；安卓桌面显示用中文名"),
    ("scripts/ai_bridge.gd", "LF",
     '硬编码 "卡牌肉鸽 · AI 视图" → GameBrand.display_name()',
     "顺手收口，避免又一处独立文案"),
]

CHECKS = [
    ("assemble", "exit=0", "0✓ / 0✗"),
    ("engine", "exit=0", "5766✓ / 0✗"),
    ("reward", "exit=0", "26✓ / 0✗"),
    ("bgm", "exit=0", "39✓ / 0✗"),
    ("smoke", "exit=0", "68✓ / 0✗"),
    ("mana", "exit=0", "PASS"),
]

rows_html = "\n".join(
    f"""      <tr>
        <td class="file">{f}</td>
        <td class="eol">{e}</td>
        <td>{c}</td>
        <td class="why">{w}</td>
      </tr>"""
    for f, e, c, w in ROWS
)

checks_html = "\n".join(
    f"""      <div class="chk"><span class="ok">{s}</span><b>{n}</b><span class="num">{r}</span></div>"""
    for n, s, r in CHECKS
)

HTML = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>R603 改名验收 · 嘎嘎乱杀 / Quackill</title>
<style>
  :root {{
    --ink:#2b2118; --ink2:#5a4a3a; --gold:#a9852f; --gold-l:#d8b45a;
    --paper:#f6efdf; --paper2:#efe4cc; --line:#d8c9a8; --ok:#2f7d4f;
  }}
  * {{ box-sizing:border-box; }}
  body {{
    margin:0; padding:32px 20px 64px; background:#e8ddc6; color:var(--ink);
    font-family:"Noto Serif SC","Songti SC",Georgia,serif; line-height:1.7;
  }}
  .wrap {{ max-width:1000px; margin:0 auto; }}
  header {{
    text-align:center; padding:28px 20px 22px; background:var(--paper);
    border:1px solid var(--line); border-radius:10px; box-shadow:0 2px 0 #d5c6a6;
  }}
  h1 {{ margin:0 0 6px; font-size:34px; letter-spacing:.34em; text-indent:.34em; }}
  .en {{ font-family:Georgia,serif; font-size:20px; letter-spacing:.14em; color:var(--gold); margin-bottom:10px; }}
  .sub {{ font-size:13px; color:var(--ink2); letter-spacing:.08em; }}
  h2 {{
    margin:34px 0 12px; font-size:17px; letter-spacing:.16em; color:var(--ink);
    border-left:4px solid var(--gold); padding-left:12px;
  }}
  .shot {{ margin-top:20px; border:1px solid var(--line); border-radius:8px; overflow:hidden; background:#000; }}
  .shot img {{ display:block; width:100%; height:auto; }}
  .cap {{ font-size:12px; color:var(--ink2); text-align:center; padding:8px 0 0; }}
  table {{ width:100%; border-collapse:collapse; background:var(--paper); font-size:13.5px; }}
  th {{ background:var(--paper2); font-weight:600; letter-spacing:.08em; padding:10px 12px; text-align:left; border-bottom:1px solid var(--line); }}
  td {{ padding:10px 12px; border-bottom:1px solid var(--line); vertical-align:top; }}
  tr:last-child td {{ border-bottom:none; }}
  .file {{ font-family:Consolas,Menlo,monospace; font-size:12.5px; color:#6b4a1c; white-space:nowrap; }}
  .eol {{ font-family:Consolas,monospace; font-size:11.5px; color:var(--ink2); }}
  .why {{ font-size:12.5px; color:var(--ink2); }}
  .checks {{ display:flex; flex-wrap:wrap; gap:10px; }}
  .chk {{
    flex:1 1 150px; background:var(--paper); border:1px solid var(--line);
    border-radius:8px; padding:12px 14px; display:flex; flex-direction:column; gap:2px;
  }}
  .chk b {{ font-size:13px; letter-spacing:.06em; }}
  .ok {{ font-size:11px; color:var(--ok); letter-spacing:.06em; }}
  .num {{ font-family:Consolas,monospace; font-size:13px; color:var(--ink2); }}
  .note {{ background:var(--paper); border:1px solid var(--line); border-left:4px solid var(--gold-l); border-radius:6px; padding:14px 18px; font-size:13.5px; }}
  .note ul {{ margin:8px 0 0; padding-left:20px; }}
  .note li {{ margin:5px 0; }}
  code {{ font-family:Consolas,Menlo,monospace; font-size:12.5px; background:#e9dcc0; padding:1px 5px; border-radius:3px; }}
  .warn {{ color:#9a4a1a; font-weight:600; }}
  footer {{ margin-top:36px; text-align:center; font-size:12px; color:var(--ink2); letter-spacing:.08em; }}
</style>
</head>
<body>
<div class="wrap">

  <header>
    <h1>嘎嘎乱杀</h1>
    <div class="en">QUACKILL</div>
    <div class="sub">中文负责记得住 · 英文负责搜得到 · Steam 本地化 app 名各显示各的</div>
  </header>

  <h2>标题页实机效果（1280×800，未缩放）</h2>
  <div class="shot"><img src="data:image/png;base64,{img}" alt="标题页"></div>
  <div class="cap">窗口标题 = 嘎嘎乱杀 (Quackill)　·　大标题四字紧凑，金描边压在暖光村庄上，未被撑宽</div>

  <h2>四处改动</h2>
  <table>
    <thead>
      <tr><th>文件</th><th>行尾</th><th>改了什么</th><th>为什么</th></tr>
    </thead>
    <tbody>
{rows_html}
    </tbody>
  </table>

  <h2>六套回归</h2>
  <div class="checks">
{checks_html}
  </div>

  <h2>没有动的地方（重要）</h2>
  <div class="note">
    <ul>
      <li><code>project.godot</code> 的 <code>config/name</code> <span class="warn">保持「卡牌肉鸽」不动</span> —— 它决定 <code>user://</code> 存档目录名。改了老玩家的档案看起来会「消失」（实际躺在旧目录里）。R578 的存档目录锁继续守着。</li>
      <li>存档目录已按「文件集合 + 内容」逐文件还原，28 个备份文件里回填 9 个，无残留。</li>
      <li><code>test_engine.gd</code> 有 <span class="warn">3.7 万行的未提交并行线改动</span>（工作区 71478 行 vs HEAD 34386 行）。我只动了 R578 那两条锁，<b>提交时不要整文件 add</b>。</li>
    </ul>
  </div>

  <h2>上架前还该处理的三件小事</h2>
  <div class="note">
    <ul>
      <li><code>GameBrand.FOOTER</code> 仍是 <code>"v{{v}}-rogue · 肉鸽开发版"</code> —— 「开发版」三个字在商店页截图里会被看到，建议改成纯 <code>v1.0</code> 或版权行。</li>
      <li><code>export_presets.cfg</code> 的 <code>export_path</code> 仍是 <code>dist/DuckCardsRogue.apk</code>，导出文件名没跟着改。</li>
      <li>Steamworks 后台要单独配 app 名的中英本地化 —— 那侧是独立配置，游戏内改不到。</li>
    </ul>
  </div>

  <footer>R603 · 2026-11-12　·　名字的唯一来源仍是 GameBrand，改一处四显示全动</footer>
</div>
</body>
</html>
"""

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(HTML)
print("wrote", OUT, len(HTML), "chars")
