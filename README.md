# claude-codex-bridge

把 **Claude Code** 与 **Codex（ChatGPT）** 两个 AI 编程面板配成一对协作搭子：
**Codex 出路线/计划/裁决，Claude 执行**——交接全走文件，零复制粘贴；
另附 `ask-codex` 桥，在 Claude 面板里直接拉 Codex 进讨论（复用 ChatGPT 订阅额度，**不需要 API key**）。

> **English**: A lightweight file-mailbox collaboration kit that pairs Claude Code and Codex (ChatGPT)
> as planner + executor. Handoffs go through plain files (`handoff/`), and an `ask-codex` bridge lets
> Claude consult Codex headlessly via the bundled `codex` CLI — authenticated by your ChatGPT
> subscription login, no API key required.

## 解决什么问题

同时开 Claude 和 Codex 两个面板协作时，计划、进展、问题要在两边**人工复制粘贴**。
两个插件没有互通 API，但它们共享同一个工作区文件系统——所以让文件当"信箱"，
再用全局约定让两边自动读写信箱，复制粘贴就归零了。

## 架构（3 个组件，无服务、无后台、无 API key）

```
┌─ Codex 面板(规划/裁决) ──写──→ handoff/plan.md ──读──→ Claude 面板(执行)
│                                                          │
│                             handoff/status.md ←────写────┘
│                                      │
└──────────────── 读(复盘) ────────────┘

ask-codex 桥: Claude ──命令行 codex exec──→ GPT(订阅额度) ──落盘──→ handoff/consult/
```

| 组件 | 位置 | 作用 |
|---|---|---|
| 文件信箱 | 各项目根 `handoff/` | `plan.md`（Codex 写）/ `status.md`（Claude 写，六字段交接）/ `consult/`（桥的回复） |
| 全局约定 | `~/.claude/CLAUDE.md` + `~/.codex/AGENTS.md` | 各插一段协作规则（安装器幂等写入），两边开会话自动遵守 |
| ask-codex 桥 | `~/.claude/skills/ask-codex/` | bash 脚本调用 Codex 插件捆绑的 `codex` CLI（或 PATH 的 codex），复用**插件登录的 ChatGPT 订阅额度** |

## 快速开始

```bash
git clone https://github.com/<you>/claude-codex-bridge
cd claude-codex-bridge
bash install.sh                  # 装全局部分（幂等，可重复跑）
bash install.sh --with-handoff   # 同时在当前目录建 handoff/ 信箱
```

前置：VSCode 的 Claude Code 插件 + Codex(ChatGPT) 插件（已登录）；Windows 用 Git Bash。
详见 [INSTALL.md](INSTALL.md)（含手动安装、macOS/Linux、卸载）。

装完新开会话，日常循环就三句话：

1. **Codex 面板**：`出个计划，写 handoff/plan.md`
2. **Claude 面板**：`继续`（自动读 plan/status 干活，完事写六字段交接）
3. **Codex 面板**：`看 handoff/status.md，更新计划`

不切面板问 GPT：在 Claude 里说 **`问 Codex：<问题>`**（或 `/ask-codex <问题>`）。
自检：`问 Codex：回复「桥已接通」`，回复落在 `handoff/consult/` 即成功。

## 使用细则

- **交接六字段**（`status.md` 每节）：改了哪些文件 / 做到哪 / 未完成项 / 验收情况 / 已知坑 / 下一步
- **所有权**：`plan.md` 只有 Codex 改（Claude 只读执行）；`status.md` 只有 Claude 追加（Codex 只读复盘）
- **协作纪律**：写完就停、验收先行、同任务 3 返工即熔断升级给人
- **桥参数**：`-r` 另开新会话（默认续上次，保留上下文）；`-w` 允许 Codex 写工作区；`-o` 自定义落盘文件
- **额度**：桥走 ChatGPT Plus/Pro **订阅的 Codex 用量**（与面板同池），不是 API 计费

## 用量控制（ChatGPT 额度少时必看）

Codex(Plus) 的用量是 5 小时窗口 + 周上限；**续会话每次调用都会重发全部历史**，是最贵的隐藏成本。
桥内置三道闸 + 记账：

| 机制 | 默认 | 调节 |
|---|---|---|
| 会话自动轮换 | 单会话累计 ≥20k tokens 自动开新会话（旧上下文不带入） | `ASK_CODEX_SESSION_LIMIT`（0=关） |
| 每日预算闸 | 不启用 | `ASK_CODEX_DAILY_BUDGET=30000` 后，超出要 `-f` 才放行 |
| 用量记账 | 每次调用后打印「本次/今日/会话」累计，落盘 `handoff/.codex_usage.tsv` | — |
| 换便宜模型 | 跟随 `~/.codex/config.toml` | `ASK_CODEX_MODEL=<型号>` |
| 限制回复长度 | 不限 | `ASK_CODEX_MAX_OUTPUT=1500` |

省额度习惯：**日常交接走文件信箱（零消耗）；`问 Codex` 只留给关键裁决/评审**；
长讨论放 Codex 面板手动聊（可控），桥只做短问答。

## 工作原理

- **没有魔法**：Codex 插件自带完整 `codex` CLI 并与插件共用 `~/.codex/auth.json` 登录态；
  桥就是命令行调用它的 `codex exec`（官方 headless 模式），所以走订阅额度而非 API key。
- **中文 Windows 友好**：提示词走 stdin、回复落盘 UTF-8 文件，绕开 argv 转码与控制台乱码。
- **跨平台**：自动在 PATH / 插件捆绑二进制（win/mac/linux）里找 codex；代理默认 7892，
  不通自动去代理重试（也可 `ASK_CODEX_NO_PROXY=1`）。
- **约定幂等**：全局规则用 `claude-codex-bridge` 标记块管理，安装器重复运行不会重复追加。

## 与同类项目的关系

| 项目 | 差异 |
|---|---|
| [OpenMOSS/claude-codex-handoff](https://github.com/OpenMOSS/claude-codex-handoff) | 同为文件信箱思路，走"双向 JSONL + 心跳轮询"的**无人值守自治**重路线；本项目走"人驱动 + 点对点咨询"轻路线 |
| [jessepike/claude-codex-handoff](https://github.com/jessepike/claude-codex-handoff) | Claude 调 Codex 的先例（`/codex-delegate`），分工为 Claude 规划/Codex 实现；本项目方向可任意，且桥带续会话 |
| handoff.md 单文件模板（aicodewith 博文） | 最轻量一次性交接；本项目的 `status.md` 六字段即取自它 |

## License

MIT
