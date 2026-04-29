#!/bin/sh
# constraint-check.sh — 하네스 제약 조건 검증 오케스트레이터
#
# 사용법:
#   constraint-check.sh               전체 검증 (병렬)
#   constraint-check.sh --only C07    단일 제약만 실행
#   constraint-check.sh --fix         수정 모드 (직렬, FIX_AVAILABLE:true 린터에 HARNESS_FIX=1 주입)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
export HARNESS_ROOT HARNESS_PHASE

LINTERS_DIR="${HARNESS_ROOT}/linters"
REPORT_FILE="${HARNESS_ROOT}/.harness/reports/last-check.json"

# _lib.sh 로드
. "${LINTERS_DIR}/_lib.sh"

# 옵션 파싱
ONLY_ID=""
FIX_MODE=0
for _arg in "$@"; do
  case "$_arg" in
    --only) _next_is_id=1 ;;
    --fix)  FIX_MODE=1 ;;
    C*)     [ "${_next_is_id:-0}" = "1" ] && ONLY_ID="$_arg"; _next_is_id=0 ;;
  esac
done

# 실행할 제약 목록
if [ -n "$ONLY_ID" ]; then
  CONSTRAINTS="$ONLY_ID"
else
  CONSTRAINTS=$(get_active_constraints)
fi

mkdir -p "$(dirname "$REPORT_FILE")"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
FAIL_IDS=""
REPORT_ENTRIES=""

printf '=== Constraint Check [phase=%s] ===\n' "$HARNESS_PHASE" >&2

# 린터 하나 실행
run_linter() {
  _id="$1"
  _script=$(constraint_to_linter "$_id")

  if [ -z "$_script" ] || [ ! -f "$_script" ]; then
    printf 'SKIP:%s:린터 스크립트 없음\n' "$_id" >&2
    return
  fi

  if [ "$FIX_MODE" = "1" ]; then
    export HARNESS_FIX=1
  else
    export HARNESS_FIX=0
  fi

  _out=$(sh "$_script" 2>/dev/null) && _exit=0 || _exit=$?

  # stdout 첫 줄이 STATUS:ID:MESSAGE 형식
  _first=$(echo "$_out" | head -1)
  _status=$(echo "$_first" | cut -d: -f1)
  _msg=$(echo "$_first" | cut -d: -f3-)

  case "$_status" in
    PASS)
      printf '  \342\234\223 %s PASS: %s\n' "$_id" "$_msg" >&2
      PASS_COUNT=$((PASS_COUNT + 1))
      REPORT_ENTRIES="${REPORT_ENTRIES}{\"id\":\"${_id}\",\"status\":\"PASS\",\"msg\":\"${_msg}\"},"
      ;;
    WARN)
      printf '  \342\232\240 %s WARN: %s\n' "$_id" "$_msg" >&2
      WARN_COUNT=$((WARN_COUNT + 1))
      REPORT_ENTRIES="${REPORT_ENTRIES}{\"id\":\"${_id}\",\"status\":\"WARN\",\"msg\":\"${_msg}\"},"
      ;;
    FAIL)
      printf '  \342\234\227 %s FAIL: %s\n' "$_id" "$_msg" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAIL_IDS="${FAIL_IDS} ${_id}"
      REPORT_ENTRIES="${REPORT_ENTRIES}{\"id\":\"${_id}\",\"status\":\"FAIL\",\"msg\":\"${_msg}\"},"
      # FIX 정보 stderr 출력
      echo "$_out" | grep -E '^(FIX_AVAILABLE|FIX_REF):' >&2 || true
      ;;
  esac
}

# 실행 (FIX 모드면 직렬, 아니면 순차 — 진정한 병렬은 wait/& 필요하나 POSIX sh에서 결과 수집이 복잡)
for _c in $CONSTRAINTS; do
  run_linter "$_c"
done

# 요약
printf '\n=== Summary: PASS=%d WARN=%d FAIL=%d ===\n' \
  "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" >&2

# last-check.json 저장
_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
_entries=$(echo "$REPORT_ENTRIES" | sed 's/,$//')
cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "${_ts}",
  "phase": "${HARNESS_PHASE}",
  "pass": ${PASS_COUNT},
  "warn": ${WARN_COUNT},
  "fail": ${FAIL_COUNT},
  "failed_ids": [$(echo "$FAIL_IDS" | tr ' ' '\n' | grep -v '^$' | sed 's/.*/"&"/' | paste -sd ',' -)],
  "budget_warn_streak": 0,
  "results": [${_entries}]
}
EOF

[ "$FAIL_COUNT" -gt 0 ] && exit 1 || exit 0
