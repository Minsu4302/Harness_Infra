#!/bin/bash

##############################################################################
# constraint-check.sh — 모든 제약 조건 검증
#
# 역할: 모든 린터를 순서대로 실행하고 결과를 집계
# 옵션: --only C05 (특정 린터만 실행)
#
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# 린터 로드 경로
LINTERS_DIR="${HARNESS_ROOT}/linters"

# 옵션 파싱
ONLY_CONSTRAINT=""
if [[ $# -gt 0 ]] && [[ "$1" == "--only" ]]; then
  ONLY_CONSTRAINT="$2"
fi

# Phase에 따른 활성 제약 조건
declare -a CONSTRAINTS
case "$HARNESS_PHASE" in
  planning)
    CONSTRAINTS=(C02 C03 C06)
    ;;
  development)
    CONSTRAINTS=(C01 C02 C03 C07)
    ;;
  stabilization)
    CONSTRAINTS=(C01 C02 C03 C04 C07)
    ;;
  production)
    CONSTRAINTS=(C01 C02 C03 C04 C05 C07)
    ;;
  *)
    CONSTRAINTS=(C01 C02 C03)
    ;;
esac

# 단일 제약만 실행하는 경우
if [[ -n "$ONLY_CONSTRAINT" ]]; then
  CONSTRAINTS=("$ONLY_CONSTRAINT")
fi

# 결과 수집
PASSED=()
WARNED=()
FAILED=()

echo "=== Constraint Check: HARNESS_PHASE=$HARNESS_PHASE ===" >&2

# 각 제약 조건 실행
for constraint in "${CONSTRAINTS[@]}"; do
  linter_name=$(echo "$constraint" | tr '[:upper:]' '[:lower:]')

  # 예외: C07은 session-checkpoint.sh, C06은 gc-frequency.sh, C05는 adr-required.sh 등
  case "$constraint" in
    C01) linter_script="${LINTERS_DIR}/harness-size.sh" ;;
    C02) linter_script="${LINTERS_DIR}/dependency-check.sh" ;;
    C03) linter_script="${LINTERS_DIR}/task-completeness.sh" ;;
    C04) linter_script="${LINTERS_DIR}/commit-gate.sh" ;;
    C05) linter_script="${LINTERS_DIR}/adr-required.sh" ;;
    C06) linter_script="${LINTERS_DIR}/gc-frequency.sh" ;;
    C07) linter_script="${LINTERS_DIR}/session-checkpoint.sh" ;;
    *)
      echo "WARN: 알 수 없는 제약 조건: $constraint" >&2
      continue
      ;;
  esac

  # 린터 실행
  if [[ -f "$linter_script" ]]; then
    result=$(bash "$linter_script" 2>&1)
    exit_code=$?

    # 결과 파싱
    if [[ "$result" =~ ^PASS: ]]; then
      PASSED+=("$constraint: $(echo "$result" | sed 's/^PASS:[^:]*: //')")
      echo "✓ $constraint PASS" >&2
    elif [[ "$result" =~ ^WARN: ]]; then
      WARNED+=("$constraint: $(echo "$result" | sed 's/^WARN:[^:]*: //')")
      echo "⚠ $constraint WARN" >&2
      echo "$result" | grep -v "^WARN" >&2 || true
    elif [[ "$result" =~ ^FAIL: ]]; then
      FAILED+=("$constraint: $(echo "$result" | sed 's/^FAIL:[^:]*: //')")
      echo "✗ $constraint FAIL" >&2
      echo "$result" | grep -v "^FAIL" >&2 || true
    fi
  else
    echo "ERROR: 린터 스크립트를 찾을 수 없음: $linter_script" >&2
  fi
done

# 결과 요약
echo "" >&2
echo "=== Summary ===" >&2
echo "PASSED: ${#PASSED[@]} | WARNED: ${#WARNED[@]} | FAILED: ${#FAILED[@]}" >&2

# 최종 종료 코드
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "" >&2
  echo "실패한 제약 조건:" >&2
  for fail in "${FAILED[@]}"; do
    echo "  ✗ $fail" >&2
  done
  exit 1
fi

if [[ ${#WARNED[@]} -gt 0 ]]; then
  echo "" >&2
  echo "경고 제약 조건:" >&2
  for warn in "${WARNED[@]}"; do
    echo "  ⚠ $warn" >&2
  done
  exit 0
fi

exit 0
