#!/bin/bash

##############################################################################
# C02 — Dependency Check Linter
#
# 역할: 의존성 검증
#   - 필요한 도구 설치 확인
#   - 존재하지 않는 파일 참조 확인
# 활성 phase: planning, development, stabilization, production
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# _lib.sh 로드
source "${HARNESS_ROOT}/linters/_lib.sh"

# Phase 필터
if ! is_phase_active "C02"; then
  lint_pass "C02" "현재 phase에서 비활성"
  exit 0
fi

MISSING_TOOLS=()
MISSING_FILES=()

# 필수 도구 검사
for tool in bash grep sed awk; do
  if ! command -v "$tool" &> /dev/null; then
    MISSING_TOOLS+=("$tool")
  fi
done

# 선택적 도구 검사 (jq)
if ! command -v jq &> /dev/null; then
  MISSING_TOOLS+=("jq (선택적)")
fi

# 핵심 파일 존재 확인
for file in HARNESS.md CLAUDE.md AGENTS.md; do
  if [[ ! -f "${HARNESS_ROOT}/${file}" ]]; then
    MISSING_FILES+=("${file}")
  fi
done

# 디렉토리 존재 확인
for dir in scripts linters validators docs logs .harness; do
  if [[ ! -d "${HARNESS_ROOT}/${dir}" ]]; then
    MISSING_FILES+=("${dir}/")
  fi
done

# 결과 판정
has_critical_issues=false

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  # jq 없는 것은 경고이고, 다른 것은 실패
  critical_tools=()
  for tool in "${MISSING_TOOLS[@]}"; do
    if [[ ! "$tool" =~ "선택적" ]]; then
      critical_tools+=("$tool")
    fi
  done

  if [[ ${#critical_tools[@]} -gt 0 ]]; then
    has_critical_issues=true
    echo "필수 도구 누락: $(IFS=, ; echo "${critical_tools[*]}")"
  fi
fi

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
  has_critical_issues=true
  echo "필수 파일/디렉토리 누락:"
  for file in "${MISSING_FILES[@]}"; do
    echo "  - $file"
  done
fi

# 종합 판정
if [[ "$has_critical_issues" == true ]]; then
  lint_fail "C02" "의존성 확인 실패"
  exit 1
fi

lint_pass "C02" "모든 의존성 확인됨"
exit 0
