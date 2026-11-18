# 双面板协作协议（Claude ↔ Codex）

两个 AI 面板分工：**Codex（ChatGPT）出路线/计划/裁决，Claude（Claude Code）执行**。
本目录是二者的“信箱”：交接全走文件，人只需要说“继续/执行/复盘”，不需要复制粘贴。

## 文件与所有权

| 文件 | 谁写 | 谁读 | 内容 |
|---|---|---|---|
| `plan.md` | Codex | Claude、人 | 当前路线/计划/任务清单/裁决（带日期小节） |
| `status.md` | Claude | Codex、人 | 交接六字段：改了哪些文件/做到哪/未完成项/验收情况/已知坑/下一步（追加式，最新在下） |
| `consult/` | ask-codex 桥 | 人 | Claude 直接咨询 Codex 的落盘回复 |
| `.codex_session` | 桥自动维护 | 桥 | Codex 续会话 id（可删，删了就重开） |

规则：`plan.md` 只有 Codex 改写（Claude 只读执行；有异议记入 `status.md` 的“待裁决”）；
`status.md` 只有 Claude 追加（Codex 只读复盘）。

## 日常循环

1. **Codex 面板**：`出个计划，写 handoff/plan.md`（或直接“出计划”，AGENTS.md 约定它会写）
2. **Claude 面板**：`继续` 或 `执行 handoff/plan.md`（CLAUDE.md 约定会先读 plan.md / status.md）
3. Claude 每完成一段工作、或遇阻塞 → 自动追加 `status.md`
4. **Codex 面板**：`看 handoff/status.md，更新计划 / 回应待裁决`

## 协作纪律（吸收自社区实践）

- **写完就停**：Claude 写完 status.md 交接后停下，不擅自改 plan.md 或继续下一段；Codex 更新完 plan.md 也停，不代做实现。
- **验收先行**：plan.md 每个任务写明验收标准（“什么算做完”）；status.md 汇报给出验证证据（跑过什么测试/命令）。
- **已知坑要写全**：status.md 的“已知坑”是省对方时间最多的字段，路径/编码/依赖/口径的坑务必留下。
- **熔断**：同一任务失败或返工 3 次 → 停手升级给人裁决，不无限循环。

## Claude 直接咨询 Codex（不切面板）

```bash
bash "$HOME/.claude/skills/ask-codex/ask_codex.sh" "问题"
bash "$HOME/.claude/skills/ask-codex/ask_codex.sh" -r "另开新会话的问题"
bash "$HOME/.claude/skills/ask-codex/ask_codex.sh" -w "把X方案写进 handoff/plan.md 的候选方案A"
```

- 默认续上次会话（保留上下文）；`-r` 重开；`-w` 允许 Codex 写工作区（否则只读，且必另开会话）。
- 回复落盘 `handoff/consult/codex-<时间戳>.md`，不走控制台（防乱码）。
- 反向：Codex 面板里它也能跑 `claude -p "..."` 问 Claude（花 MiMo 额度，大活先问人）。

## 环境与排障

- **codex 二进制**：优先 PATH 上的 `codex`；否则自动用 `openai.chatgpt` 扩展捆绑的
  `~/.vscode/extensions/openai.chatgpt-*/bin/windows-x86_64/codex.exe`（扩展升级会换目录，
  脚本自动挑最新，不要写死路径）。可用 `ASK_CODEX_BIN` 覆盖。
- **代理**：默认补 `HTTPS_PROXY=http://127.0.0.1:7892`（ChatGPT 需要）。
  不走这个端口/代理没开：`ASK_CODEX_NO_PROXY=1`，或先 `export HTTPS_PROXY=...`。
- **额度**：每次咨询按 Codex（ChatGPT 账号）配额计费；`-w` / 长上下文更贵。
- **会话文件** `handoff/.codex_session` 丢失或过期 → 自动开新会话，无需处理。
- **全局约定**：装在 `~/.claude/CLAUDE.md` 与 `~/.codex/AGENTS.md`（所有项目生效，新会话加载）。
  某项目分工特殊时，在该项目根写 `CLAUDE.md` / `AGENTS.md` 补充覆盖。

## 已知坑（实测）

- Codex 低推理档（config.toml 默认 low）可能不调用工具就断言“读不了文件”：把关键上下文直接写进问题，别指望它自己翻文件。
- Codex 的 shell 捕获 PowerShell 输出时中文路径/中文文本会乱码（GBK/UTF-8 混层），且转述可能丢行：只信它的分析判断，文件内容以本侧 Read 为准；让它写文件用相对路径。
- Windows python 读不了 Git Bash 的 `/tmp` 路径：脚本/命令里 curl 结果用管道喂 stdin，或用相对路径。

## 相关工作（2026-11-18 调研）

- [OpenMOSS/claude-codex-handoff](https://github.com/OpenMOSS/claude-codex-handoff)：同类最完整的自治版——双向 JSONL 消息流 + 原子租约 + 心跳轮询，agent 自主互相对话（question/handoff 互顶、不能一致才升级给人）。与本协议同思路（文件信箱 + CLAUDE.md/AGENTS.md 入口），但重在“无人值守自治”；本协议走“人驱动 + 点对点咨询”轻量路线。
- [jessepike/claude-codex-handoff](https://github.com/jessepike/claude-codex-handoff)：Claude Code 插件 `/codex-delegate`——Claude 规格/验证 + Codex 实现（分工方向与本协议相反），含熔断（3 连败停）与 status.md/BACKLOG.md 状态文件。我们的 ask-codex 桥与其同属“一端调用另一端 CLI”形态。
- handoff.md 单文件模板（aicodewith.ai《Hand Off from Claude Code to Codex》）：六字段交接 + “写完就停”提示词，实测 37s+86s 接力；本协议 status.md 字段即取自它。
- agiflow.io《Claude Code and Codex Orchestration: Handoff Contracts》：角色辖区 / 验证门 / 证据式交接契约，方法论向，可作为协议演进方向。
- 编排面板（不同形态的替代/上位方案）：[vibe-kanban](https://github.com/BloopAI/vibe-kanban)（28.7k★，看板驱动多 coding agent）、[claude-squad](https://github.com/smtg-ai/claude-squad)（8.8k★，管理多个 AI 终端 agent）、cc-switch（多 harness 统一助手）、orca（多 agent 舰队，自有订阅）。
- 学术：MAST《Why Do Multi-Agent LLM Systems Fail?》(arXiv)——1642 条轨迹 / 14 种失败模式（drift、context loss、conflicting edits 等）；本协议的文件所有权规则正针对 conflicting edits，六字段交接针对 context loss。

## 换个项目用

全局规则已就位，新项目只需：对 Codex 说“出个计划写 handoff/plan.md”即可（目录会自动建）。
想省事也可以把本文件拷到新项目 `handoff/PROTOCOL.md` 备查。
