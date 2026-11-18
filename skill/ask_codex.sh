#!/usr/bin/env bash
# ask_codex.sh — Claude→Codex 桥：问题发给 Codex(GPT)，回复落盘 UTF-8 文件
# 用法: ask_codex.sh [-w] [-r] [-o 输出文件] "问题"
#   -w  允许 Codex 写工作区（必另开新会话；默认只读）
#   -r  另开新会话（默认续 handoff/.codex_session 里的会话）
#   -o  自定义回复文件（默认 handoff/consult/codex-<时间戳>.md）
# 环境: ASK_CODEX_BIN 指定二进制；ASK_CODEX_NO_PROXY=1 不走代理；
#       HTTPS_PROXY 已设置则尊重之，否则默认补 http://127.0.0.1:7892（不通自动去代理重试）
set -euo pipefail

WRITE=0; RESET=0; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -w) WRITE=1; RESET=1; shift ;;
    -r) RESET=1; shift ;;
    -o) OUT="${2:?缺输出路径}"; shift 2 ;;
    -*) echo "未知参数: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
if [ $# -lt 1 ]; then
  echo '用法: ask_codex.sh [-w] [-r] [-o 输出文件] "问题"' >&2
  exit 2
fi
Q="$1"

# ---- 定位 codex：PATH 优先，否则用 openai.chatgpt 插件捆绑的二进制（按 OS） ----
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
if [ -z "$CODEX_BIN" ] || [ ! -e "$CODEX_BIN" ]; then
  echo "找不到 codex。可 npm i -g @openai/codex，或保留 openai.chatgpt 插件，或设 ASK_CODEX_BIN。" >&2
  exit 1
fi

# ---- 代理：尊重已有值；未设且未禁用则默认 7892，失败自动去代理重试一次 ----
AUTO_PROXY=0
if [ -z "${HTTPS_PROXY:-}" ] && [ "${ASK_CODEX_NO_PROXY:-0}" != "1" ]; then
  export HTTPS_PROXY="http://127.0.0.1:7892"
  export HTTP_PROXY="$HTTPS_PROXY"
  AUTO_PROXY=1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p "$ROOT/handoff/consult"
[ -n "$OUT" ] || OUT="$ROOT/handoff/consult/codex-$(date +%Y%m%d-%H%M%S).md"
LOG="$ROOT/handoff/consult/_bridge.log"
SID_FILE="$ROOT/handoff/.codex_session"

# 提示词一律走 stdin（防中文 argv 转码问题），回复走 -o 文件（防控制台乱码）
try_run() {
  if [ "$RESET" = 0 ] && [ -f "$SID_FILE" ]; then
    local SID
    SID="$(tr -d ' \r\n' < "$SID_FILE")"
    if [ -n "$SID" ]; then
      if printf '%s\n' "$Q" | "$CODEX_BIN" exec resume "$SID" --skip-git-repo-check -o "$OUT" - >"$LOG" 2>&1; then
        return 0
      fi
      echo "[ask-codex] 续会话失败，改开新会话" >&2
    fi
  fi
  local SB="read-only"
  [ "$WRITE" = 1 ] && SB="workspace-write"
  printf '%s\n' "$Q" | "$CODEX_BIN" exec - -s "$SB" --skip-git-repo-check --color never -C "$ROOT" -o "$OUT" >"$LOG" 2>&1
}

RC=0
try_run || RC=$?
if [ $RC -ne 0 ] && [ "$AUTO_PROXY" = 1 ]; then
  echo "[ask-codex] 代理不通，去掉代理重试一次" >&2
  unset HTTPS_PROXY HTTP_PROXY
  RC=0
  try_run || RC=$?
fi
if [ $RC -ne 0 ]; then
  echo "[ask-codex] codex 调用失败，日志尾部：" >&2
  tail -n 20 "$LOG" >&2
  exit 1
fi

# 记录会话 id（供下次续）；解析不到就保留旧值
NEWSID="$(sed -n 's/^session id: //p' "$LOG" | head -n1 | tr -d '\r')"
[ -n "$NEWSID" ] && printf '%s\n' "$NEWSID" > "$SID_FILE" || true

if [ ! -s "$OUT" ]; then
  echo "[ask-codex] 无回复产出，见日志: $LOG" >&2
  exit 1
fi
echo "$OUT"
