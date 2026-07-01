# Agent Island · Handoff

State of the project as of v1.2.4 — what shipped, where things live, what the knobs are. Read this first if you (or another agent) are picking it up cold.

## Shipped

- Repo: **https://github.com/tristan666666/agent-island** (public, MIT, fork of [codex-island](https://github.com/ericjypark/codex-island))
- Current release: **v1.2.4** — https://github.com/tristan666666/agent-island/releases/tag/v1.2.4
- App bundle id: `dev.agentisland.AgentIsland` · binary at `/Applications/AgentIsland.app`
- Sparkle auto-update: **enabled** by default through the GitHub release appcast in `build.sh`.

## Two core features (the differentiator)

1. **Auto-resume after the 5h reset.** When the provider's 5-hour usage window rolls over, fire `claude --resume <id> -p "<msg>" --dangerously-skip-permissions` or `codex exec resume <id> "<msg>" --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check`. Driven by `UsageStore.fiveHour.resetAt` changing.
2. **Live session state on the provider logos and alarm window** (working → rotate; turn finished → foreground alarm window; stalled/auth/rate/provider errors → red pulse). The red attention state also bleeds through to the silhouette halo so it's visible at `.compact`.

Plus: 4th island page (Auto-Trigger) · 5th Settings tab (Status guide w/ live legend + alarm sound controls) · cross-tool session picker reading real thread titles (Claude's desktop store) / one entry per Codex project / archived filtered out.

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
  AgentReminderStore.swift — UserDefaults-backed turn alarm, built-in sound preset, custom sound file, volume.
  ScreenPref.swift         — adds .triggers as the 4th carousel page.
  AppEnvironment.swift     — reads AGENTISLAND_DEMO / AGENTISLAND_DEBUG (CODEXISLAND_* still accepted as fallback).
  TurnAlarmWindowController.swift — owns the foreground NSPanel lifecycle only.
  TurnAlarmNavigator.swift — opens Codex/Claude from alarm actions.
  TurnAlarmSoundLooper.swift — repeats the selected alarm sound until dismissed or paused.
Sources/Views/
  TurnAlarmView.swift             — foreground "your turn" alarm UI.
  TriggerPageView.swift          — the 4th island page (reset countdowns + triggers list + Manage button)
  StatePreviewLogo.swift         — animated demo logo for Settings legend (state is fixed at the call site)
  IslandRootView.swift           — LogoOverlay drives working rotation and blocked-state red pulse. Silhouette halo
                                    turns red + pulses when ActivityMonitor reports attention states.
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
- Settings → Status guide gets buttons such as **Working / Your turn / Auth / Rate / Live** to force the notch into states on cue.

Typecheck only (fast): `swiftc -typecheck -target arm64-apple-macos13.0 -parse-as-library -F Vendor/Sparkle -framework SwiftUI -framework AppKit -framework ServiceManagement -framework Sparkle $(find Sources -name '*.swift')`

## Tunable thresholds (where to change them)

| What | Where | Default |
|---|---|---|
| Stall detection delay | `Sources/Trigger/SessionScanner.swift` — `stallAfter` | 300s |
| "Still working" window | `SessionScanner.activeWindow` | 18s |
| Beyond this = idle, not stalled | `SessionScanner.stallCap` | 15 min |
| "Your turn" stays fresh | `SessionScanner.needsYouCap` | 20 min |
| Only watch sessions touched within | `SessionScanner.attentionWindow` | 30 min |
| Tail bytes / lines | `SessionScanner.tailLines(bytes:keep:)` | 128 KB / 200 |
| Activity poll interval | `ActivityMonitor.start()` Timer | 6s |
| Trigger interval-mode interval | `Trigger.everyHours` (per-trigger, UI) | 5h |
| Turn alarm repeat | `Sources/Model/TurnAlarmSoundLooper.swift` | 1.8s until dismissed |

## Public assets

- `poster.png` — Release page header
- `social-preview.png` — GitHub repository social preview source image
- `agent-island-usage.png` / `agent-island-auto-trigger.png` — real-notch screenshots

## What's NOT done / open

- **Launch distribution started.** X posts/replies, OpenAI Community posts/replies, Reddit megathread comment, and targeted GitHub issue comments have been sent. HN / PH have not been posted.
- **Triggers persist under `"AgentIsland.triggers"`**; the per-tool reset baselines under `"AgentIsland.triggerResetBaselines"`. (The old `"CodexIsland.triggers"` key was retired during the rebrand — pre-rename triggers do not migrate.)
- **Demo screenshots** are user-local unless listed in `Assets/`.
- **Tests are still lightweight.** The app compiles with `swiftc` over `Sources/**/*.swift`; focused script-level regression tests cover extracted pure helpers when a behavior needs protection.
- **Code-review punch list**: all high/medium release blockers from the v1.2 review pass must stay fixed before tagging. Low items still open:
  - `tailLines` UTF-8 boundary truncation (cosmetic, first partial line is dropped anyway).
  - `Process` standardOutput FileHandle in `TriggerEngine.fire()` closes when the spawned process retains it; trailing log bytes may truncate. Cosmetic.

## Credits

Fork of [codex-island](https://github.com/ericjypark/codex-island) by Eric Park (MIT). Usage-island + cost-tracking foundation is his.
