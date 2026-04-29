#!/bin/sh
# C05 — main 브랜치 직접 커밋 금지
# 활성 phase: prod

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

# prod에서만 활성
case "$HARNESS_PHASE" in
  prod|production) ;;
  *)
    lint_pass "C05" "현재 phase에서 비활성"; exit 0 ;;
esac

if ! command -v git >/dev/null 2>&1; then
  lint_warn "C05" "git 없음 — 브랜치 확인 불가"
  exit 0
fi

_branch=$(git -C "$HARNESS_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

case "$_branch" in
  main|master)
    lint_fail "C05" "현재 브랜치가 ${_branch} — main에 직접 커밋 금지"
    exit 1 ;;
  unknown)
    lint_warn "C05" "브랜치 확인 불가"
    exit 0 ;;
  *)
    lint_pass "C05" "브랜치 정상: ${_branch}"
    exit 0 ;;
esac
