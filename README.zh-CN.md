<div align="center">

# Agent Island

**你的 AI 守夜人 —— 自动续跑长任务，也能在刘海里看状态。**

[English](README.md)

[![已收录 awesome-mac](https://img.shields.io/badge/%E5%B7%B2%E6%94%B6%E5%BD%95-awesome--mac-0969da?style=for-the-badge)](https://github.com/jaywcjlove/awesome-mac/blob/master/README-zh.md#%E8%8F%9C%E5%8D%95%E6%A0%8F%E5%B7%A5%E5%85%B7)
[![已收录 awesome-swift-macos-apps](https://img.shields.io/badge/%E5%B7%B2%E6%94%B6%E5%BD%95-awesome--swift--macOS-f97316?style=for-the-badge)](https://github.com/jaywcjlove/awesome-swift-macos-apps/blob/main/README.md#ai)
[![已收录 awesome-codex-cli](https://img.shields.io/badge/%E5%B7%B2%E6%94%B6%E5%BD%95-awesome--codex--cli-10b981?style=for-the-badge)](https://github.com/milisp/awesome-codex-cli)
[![已收录 awesome-coding-agents](https://img.shields.io/badge/%E5%B7%B2%E6%94%B6%E5%BD%95-awesome--coding--agents-7c3aed?style=for-the-badge)](https://github.com/kailiu42/awesome-coding-agents)
[![已收录 awesome-claude-code-and-skills](https://img.shields.io/badge/%E5%B7%B2%E6%94%B6%E5%BD%95-awesome--claude--code--and--skills-8b5cf6?style=for-the-badge)](https://github.com/GetBindu/awesome-claude-code-and-skills)
[![已收录 awesome-vibe-coding-resources](https://img.shields.io/badge/%E5%B7%B2%E6%94%B6%E5%BD%95-awesome--vibe--coding--resources-ec4899?style=for-the-badge)](https://github.com/acvnace/awesome-vibe-coding-resources#desktop-apps)

<a href="https://www.producthunt.com/products/agent-island-2?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-agent-island-2">
  <img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1175477&theme=light" alt="Agent Island - AI night-watch for Claude Code and Codex runs | Product Hunt" width="250" height="54">
</a>

<video src="https://github.com/user-attachments/assets/d69b41e0-9298-4f17-b6c9-6014f3bd956b" controls width="900"></video>

<p>
  <a href="#快速开始"><strong>快速开始</strong></a> ·
  <a href="https://github.com/tristan666666/agent-island/releases/tag/v1.0.0">最新 release</a> ·
  <a href="CONTRIBUTING.md">参与贡献</a>
</p>

<p><strong>如果 Agent Island 让你少守一次半夜卡住的 agent，给它一个 Star，让更多 Claude/Codex 用户找到它。</strong></p>

<img src="Assets/agent-island-auto-trigger.png" alt="Agent Island 自动续跑会话视图" width="900">
<img src="Assets/agent-island-usage.png" alt="Agent Island 用量规划视图" width="900">

</div>

Agent Island 住在你 MacBook 的刘海里。它是给 Claude Code 和 Codex 长任务用的小工具：

- 在任务能继续时，**自动续跑指定会话**。
- 把每个会话的**实时状态**直接显示在对应 logo 上。

用量和重置倒计时只是帮你规划任务；核心更简单：让长任务别无声停住，也让你不用打开每个终端才能知道状态。

## 为什么做它

重度用 Claude / Codex 有两个很实际的坑：

- 长任务暂停后，还得你回来手动发一句「继续」。
- 你没法一眼看出某个会话还在跑、该你接手了，还是已经卡住。

这两件，Agent Island 在刘海里处理。用量和重置倒计时只是帮助你更精准地安排任务，不是拿来刷重置次数。

## 功能

### 🌙 长任务自动续跑 —— 守夜人

Agent Island 可以自动给你选定的 Claude 或 Codex 会话发一句话（`继续`、`OK`，随你设），让任务接着跑，不用你守着。你可以按各家用量 API 给的**真实重置时刻**触发，也可以在 **设置 → 自动触发** 里配置"每 N 小时"固定间隔。

### ⚡ Logo 上的实时状态

两家的 logo 会跟着 agent 的真实状态动起来：

| 状态 | 怎么判 | 表现 |
|---|---|---|
| **正在跑** | 记录文件还在增长 | logo 缓慢呼吸 + 微光 |
| **该你了** | 一轮跑完、停了 | logo **转圈** —— Claude 顺时针 ↻、Codex 逆时针 ↺ —— 并变亮 |
| **卡住了** | 卡在半路太久没动 | **红色**告警脉冲 + 哔哔哔三声 |

### 📊 用量岛

Claude / Codex 的 5 小时、周用量、成本、重置倒计时 —— 刘海里左右滑动的几页。

## 跟 Codex Island 有什么不一样

Codex Island 是个**被动电表** —— 给你看用量。Agent Island 是**主动的** —— 它盯着你的会话、替你动手。下表第一行以下都是新加的:

| | Codex Island | Agent Island |
|---|:---:|:---:|
| 刘海里看用量 / 成本 / 重置 | ✅ | ✅ *(继承)* |
| **长任务自动续跑**(给指定会话自动发继续) | — | ✅ Claude & Codex |
| **Logo 跟着会话状态动** —— 呼吸(运行)、转圈(该你了)、变红+哔(卡住) | — | ✅ |
| 岛里的 **自动触发** 页 | — | ✅ |
| **状态说明** 设置页(实时图例 + 声音开关) | — | ✅ |
| 跨工具线程选择,显示真实标题、自动过滤已归档 | — | ✅ |

一句话:Codex Island 告诉你**用了多少**;Agent Island 帮你把长任务接上，也把会话状态摆在刘海里 —— 守夜人。

## 快速开始

下载最新 DMG，把 AgentIsland 拖进 Applications，然后打开：

[**下载 AgentIsland-1.0.0.dmg**](https://github.com/tristan666666/agent-island/releases/download/v1.0.0/AgentIsland-1.0.0.dmg)

macOS 13+，通用二进制（Apple 芯片 + Intel）。

如果 macOS 第一次启动时提示应用未公证，请在 Finder 里右键 AgentIsland，选择一次 **打开**。

源码构建：

```sh
git clone https://github.com/tristan666666/agent-island.git
cd agent-island
./scripts/verify.sh
open build/AgentIsland.app
```

## 原理

- **重置时间**来自各家真实用量 API。
- **会话状态**从记录文件读：文件 mtime（还在产出吗）+ 轮次完成标记 —— Claude 的 `stop_reason: end_turn`、Codex 的 `task_complete` 事件。
- **续跑**执行 `claude --resume … -p "<消息>"` 或 `codex exec resume … "<消息>"`，运行日志在 `~/Library/Application Support/AgentIsland/trigger-runs/`。
- 触发需要 Mac 醒着；每次触发都会消耗 token。
- ⚠️ 续跑会**无人值守、关掉权限确认**地恢复 agent(上面那些 `--dangerously-*` 参数)。只给你信任的会话挂触发器。全程在本机以你的身份运行,不外传任何东西。

更完整的实现拆解（英文）：[How Agent Island detects Claude Code and Codex session state](docs/how-agent-island-detects-session-state.md)。

## 致谢与许可

Agent Island fork 自 **[codex-island](https://github.com/ericjypark/codex-island)**（作者 **Eric Park**）—— 用量岛与成本统计的底子是他的。Agent Island 在此之上加了"守夜人"自动触发与实时状态动效，并重塑了品牌。

MIT 许可 —— © 2026 Eric Park，本 fork 保留该声明。见 [LICENSE](LICENSE)。
