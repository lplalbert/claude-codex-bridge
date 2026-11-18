---
name: ask-codex
description: 向 Codex(ChatGPT/GPT-6) 咨询路线、评审、裁决意见，结果落盘 handoff/consult/。双面板协作（Claude 执行 + Codex 规划）中需要跨模型意见，或用户说“问下Codex / 让Codex评 / 听听GPT的看法”时使用。
---

# ask-codex

在项目根目录执行：

```bash
bash "$HOME/.claude/skills/ask-codex/ask_codex.sh" "问题内容"
```

参数：`-r` 另开新会话（默认续上次会话）；`-w` 允许 Codex 写工作区文件（必另开会话）；`-o 路径` 自定义回复落盘文件。

要点：
- 关键上下文直接写进问题（实测它低推理档常不调工具就作答，其 shell 输出中文还会乱码）；文件路径只作补充线索。
- 跑完 Read 输出文件，向用户转述要点；原文留在 `handoff/consult/` 备查。
- 路线/方向分歧记入 `handoff/status.md` 的“待裁决”，不要自己拍板。
- 常用环境变量：`ASK_CODEX_NO_PROXY=1`（不走默认 7892 代理）、`ASK_CODEX_BIN`（指定 codex 路径）。
