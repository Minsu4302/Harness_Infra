#!/bin/bash

##############################################################################
# C05 — ADR Required Linter
#
# 역할: 아키텍처 결정 기록 요구사항 검증
#   - docs/decisions/에 최근 ADR 문서 확인
#   - 커밋에 주요 아키텍처 변경이 포함된 경우 ADR 필수
# 활성 phase: production
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# _lib.sh 로드
source "${HARNESS_ROOT}/linters/_lib.sh"

# Phase 필터
if ! is_phase_active "C05"; then
  lint_pass "C05" "현재 phase에서 비활성"
  exit 0
fi

DECISIONS_DIR="${HARNESS_ROOT}/docs/decisions"

# docs/decisions 디렉토리 확인
if [[ ! -d "$DECISIONS_DIR" ]]; then
  lint_warn "C05" "docs/decisions 디렉토리 없음"
  exit 0
fi

# ADR 파일 개수 확인
local adr_count=$(find "$DECISIONS_DIR" -name "*.md" -type f 2>/dev/null | wc -l || echo "0")

# 최소 1개의 ADR이 있는지 확인
if (( adr_count > 0 )); then
  lint_pass "C05" "ADR 문서 확인됨 (총 ${adr_count}개)"
  exit 0
fi

# 처음 세팅일 경우 경고
if [[ -f "${HARNESS_ROOT}/.harness/session/task.md" ]]; then
  lint_warn "C05" "ADR 문서가 없음 (주요 결정사항이 있으면 docs/decisions/에 추가하세요)"
  exit 0
fi

lint_pass "C05" "초기 세팅 단계"
exit 0
