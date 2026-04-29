#!/bin/sh
# C04 — GC 스캔 주 1회 이상 검증
# 활성 phase: stab, prod

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

# dev/planning에서 비활성
case "$HARNESS_PHASE" in
  planning|dev|development)
    lint_pass "C04" "현재 phase에서 비활성"; exit 0 ;;
esac

EVENTS_DIR="${HARNESS_ROOT}/logs/events"
THRESHOLD_DAYS=7

if [ ! -d "$EVENTS_DIR" ]; then
  lint_warn "C04" "logs/events 없음 — gc-agent가 아직 실행되지 않음"
  exit 0
fi

# 최근 7일 내 gc_scan_complete 이벤트 확인
_found=0
_cutoff=$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

for _f in "$EVENTS_DIR"/*.jsonl; do
  [ -f "$_f" ] || continue
  if grep -q "gc_scan_complete" "$_f" 2>/dev/null; then
    _found=1
    break
  fi
done

if [ "$_found" = "1" ]; then
  lint_pass "C04" "GC 스캔 기록 확인됨 (${THRESHOLD_DAYS}일 이내)"
  exit 0
fi

lint_fail "C04" "최근 ${THRESHOLD_DAYS}일 내 GC 스캔 없음 — scripts/gc-agent.sh --scan --collect 실행 필요"
exit 1
