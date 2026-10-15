// OpenTracks BGM 下载器（浏览器路径 v2）
// 关键：浏览器整体走系统代理 127.0.0.1:7897；在详情页上驱动 <audio> 加载，
//       用 page.on('response') 捕获浏览器实际收到的 dova-worker 音频字节。
// 用法: node _download_opentracks.js
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright-core");

const ROOT = "E:/work/card_rogue/assets/audio/_audition";
const MANIFEST = path.join(ROOT, "music_manifest.json");
const OUT = path.join(ROOT, "raw", "opentracks");
const PROXY = "http://127.0.0.1:7897";

async function main() {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
  const jobs = [];
  for (const slot of Object.keys(manifest)) {
    for (const t of manifest[slot]) {
      if (t.lib === "OpenTracks" && t.detail) {
        const id = t.detail.replace(/\/+$/, "").split("/").pop();
        jobs.push({ slot, name: t.name, detail: t.detail, id });
      }
    }
  }
  console.log("OpenTracks 任务数:", jobs.length);
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch({
    channel: "msedge",
    headless: true,
    proxy: { server: PROXY },
  });
  const ctx = await browser.newContext({
    userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0",
  });
  const page = await ctx.newPage();

  let ok = 0;
  const failed = [];
  for (const j of jobs) {
    const dst = path.join(OUT, j.id + ".mp3");
    if (fs.existsSync(dst) && fs.statSync(dst).size > 100 * 1024) {
      console.log("跳过(已存在):", j.id, j.name);
      ok++;
      continue;
    }
    console.log("处理:", j.id, j.name, j.detail);
    let saved = false;
    const onResp = (resp) => {
      if (!resp.url().includes("dova-worker")) return;
      resp.body().then((body) => {
        if (body && body.length > 100 * 1024 && !saved) {
          fs.writeFileSync(dst, body);
          saved = true;
          console.log("  捕获 %.1f MB", body.length / 1048576);
        }
      }).catch(() => {});
    };
    page.on("response", onResp);
    try {
      await page.goto(j.detail, { waitUntil: "domcontentloaded", timeout: 90000 });
      const src = await page.evaluate(() => {
        const a = document.querySelector("audio");
        if (a && a.src) return a.src;
        const s = document.querySelector("audio source");
        if (s && s.src) return s.src;
        return null;
      });
      if (!src) {
        console.log("  !! 页面未找到 audio src");
        failed.push(j.id);
        page.removeListener("response", onResp);
        continue;
      }
      console.log("  src:", src.slice(0, 80) + "...");
      // 驱动 audio 元素拉流（浏览器网络栈 + 浏览器 TLS 指纹 + 代理）
      await page.evaluate(() => {
        const a = document.querySelector("audio");
        if (a) { a.preload = "auto"; a.load(); a.play().catch(() => {}); }
      });
      // 等捕获完成（音频几 MB，代理 ~100KB/s，最多等 3 分钟）
      const t0 = Date.now();
      while (!saved && Date.now() - t0 < 180000) {
        await page.waitForTimeout(2000);
      }
      if (saved) {
        ok++;
      } else {
        console.log("  !! 超时未捕获");
        failed.push(j.id);
      }
    } catch (e) {
      console.log("  !! 异常:", String(e).slice(0, 120));
      failed.push(j.id);
    }
    page.removeListener("response", onResp);
  }
  await browser.close();
  console.log("\n== 汇总 ==  成功 %d / 失败 %d", ok, failed.length);
  for (const f of failed) console.log("  失败:", f);
}

main().catch((e) => {
  console.error("FATAL", e);
  process.exit(1);
});
