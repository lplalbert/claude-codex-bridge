#!/usr/bin/env bash
# ask_codex.sh — Claude→Codex 桥：问题发给 Codex(GPT)，回复落盘 UTF-8 文件
# 用法: ask_codex.sh [-w] [-r] [-f] [-o 输出文件] "问题"
#   -w  允许 Codex 写工作区（必另开新会话；默认只读）
#   -r  另开新会话（默认续 handoff/.codex_session 里的会话）
#   -f  强制执行（越过每日预算闸）
#   -o  自定义回复文件（默认 handoff/consult/codex-<时间戳>.md）
# 环境:
#   ASK_CODEX_BIN            指定 codex 二进制
#   ASK_CODEX_NO_PROXY=1     不走代理（否则默认补 127.0.0.1:7892，不通自动去代理重试）
#   ASK_CODEX_DAILY_BUDGET   每日 token 预算（如 30000），超出需 -f 放行
#   ASK_CODEX_SESSION_LIMIT  单会话累计 token 上限（默认 20000，0=不轮换）
#   ASK_CODEX_MODEL          换更省的模型（按你账号可用型号）
#   ASK_CODEX_MAX_OUTPUT     限制回复最大 token（写入 model_max_output_tokens）
# 用量账本: handoff/.codex_usage.tsv（日期/会话/每次 tokens）
set -euo pipefail

WRITE=0; RESET=0; FORCE=0; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -w) WRITE=1; RESET=1; shift ;;
    -r) RESET=1; shift ;;
    -f) FORCE=1; shift ;;
    -o) OUT="${2:?缺输出路径}"; shift 2 ;;
    -*) echo "未知参数: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
if [ $# -lt 1 ]; then
  echo '用法: ask_codex.sh [-w] [-r] [-f] [-o 输出文件] "问题"' >&2
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
USAGE="$ROOT/handoff/.codex_usage.tsv"
[ -f "$USAGE" ] || : > "$USAGE"

# ---- 每日预算闸 ----
if [ "${ASK_CODEX_DAILY_BUDGET:-0}" -gt 0 ] 2>/dev/null && [ "$FORCE" = 0 ]; then
  TODAY_USED=$(awk -F'\t' -v d="$(date +%F)" '$1==d{t+=$3}END{print t+0}' "$USAGE" 2>/dev/null || echo 0)
  if [ "${TODAY_USED:-0}" -ge "$ASK_CODEX_DAILY_BUDGET" ]; then
    echo "[ask-codex] 今日预算 ${ASK_CODEX_DAILY_BUDGET} tokens 已用完（累计 ${TODAY_USED}）。加 -f 强制，或调大 ASK_CODEX_DAILY_BUDGET。" >&2
    exit 3
  fi
fi

# ---- 会话轮换闸（续会话每次要重发全部历史，超限自动开新会话省额度） ----
if [ "$RESET" = 0 ] && [ -f "$SID_FILE" ]; then
  SID0="$(tr -d ' \r\n' < "$SID_FILE")"
  SLIM="${ASK_CODEX_SESSION_LIMIT:-20000}"
  if [ -n "$SID0" ] && [ "$SLIM" -gt 0 ] 2>/dev/null; then
    SUSED=$(awk -F'\t' -v s="$SID0" '$2==s{t+=$3}END{print t+0}' "$USAGE" 2>/dev/null || echo 0)
    if [ "${SUSED:-0}" -ge "$SLIM" ]; then
      echo "[ask-codex] 会话累计 ~${SUSED} tokens ≥ ${SLIM}，自动开新会话（旧上下文不带入，省额度）" >&2
      RESET=1
    fi
  fi
fi

# ---- 可选参数：换模型 / 限制输出长度 ----
EXTRA=""
[ -n "${ASK_CODEX_MODEL:-}" ] && EXTRA="$EXTRA -m $ASK_CODEX_MODEL"
[ -n "${ASK_CODEX_MAX_OUTPUT:-}" ] && EXTRA="$EXTRA -c model_max_output_tokens=$ASK_CODEX_MAX_OUTPUT"

# 提示词一律走 stdin（防中文 argv 转码问题），回复走 -o 文件（防控制台乱码）
try_run() {
  if [ "$RESET" = 0 ] && [ -f "$SID_FILE" ]; then
    local SID
    SID="$(tr -d ' \r\n' < "$SID_FILE")"
    if [ -n "$SID" ]; then
      if printf '%s\n' "$Q" | "$CODEX_BIN" exec resume "$SID" --skip-git-repo-check -o "$OUT" - $EXTRA >"$LOG" 2>&1; then
        return 0
      fi
      echo "[ask-codex] 续会话失败，改开新会话" >&2
    fi
  fi
  local SB="read-only"
  [ "$WRITE" = 1 ] && SB="workspace-write"
  printf '%s\n' "$Q" | "$CODEX_BIN" exec - -s "$SB" --skip-git-repo-check --color never -C "$ROOT" -o "$OUT" $EXTRA >"$LOG" 2>&1
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

# ---- 记录会话 id + 用量记账 ----
SESS_ID="$(sed -n 's/^session id: //p' "$LOG" | head -n1 | tr -d '\r')"
[ -n "$SESS_ID" ] && printf '%s\n' "$SESS_ID" > "$SID_FILE" || true
[ -z "$SESS_ID" ] && SESS_ID="$(tr -d ' \r\n' < "$SID_FILE" 2>/dev/null || true)"
USED=$(tr -d '\r' < "$LOG" | sed -n '/^tokens used$/{n;s/,//g;p;q}')
case "$USED" in ''|*[!0-9]*) USED=0 ;; esac
printf '%s\t%s\t%s\n' "$(date +%F)" "${SESS_ID:-na}" "$USED" >> "$USAGE"
TODAY_USED=$(awk -F'\t' -v d="$(date +%F)" '$1==d{t+=$3}END{print t+0}' "$USAGE")
SESS_USED=$(awk -F'\t' -v s="${SESS_ID:-na}" '$2==s{t+=$3}END{print t+0}' "$USAGE")
echo "[用量] 本次 ~${USED} tokens | 今日累计 ~${TODAY_USED} | 本会话累计 ~${SESS_USED}" >&2

if [ ! -s "$OUT" ]; then
  echo "[ask-codex] 无回复产出，见日志: $LOG" >&2
  exit 1
fi
echo "$OUT"
