#!/bin/bash

##############################################################################
# context-loader.sh — 세션 컨텍스트 로드
#
# 역할: 새 세션 시작 시 필요한 정보를 로드
#   1. HARNESS.md 읽기
#   2. debt-report.md 요약을 context/current.md에 저장
#   3. 이전 task.md를 history에 백업
#   4. 새로운 세션 초기화
#
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# 디렉토리 생성
mkdir -p "${HARNESS_ROOT}/.harness/context"
mkdir -p "${HARNESS_ROOT}/.harness/reports"
mkdir -p "${HARNESS_ROOT}/.harness/session"

CURRENT_CONTEXT="${HARNESS_ROOT}/.harness/context/current.md"
DEBT_REPORT="${HARNESS_ROOT}/.harness/reports/debt-report.md"
TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"
HISTORY_DIR="${HARNESS_ROOT}/.harness/reports/history"

echo ">>> [context-loader] Loading harness context (phase: $HARNESS_PHASE)..." >&2

# ============================================================================
# 1. 이전 task.md를 history에 백업
# ============================================================================
if [[ -f "$TASK_FILE" ]]; then
  timestamp=$(date +%Y%m%d_%H%M%S)
  mkdir -p "$HISTORY_DIR"
  cp "$TASK_FILE" "${HISTORY_DIR}/task_${timestamp}.md"
  echo ">>> [context-loader] Previous task backed up to history" >&2
fi

# ============================================================================
# 2. debt-report.md 요약을 current.md에 저장
# ============================================================================
cat > "$CURRENT_CONTEXT" << 'EOF'
---
title: Current Context
watches:
  - .harness/reports/debt-report.md
loaded_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
phase: development
---

# Current Context

## 기술 부채 요약

EOF

# debt-report.md가 있으면 요약 추가
if [[ -f "$DEBT_REPORT" ]]; then
  echo "### CRITICAL Issues" >> "$CURRENT_CONTEXT"
  grep -A 20 "^## CRITICAL" "$DEBT_REPORT" | tail -n +2 >> "$CURRENT_CONTEXT" 2>/dev/null || echo "없음" >> "$CURRENT_CONTEXT"

  echo "" >> "$CURRENT_CONTEXT"
  echo "### WARNING Issues" >> "$CURRENT_CONTEXT"
  grep -A 20 "^## WARNING" "$DEBT_REPORT" | tail -n +2 >> "$CURRENT_CONTEXT" 2>/dev/null || echo "없음" >> "$CURRENT_CONTEXT"
else
  echo "없음" >> "$CURRENT_CONTEXT"
fi

# ============================================================================
# 3. 환경 정보 추가
# ============================================================================
cat >> "$CURRENT_CONTEXT" << EOF

## 환경 정보

- **Phase**: $HARNESS_PHASE
- **Timestamp**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- **User**: \${USER:-unknown}
- **PWD**: $HARNESS_ROOT

## 활성 제약 조건

EOF

# Phase에 따른 활성 제약 조건 출력
case "$HARNESS_PHASE" in
  planning)
    echo "C02, C03, C06" >> "$CURRENT_CONTEXT"
    ;;
  development)
    echo "C01, C02, C03, C07" >> "$CURRENT_CONTEXT"
    ;;
  stabilization)
    echo "C01, C02, C03, C04, C07" >> "$CURRENT_CONTEXT"
    ;;
  production)
    echo "C01, C02, C03, C04, C05, C07" >> "$CURRENT_CONTEXT"
    ;;
esac

# ============================================================================
# 4. 현재 context 줄 수 계산 (예산 확인)
# ============================================================================
context_lines=$(wc -l < "$CURRENT_CONTEXT" || echo "0")
max_budget=2000
budget_pct=$((context_lines * 100 / max_budget))

echo "" >> "$CURRENT_CONTEXT"
echo "## Context Budget" >> "$CURRENT_CONTEXT"
echo "" >> "$CURRENT_CONTEXT"
echo "- 사용 중: $context_lines 줄" >> "$CURRENT_CONTEXT"
echo "- 한계: $max_budget 줄" >> "$CURRENT_CONTEXT"
echo "- 사용률: ${budget_pct}%" >> "$CURRENT_CONTEXT"

# ============================================================================
# 5. 콘솔 출력
# ============================================================================
echo "" >&2
cat "$CURRENT_CONTEXT" | head -30 >&2
echo "..." >&2
echo "" >&2
echo ">>> [context-loader] Context loaded successfully" >&2
echo ">>> [context-loader] Context file: $CURRENT_CONTEXT" >&2
echo ">>> [context-loader] Context budget: ${budget_pct}% ($context_lines / $max_budget)" >&2

exit 0
