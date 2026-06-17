<div align="center">

# Agent Island

**Your AI night-watch — keeps your Claude & Codex agents running.**

[简体中文](README.zh-CN.md)

![Agent Island](Assets/launch.gif)

</div>

Agent Island lives in your MacBook notch. It isn't just a usage meter — it **watches your Claude Code and Codex sessions and acts on them**: resumes them when you hit the 5-hour limit, tells you the moment a turn finishes, and alarms when one stalls.

## Why

Heavy Claude / Codex use has three quiet time-sinks:

- You hit the **5-hour limit** mid-task and it dies until you come back.
- A session **stalls** (stuck tool, waiting on input, dead network) and sits idle for half an hour.
- A session **finishes** while you're away and you never notice it's your turn.

Agent Island handles all three, from the notch.

## Features

### 🌙 Auto-resume after reset — the night-watch

When your 5-hour window resets, Agent Island auto-sends a message (`继续`, `OK`, whatever you set) to a chosen Claude or Codex session so the task keeps going — no babysitting. Set it up in **Settings → 自动触发**, or run on a fixed every-N-hours schedule. It fires at the *real* reset instant, read from each provider's usage API.

### ⚡ Live session state, on your logos

The provider logos react to what your agents are actually doing:

| State | How it's detected | The cue |
|---|---|---|
| **Working** | transcript still growing | logo breathes + soft glow |
| **Your turn** | turn finished + stopped | logo **spins** — Claude clockwise ↻, Codex counter-clockwise ↺ — and brightens |
| **Stalled** | frozen mid-turn too long | **red** alarm pulse + three beeps |

### 📊 Usage island

Live Claude & Codex 5-hour / weekly usage, cost, and reset countdowns — swipeable pages in the notch.

## What's different from Codex Island

Codex Island is a **passive meter** — it shows your usage. Agent Island is **active** — it watches your sessions and acts on them. Everything below the first row is new here:

| | Codex Island | Agent Island |
|---|:---:|:---:|
| Usage / cost / reset in the notch | ✅ | ✅ *(inherited)* |
| **Auto-resume** a session after the 5h limit resets | — | ✅ Claude & Codex |
| **Logo reacts to session state** — breathe (working), spin (your turn), red + beep (stalled) | — | ✅ |
| **Auto-Trigger** page inside the island | — | ✅ |
| **Status-guide** settings tab (live legend + sound toggle) | — | ✅ |
| Cross-tool session picker with real thread titles, archived filtered out | — | ✅ |

In short: Codex Island tells you *how much you've used*; Agent Island makes sure *your agents keep running* — the night-watch.

## Install

```sh
git clone https://github.com/tristan666666/agent-island.git
cd agent-island
./build.sh
open build/AgentIsland.app
```

macOS 13+. Universal binary (Apple Silicon + Intel). Auto-update is off in this build.

## How it works

- **Reset times** come from each provider's real usage API.
- **Session state** is read from the transcript files: mtime (is it still producing output?) plus the turn-complete markers — Claude's `stop_reason: end_turn`, Codex's `task_complete` event.
- **Resume** runs `claude --resume … -p "<msg>" --dangerously-skip-permissions` or `codex exec resume … "<msg>" --dangerously-bypass-approvals-and-sandbox`. Run logs land in `~/Library/Application Support/AgentIsland/trigger-runs/`.
- The Mac must be awake for a trigger to fire, and each fire spends tokens.
- ⚠️ A trigger resumes the agent **unattended with permission checks off** (the `--dangerously-*` flags above). Only attach triggers to sessions you trust. Everything runs locally as you; nothing is sent anywhere.

## Credits & license

Agent Island is a fork of **[codex-island](https://github.com/ericjypark/codex-island)** by **Eric Park** — the usage-island and cost-tracking foundation are his work. Agent Island adds the auto-trigger watchman and the live session-state animations, and rebrands the project.

MIT licensed — © 2026 Eric Park. This fork retains that notice. See [LICENSE](LICENSE).
