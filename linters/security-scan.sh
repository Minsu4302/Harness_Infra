#!/bin/sh
# C09 — 보안 규칙 (secrets 노출 등) 검증
# 활성 phase: dev, stab, prod

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

case "$HARNESS_PHASE" in
  planning)
    lint_pass "C09" "planning 단계에서 비활성"; exit 0 ;;
esac

RULES_FILE="${HARNESS_ROOT}/docs/constraints/security-rules.md"
VIOLATIONS=""

# 규칙 1: .env 파일이 git-tracked 되어 있는지 확인
if command -v git >/dev/null 2>&1 && [ -d "${HARNESS_ROOT}/.git" ]; then
  _tracked=$(git -C "$HARNESS_ROOT" ls-files "*.env" ".env*" 2>/dev/null || echo "")
  if [ -n "$_tracked" ]; then
    VIOLATIONS="${VIOLATIONS}\n  - .env 파일이 git에 추적됨: $(echo "$_tracked" | head -3)"
  fi
fi

# 규칙 2: 하드코딩된 시크릿 패턴 탐색 (스크립트/소스 파일)
_secret_patterns='(password|secret|api_key|apikey|token|private_key)\s*=\s*["\x27][^"\x27]{8,}'

for _dir in scripts linters validators src; do
  _d="${HARNESS_ROOT}/${_dir}"
  [ -d "$_d" ] || continue
  _hits=$(grep -rEil "$_secret_patterns" "$_d" 2>/dev/null || true)
  if [ -n "$_hits" ]; then
    VIOLATIONS="${VIOLATIONS}\n  - 하드코딩 시크릿 의심: $(echo "$_hits" | head -2)"
  fi
done

# 규칙 3: .gitignore에 .env 포함 여부
if [ -f "${HARNESS_ROOT}/.gitignore" ]; then
  if ! grep -q '\.env' "${HARNESS_ROOT}/.gitignore" 2>/dev/null; then
    VIOLATIONS="${VIOLATIONS}\n  - .gitignore에 .env 패턴 없음"
  fi
fi

if [ -n "$VIOLATIONS" ]; then
  lint_fail "C09" "보안 규칙 위반"
  printf '%b\n' "$VIOLATIONS"
  [ -f "$RULES_FILE" ] && printf '  규칙 참조: docs/constraints/security-rules.md\n'
  exit 1
fi

lint_pass "C09" "보안 규칙 위반 없음"
exit 0
