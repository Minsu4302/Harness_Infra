#!/bin/sh
# C06 — 아키텍처 결정 ADR 기록 검증
# 활성 phase: planning

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

# planning에서만 활성
case "$HARNESS_PHASE" in
  planning) ;;
  *)
    lint_pass "C06" "현재 phase에서 비활성"; exit 0 ;;
esac

DECISIONS_DIR="${HARNESS_ROOT}/docs/decisions"

if [ ! -d "$DECISIONS_DIR" ]; then
  lint_warn "C06" "docs/decisions 없음"
  exit 0
fi

_count=$(find "$DECISIONS_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | wc -l | tr -d '[:space:]')

if [ "$_count" -gt 0 ]; then
  lint_pass "C06" "ADR 문서 ${_count}개 확인됨"
  exit 0
fi

lint_warn "C06" "ADR 문서 없음 — 주요 아키텍처 결정이 있으면 docs/decisions/에 기록하세요"
exit 0
