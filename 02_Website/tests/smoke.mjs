import { existsSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";

const root = resolve(import.meta.dirname, "..");

const requiredFiles = [
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

const english = readFileSync(join(root, "index.html"), "utf8");
const chinese = readFileSync(join(root, "zh/index.html"), "utf8");
const script = readFileSync(join(root, "script.js"), "utf8");
const vercel = readFileSync(join(root, "vercel.json"), "utf8");

const requiredEnglish = [
  "Your AI night-watch. Calls you back.",
  "View source",
  "Get Started",
  "agent-island-hero-demo.mp4",
  "agent-island-hero-poster.png",
  "v1.1.0",
  ">8<",
  ">3<",
  "MIT",
  "awesome-mac",
];

for (const needle of requiredEnglish) {
  if (!english.includes(needle)) throw new Error(`English page missing: ${needle}`);
}

const requiredChinese = [
  'lang="zh-CN"',
  'data-lang="zh"',
  "../assets/agent-island-hero-demo.mp4",
  "../assets/agent-island-hero-poster.png",
  "你的 macOS AI 守夜人",
];

for (const needle of requiredChinese) {
  if (!chinese.includes(needle)) throw new Error(`Chinese route missing: ${needle}`);
}

const requiredScript = [
  "你的 AI 守夜人。负责叫你回来。",
  "setStoryState",
  "navigator.clipboard.writeText",
];

for (const needle of requiredScript) {
  if (!script.includes(needle)) throw new Error(`Script missing behavior: ${needle}`);
}

const vercelConfig = JSON.parse(vercel);
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

try {
  await new Promise((resolveReady, rejectReady) => {
    const timer = setTimeout(() => rejectReady(new Error("Server did not start")), 3000);
    server.once("exit", (code) => {
      clearTimeout(timer);
      rejectReady(new Error(`Server exited before smoke checks: ${code}`));
    });
    server.stdout.on("data", (chunk) => {
      if (String(chunk).includes("listening")) {
        clearTimeout(timer);
        resolveReady();
      }
    });
    server.stderr.on("data", (chunk) => {
      clearTimeout(timer);
      rejectReady(new Error(String(chunk)));
    });
  });

  const missing = await fetch(`http://127.0.0.1:${port}/not-a-real-page`);
  if (missing.status !== 404) throw new Error("Missing pages must return 404");

  const malformed = await fetch(`http://127.0.0.1:${port}/%E0%A4%A`);
  if (malformed.status !== 404) throw new Error("Malformed URLs must return 404");
} finally {
  server.kill();
}

console.log("smoke: ok");
