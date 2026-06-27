#!/bin/sh
# tests/loop-runner.test.sh — loop-runner.sh 검증
# happy path: 3회 이내 수렴
# edge case 1: max 초과 시 exit 1
# edge case 2: --check 단일 실행 (루프 없이)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
RUNNER="${HARNESS_ROOT}/scripts/loop-runner.sh"
PASS=0
FAIL=0

_ok()  { printf '  PASS: %s\n' "$1"; PASS=$(( PASS + 1 )); }
_err() { printf '  FAIL: %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

echo "=== loop-runner 테스트 ==="

# ─────────────────────────────────────────────────────────────────────────────
# [0] --help 옵션 exit 0
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [0] --help exit 0 ---"
sh "$RUNNER" --help > /dev/null 2>&1 && _ok "--help exit 0" || _err "--help exit 0 실패"

# ─────────────────────────────────────────────────────────────────────────────
# [1] happy path: 성공 명령으로 즉시 수렴 (1회차)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1] happy path: 즉시 수렴 ---"

sh "$RUNNER" --reset > /dev/null 2>&1 || true

sh "$RUNNER" --run "exit 0" > /dev/null 2>&1
_exit=$?
if [ "$_exit" = "0" ]; then
  _ok "exit 0 명령 → 수렴 성공 (exit 0)"
else
  _err "exit 0 명령 → 수렴 실패 (exit $_exit)"
fi

# current.yaml 상태 확인
_status=$(grep "^status:" "${HARNESS_ROOT}/.harness/loop/current.yaml" 2>/dev/null | head -1 | tr -d '"' | sed 's/^status:[[:space:]]*//')
if [ "$_status" = "converged" ]; then
  _ok "current.yaml status=converged"
else
  _err "current.yaml status 기대값=converged, 실제=${_status}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [2] edge case 1: max 초과 → exit 1 (C10 위반)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2] edge case 1: max 초과 → exit 1 ---"

sh "$RUNNER" --reset > /dev/null 2>&1 || true

sh "$RUNNER" --max 2 --run "exit 1" > /dev/null 2>&1 || _exit=$?; _exit="${_exit:-0}"
if [ "$_exit" = "1" ]; then
  _ok "--max 2, 항상 실패 명령 → exit 1 (수렴 실패)"
else
  _err "--max 2, 항상 실패 명령 → 기대 exit 1, 실제 exit $_exit"
fi

# current.yaml status=failed 확인
_status=$(grep "^status:" "${HARNESS_ROOT}/.harness/loop/current.yaml" 2>/dev/null | head -1 | tr -d '"' | sed 's/^status:[[:space:]]*//')
if [ "$_status" = "failed" ]; then
  _ok "current.yaml status=failed"
else
  _err "current.yaml status 기대값=failed, 실제=${_status}"
fi

# last-fail-context.md 생성 확인
_ctx="${HARNESS_ROOT}/.harness/loop/last-fail-context.md"
if [ -f "$_ctx" ]; then
  _ok "last-fail-context.md 생성됨"
else
  _err "last-fail-context.md 생성 안 됨"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [3] edge case 2: --check 단일 실행 (루프 없이)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3] edge case 2: --check 단일 실행 ---"

sh "$RUNNER" --check "exit 0" > /dev/null 2>&1
_exit=$?
[ "$_exit" = "0" ] && _ok "--check exit 0 → exit 0" || _err "--check exit 0 → exit $_exit"

sh "$RUNNER" --check "exit 1" > /dev/null 2>&1 || _exit=$?; _exit="${_exit:-0}"
[ "$_exit" = "1" ] && _ok "--check exit 1 → exit 1" || _err "--check exit 1 → exit $_exit"

# ─────────────────────────────────────────────────────────────────────────────
# 결과
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== 결과: PASS=${PASS} FAIL=${FAIL} ==="

[ "$FAIL" = "0" ] && exit 0 || exit 1
