#!/bin/bash

##############################################################################
# C06 — GC Frequency Linter
#
# 역할: GC (Garbage Collection) 실행 빈도 검증
#   - logs/events에 최근 gc_scan_complete 이벤트 확인
#   - planning phase: 경고 (필수 아님)
# 활성 phase: planning
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# _lib.sh 로드
source "${HARNESS_ROOT}/linters/_lib.sh"

# Phase 필터
if ! is_phase_active "C06"; then
  lint_pass "C06" "현재 phase에서 비활성"
  exit 0
fi

EVENTS_DIR="${HARNESS_ROOT}/logs/events"

# logs/events 디렉토리 확인
if [[ ! -d "$EVENTS_DIR" ]]; then
  lint_warn "C06" "logs/events 디렉토리 없음 (gc-agent 아직 실행되지 않음)"
  exit 0
fi

# 최근 gc_scan_complete 이벤트 확인
local gc_events=$(find "$EVENTS_DIR" -name "*.jsonl" -type f 2>/dev/null -exec grep -l "gc_scan_complete" {} \; 2>/dev/null | wc -l || echo "0")

if (( gc_events > 0 )); then
  lint_pass "C06" "GC 스캔 기록 확인됨"
  exit 0
fi

# planning phase에서는 경고만 표시 (필수 아님)
lint_warn "C06" "GC 스캔이 아직 실행되지 않음"
exit 0
