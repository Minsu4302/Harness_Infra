#!/bin/sh
# reflect-agent.sh — 세션 반성 루프 에이전트
#
# 사용법:
#   reflect-agent.sh                  분석 후 reflection.md 생성/갱신
#   reflect-agent.sh --help           도움말
#   reflect-agent.sh --summary        reflection.md 요약 출력 (stdout)
#   reflect-agent.sh --dry-run        분석 결과만 출력, 파일 쓰지 않음

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HISTORY_DIR="${HARNESS_ROOT}/.harness/reports/history"
LOOP_HISTORY="${HARNESS_ROOT}/.harness/loop/history.md"
REFLECTION_FILE="${HARNESS_ROOT}/.harness/reports/reflection.md"

_usage() {
  cat <<'HELP'
reflect-agent.sh — 세션 반성 루프 에이전트

사용법:
  reflect-agent.sh              task 히스토리 분석 후 reflection.md 생성
  reflect-agent.sh --summary    reflection.md 요약을 stdout으로 출력
  reflect-agent.sh --dry-run    파일을 쓰지 않고 분석 결과만 출력
  reflect-agent.sh --help       이 도움말

출력 파일:
  .harness/reports/reflection.md

context-loader.sh이 이 파일을 자동으로 다음 세션에 주입합니다.
HELP
}

_ts() {
  date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ
}

# task 히스토리에서 task_type 집계
_count_task_types() {
  if [ ! -d "$HISTORY_DIR" ]; then
    echo "0 0 0 0"
    return
  fi
  _feature=0; _bug=0; _refactor=0; _general=0
  for _f in "${HISTORY_DIR}"/task_*.md; do
    [ -f "$_f" ] || continue
    _type=$(grep "^task_type:" "$_f" 2>/dev/null | head -1 | sed 's/^task_type:[[:space:]]*//' | tr -d '"')
    case "$_type" in
      feature)   _feature=$((_feature + 1)) ;;
      bug|bugfix) _bug=$((_bug + 1)) ;;
      refactor)  _refactor=$((_refactor + 1)) ;;
      *)         _general=$((_general + 1)) ;;
    esac
  done
  echo "$_feature $_bug $_refactor $_general"
}

# task 히스토리에서 open_questions 누적 수 집계
_count_open_questions() {
  if [ ! -d "$HISTORY_DIR" ]; then
    echo "0"
    return
  fi
  _total=0
  for _f in "${HISTORY_DIR}"/task_*.md; do
    [ -f "$_f" ] || continue
    _q=$(grep -c "^  - " "$_f" 2>/dev/null || echo 0)
    _total=$((_total + _q))
  done
  echo "$_total"
}

# 루프 히스토리에서 수렴/실패 통계
_parse_loop_history() {
  if [ ! -f "$LOOP_HISTORY" ]; then
    echo "0 0 0"
    return
  fi
  _converged=0; _failed=0; _total_iter=0
  while IFS='|' read -r _date _task _iter _result _conv _rest; do
    _iter=$(echo "$_iter" | tr -d ' ')
    _conv=$(echo "$_conv" | tr -d ' ')
    _result=$(echo "$_result" | tr -d ' ')
    case "$_iter" in
      ''|*[!0-9]*) continue ;;  # 헤더·구분선 스킵
    esac
    _total_iter=$((_total_iter + _iter))
    case "$_conv" in
      YES) _converged=$((_converged + 1)) ;;
      NO)  _failed=$((_failed + 1)) ;;
    esac
  done < "$LOOP_HISTORY"
  echo "$_converged $_failed $_total_iter"
}

