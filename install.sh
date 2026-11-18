#!/usr/bin/env bash
# 安装 Claude↔Codex 双面板协作套件（幂等，可重复运行）
# 用法: bash install.sh [--with-handoff [目录]]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WITH_HANDOFF=0
HANDOFF_TARGET="./handoff"
if [ "${1:-}" = "--with-handoff" ]; then
  WITH_HANDOFF=1
  [ -n "${2:-}" ] && HANDOFF_TARGET="$2"
fi

echo "== 1/4 前置检查 =="
CODEX_BIN="${ASK_CODEX_BIN:-}"
if [ -z "$CODEX_BIN" ]; then
  if command -v codex >/dev/null 2>&1; then
    CODEX_BIN="$(command -v codex)"
  else
    OS="$(uname -s 2>/dev/null || echo unknown)"
    case "$OS" in
      MINGW*|MSYS*|CYGWIN*) CODEX_BIN="$(ls -d "$HOME"/.vscode/extensions/openai.chatgpt-*/bin/*/codex.exe 2>/dev/null | sort -V | tail -n1 || true)" ;;
      *) CODEX_BIN="$(ls -d "$HOME"/.vscode/extensions/openai.chatgpt-*/bin/*/codex 2>/dev/null | sort -V | tail -n1 || true)" ;;
    esac
  fi
fi
if [ -n "$CODEX_BIN" ] && [ -e "$CODEX_BIN" ]; then
  echo "  [ok] codex: $CODEX_BIN"
else
  echo "  [缺] 找不到 codex。装 npm i -g @openai/codex，或保留 openai.chatgpt 插件，或 ASK_CODEX_BIN 指定"
fi
if [ -f "$HOME/.codex/auth.json" ]; then
  echo "  [ok] Codex 登录态存在 (~/.codex/auth.json)"
else
  echo "  [缺] 未登录 Codex：先在 Codex 插件里 Sign in with ChatGPT"
fi
if command -v claude >/dev/null 2>&1; then
  echo "  [ok] claude CLI（反向桥可用）"
else
  echo "  [..] 无 claude CLI（可选，仅 Codex 反向问 Claude 时需要）"
fi

echo "== 2/4 安装 ask-codex 技能 =="
mkdir -p "$HOME/.claude/skills/ask-codex"
cp "$HERE/skill/ask_codex.sh" "$HERE/skill/SKILL.md" "$HOME/.claude/skills/ask-codex/"
chmod +x "$HOME/.claude/skills/ask-codex/ask_codex.sh" 2>/dev/null || true
echo "  [ok] ~/.claude/skills/ask-codex/"

echo "== 3/4 写入全局约定（幂等） =="
append_block() {
  local target="$1" src="$2"
  if [ -f "$target" ] && grep -q "claude-codex-bridge:begin" "$target" 2>/dev/null; then
    echo "  [跳过] $target 已含协作块"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  printf '\n' >> "$target"
  cat "$src" >> "$target"
  echo "  [写入] $target"
}
append_block "$HOME/.claude/CLAUDE.md" "$HERE/conventions/claude.md"
append_block "$HOME/.codex/AGENTS.md" "$HERE/conventions/codex.md"

echo "== 4/4 项目 handoff 信箱 =="
if [ "$WITH_HANDOFF" = 1 ]; then
  if [ -e "$HANDOFF_TARGET" ]; then
    echo "  [跳过] $HANDOFF_TARGET 已存在"
  else
    cp -r "$HERE/handoff-template" "$HANDOFF_TARGET"
    echo "  [ok] $HANDOFF_TARGET"
  fi
else
  echo "  [..] 未指定 --with-handoff；新项目首次使用时按 INSTALL.md 拷 handoff-template/ 即可"
fi

echo "完成。新开会话生效；自检：在 Claude 里说「问 Codex：回复 桥已接通」。"
