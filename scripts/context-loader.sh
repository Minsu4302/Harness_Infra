#!/bin/sh
# context-loader.sh — 세션 컨텍스트 로드
#
# 사용법:
#   context-loader.sh                     compile 모드 (기본)
#   context-loader.sh --task-type feature compile 모드 + 태스크 유형 지정
#   context-loader.sh --verify            컨텍스트 예산 검사만 실행

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
export HARNESS_ROOT HARNESS_PHASE

MAX_LINES=400
WARN_LINES=320

CURRENT_CONTEXT="${HARNESS_ROOT}/.harness/context/current.md"
DEBT_REPORT="${HARNESS_ROOT}/.harness/reports/debt-report.md"
TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"
HISTORY_DIR="${HARNESS_ROOT}/.harness/reports/history"

# 옵션 파싱
MODE="compile"
TASK_TYPE="general"
for _arg in "$@"; do
  case "$_arg" in
    --verify)          MODE="verify" ;;
    --task-type)       _next_task_type=1 ;;
    feature|bug|refactor|general)
      [ "${_next_task_type:-0}" = "1" ] && TASK_TYPE="$_arg"; _next_task_type=0 ;;
  esac
done

# ── verify 모드 ──────────────────────────────────────────────────────────────
if [ "$MODE" = "verify" ]; then
  if [ ! -f "$CURRENT_CONTEXT" ]; then
    printf 'WARN: context/current.md 없음 — compile 모드를 먼저 실행하세요\n' >&2
    exit 1
  fi
  _lines=$(wc -l < "$CURRENT_CONTEXT" | tr -d '[:space:]')
  _pct=$(( _lines * 100 / MAX_LINES ))
  printf '[context-loader] budget: %d/%d lines (%d%%)\n' "$_lines" "$MAX_LINES" "$_pct" >&2

  if [ "$_lines" -gt "$MAX_LINES" ]; then
    printf 'FAIL: 컨텍스트 예산 초과 (%d > %d)\n' "$_lines" "$MAX_LINES" >&2
    exit 1
  elif [ "$_lines" -gt "$WARN_LINES" ]; then
    printf 'WARN: 컨텍스트 예산 경고 (%d > %d)\n' "$_lines" "$WARN_LINES" >&2
    exit 0
  fi
  printf 'PASS: 컨텍스트 예산 정상\n' >&2
  exit 0
fi

# ── compile 모드 ─────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$CURRENT_CONTEXT")" "$HISTORY_DIR" \
         "$(dirname "$TASK_FILE")" "$(dirname "$DEBT_REPORT")"

printf '[context-loader] compile (phase=%s, task_type=%s)\n' "$HARNESS_PHASE" "$TASK_TYPE" >&2

# 이전 task.md 백업
if [ -f "$TASK_FILE" ]; then
  _ts=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo "backup")
  cp "$TASK_FILE" "${HISTORY_DIR}/task_${_ts}.md"
  printf '[context-loader] previous task backed up\n' >&2
fi

# current.md 생성
_now=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

cat > "$CURRENT_CONTEXT" <<HEADER
---
title: Current Context
loaded_at: ${_now}
phase: ${HARNESS_PHASE}
task_type: ${TASK_TYPE}
watches:
  - .harness/reports/debt-report.md
---

# 현재 세션 컨텍스트

## 활성 제약 조건

HEADER

# _lib.sh 로드해서 get_active_constraints 사용
. "${HARNESS_ROOT}/linters/_lib.sh"
_constraints=$(get_active_constraints)
echo "$_constraints" | tr ' ' '\n' | grep -v '^$' | \
  while read -r _c; do echo "- $_c"; done >> "$CURRENT_CONTEXT"

cat >> "$CURRENT_CONTEXT" <<SECTION

## 기술 부채 요약

SECTION

if [ -f "$DEBT_REPORT" ]; then
  # CRITICAL 섹션 발췌
  _critical=$(awk '/^## CRITICAL/{f=1;next} /^## /{f=0} f' "$DEBT_REPORT" 2>/dev/null || true)
  printf '### CRITICAL\n\n' >> "$CURRENT_CONTEXT"
  if [ -n "$_critical" ]; then
    echo "$_critical" >> "$CURRENT_CONTEXT"
  else
    printf '없음\n' >> "$CURRENT_CONTEXT"
  fi

  # WARN 섹션 발췌
  _warn=$(awk '/^## WARN/{f=1;next} /^## /{f=0} f' "$DEBT_REPORT" 2>/dev/null || true)
  printf '\n### WARN\n\n' >> "$CURRENT_CONTEXT"
  if [ -n "$_warn" ]; then
    echo "$_warn" >> "$CURRENT_CONTEXT"
  else
    printf '없음\n' >> "$CURRENT_CONTEXT"
  fi
else
  printf '(debt-report.md 없음 — gc-agent --scan 실행 후 재로드)\n' >> "$CURRENT_CONTEXT"
fi

# 태스크 유형별 CoT 프롬프트 주입
printf '\n## 태스크 프롬프트 (%s)\n\n' "$TASK_TYPE" >> "$CURRENT_CONTEXT"

_prompt_selector="${HARNESS_ROOT}/scripts/prompt-selector.sh"
if [ -x "$_prompt_selector" ]; then
  "$_prompt_selector" --task-type "$TASK_TYPE" >> "$CURRENT_CONTEXT" 2>/dev/null || \
    printf '- CLAUDE.md 규칙 1~5 준수\n' >> "$CURRENT_CONTEXT"
else
  printf '- CLAUDE.md 규칙 1~5 준수\n' >> "$CURRENT_CONTEXT"
fi

# 예산 계산
_lines=$(wc -l < "$CURRENT_CONTEXT" | tr -d '[:space:]')
_pct=$(( _lines * 100 / MAX_LINES ))

cat >> "$CURRENT_CONTEXT" <<FOOTER

## Context Budget

- 사용: ${_lines}줄 / ${MAX_LINES}줄 (${_pct}%)
FOOTER

printf '[context-loader] done: %d/%d lines (%d%%)\n' "$_lines" "$MAX_LINES" "$_pct" >&2

if [ "$_lines" -gt "$WARN_LINES" ]; then
  printf 'WARN: 컨텍스트 예산 경고 — gc-agent --scan --collect 실행 권장\n' >&2
fi

exit 0
