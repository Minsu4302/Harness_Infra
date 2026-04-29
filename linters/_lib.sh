#!/bin/bash

##############################################################################
# _lib.sh — 린터 공통 라이브러리
#
# 모든 린터가 사용하는 공통 함수들
##############################################################################

set -euo pipefail

# ============================================================================
# HARNESS.md 설정값 읽기
# ============================================================================
read_harness_config() {
  local key="$1"
  local default="$2"

  if [[ -f "${HARNESS_ROOT}/HARNESS.md" ]]; then
    grep "${key}:" "${HARNESS_ROOT}/HARNESS.md" 2>/dev/null | \
      head -1 | \
      sed -E 's/.*:\s*([0-9]+).*/\1/' | tr -d '[:space:]'
  fi

  # 찾지 못하면 기본값 반환
  local result=$(grep "${key}:" "${HARNESS_ROOT}/HARNESS.md" 2>/dev/null || echo "")
  if [[ -z "$result" ]]; then
    echo "$default"
  fi
}

# ============================================================================
# 린터 출력 헬퍼
# ============================================================================
lint_pass() {
  local constraint="$1"
  local message="$2"
  echo "PASS:${constraint}:${message}"
}

lint_warn() {
  local constraint="$1"
  local message="$2"
  echo "WARN:${constraint}:${message}"
}

lint_fail() {
  local constraint="$1"
  local message="$2"
  echo "FAIL:${constraint}:${message}"
  echo "FIX_AVAILABLE:false"
  echo "FIX_REF:docs/constraints/${constraint}.md#fix"
}

# ============================================================================
# Phase 필터
# ============================================================================
is_phase_active() {
  local constraint="$1"
  local phase="${HARNESS_PHASE:-development}"

  case "$phase" in
    planning)
      [[ "$constraint" =~ ^(C02|C03|C06)$ ]]
      ;;
    development)
      [[ "$constraint" =~ ^(C01|C02|C03|C07)$ ]]
      ;;
    stabilization)
      [[ "$constraint" =~ ^(C01|C02|C03|C04|C07)$ ]]
      ;;
    production)
      [[ "$constraint" =~ ^(C01|C02|C03|C04|C05|C07)$ ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# ============================================================================
# 파일 시스템 헬퍼
# ============================================================================
count_lines() {
  local file="$1"
  [[ -f "$file" ]] && wc -l < "$file" || echo "0"
}

file_exists() {
  [[ -f "$1" ]]
}

dir_exists() {
  [[ -d "$1" ]]
}

# ============================================================================
# 텍스트 처리
# ============================================================================
trim_spaces() {
  tr -d '[:space:]'
}

extract_number() {
  grep -o '[0-9]*' | head -1 || echo "0"
}
