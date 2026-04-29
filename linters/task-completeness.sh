#!/bin/bash

##############################################################################
# C03 — Task Completeness Linter
#
# 역할: 작업 완성도 검증
#   - task.md의 필수 필드 확인
#   - done_condition 명시 확인
# 활성 phase: planning, development, stabilization, production
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# _lib.sh 로드
source "${HARNESS_ROOT}/linters/_lib.sh"

# Phase 필터
if ! is_phase_active "C03"; then
  lint_pass "C03" "현재 phase에서 비활성"
  exit 0
fi

TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"
MISSING_FIELDS=()
WARNINGS=()

# task.md 존재 확인
if [[ ! -f "$TASK_FILE" ]]; then
  lint_fail "C03" "task.md 파일 없음"
  exit 1
fi

# 필수 필드 확인
if ! grep -q "^task_type:" "$TASK_FILE"; then
  MISSING_FIELDS+=("task_type")
fi

if ! grep -q "^title:" "$TASK_FILE"; then
  MISSING_FIELDS+=("title")
fi

if ! grep -q "^done_condition:" "$TASK_FILE"; then
  MISSING_FIELDS+=("done_condition")
fi

# done_condition이 비어있는지 확인
if grep -A 3 "^done_condition:" "$TASK_FILE" | grep -q "^\s*- \["; then
  : # 제대로 작성됨
else
  WARNINGS+=("done_condition이 비어있음 (최소 1개 항목 필요)")
fi

# task_type 유효성 확인
task_type=$(grep "^task_type:" "$TASK_FILE" | sed 's/task_type: //' | tr -d '[:space:]')
if [[ ! "$task_type" =~ ^(general|feature|bugfix|refactor)$ ]]; then
  WARNINGS+=("task_type 값이 유효하지 않음: $task_type")
fi

# title 공백 확인
title=$(grep "^title:" "$TASK_FILE" | sed 's/title: //; s/\"//g' | tr -d '[:space:]')
if [[ -z "$title" ]]; then
  WARNINGS+=("title이 비어있음")
fi

# 결과 판정
if [[ ${#MISSING_FIELDS[@]} -gt 0 ]]; then
  lint_fail "C03" "필수 필드 누락: $(IFS=, ; echo "${MISSING_FIELDS[*]}")"
  exit 1
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  lint_warn "C03" "작업 완성도 경고 (${#WARNINGS[@]}개)"
  for warning in "${WARNINGS[@]}"; do
    echo "  - $warning"
  done
  exit 0
fi

lint_pass "C03" "작업 정의 완료"
exit 0
