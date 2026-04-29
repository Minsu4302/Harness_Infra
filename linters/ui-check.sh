#!/bin/sh
# C08 — UI 검증 기준 충족 확인
# 활성 phase: stab, prod

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

# stab/prod에서만 활성
case "$HARNESS_PHASE" in
  stab|stabilization|prod|production) ;;
  *)
    lint_pass "C08" "현재 phase에서 비활성"; exit 0 ;;
esac

SPEC_FILE="${HARNESS_ROOT}/docs/specs/ui-verification.md"
UI_LOG="${HARNESS_ROOT}/logs/events"

if [ ! -f "$SPEC_FILE" ]; then
  lint_warn "C08" "docs/specs/ui-verification.md 없음 — UI 검증 기준 미정의"
  exit 0
fi

# UI 검증 항목 수 확인 (체크리스트 패턴)
_total=$(grep -cE '^\s*-\s*\[' "$SPEC_FILE" 2>/dev/null || echo "0")

if [ "$_total" -lt 1 ]; then
  lint_warn "C08" "ui-verification.md에 체크리스트 항목 없음"
  exit 0
fi

# logs/events에서 최근 ui_check 이벤트 확인
_verified=0
if [ -d "$UI_LOG" ]; then
  for _f in "$UI_LOG"/*.jsonl; do
    [ -f "$_f" ] || continue
    if grep -q '"event_type":"ui_check_pass"' "$_f" 2>/dev/null; then
      _verified=1
      break
    fi
  done
fi

if [ "$_verified" = "1" ]; then
  lint_pass "C08" "UI 검증 완료 기록 확인됨 (${_total}개 항목)"
  exit 0
fi

lint_fail "C08" "UI 검증 미완료 — docs/specs/ui-verification.md 체크리스트 수동 확인 후 이벤트 기록 필요"
exit 1
