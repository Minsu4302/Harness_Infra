#!/bin/sh
# C03 — HARNESS.md 100줄 이하 검증
# 활성 phase: 전체

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "${HARNESS_ROOT}/linters/_lib.sh"

MAX=100
_file="${HARNESS_ROOT}/HARNESS.md"

if [ ! -f "$_file" ]; then
  lint_fail "C03" "HARNESS.md 없음"
  exit 1
fi

_lines=$(count_lines "$_file")

if [ "$_lines" -gt "$MAX" ]; then
  lint_fail "C03" "HARNESS.md ${_lines}줄 (한계: ${MAX}줄)"
  exit 1
fi

lint_pass "C03" "HARNESS.md ${_lines}줄 (한계: ${MAX}줄)"
exit 0
