# Agent Island · Launch 视频拍摄 + 剪辑指南

35 秒,轻松调,Screen Studio 出片。照着做 1 小时完工。

---

## 0 · 准备(5 分钟)

- 深色干净壁纸,隐藏桌面图标
- 底下开一个代码编辑器/终端窗口当背景,暗示"agent 在干活"
- 用演示模式启动 App:`AGENTISLAND_DEMO=1 /Applications/AgentIsland.app/Contents/MacOS/AgentIsland`
  (用量数字、倒计时自动是好看的演示数据)
- 设置 → 状态说明 → 最下面有 **Demo** 按钮:Working / Your turn / Stalled / Live
- Screen Studio:录主显示器,**勾上 System Audio**(要录到"哔"声)
- Suno 出 35s 背景音乐(提示词见末尾)

---

## 1 · 录素材(20 分钟)

**分 4 段单独录,每段 6 秒留剪辑余量。**

| 段 | 操作 | 内容 |
|---|---|---|
| ① 运行 | Demo → Working,hover 刘海展开 | logo 缓慢呼吸 + 用量面板 |
| ② 该你了 | Demo → Your turn | logo 转圈(Claude 顺时针 / Codex 逆时针) |
| ③ 卡住 | Demo → Stalled | logo 变红 + 哔声(**重点录音**) |
| ④ 续跑 | 切到 自动触发 页 | 触发器列表 + "窗口重置后" |

录完拖进 Screen Studio。

---

## 2 · 时间线(精确到秒)

| 秒 | 段 | 画面 | 镜头(变焦) | 屏幕文字 | 音乐 / 声音 |
|---|---|---|---|---|---|
| 0.0–3.0 | 片头 | 桌面 + 平静刘海 | 1.0× 全景 | 让你的 AI 自己跑 🌙 | Suno 起,鼓点低 |
| 3.0–4.0 | 过渡 | 推向刘海 | 1.0× → 2.5× | 文字渐出 | 鼓点轻起 |
| 4.0–9.0 | ① 运行 | logo 呼吸 | 2.5× 怼住刘海 | 它,帮你盯着 | 节奏平稳 |
| 9.0–10.0 | 过渡 | 同上 | 2.5× | — | — |
| 10.0–15.0 | ② 该你了 | logo 转圈 | 2.8× 稍推 | 跑完了?它转个圈 —— 该你了 🌀 | 一个小亮点(铃 / 拨弦) |
| 15.0–16.5 | 过渡 | 拉远 | 2.5× → 1.5× | — | 音乐压暗一拍 |
| 16.5–22.0 | ③ 卡住 | logo 变红+哔 | 怼回 3.0× | 卡住了?它变红 + 哔你一下 🔴 | **"哔"对齐 16.7s 的重拍** |
| 22.0–23.5 | 过渡 | Demo → Live | 3.0× → 1.5× | — | 音乐释放 |
| 23.5–29.0 | ④ 续跑 | 自动触发页 | 1.5× 全展开 | 额度用完?它自己接着跑 ✨ | 节奏上扬 |
| 29.0–32.5 | 片尾 | 桌面全景 | 1.5× → 1.0× | **Agent Island** 居中 | 鼓点收 |
| 32.5–35.0 | 链接 | 同上 | 1.0× | github.com/tristan666666/agent-island | 收尾音 |

---

## 3 · Screen Studio 操作 cheatsheet

- **变焦** = 右键时间线 → Add Zoom → 拖关键帧
- **背景** = Layout → Wallpaper 暗色渐变,Padding 60px(录屏内嵌成卡片)
- **光标** = 动效阶段 Cursor → Hide(别让鼠标抢戏)
- **文字** = SF Pro / Inter,字重 600,白色,细微阴影
- **音乐** = Audio 轨拖 Suno mp3;③ 段那一下哔对齐音乐波形的鼓点
- **导出** = 1080p 60fps,H.264 mp4

---

## 4 · Suno 提示词

```
warm playful chillhop / lo-fi, cozy late-night vibe, soft bouncy kick + claps,
mellow Rhodes, friendly and a bit cheeky (not corporate), ~92 BPM, instrumental,
35 seconds, gentle build, leave a tiny breath around 0:16 for a "beep" punch-in
```

---

## 5 · 可选:Codex/Remotion 加片头片尾

主片(Screen Studio 出的)前后各贴一段(3 秒):
- **片头字卡**:粒子聚成融合徽标 → Agent Island
- **片尾字卡**:链接 + 二维码弹出

主片 + 这两段在剪映/Final Cut 里拼起来即可。
