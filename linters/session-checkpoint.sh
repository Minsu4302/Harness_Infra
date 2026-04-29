#!/bin/sh
# C07 — 세션 체크포인트 강제
# 트리거 조건 (OR): 시간 초과 | budget_warn 연속 | open-questions 누적
# 활성 phase: dev, stab, prod

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

# planning에서 비활성
case "$HARNESS_PHASE" in
  planning)
    lint_pass "C07" "planning 단계에서 비활성"; exit 0 ;;
esac

MAX_HOURS=$(read_harness_config "time_threshold_hours" "4")
MAX_OQ=$(read_harness_config "open_questions_max" "5")
STREAK_LIMIT=$(read_harness_config "context_budget_consecutive" "3")

TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"
OQ_FILE="${HARNESS_ROOT}/.harness/session/open-questions.md"
LAST_CHECK="${HARNESS_ROOT}/.harness/reports/last-check.json"

FAIL_REASONS=""

# ── 조건 1: 경과 시간 ────────────────────────────────────────────────────────
if [ -f "$TASK_FILE" ]; then
  _started=$(grep '^started_at:' "$TASK_FILE" 2>/dev/null | sed 's/started_at:[[:space:]]*//' | tr -d '"' | head -1)

  if [ -n "$_started" ] && [ "$_started" != '""' ]; then
    # GNU date와 BSD date 모두 지원
    _now=$(date +%s 2>/dev/null || echo "0")
    _start=$(date -d "$_started" +%s 2>/dev/null || \
             date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_started" +%s 2>/dev/null || echo "0")

    if [ "$_start" != "0" ] && [ "$_now" != "0" ]; then
      _elapsed_h=$(( (_now - _start) / 3600 ))
      if [ "$_elapsed_h" -gt "$MAX_HOURS" ]; then
        FAIL_REASONS="${FAIL_REASONS}\n  - 태스크 시작 후 ${_elapsed_h}시간 경과 (한계: ${MAX_HOURS}시간)"
      fi
    fi
  fi
fi

# ── 조건 2: budget_warn_streak ───────────────────────────────────────────────
if [ -f "$LAST_CHECK" ]; then
  _streak=$(grep '"budget_warn_streak"' "$LAST_CHECK" 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "0")
  _streak="${_streak:-0}"
  if [ "$_streak" -gt "$STREAK_LIMIT" ]; then
    FAIL_REASONS="${FAIL_REASONS}\n  - 예산 경고 연속 ${_streak}회 (한계: ${STREAK_LIMIT}회)"
  fi
fi

# ── 조건 3: open-questions 누적 ──────────────────────────────────────────────
if [ -f "$OQ_FILE" ]; then
  _oq_count=$(grep -c '^- \[' "$OQ_FILE" 2>/dev/null || echo "0")
  if [ "$_oq_count" -gt "$MAX_OQ" ]; then
    FAIL_REASONS="${FAIL_REASONS}\n  - 미결 항목 ${_oq_count}개 (한계: ${MAX_OQ}개)"
  fi
fi

# ── 판정 ─────────────────────────────────────────────────────────────────────
if [ -n "$FAIL_REASONS" ]; then
  lint_fail "C07" "체크포인트 필요"
  printf '%b\n' "$FAIL_REASONS"
  exit 1
fi

lint_pass "C07" "체크포인트 조건 없음"
exit 0
