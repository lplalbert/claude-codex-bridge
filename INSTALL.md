# Claude ↔ Codex 双面板协作套件 — 安装指南

让 Claude Code（MiMo 或任意 Anthropic 兼容端点）与 Codex（ChatGPT 订阅）两个 VSCode 面板
**分工协作、文件交接**，免复制粘贴；附 `ask-codex` 桥，可在 Claude 面板内直接拉 Codex 进讨论。

## 实现架构（3 个组件，无服务无后台，用你自己的登录态）

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
| 文件信箱 | 各项目根 `handoff/` | plan.md（Codex 写）/ status.md（Claude 写，六字段）/ consult/（桥的回复） |
| 全局约定 | `~/.claude/CLAUDE.md` + `~/.codex/AGENTS.md` | 各插一段协作规则，两边开会话自动遵守 |
| ask-codex 桥 | `~/.claude/skills/ask-codex/` | 命令行调用 Codex 插件捆绑的 `codex.exe`（或 PATH 的 codex），复用**插件登录的 ChatGPT 订阅额度** |

## 前置条件

| 项 | 必需 | 说明 |
|---|---|---|
| VSCode + Claude Code 插件 | ✅ | 接 MiMo 或任意端点 |
| VSCode + Codex(ChatGPT) 插件（`openai.chatgpt`） | ✅ | 已用 ChatGPT 账号登录（生成 `~/.codex/auth.json`） |
| Git Bash（Windows）或 bash | ✅ | 跑安装脚本和桥 |
| `codex` CLI（`npm i -g @openai/codex`） | 可选 | 没有也行：桥自动用插件捆绑的 codex 二进制 |
| `claude` CLI | 可选 | 仅 Codex 反向问 Claude（`claude -p`）时用 |
| 代理 | 视网络 | 国内需能访问 ChatGPT；默认自动走 `127.0.0.1:7892`，不通会自动去代理重试 |

## 一键安装

把整个 `claude_codex_bridge/` 文件夹拷到新机器（U 盘 / git / 网盘均可），然后：

```bash
cd claude_codex_bridge
bash install.sh                 # 装全局部分（技能 + 两份约定，幂等可重复跑）
bash install.sh --with-handoff  # 同时在当前目录创建 handoff/ 信箱
```

装完**新开会话**生效（全局约定和技能在会话启动时加载）。

## 手动安装（不用脚本）

1. 复制 `skill/` 下两个文件到 `~/.claude/skills/ask-codex/`
2. 把 `conventions/claude.md` 追加到 `~/.claude/CLAUDE.md`
3. 把 `conventions/codex.md` 追加到 `~/.codex/AGENTS.md`（或写进项目的 AGENTS.md）
4. 把 `handoff-template/` 拷成项目根的 `handoff/`

## 新项目怎么用（复制粘贴归零）

1. **Codex 面板**：`出个计划，写 handoff/plan.md`
2. **Claude 面板**：`继续`（自动读 plan/status 干活，完事写六字段交接）
3. **Codex 面板**：`看 handoff/status.md，更新计划`
4. 不切面板问 GPT：在 Claude 里说 `问 Codex：<问题>`（或 `/ask-codex <问题>`）

## 验证安装

在 Claude 面板说：`问 Codex：回复「桥已接通」`。回复落在 `handoff/consult/` 即成功。

## 常见问题

- **额度**：桥走 ChatGPT Plus/Pro **订阅的 Codex 用量限额**（与面板共用一个池，周期性重置），
  不是 API 按 token 计费；省额度就多走文件信箱，"问 Codex"只留给关键裁决。
  用量控制旋钮（每日预算闸 / 会话自动轮换 / 换便宜模型）见 README《用量控制》，账本在 `handoff/.codex_usage.tsv`。
- **代理**：默认补 `HTTPS_PROXY=http://127.0.0.1:7892`，失败自动去代理重试一次；
  也可 `export ASK_CODEX_NO_PROXY=1`，或自己 `export HTTPS_PROXY=...` 后再跑（脚本尊重已有值）。
- **找不到 codex**：`npm i -g @openai/codex`，或保留 openai.chatgpt 插件，或
  `export ASK_CODEX_BIN=/path/to/codex`。
- **插件更新后路径变了**：脚本按 `~/.vscode*/extensions/openai.chatgpt-*/bin/*/codex*` 通配挑最新，
  本地（`~/.vscode`）与远程服务器（`~/.vscode-server`、`~/.vscode-server-insiders`，VSCode Remote SSH/容器
  装插件的位置）都会依次找，一般无需处理。
- **中文乱码**：桥已绕开（提示词走 stdin、回复落盘 UTF-8 文件）；Codex 自身 shell 输出中文乱码是它的坑，
  只信它的分析、文件内容自己读，详见 `handoff-template/PROTOCOL.md`。
- **macOS/Linux**：桥脚本跨平台（自动识别 codex 二进制位置）；bash 需 3.2+。
- **卸载**：删 `~/.claude/skills/ask-codex/`，再删两个全局文件里 `claude-codex-bridge`
  标记块之间的内容。
