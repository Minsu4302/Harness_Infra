#!/bin/bash

##############################################################################
# C04 — Commit Gate Linter
#
# 역할: 커밋 메시지 형식 검증
#   - 형식: type(scope): description
#   - 유효한 type: feat, fix, refactor, docs, test, chore
# 활성 phase: stabilization, production
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# _lib.sh 로드
source "${HARNESS_ROOT}/linters/_lib.sh"

# Phase 필터
if ! is_phase_active "C04"; then
  lint_pass "C04" "현재 phase에서 비활성"
  exit 0
fi

# GIT_COMMIT_MSG 환경 변수가 없으면 (커밋 훅이 아닌 경우)
# git log의 마지막 커밋 메시지 확인
local commit_msg=""

if [[ -n "${GIT_COMMIT_MSG:-}" ]]; then
  commit_msg="$GIT_COMMIT_MSG"
elif command -v git &> /dev/null && [[ -d "${HARNESS_ROOT}/.git" ]]; then
  commit_msg=$(git log -1 --pretty=format:"%B" 2>/dev/null || echo "")
fi

# 커밋 메시지가 없으면 스킵
if [[ -z "$commit_msg" ]]; then
  lint_pass "C04" "커밋 메시지 확인 스킵 (git 환경 없음)"
  exit 0
fi

# 첫 줄만 검증
local first_line=$(echo "$commit_msg" | head -1)

# 형식: type(scope): description
# 또는: type: description (scope 없음)
if echo "$first_line" | grep -qE '^(feat|fix|refactor|docs|test|chore)(\([^)]+\))?: .+'; then
  lint_pass "C04" "커밋 메시지 형식 검증됨"
  exit 0
fi

# 형식 오류
lint_fail "C04" "커밋 메시지 형식 오류"
echo "  형식: type(scope): description"
echo "  예시: feat(auth): 로그인 기능 추가"
echo "  받은 메시지: $first_line"
exit 1
