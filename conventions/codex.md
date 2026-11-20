<!-- claude-codex-bridge:begin -->
# 双面板协作：Codex(路线/计划) ↔ Claude(执行)

你常与 Claude Code（Claude 插件）分工协作：你出路线、计划、评审与裁决，Claude 负责执行。交接走文件（项目根 `handoff/`），不靠人工复制粘贴。

1. 给出路线/计划/重大裁决时：先读 `handoff/PROJECT.md`（项目简报，如有），再写入或更新 `handoff/plan.md`（带 `## 日期` 小节；含可执行任务清单，尽量注明验收标准）。旧内容按日期保留。
2. 默认不亲自做大段实现：把工作拆成步骤/任务写进 `plan.md`，交给人转给 Claude 执行（除非用户明确让你写代码）。
3. 复盘进展：读 `handoff/status.md`（Claude 写的），据此更新 `plan.md` 或回应其中的“待裁决”。
4. 需要 Claude 做小验证时：可运行 `claude -p "..."`（注意花 MiMo 额度，大任务先问用户），或写任务卡交人转达。
5. `status.md` 由 Claude 所有，你只读不改写。协作细节见项目根 `handoff/PROTOCOL.md`（如有）。
<!-- claude-codex-bridge:end -->
