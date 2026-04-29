#!/bin/sh
# completion-check.sh — 작업 완료 검증
#
# task.md의 done_condition 항목 검증
# [auto] test: → constraint-check.sh 위임
# [human]      → 목록 출력 후 수동 확인 안내

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export HARNESS_ROOT

TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"

if [ ! -f "$TASK_FILE" ]; then
  printf 'ERROR: task.md 없음\n' >&2
  exit 1
fi

printf '=== Completion Check ===\n' >&2

# done_condition 블록 추출 (YAML 리스트 항목)
_conditions=$(grep -E '^\s*-\s*"\[' "$TASK_FILE" 2>/dev/null || \
              grep -E "^\s*-\s*'\[" "$TASK_FILE" 2>/dev/null || \
              grep -E '^\s*-\s*\[' "$TASK_FILE" 2>/dev/null || true)

if [ -z "$_conditions" ]; then
  printf 'WARN: done_condition 항목 없음\n' >&2
  exit 1
fi

AUTO_FAIL=0
HUMAN_COUNT=0

printf '\n[auto] 항목:\n' >&2
echo "$_conditions" | while IFS= read -r _line; do
  case "$_line" in
    *'\[auto\]'*|*"[auto]"*)
      _desc=$(echo "$_line" | sed 's/.*\[auto\][[:space:]]*//')
      case "$_desc" in
        test:*)
          # constraint-check.sh 실행으로 검증
          printf '  -> %s\n' "$_desc" >&2
          if sh "${HARNESS_ROOT}/scripts/constraint-check.sh" >/dev/null 2>&1; then
            printf '     PASS\n' >&2
          else
            printf '     FAIL\n' >&2
            AUTO_FAIL=$((AUTO_FAIL + 1))
          fi
          ;;
        *)
          printf '  -> %s (수동 판단 필요)\n' "$_desc" >&2
          ;;
      esac
      ;;
  esac
done

printf '\n[human] 항목 (직접 확인 필요):\n' >&2
echo "$_conditions" | while IFS= read -r _line; do
  case "$_line" in
    *'\[human\]'*|*"[human]"*)
      _desc=$(echo "$_line" | sed 's/.*\[human\][[:space:]]*//')
      printf '  - %s\n' "$_desc" >&2
      HUMAN_COUNT=$((HUMAN_COUNT + 1))
      ;;
  esac
done

if [ "$AUTO_FAIL" -gt 0 ]; then
  printf '\nFAIL: 자동 검증 %d개 실패\n' "$AUTO_FAIL" >&2
  exit 1
fi

printf '\nPASS: 자동 검증 완료 (수동 항목은 위 목록 직접 확인)\n' >&2
exit 0
