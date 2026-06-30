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

function anchorTexts(html) {
  return [...html.matchAll(/<a\b[^>]*>([\s\S]*?)<\/a>/g)].map((match) => match[1].replace(/<[^>]+>/g, "").trim());
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

  if (englishHero.includes("AgentIsland-1.1.0.dmg") || chineseHero.includes("AgentIsland-1.1.0.dmg")) {
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
