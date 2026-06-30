import { existsSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";

const root = resolve(import.meta.dirname, "..");

const requiredFiles = [
  ".vercelignore",
  "404.html",
  "index.html",
  "zh/index.html",
  "styles.css",
  "script.js",
  "server.mjs",
  "vercel.json",
  "assets/agent-island-hero-poster.png",
  "assets/agent-island-hero-demo.mp4",
  "assets/agent-island-usage.png",
  "assets/agent-island-auto-trigger.png",
  "assets/agentisland_logo.png",
];

for (const file of requiredFiles) {
  const path = join(root, file);
  if (!existsSync(path) || !statSync(path).isFile()) {
    throw new Error(`Missing required file: ${file}`);
  }
}

const vercelIgnore = readFileSync(join(root, ".vercelignore"), "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);
const vercelConfig = JSON.parse(readFileSync(join(root, "vercel.json"), "utf8"));

const ignoredDeployFiles = ["server.mjs", "tests/", "package.json", ".env*", ".vercel/"];
for (const entry of ignoredDeployFiles) {
  if (!vercelIgnore.includes(entry)) throw new Error(`Vercel deploy ignore missing: ${entry}`);
}

const forbiddenRoute = vercelConfig.routes?.find((entry) => {
  if (typeof entry.src !== "string" || entry.status !== 404) return false;
  const route = new RegExp(entry.src);
  return ["/server.mjs", "/server%2emjs", "/tests/smoke.mjs", "/tests%2fsmoke.mjs"].every((path) => route.test(path));
});
if (!forbiddenRoute) {
  throw new Error("Vercel config must block source/test/config files, including encoded variants");
}

const assetHeader = vercelConfig.headers?.find((entry) => entry.source === "/assets/(.*)");
const cacheHeader = assetHeader?.headers?.find((entry) => entry.key.toLowerCase() === "cache-control");
if (cacheHeader?.value !== "public, max-age=31536000, immutable") {
  throw new Error("Vercel assets must use immutable cache headers");
}

const port = 4197;
const server = spawn(process.execPath, ["server.mjs"], {
  cwd: root,
  env: { ...process.env, PORT: String(port) },
  stdio: ["ignore", "pipe", "pipe"],
});

function sliceHero(html) {
  const start = html.indexOf('<section class="hero"');
  const end = html.indexOf("</section>", start);
  if (start < 0 || end < 0) throw new Error("Hero section not found");
  return html.slice(start, end);
}

function sliceSection(html, selectorStart, selectorEnd) {
  const start = html.indexOf(selectorStart);
  const end = html.indexOf(selectorEnd, start);
  if (start < 0 || end < 0) throw new Error(`${selectorStart} section not found`);
  return html.slice(start, end);
}

function anchorTexts(html) {
  return [...html.matchAll(/<a\b[^>]*>([\s\S]*?)<\/a>/g)].map((match) => match[1].replace(/<[^>]+>/g, "").trim());
}

function footerHeadings(html) {
  const footer = sliceSection(html, '<footer class="site-footer">', "</footer>");
  return [...footer.matchAll(/<h3>(.*?)<\/h3>/g)].map((match) => match[1].trim());
}

function footerHrefs(html) {
  const footer = sliceSection(html, '<footer class="site-footer">', "</footer>");
  return [...footer.matchAll(/<a\b[^>]*href="([^"]+)"/g)].map((match) => match[1]);
}

function assertSameList(actual, expected, label) {
  const sameLength = actual.length === expected.length;
  const sameValues = actual.every((value, index) => value === expected[index]);
  if (!sameLength || !sameValues) throw new Error(`${label}: expected ${expected.join(", ")}, got ${actual.join(", ")}`);
}

try {
  await new Promise((resolveReady, rejectReady) => {
    const timer = setTimeout(() => rejectReady(new Error("Server did not start")), 3000);
    server.once("exit", (code) => {
      clearTimeout(timer);
      rejectReady(new Error(`Server exited before smoke checks: ${code}`));
    });
    server.stdout.on("data", (chunk) => {
      const output = String(chunk);
      if (output.includes(`http://127.0.0.1:${port}`)) {
        clearTimeout(timer);
        resolveReady();
      }
    });
    server.stderr.on("data", (chunk) => {
      clearTimeout(timer);
      rejectReady(new Error(String(chunk)));
    });
  });

  const okPaths = ["/", "/zh/", "/styles.css", "/script.js", "/assets/agent-island-hero-demo.mp4"];
  for (const path of okPaths) {
    const response = await fetch(`http://127.0.0.1:${port}${path}`);
    if (response.status !== 200) throw new Error(`${path} must return 200, got ${response.status}`);
  }

  const english = await (await fetch(`http://127.0.0.1:${port}/`)).text();
  const chinese = await (await fetch(`http://127.0.0.1:${port}/zh/`)).text();
  const englishHero = sliceHero(english);
  const chineseHero = sliceHero(chinese);

  if (english.includes("v1.1.0") || english.includes("1.1.0") || chinese.includes("v1.1.0") || chinese.includes("1.1.0")) {
    throw new Error("Website must not contain v1.1.0 or 1.1.0 version references");
  }
  if (!english.includes("v1.2.0") || !chinese.includes("v1.2.0")) {
    throw new Error("Website must expose v1.2.0 version references");
  }
  if (englishHero.includes("AgentIsland-1.2.0.dmg") || chineseHero.includes("AgentIsland-1.2.0.dmg")) {
    throw new Error("Hero must not link directly to the DMG");
  }

  const englishActions = anchorTexts(englishHero);
  const chineseActions = anchorTexts(chineseHero);
  if (englishActions[0] !== "View on GitHub") throw new Error(`English first hero action is ${englishActions[0]}`);
  if (chineseActions[0] !== "在 GitHub 上查看") throw new Error(`Chinese first hero action is ${chineseActions[0]}`);
  if (!englishHero.includes("source build") || !chineseHero.includes("源码构建")) {
    throw new Error("Hero must expose the source build path");
  }
  if (!englishHero.includes("agent-island-hero-demo.mp4") || !chineseHero.includes("../assets/agent-island-hero-demo.mp4")) {
    throw new Error("Hero video source missing");
  }
  if (!chinese.includes('lang="zh-CN"') || !chinese.includes("给 Claude Code 和 Codex 长任务用的 AI 守夜人。")) {
    throw new Error("Chinese route must ship static Chinese content");
  }
  if (chinese.includes("Your AI night-watch. Calls you back.")) {
    throw new Error("Chinese route must not ship English fallback hero copy");
  }

  if (english.indexOf('id="faq"') >= english.indexOf("</main>") || english.indexOf('id="faq"') <= english.indexOf('id="trust"')) {
    throw new Error("English FAQ must appear after Trust and before the footer");
  }
  if (chinese.indexOf('id="faq"') >= chinese.indexOf("</main>") || chinese.indexOf('id="faq"') <= chinese.indexOf('id="trust"')) {
    throw new Error("Chinese FAQ must appear after Trust and before the footer");
  }

  assertSameList(footerHeadings(english), ["Learn", "Project", "Trust", "Community", "Meta"], "English footer headings");
  assertSameList(footerHeadings(chinese), ["学习", "项目", "信任", "社区", "元信息"], "Chinese footer headings");
  if (footerHeadings(english).includes("Product") || footerHeadings(english).includes("Get Started")) {
    throw new Error("English footer must not include Product or Get Started columns");
  }

  const requiredFooterHrefs = [
    "#faq",
    "#how",
    "#trust",
    "https://github.com/tristan666666/agent-island",
    "https://github.com/tristan666666/agent-island/tree/v1.2.0",
    "https://github.com/tristan666666/agent-island/blob/main/LICENSE",
    "https://github.com/tristan666666/agent-island/blob/main/CONTRIBUTING.md",
    "https://github.com/tristan666666/agent-island/blob/main/SECURITY.md",
    "https://github.com/tristan666666/agent-island/blob/main/docs/SPARKLE.md",
    "https://github.com/tristan666666/agent-island/blob/main/docs/how-agent-island-detects-session-state.md",
    "https://github.com/tristan666666/agent-island/issues",
    "https://github.com/jaywcjlove/awesome-mac/blob/master/README.md#menu-bar-tools",
    "https://github.com/jaywcjlove/awesome-swift-macos-apps",
  ];
  for (const html of [english, chinese]) {
    const hrefs = footerHrefs(html);
    for (const href of requiredFooterHrefs) {
      if (!hrefs.includes(href)) throw new Error(`Footer missing link: ${href}`);
    }
    if (hrefs.some((href) => href.includes("/releases/latest"))) throw new Error("Footer must not use stale releases/latest redirect");
    if (hrefs.some((href) => href.includes("/releases/tag/"))) throw new Error("Footer must not present a Git tag page as a GitHub Release");
    if (hrefs.some((href) => href.includes("producthunt.com"))) throw new Error("Footer must not link to Product Hunt");
  }

  const protectedPaths = [
    "/.gitignore",
    "/%2egitignore",
    "/.env.local",
    "/%2eenv.local",
    "/.vercel/project.json",
    "/%2evercel%2fproject.json",
    "/server.mjs",
    "/server%2emjs",
    "/package.json",
    "/package%2ejson",
    "/vercel.json",
    "/vercel%2ejson",
    "/tests/smoke.mjs",
    "/tests%2fsmoke.mjs",
    "/assets/../server.mjs",
  ];

  for (const path of protectedPaths) {
    const response = await fetch(`http://127.0.0.1:${port}${path}`);
    if (response.status !== 404) throw new Error(`${path} must return 404, got ${response.status}`);
  }

  const missing = await fetch(`http://127.0.0.1:${port}/not-a-real-page`);
  if (missing.status !== 404) throw new Error("Missing pages must return 404");

  const malformed = await fetch(`http://127.0.0.1:${port}/%E0%A4%A`);
  if (malformed.status !== 404) throw new Error("Malformed URLs must return 404");
} finally {
  server.kill();
}

console.log("smoke: ok");
