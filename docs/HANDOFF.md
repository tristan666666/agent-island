# Agent Island · Handoff

State of the project as of v1.0.0 — what shipped, where things live, what the knobs are. Read this first if you (or another agent) are picking it up cold.

## Shipped

- Repo: **https://github.com/tristan666666/agent-island** (public, MIT, fork of [codex-island](https://github.com/ericjypark/codex-island))
- Release: **v1.0.0** — https://github.com/tristan666666/agent-island/releases/tag/v1.0.0
- App bundle id: `dev.agentisland.AgentIsland` · binary at `/Applications/AgentIsland.app`
- Sparkle auto-update: **disabled** in this build (`SU_FEED_URL` empty in `build.sh`)

## Two core features (the differentiator)

1. **Auto-resume after the 5h reset.** When the provider's 5-hour usage window rolls over, fire `claude --resume <id> -p "<msg>" --dangerously-skip-permissions` or `codex exec resume <id> "<msg>" --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check`. Driven by `UsageStore.fiveHour.resetAt` changing.
2. **Live session state on the provider logos** (working → breathe; turn finished → spin Claude ↻ / Codex ↺; stalled → red + beep). The stall also bleeds through to the silhouette halo so it's visible at `.compact`.

Plus: 4th island page (Auto-Trigger) · 5th Settings tab (Status guide w/ live legend + stall sound toggle) · cross-tool session picker reading real thread titles (Claude's desktop store) / one entry per Codex project / archived filtered out.

## Code map

```
Sources/Trigger/
  Trigger.swift            — model + CLI locator (hardcoded paths because GUI apps get a stripped PATH)
  SessionScanner.swift     — Claude: ~/Library/Application Support/Claude/claude-code-sessions/local_*.json
                              (title, cliSessionId, isArchived). Codex: ~/.codex/sessions/Y/M/D/*.jsonl (session_meta).
  TriggerStore.swift       — UserDefaults: "AgentIsland.triggers" (JSON array of Trigger; default empty)
  TriggerEngine.swift      — subscribes to UsageStore. afterReset fires ONCE per genuine 5h rollover:
                              resetAt must advance past a boundary that has actually elapsed (previous <= now),
                              so a resetAt merely sliding forward (demo recomputes it every refresh) is ignored.
                              Baseline persisted ("AgentIsland.triggerResetBaselines") so a reset missed while
                              closed/asleep is caught up once on relaunch. Never spawns outside normal mode.
                              + every-N-hours timer. Run logs: ~/Library/Application Support/AgentIsland/trigger-runs/
  ActivityMonitor.swift    — IO off the main actor. tick() every 6s, classifies on a Task.detached, hops back to
                              assign published state. Demo override: ActivityMonitor.shared.demo(.stalled).
Sources/Model/
  StallSoundStore.swift    — UserDefaults key "AgentIsland.stallSound"; default ON. Read by ActivityMonitor.beep().
  ScreenPref.swift         — adds .triggers as the 4th carousel page.
  AppEnvironment.swift     — reads AGENTISLAND_DEMO / AGENTISLAND_DEBUG (CODEXISLAND_* still accepted as fallback).
Sources/Views/
  TriggerPageView.swift          — the 4th island page (reset countdowns + triggers list + Manage button)
  StatePreviewLogo.swift         — animated demo logo for Settings legend (state is fixed at the call site)
  IslandRootView.swift           — LogoOverlay drives the breathe/spin/red animations. Silhouette halo turns red
                                    + pulses when ActivityMonitor reports stalled (visible at .compact too).
  Settings/TriggerSettingsView.swift  — 4th Settings tab
  Settings/StatusGuideView.swift      — 5th Settings tab. Demo buttons appear under AGENTISLAND_DEMO=1.
App.swift                — starts UsageStore, CostStore, AlertEngine, TriggerEngine, ActivityMonitor.
Sources/Views/SettingsView.swift   — registers .triggers + .statusGuide tabs.
```

Localized strings: `Resources/{en,zh-Hans}.lproj/Localizable.strings` — append, don't overwrite the existing keys.

## Build / install / run

```sh
./build.sh                                # universal binary → build/AgentIsland.app
open build/AgentIsland.app                # or
AGENTISLAND_DEMO=1 ./build/AgentIsland.app/Contents/MacOS/AgentIsland   # demo mode
```

Demo mode does two things:
- `UsageStore` injects healthy-looking 73% / 67% / nice reset countdowns (good for screenshots).
- Settings → Status guide gets four buttons: **Working / Your turn / Stalled / Live** to force the notch into any state on cue.

Typecheck only (fast): `swiftc -typecheck -target arm64-apple-macos13.0 -parse-as-library -F Vendor/Sparkle -framework SwiftUI -framework AppKit -framework ServiceManagement -framework Sparkle $(find Sources -name '*.swift')`

## Tunable thresholds (where to change them)

| What | Where | Default |
|---|---|---|
| Stall detection delay | `Sources/Trigger/ActivityMonitor.swift` — `Scan.stallAfter` | 300s |
| "Still working" window | `Scan.activeWindow` | 18s |
| Beyond this = idle, not stalled | `Scan.stallCap` | 15 min |
| "Your turn" stays fresh | `Scan.needsYouCap` | 20 min |
| Only watch sessions touched within | `Scan.attentionWindow` | 30 min |
| Tail bytes / lines | `Scan.tailLines(bytes:keep:)` | 128 KB / 200 |
| Activity poll interval | `ActivityMonitor.start()` Timer | 6s |
| Trigger interval-mode interval | `Trigger.everyHours` (per-trigger, UI) | 5h |
| Beep throttle | `ActivityMonitor.beep()` | 30s min between alarms |

## Public assets

- `poster.png` — Release page header
- `agent-island-usage.png` / `agent-island-auto-trigger.png` — real-notch screenshots

## What's NOT done / open

- **Launch distribution started.** X posts/replies, OpenAI Community posts/replies, Reddit megathread comment, and targeted GitHub issue comments have been sent. HN / PH have not been posted.
- **Triggers persist under `"AgentIsland.triggers"`**; the per-tool reset baselines under `"AgentIsland.triggerResetBaselines"`. (The old `"CodexIsland.triggers"` key was retired during the rebrand — pre-rename triggers do not migrate.)
- **Demo screenshots** are user-local unless listed in `Assets/`.
- **No tests.** The whole project compiles with `swiftc` over `Sources/**/*.swift`; no XCTest target. If adding tests, factor `Scan` and the turn-done helpers further — they're already pure functions.
- **Code-review punch list** (from the v1.0.0 review pass): all high/medium items fixed. Low items still open:
  - `tailLines` UTF-8 boundary truncation (cosmetic, first partial line is dropped anyway).
  - `Process` standardOutput FileHandle in `TriggerEngine.fire()` closes when the spawned process retains it; trailing log bytes may truncate. Cosmetic.

## Credits

Fork of [codex-island](https://github.com/ericjypark/codex-island) by Eric Park (MIT). Usage-island + cost-tracking foundation is his.
