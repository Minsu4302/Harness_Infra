#!/bin/sh
# C01 — 의존성 단방향 검증 (Types → Config → Service → UI)
# 활성 phase: dev, stab, prod

set -eu
HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"
. "${HARNESS_ROOT}/linters/_lib.sh"

# planning에서는 비활성
case "$HARNESS_PHASE" in planning)
  lint_pass "C01" "planning 단계에서 비활성"; exit 0 ;;
esac

# 레이어 역방향 임포트 감지
# 규칙: Types는 아무것도 import 불가 / Config는 Types만 / Service는 Config+Types / UI는 전부 허용
VIOLATIONS=""

# src/ 가 없으면 검사 건너뜀 (하네스 자체는 sh 스크립트 프로젝트)
SRC_DIR="${HARNESS_ROOT}/src"
if [ ! -d "$SRC_DIR" ]; then
  lint_pass "C01" "src/ 디렉토리 없음 — 단방향 의존성 검사 해당 없음"
  exit 0
fi

# Config 레이어가 Service/UI를 import 하는지
if find "$SRC_DIR/config" -name "*.ts" -o -name "*.js" 2>/dev/null | xargs grep -l "from.*service\|from.*ui\|from.*components" 2>/dev/null | grep -q .; then
  VIOLATIONS="${VIOLATIONS}\n  - config 레이어가 service/ui를 import"
fi

# Types 레이어가 다른 레이어를 import 하는지
if find "$SRC_DIR/types" -name "*.ts" -o -name "*.js" 2>/dev/null | xargs grep -l "from.*config\|from.*service\|from.*ui" 2>/dev/null | grep -q .; then
  VIOLATIONS="${VIOLATIONS}\n  - types 레이어가 다른 레이어를 import"
fi

if [ -n "$VIOLATIONS" ]; then
  lint_fail "C01" "단방향 의존성 위반 감지"
  printf '%b\n' "$VIOLATIONS"
  exit 1
fi

lint_pass "C01" "단방향 의존성 정상 (Types→Config→Service→UI)"
exit 0
