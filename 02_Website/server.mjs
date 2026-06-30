import { createReadStream, existsSync, statSync } from "node:fs";
import { extname, join, normalize, resolve, sep } from "node:path";
import { createServer } from "node:http";

const root = resolve(import.meta.dirname);
const port = Number(process.env.PORT || 4173);
const host = "127.0.0.1";

const routeFiles = new Map([
  ["/", "index.html"],
  ["/index.html", "index.html"],
  ["/zh", "zh/index.html"],
  ["/zh/", "zh/index.html"],
  ["/zh/index.html", "zh/index.html"],
  ["/styles.css", "styles.css"],
  ["/script.js", "script.js"],
]);

const assetExtensions = new Set([".png", ".webp", ".mp4"]);

const types = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mp4": "video/mp4",
  ".png": "image/png",
  ".webp": "image/webp",
};

function insideRoot(filePath) {
  return filePath === root || filePath.startsWith(`${root}${sep}`);
}

function hasUnsafeSegment(pathname) {
  return pathname.split("/").some((segment) => segment === ".." || segment.startsWith("."));
}

function resolvePath(urlPath) {
  let pathname;
  try {
    pathname = decodeURIComponent(urlPath.split("?")[0]);
  } catch {
    return null;
  }

  if (!pathname.startsWith("/") || pathname.includes("\0") || hasUnsafeSegment(pathname)) {
    return null;
  }

  const routeFile = routeFiles.get(pathname);
  if (routeFile) return join(root, routeFile);

  if (!pathname.startsWith("/assets/")) return null;

  const normalizedAsset = normalize(pathname.slice(1));
  if (!normalizedAsset.startsWith(`assets${sep}`) && !normalizedAsset.startsWith("assets/")) {
    return null;
  }

  if (!assetExtensions.has(extname(normalizedAsset).toLowerCase())) return null;

  const candidate = join(root, normalizedAsset);
  if (!insideRoot(candidate)) return null;
  return candidate;
}

createServer((request, response) => {
  const filePath = resolvePath(request.url || "/");

  if (!filePath || !insideRoot(filePath) || !existsSync(filePath) || !statSync(filePath).isFile()) {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("Not found");
    return;
  }

  const extension = extname(filePath).toLowerCase();
  response.writeHead(200, {
    "content-type": types[extension] || "application/octet-stream",
    "cache-control": extension === ".html" ? "no-cache" : "public, max-age=31536000, immutable",
  });
  createReadStream(filePath).pipe(response);
}).listen(port, host, () => {
  console.log(`Agent Island website listening on http://${host}:${port}`);
});
