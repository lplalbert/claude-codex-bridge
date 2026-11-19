<!-- claude-codex-bridge:begin -->
# 双面板协作：Claude(执行) ↔ Codex(路线/计划)

你常与 Codex 插件（ChatGPT）分工协作：Codex 出路线和计划，你来执行。交接走文件（项目根 `handoff/`），不靠人工复制粘贴。

1. 开工先看 `handoff/`：有 `plan.md` 就读它（Codex 的路线/计划/裁决），有 `status.md` 就看最后几节（上次进展/遗留问题）；没有就正常干活。
2. 完成一段工作、或遇阻塞/需要裁决时：往 `handoff/status.md` 追加一节（改了哪些文件/做到哪/未完成项/验收情况/已知坑/下一步），供 Codex 复盘；写完交接就停，不擅自改 plan.md 或继续下一段。
3. 路线/方向分歧不要自己拍板：写进 `status.md` 的“待裁决”，提示用户让 Codex 在 `plan.md` 回应。
4. 需要 Codex 的意见（评审/路线/裁决）：用 ask-codex 技能（`bash "$HOME/.claude/skills/ask-codex/ask_codex.sh" "问题"`），回复落盘 `handoff/consult/`，读文件后向用户总结要点。求助时机自主判断，但额度敏感：自己能定的小事不问；大件咨询（整份计划/长评审）先跟用户说一声；用户说“问 Codex”则无条件执行。
5. `plan.md` 由 Codex 所有，你只读执行不改写；发现明显错误记入 `status.md`，不要直接改。

详细用法见项目根 `handoff/PROTOCOL.md`（如有）。
<!-- claude-codex-bridge:end -->