# 가장 자주 나오는 constraint 실패 (last-check.json 기반)
_top_failed_constraints() {
  _last_check="${HARNESS_ROOT}/.harness/reports/last-check.json"
  if [ ! -f "$_last_check" ]; then
    echo "(데이터 없음 — constraint-check.sh 실행 후 재분석)"
    return
  fi
  _fails=$(grep '"status":"FAIL"' "$_last_check" 2>/dev/null | \
    grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//' | sort | uniq -c | sort -rn | head -5)
  if [ -z "$_fails" ]; then
    echo "(최근 제약 실패 없음)"
  else
    echo "$_fails"
  fi
}

# 태스크 히스토리 총 수
_total_tasks() {
  if [ ! -d "$HISTORY_DIR" ]; then
    echo "0"
    return
  fi
  find "$HISTORY_DIR" -name "task_*.md" 2>/dev/null | wc -l | tr -d '[:space:]'
}

# ── 분석 실행 ────────────────────────────────────────────────────────────────
_run_analysis() {
  _types=$(_count_task_types)
  _feat=$(echo "$_types" | cut -d' ' -f1)
  _bug=$(echo "$_types" | cut -d' ' -f2)
  _refactor=$(echo "$_types" | cut -d' ' -f3)
  _general=$(echo "$_types" | cut -d' ' -f4)
  _oq=$(_count_open_questions)
  _loop=$(_parse_loop_history)
  _conv=$(echo "$_loop" | cut -d' ' -f1)
  _fail=$(echo "$_loop" | cut -d' ' -f2)
  _iter_total=$(echo "$_loop" | cut -d' ' -f3)
  _total=$(_total_tasks)

  # 평균 반복 횟수
  _loop_runs=$((_conv + _fail))
  if [ "$_loop_runs" -gt 0 ]; then
    _avg_iter=$(echo "scale=1; $_iter_total / $_loop_runs" | bc 2>/dev/null || echo "$_iter_total/$_loop_runs")
  else
    _avg_iter="N/A"
  fi

  # 수렴율
  if [ "$_loop_runs" -gt 0 ]; then
    _conv_rate=$(( _conv * 100 / _loop_runs ))
  else
    _conv_rate=0
  fi

  # 인사이트 도출
  _insights=""

  # 인사이트 1: feature 비율 높으면 기능 중심 세션
  if [ "$_feat" -gt 0 ] && [ "$_total" -gt 0 ]; then
    _feat_pct=$((_feat * 100 / _total))
    if [ "$_feat_pct" -ge 60 ]; then
      _insights="${_insights}
- 최근 세션의 ${_feat_pct}%가 feature 태스크 — 기능 구현 중심 국면"
    fi
  fi

  # 인사이트 2: open_questions 누적 경고
  if [ "$_oq" -ge 3 ]; then
    _insights="${_insights}
- 누적 open_questions ${_oq}개 — 해결되지 않은 결정 사항이 많음 (C07 임계: 5개)"
  fi

  # 인사이트 3: 루프 수렴율 낮으면 태스크 분할 권장
  if [ "$_loop_runs" -ge 2 ] && [ "$_conv_rate" -lt 60 ]; then
    _insights="${_insights}
- 루프 수렴율 ${_conv_rate}% (${_conv}/${_loop_runs}) — 태스크 단위가 너무 큰 경향. EXEC_PLAN 분할 검토"
  fi

  # 인사이트 4: 루프 사용 없으면 PEV 도입 권장
  if [ "$_loop_runs" = "0" ]; then
    _insights="${_insights}
- 루프 사용 기록 없음 — 검증 자동화가 필요한 태스크에 loop-runner.sh 사용 권장"
  fi

  if [ -z "$_insights" ]; then
    _insights="
- 특이 패턴 없음 — 정상 운영 중"
  fi

  # 출력
  cat <<REPORT
## 반성 인사이트 (Reflection)

> 생성: $(_ts) | reflect-agent.sh

### 태스크 통계

| 유형 | 수 |
|------|---|
| feature | ${_feat} |
| bugfix | ${_bug} |
| refactor | ${_refactor} |
| general | ${_general} |
| **합계** | **${_total}** |

### 루프 통계

| 항목 | 값 |
|------|---|
| 총 루프 실행 | ${_loop_runs} |
| 수렴 성공 | ${_conv} |
| 수렴 실패 | ${_fail} |
| 수렴율 | ${_conv_rate}% |
| 평균 반복 횟수 | ${_avg_iter} |

### 인사이트
${_insights}

### 최근 제약 실패

$(_top_failed_constraints)
REPORT
}

# ── 메인 ─────────────────────────────────────────────────────────────────────
MODE="run"
for _arg in "$@"; do
  case "$_arg" in
    --help|-h)    MODE="help" ;;
    --summary)    MODE="summary" ;;
    --dry-run)    MODE="dry" ;;
  esac
done

case "$MODE" in
  help)
    _usage
    exit 0
    ;;
  summary)
    if [ -f "$REFLECTION_FILE" ]; then
      cat "$REFLECTION_FILE"
    else
      printf '(reflection.md 없음 — reflect-agent.sh 먼저 실행)\n' >&2
      exit 1
    fi
    ;;
  dry)
    _run_analysis
    ;;
  run)
    mkdir -p "$(dirname "$REFLECTION_FILE")"
    _run_analysis > "$REFLECTION_FILE"
    printf '[reflect-agent] reflection.md 갱신: %s\n' "$REFLECTION_FILE" >&2
    exit 0
    ;;
esac
