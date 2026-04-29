#!/bin/bash

##############################################################################
# completion-check.sh — 작업 완료 검증
#
# 역할: task.md의 done_condition 항목들 검증
#   - [auto] test: 자동으로 검증 가능한 항목
#   - [human]: 사람의 확인이 필요한 항목
#
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"

TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "ERROR: task.md 파일을 찾을 수 없음"
  exit 1
fi

echo "=== Task Completion Check ===" >&2
echo "" >&2

# task.md에서 done_condition 추출
auto_conditions=$(grep -A 10 "^done_condition:" "$TASK_FILE" | grep "^\s*- \[auto\]" | sed 's/.*\[auto\] //' || echo "")
human_conditions=$(grep -A 10 "^done_condition:" "$TASK_FILE" | grep "^\s*- \[human\]" | sed 's/.*\[human\] //' || echo "")

AUTO_PASSED=()
AUTO_FAILED=()
HUMAN_PENDING=()

# [auto] 조건들 검증
echo "자동 검증 항목:" >&2
if [[ -n "$auto_conditions" ]]; then
  while IFS= read -r condition; do
    [[ -z "$condition" ]] && continue

    # test: 형식인 경우
    if echo "$condition" | grep -q "^test:"; then
      test_desc=$(echo "$condition" | sed 's/^test: //')
      echo "  ▢ $test_desc" >&2
      # 실제 검증은 여기서 구현 (constraint-check.sh 호출 등)
      # 지금은 pending 상태로 표시
      AUTO_FAILED+=("$test_desc")
    else
      echo "  ▢ $condition" >&2
      AUTO_FAILED+=("$condition")
    fi
  done <<< "$auto_conditions"
else
  echo "  (없음)" >&2
fi

echo "" >&2
echo "수동 확인 항목:" >&2
if [[ -n "$human_conditions" ]]; then
  while IFS= read -r condition; do
    [[ -z "$condition" ]] && continue
    echo "  ☐ $condition" >&2
    HUMAN_PENDING+=("$condition")
  done <<< "$human_conditions"
else
  echo "  (없음)" >&2
fi

# 결과 요약
echo "" >&2
echo "=== 요약 ===" >&2
echo "자동 검증: ${#AUTO_PASSED[@]} 완료, ${#AUTO_FAILED[@]} 실패" >&2
echo "수동 확인: ${#HUMAN_PENDING[@]} 대기" >&2

if [[ ${#AUTO_FAILED[@]} -gt 0 ]] || [[ ${#HUMAN_PENDING[@]} -gt 0 ]]; then
  echo "" >&2
  echo "⚠ 완료되지 않은 항목이 있습니다" >&2
  exit 1
fi

echo "" >&2
echo "✓ 모든 작업 완료됨" >&2
exit 0
