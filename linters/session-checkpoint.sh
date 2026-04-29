#!/bin/bash

##############################################################################
# C07 — Session Checkpoint Linter
#
# 역할: 세션 과부하 감지
# 트리거 조건 (OR 관계):
#   1. task.md started_at 기준 경과 시간 > max_hours
#   2. budget_warn_streak 연속 횟수 > 임계값
#   3. open-questions.md 미해결 항목 수 > max_open_questions
#
# 활성 phase: development, stabilization, production
##############################################################################

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-.}"
HARNESS_PHASE="${HARNESS_PHASE:-development}"

# HARNESS.md에서 설정값 읽기
read_harness_config() {
  local key="$1"
  local default="$2"

  if [[ -f "${HARNESS_ROOT}/HARNESS.md" ]]; then
    grep "${key}:" "${HARNESS_ROOT}/HARNESS.md" 2>/dev/null | \
      head -1 | \
      sed -E 's/.*:\s*([0-9]+).*/\1/'
  fi

  # 찾지 못하면 기본값 반환
  if [[ -z "$(grep "${key}:" "${HARNESS_ROOT}/HARNESS.md" 2>/dev/null)" ]]; then
    echo "$default"
  fi
}

# 공백 제거 후 할당
MAX_HOURS=$(read_harness_config "max_hours" "4" | tr -d '[:space:]')
[[ -z "$MAX_HOURS" ]] && MAX_HOURS="4"

MAX_OPEN_QUESTIONS=$(read_harness_config "max_open_questions" "5" | tr -d '[:space:]')
[[ -z "$MAX_OPEN_QUESTIONS" ]] && MAX_OPEN_QUESTIONS="5"

BUDGET_WARN_STREAK_LIMIT=$(read_harness_config "budget_warn_streak" "3" | tr -d '[:space:]')
[[ -z "$BUDGET_WARN_STREAK_LIMIT" ]] && BUDGET_WARN_STREAK_LIMIT="3"

# Phase 필터: C07은 planning에서는 비활성
if [[ "$HARNESS_PHASE" == "planning" ]]; then
  echo "PASS:C07:planning 단계에서는 검증 불필요"
  exit 0
fi

TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"
OPEN_QUESTIONS_FILE="${HARNESS_ROOT}/.harness/session/open-questions.md"
LAST_CHECK_FILE="${HARNESS_ROOT}/.harness/reports/last-check.json"

# 트리거 조건 1: 경과 시간 확인
check_task_duration() {
  if [[ ! -f "$TASK_FILE" ]]; then
    return 1  # 파일 없음 = 조건 불충족
  fi

  local started_at=$(grep "^started_at:" "$TASK_FILE" | sed 's/started_at: //; s/"//g' | head -1)

  if [[ -z "$started_at" ]]; then
    return 1  # started_at 없음 = 아직 시작 안 됨
  fi

  # GNU date가 없을 경우를 대비한 폴백
  if ! date --version 2>/dev/null | grep -q GNU; then
    # macOS/BSD date 사용
    local start_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || echo "0")
  else
    # GNU date 사용
    local start_timestamp=$(date -d "$started_at" +%s 2>/dev/null || echo "0")
  fi

  local now_timestamp=$(date +%s 2>/dev/null || echo "0")

  if [[ "$start_timestamp" == "0" ]] || [[ "$now_timestamp" == "0" ]]; then
    return 1  # 날짜 파싱 실패
  fi

  local elapsed_seconds=$((now_timestamp - start_timestamp))
  local elapsed_hours=$((elapsed_seconds / 3600))

  if (( elapsed_hours > MAX_HOURS )); then
    echo "타스크 시작 후 ${elapsed_hours}시간 경과 (한계: ${MAX_HOURS}시간)"
    return 0
  fi

  return 1
}

# 트리거 조건 2: budget_warn_streak 확인
check_budget_warn_streak() {
  if [[ ! -f "$LAST_CHECK_FILE" ]]; then
    return 1
  fi

  local streak=$(grep -o '"budget_warn_streak":[0-9]*' "$LAST_CHECK_FILE" 2>/dev/null | grep -o '[0-9]*' | tr -d '[:space:]' || echo "0")
  streak=${streak:-0}  # 빈 값 처리
  streak=$(echo "$streak" | tr -d '[:space:]')  # 공백 제거

  if (( streak > BUDGET_WARN_STREAK_LIMIT )); then
    echo "예산 경고 연속 횟수: ${streak}회 (한계: ${BUDGET_WARN_STREAK_LIMIT}회)"
    return 0
  fi

  return 1
}

# 트리거 조건 3: 미결 항목 개수 확인
check_open_questions() {
  if [[ ! -f "$OPEN_QUESTIONS_FILE" ]]; then
    return 1
  fi

  local count=$(grep -c "^- \[" "$OPEN_QUESTIONS_FILE" 2>/dev/null || echo "0" | tr -d '[:space:]')
  count=${count:-0}  # 빈 값 처리
  count=$(echo "$count" | tr -d '[:space:]')  # 공백 제거

  if (( count > MAX_OPEN_QUESTIONS )); then
    echo "미결 항목: ${count}개 (한계: ${MAX_OPEN_QUESTIONS}개)"
    return 0
  fi

  return 1
}

# 종합 검증
FAILURE_REASON=""
FAILURE_COUNT=0

if check_task_duration; then
  FAILURE_REASON="$FAILURE_REASON - $(check_task_duration)"$'\n'
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi

if check_budget_warn_streak; then
  FAILURE_REASON="$FAILURE_REASON - $(check_budget_warn_streak)"$'\n'
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi

if check_open_questions; then
  FAILURE_REASON="$FAILURE_REASON - $(check_open_questions)"$'\n'
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi

if [[ $FAILURE_COUNT -gt 0 ]]; then
  echo "FAIL:C07:체크포인트 필요 (조건 $FAILURE_COUNT개 충족)"
  echo "$FAILURE_REASON" | sed 's/^- /  /'
  echo "FIX_AVAILABLE:false"
  echo "FIX_REF:docs/constraints/C07.md#fix"
  exit 1
fi

echo "PASS:C07:체크포인트 조건 충족 없음"
exit 0
