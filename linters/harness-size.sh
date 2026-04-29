#!/bin/bash

##############################################################################
# C01 — Harness Size Linter
#
# 역할: 파일 크기 제한 검증 (max 1000줄)
# 활성 phase: development, stabilization, production
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# _lib.sh 로드
source "${HARNESS_ROOT}/linters/_lib.sh"

# Phase 필터
if ! is_phase_active "C01"; then
  lint_pass "C01" "현재 phase에서 비활성"
  exit 0
fi

MAX_LINES=1000
OVERSIZED_FILES=()

# scripts/ 디렉토리의 모든 sh 파일 검사
for file in "${HARNESS_ROOT}"/scripts/*.sh \
            "${HARNESS_ROOT}"/linters/*.sh \
            "${HARNESS_ROOT}"/validators/*.sh; do
  [[ ! -f "$file" ]] && continue

  line_count=$(wc -l < "$file" || echo "0")

  if (( line_count > MAX_LINES )); then
    OVERSIZED_FILES+=("$file (${line_count}줄)")
  fi
done

# 결과 판정
if [[ ${#OVERSIZED_FILES[@]} -gt 0 ]]; then
  lint_fail "C01" "파일 크기 초과 (한계: ${MAX_LINES}줄)"
  for file in "${OVERSIZED_FILES[@]}"; do
    echo "  - $file"
  done
  exit 1
fi

lint_pass "C01" "모든 파일이 ${MAX_LINES}줄 이하"
exit 0
