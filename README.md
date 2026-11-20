# 🤝 Claude × Codex 组队包

### Codex 出主意，Claude 干活，你只管下命令

> **English**: Pair Claude Code and Codex (ChatGPT) as a team — planner + executor.
> Handoffs go through plain files (zero copy-paste), and Claude can consult Codex directly,
> using your ChatGPT subscription. No API key required.

**你是不是也这样**：Claude 和 Codex 两个 AI 面板一起开，计划在 Codex 那边、活在 Claude 这边，
中间全靠你复制粘贴？

**装完这个之后**：你只管说话。Codex 出计划、Claude 干活、进展自动传回去，
连"问下 Codex 怎么看"都不用切窗口。**零复制粘贴 · 用你自己的 ChatGPT 登录 · 5 分钟装好**。

---

## 🚀 怎么装（就 3 条命令）

```bash
git clone https://github.com/lplalbert/claude-codex-bridge
cd claude-codex-bridge
bash install.sh --with-handoff
```

装完**重开一下会话**，就能用了。

> 前提：电脑上有 VSCode 的 Claude 插件 + Codex 插件（Codex 登录过 ChatGPT 账号就行）。
> Windows 用 Git Bash 跑命令。手动装法 / Mac / Linux / 卸载 → [INSTALL.md](INSTALL.md)

## 🎯 怎么用（日常就三句话）

| 你对谁说 | 说什么 | 发生什么 |
|---|---|---|
| **Codex 面板** | "出个计划，写 handoff/plan.md" | Codex 把计划写好 |
| **Claude 这边** | "继续" | Claude 读计划、干活、写进展 |
| **Codex 面板** | "看下 handoff/status.md，更新计划" | Codex 看进展、改计划 |

计划和进展在文件里自动传，你一个字都不用复制粘贴。

**懒人玩法**：连 Codex 面板都不用开——只指挥 Claude，它会自己找 Codex 商量（见下）。

## 💬 还能这样：不切窗口，直接问 Codex

在 Claude 这边说：

```
问 Codex：这个实验设计有没有坑？
```

Claude 会把 GPT 拉进来出意见，落在 `handoff/consult/` 里。
用的是**你自己账号的 ChatGPT 订阅额度**——不是 API 计费，不需要申请 API key。

## 💰 额度少？（大多数人最关心的）

- **文件传计划/进展 = 完全免费**，一个 token 都不花
- "问 Codex" 才花额度：一次约 2~3k tokens，每次自动显示用量、自动记账
- 内置保护：会话聊太长自动换新（防止重复计费历史），还能设每日上限

## ❓ 常见问题

- **"问 Codex" 走 API 吗？我没有 API key** → 不走。它用的是 Codex 插件的登录态，
  跟你在 Codex 面板里打字是同一条通道、同一个额度池。每个用户用的都是**自己电脑上自己的登录态**；
  本仓库不含任何人的密钥，工具也不会上传任何东西。
- **要开代理吗** → 国内需要能访问 ChatGPT。脚本默认走 `127.0.0.1:7892`，不通会自动去代理重试。
- **换电脑怎么办** → 回到开头那 3 条命令。
- **会不会把 Codex 变笨** → 不会。省额度靠"少问"，不靠"问傻它"。

---

<details>
<summary><b>📦 架构：它是怎么工作的（3 个零件）</b></summary>

```
┌─ Codex 面板(规划/裁决) ──写──→ handoff/plan.md ──读──→ Claude 面板(执行)
│                                                          │
│                             handoff/status.md ←────写────┘
│                                      │
└──────────────── 读(复盘) ────────────┘

问 Codex 桥: Claude ──命令行 codex exec──→ GPT(订阅额度) ──落盘──→ handoff/consult/
```

| 零件 | 位置 | 干什么 |
|---|---|---|
| 文件信箱 | 各项目根 `handoff/` | plan.md（Codex 写）/ status.md（Claude 写，六字段交接）/ consult/（问 Codex 的回复） |
| 项目简报 | 各项目根 `handoff/PROJECT.md` | 30-60 行背景包（项目是什么/阶段/文件地图/口径），问 Codex 时自动带上，免得它自己翻仓库 |
| 全局约定 | `~/.claude/CLAUDE.md` + `~/.codex/AGENTS.md` | 各插一段规则，两边开会话自动遵守 |
| 问 Codex 桥 | `~/.claude/skills/ask-codex/` | 调用 Codex 插件自带的 codex 命令行，复用订阅登录态 |

没有服务、没有后台、不需要申请 API key（用你自己的登录态）：桥用的就是 Codex 插件捆绑的 `codex` CLI 和它自己的 `~/.codex/auth.json` 登录态。

</details>

<details>
<summary><b>⚙️ 用量控制（额度旋钮）</b></summary>

Codex(Plus) 的用量是 5 小时窗口 + 周上限；**续会话每次调用都会重发全部历史**，是最贵的隐藏成本。
桥内置三道闸 + 记账：

| 机制 | 默认 | 调节 |
|---|---|---|
| 会话自动轮换 | 单会话累计 ≥20k tokens 自动开新会话（旧上下文不带入） | `ASK_CODEX_SESSION_LIMIT`（0=关） |
| 每日预算闸 | 不启用 | `ASK_CODEX_DAILY_BUDGET=30000` 后，超出要 `-f` 才放行 |
| 用量记账 | 每次调用打印「本次/今日/会话」累计，落盘 `handoff/.codex_usage.tsv` | — |
| 换便宜模型 | 跟随 `~/.codex/config.toml` | `ASK_CODEX_MODEL=<型号>` |
| 限制回复长度 | 不限 | `ASK_CODEX_MAX_OUTPUT=1500` |

**会不会影响质量？** 记账/预算闸零影响；会话轮换只是丢"对话记忆"（不降智）——自包含问题无损，
调用方把前情要点写进问题即可补回；换便宜模型（`ASK_CODEX_MODEL`）才真降智，默认不开。
深度规划请用 Codex 面板（不受闸影响），桥定位是快问快答/评审裁决。

问 Codex 的其他参数：`-r` 另开新会话（默认续上次，保留上下文）；`-w` 允许 Codex 写工作区文件；`-o 路径` 自定义回复落盘位置。

</details>

<details>
<summary><b>🔧 用法细则（分工与纪律）</b></summary>

- **交接六字段**（`status.md` 每节）：改了哪些文件 / 做到哪 / 未完成项 / 验收情况 / 已知坑 / 下一步
- **所有权**：`plan.md` 只有 Codex 改（Claude 只读执行）；`status.md` 只有 Claude 追加（Codex 只读复盘）
- **协作纪律**：写完就停、验收先行、同任务 3 返工即熔断升级给人
- **Claude 求助策略**：自己能定的小事不问 Codex；大件咨询先报备；用户点名"问 Codex"无条件执行

</details>

<details>
<summary><b>🧭 与同类项目的关系</b></summary>

| 项目 | 差异 |
|---|---|
| [OpenMOSS/claude-codex-handoff](https://github.com/OpenMOSS/claude-codex-handoff) | 同为文件信箱思路，走"双向 JSONL + 心跳轮询"的**无人值守自治**重路线；本项目走"人驱动 + 点对点咨询"轻路线 |
| [jessepike/claude-codex-handoff](https://github.com/jessepike/claude-codex-handoff) | Claude 调 Codex 的先例（`/codex-delegate`），分工为 Claude 规划/Codex 实现；本项目方向可任意，且桥带续会话 |
| handoff.md 单文件模板（aicodewith 博文） | 最轻量一次性交接；本项目的 `status.md` 六字段即取自它 |

</details>

## License

MIT
