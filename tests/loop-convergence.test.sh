#!/bin/sh
# tests/loop-convergence.test.sh — C10 loop-convergence.sh 검증
# happy path: status=converged → exit 0
# edge case 1: status=failed → exit 1
# edge case 2: 루프 상태 파일 없음 → exit 0 (루프 미사용)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LINTER="${HARNESS_ROOT}/linters/loop-convergence.sh"
CURRENT_FILE="${HARNESS_ROOT}/.harness/loop/current.yaml"
PASS=0
FAIL=0

_ok()  { printf '  PASS: %s\n' "$1"; PASS=$(( PASS + 1 )); }
_err() { printf '  FAIL: %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

# 테스트용 current.yaml 덮어쓰기
_set_state() {
  mkdir -p "$(dirname "$CURRENT_FILE")"
  cat > "$CURRENT_FILE" <<YAML
---
task_title: "test-task"
iteration: ${1}
max_iterations: ${2}
status: ${3}
last_result: ""
last_error: ""
started_at: "2026-06-29T00:00:00Z"
updated_at: "2026-06-29T00:00:00Z"
YAML
}

# 원본 백업
_backup="${CURRENT_FILE}.bak_$$"
[ -f "$CURRENT_FILE" ] && cp "$CURRENT_FILE" "$_backup" || true

echo "=== loop-convergence (C10) 테스트 ==="

# ─────────────────────────────────────────────────────────────────────────────
# [1] happy path: status=converged → exit 0
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1] happy path: status=converged ---"
_set_state 2 3 "converged"
sh "$LINTER" > /dev/null 2>&1
_exit=$?
[ "$_exit" = "0" ] && _ok "converged → exit 0" || _err "converged → exit $_exit (기대: 0)"

# ─────────────────────────────────────────────────────────────────────────────
# [2] happy path: status=idle → exit 0
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2] happy path: status=idle ---"
_set_state 0 3 "idle"
sh "$LINTER" > /dev/null 2>&1
_exit=$?
[ "$_exit" = "0" ] && _ok "idle → exit 0" || _err "idle → exit $_exit (기대: 0)"

# ─────────────────────────────────────────────────────────────────────────────
# [3] edge case 1: status=failed → exit 1
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3] edge case 1: status=failed → exit 1 ---"
_set_state 3 3 "failed"
sh "$LINTER" > /dev/null 2>&1 || _exit=$?; _exit="${_exit:-0}"
[ "$_exit" = "1" ] && _ok "failed → exit 1" || _err "failed → exit $_exit (기대: 1)"

# lint_fail 출력에 C10 포함 확인
_out=$(sh "$LINTER" 2>/dev/null || true)
echo "$_out" | grep -q "C10" \
  && _ok "FAIL 출력에 C10 포함" \
  || _err "FAIL 출력에 C10 없음"

# ─────────────────────────────────────────────────────────────────────────────
# [4] edge case 2: 루프 상태 파일 없음 → exit 0
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4] edge case 2: 상태 파일 없음 → PASS ---"
rm -f "$CURRENT_FILE"
sh "$LINTER" > /dev/null 2>&1
_exit=$?
[ "$_exit" = "0" ] && _ok "상태 파일 없음 → exit 0" || _err "상태 파일 없음 → exit $_exit (기대: 0)"

# ─────────────────────────────────────────────────────────────────────────────
# [5] constraint-check.sh에서 C10 감지 확인
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [5] constraint-check.sh C10 포함 ---"
_set_state 1 3 "converged"
_check_out=$(HARNESS_PHASE=dev sh "${HARNESS_ROOT}/scripts/constraint-check.sh" 2>&1 || true)
echo "$_check_out" | grep -q "C10" \
  && _ok "constraint-check.sh 출력에 C10 포함" \
  || _err "constraint-check.sh 출력에 C10 없음"

# ─────────────────────────────────────────────────────────────────────────────
# 원본 복원
# ─────────────────────────────────────────────────────────────────────────────
[ -f "$_backup" ] && mv "$_backup" "$CURRENT_FILE" || true

# ─────────────────────────────────────────────────────────────────────────────
# 결과
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== 결과: PASS=${PASS} FAIL=${FAIL} ==="
[ "$FAIL" = "0" ] && exit 0 || exit 1
