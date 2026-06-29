#!/bin/sh
# _lib.sh — 린터 공통 라이브러리

# HARNESS.md YAML 프론트매터에서 단일 값 읽기
# 사용법: read_harness_config key default
read_harness_config() {
  _key="$1"
  _default="$2"
  _file="${HARNESS_ROOT}/HARNESS.md"

  if [ -f "$_file" ]; then
    _val=$(grep "^  ${_key}:" "$_file" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr -d '[:space:]"')
    if [ -z "$_val" ]; then
      _val=$(grep "^${_key}:" "$_file" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr -d '[:space:]"')
    fi
    [ -n "$_val" ] && echo "$_val" && return
  fi
  echo "$_default"
}

# 린터 출력 헬퍼
lint_pass() { echo "PASS:${1}:${2}"; }
lint_warn() { echo "WARN:${1}:${2}"; }

# lint_fail id message [fix_available]
lint_fail() {
  echo "FAIL:${1}:${2}"
  _fix="${3:-false}"
  echo "FIX_AVAILABLE:${_fix}"
  echo "FIX_REF:docs/constraints/${1}.md#fix"
}

# HARNESS.md phase_constraints에서 활성 제약 목록 추출
# 출력: 공백 구분 C-ID 목록
get_active_constraints() {
  _phase="${HARNESS_PHASE:-development}"
  _file="${HARNESS_ROOT}/HARNESS.md"

  # 단축 phase 이름 정규화
  case "$_phase" in
    dev)   _phase="dev"   ;;
    stab)  _phase="stab"  ;;
    prod)  _phase="prod"  ;;
  esac

  if [ -f "$_file" ]; then
    # phase_constraints 블록에서 해당 phase 라인 찾기
    _line=$(grep "^  ${_phase}:" "$_file" 2>/dev/null | head -1)
    if [ -n "$_line" ]; then
      echo "$_line" | grep -o 'C[0-9][0-9]*' | tr '\n' ' '
      return
    fi
  fi

  # 파일 없거나 매핑 없으면 하드코딩 기본값
  case "$_phase" in
    planning) echo "C02 C03 C06" ;;
    dev)      echo "C01 C02 C03 C07 C09" ;;
    stab)     echo "C01 C02 C03 C04 C07 C08 C09" ;;
    prod)     echo "C01 C02 C03 C04 C05 C07 C08 C09" ;;
    *)        echo "C01 C02 C03" ;;
  esac
}

# 제약 ID → 린터 스크립트 경로
constraint_to_linter() {
  _id="$1"
  case "$_id" in
    C01) echo "${HARNESS_ROOT}/linters/dependency-check.sh" ;;
    C02) echo "${HARNESS_ROOT}/linters/task-completeness.sh" ;;
    C03) echo "${HARNESS_ROOT}/linters/harness-size.sh" ;;
    C04) echo "${HARNESS_ROOT}/linters/gc-frequency.sh" ;;
    C05) echo "${HARNESS_ROOT}/linters/commit-gate.sh" ;;
    C06) echo "${HARNESS_ROOT}/linters/adr-required.sh" ;;
    C07) echo "${HARNESS_ROOT}/linters/session-checkpoint.sh" ;;
    C08) echo "${HARNESS_ROOT}/linters/ui-check.sh" ;;
    C09) echo "${HARNESS_ROOT}/linters/security-scan.sh" ;;
    C10) echo "${HARNESS_ROOT}/linters/loop-convergence.sh" ;;
    *)   echo "" ;;
  esac
}

# 파일 줄 수 반환 (없으면 0)
count_lines() {
  [ -f "$1" ] && wc -l < "$1" | tr -d '[:space:]' || echo "0"
}
