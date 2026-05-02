#!/bin/sh
# tests/test-token-optimize.sh — 토큰 최적화 기능 검증
# happy path + edge case 2개

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

_ok()  { printf '  PASS: %s\n' "$1"; PASS=$(( PASS + 1 )); }
_err() { printf '  FAIL: %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

echo "=== token-optimize 테스트 ==="

# ─────────────────────────────────────────────────────────────────────────────
# [1] happy path: context-loader.sh 실행 후 메트릭에 token_estimate_input 포함
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1] token_estimate_input 메트릭 기록 ---"

sh "${HARNESS_ROOT}/scripts/context-loader.sh" --task-type feature >/dev/null 2>&1 || true
sh "${HARNESS_ROOT}/scripts/gc-agent.sh" --collect >/dev/null 2>&1 || true

TODAY=$(date +%Y-%m-%d 2>/dev/null || date +%Y%m%d)
METRICS_FILE="${HARNESS_ROOT}/logs/metrics/${TODAY}.jsonl"

if [ -f "$METRICS_FILE" ] && grep -q '"metric_name":"token_estimate_input"' "$METRICS_FILE"; then
  _val=$(grep '"metric_name":"token_estimate_input"' "$METRICS_FILE" | \
    tail -1 | grep -o '"value":[0-9]*' | grep -o '[0-9]*')
  if [ "${_val:-0}" -gt 0 ]; then
    _ok "token_estimate_input=${_val} 메트릭 기록 확인"
  else
    _err "token_estimate_input 값이 0 또는 없음"
  fi
else
  _err "metrics JSONL에 token_estimate_input 없음: ${METRICS_FILE}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [2] happy path: prompt-selector.sh --task-type feature 출력에 'Phase 1' 포함
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2] SoT 템플릿 Phase 1 포함 ---"

_out=$(sh "${HARNESS_ROOT}/scripts/prompt-selector.sh" --task-type feature 2>/dev/null)
if echo "$_out" | grep -q "Phase 1"; then
  _ok "feature 템플릿에 'Phase 1' 섹션 포함"
else
  _err "feature 템플릿에 'Phase 1' 섹션 없음"
fi

if echo "$_out" | grep -q "Phase 2"; then
  _ok "feature 템플릿에 'Phase 2' 섹션 포함 (high 기본값)"
else
  _err "feature 템플릿에 'Phase 2' 섹션 없음"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [3] edge case: complexity=low 시 출력이 20줄 이하
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3] complexity=low 시 출력 크기 축소 ---"

_line_count=$(sh "${HARNESS_ROOT}/scripts/prompt-selector.sh" \
  --task-type feature --complexity low 2>/dev/null | \
  wc -l | tr -d '[:space:]')

if [ "${_line_count:-999}" -le 20 ]; then
  _ok "complexity=low 출력 ${_line_count}줄 ≤ 20줄"
else
  _err "complexity=low 출력 ${_line_count}줄 > 20줄 (축소 미작동)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [4] edge case: complexity=medium 시 Phase 2 생략
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4] complexity=medium 시 Phase 2 생략 ---"

_med_out=$(sh "${HARNESS_ROOT}/scripts/prompt-selector.sh" \
  --task-type feature --complexity medium 2>/dev/null)

if echo "$_med_out" | grep -q "Phase 1"; then
  _ok "complexity=medium 출력에 Phase 1 포함"
else
  _err "complexity=medium 출력에 Phase 1 없음"
fi

if echo "$_med_out" | grep -q "Phase 2"; then
  _err "complexity=medium 출력에 Phase 2가 포함됨 (생략되어야 함)"
else
  _ok "complexity=medium 출력에 Phase 2 생략 확인"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 결과 요약
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== 결과: PASS=${PASS}, FAIL=${FAIL} ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
