#!/bin/sh
# C10 — Loop Convergence Constraint
# 루프 상태 파일이 없으면 PASS (루프 미사용). 있을 때만 수렴 여부 검사.
# 활성 phase: development, stabilization, production

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "${HARNESS_ROOT}/linters/_lib.sh"

CURRENT_FILE="${HARNESS_ROOT}/.harness/loop/current.yaml"
DEFAULT_MAX=3

# 루프 상태 파일 없음 → 루프 미사용, PASS
if [ ! -f "$CURRENT_FILE" ]; then
  lint_pass "C10" "루프 상태 파일 없음 — 루프 미사용 (PASS)"
  exit 0
fi

# YAML 단일 키 읽기
_yaml_get() {
  grep "^${1}:" "$CURRENT_FILE" 2>/dev/null | head -1 | sed "s/^${1}:[[:space:]]*//" | tr -d '"'
}

_status=$(_yaml_get "status")
_iteration=$(_yaml_get "iteration")
_max=$(_yaml_get "max_iterations")

# 숫자 기본값 처리
_iteration="${_iteration:-0}"
_max="${_max:-$DEFAULT_MAX}"

# 숫자인지 확인 (헤더 라인 방어)
case "$_iteration" in
  ''|*[!0-9]*) _iteration=0 ;;
esac
case "$_max" in
  ''|*[!0-9]*) _max=$DEFAULT_MAX ;;
esac

# idle / converged 상태 → 문제 없음
case "$_status" in
  idle|converged|running|"")
    lint_pass "C10" "루프 상태 정상 (status=${_status}, iteration=${_iteration}/${_max})"
    exit 0
    ;;
  failed)
    lint_fail "C10" \
      "루프 수렴 실패 — ${_iteration}회 시도 후 포기 (max=${_max}). 태스크 분할 필요." \
      "true"
    exit 1
    ;;
esac

# status 필드가 알 수 없는 값이면 iteration으로 판단
if [ "$_iteration" -gt "$_max" ]; then
  lint_fail "C10" \
    "루프 반복 초과 — iteration=${_iteration} > max=${_max}. 태스크 분할 필요." \
    "true"
  exit 1
fi

lint_pass "C10" "루프 수렴 정상 (status=${_status}, iteration=${_iteration}/${_max})"
exit 0
