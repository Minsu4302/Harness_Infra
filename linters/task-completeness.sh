#!/bin/sh
# C02 — done-condition 필드 필수 검증
# 활성 phase: 전체

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"

if [ ! -f "$TASK_FILE" ]; then
  lint_warn "C02" "task.md 없음"
  exit 0
fi

# done_condition 또는 done-condition 필드 확인
if grep -qE '^done.condition:' "$TASK_FILE" 2>/dev/null; then
  _count=$(grep -cE '^\s*-\s' "$TASK_FILE" 2>/dev/null || echo "0")
  if [ "$_count" -lt 1 ]; then
    lint_fail "C02" "done-condition 필드가 비어 있음"
    exit 1
  fi
  lint_pass "C02" "done-condition 필드 확인됨 (${_count}개 조건)"
  exit 0
fi

lint_fail "C02" "task.md에 done-condition 필드 없음"
exit 1
