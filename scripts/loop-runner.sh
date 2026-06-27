#!/bin/sh
# loop-runner.sh — PEV (Plan-Execute-Verify) 자동 재시도 루프
#
# 사용법:
#   loop-runner.sh --help                        도움말
#   loop-runner.sh --check <cmd>                 단일 검증 명령 실행 (루프 없이)
#   loop-runner.sh --run <verify_cmd>            PEV 루프 시작
#   loop-runner.sh --max <N> --run <verify_cmd>  최대 반복 횟수 지정 (기본 3)
#   loop-runner.sh --status                      현재 루프 상태 출력
#   loop-runner.sh --reset                       루프 상태 초기화

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOOP_DIR="${HARNESS_ROOT}/.harness/loop"
CURRENT_FILE="${LOOP_DIR}/current.yaml"
HISTORY_FILE="${LOOP_DIR}/history.md"
CONTEXT_FAIL_FILE="${LOOP_DIR}/last-fail-context.md"

DEFAULT_MAX=3

_usage() {
  cat <<'HELP'
loop-runner.sh — PEV (Plan-Execute-Verify) 루프

사용법:
  loop-runner.sh --help
  loop-runner.sh --status
  loop-runner.sh --reset
  loop-runner.sh --check <verify_cmd>
  loop-runner.sh [--max N] --run <verify_cmd>

옵션:
  --help            이 도움말 출력
  --status          현재 루프 상태 (.harness/loop/current.yaml) 출력
  --reset           루프 상태 초기화 (idle)
  --check <cmd>     검증 명령을 한 번만 실행 (루프 없이)
  --run <cmd>       PEV 루프 시작. <cmd> exit 0 = 수렴, 아니면 재시도
  --max <N>         최대 반복 횟수 (기본 3). --run 앞에 지정

종료 코드:
  0  수렴 성공 (verify_cmd exit 0)
  1  수렴 실패 (max 초과) — C10 제약 위반
  2  사용법 오류
HELP
}

# YAML 단일 키 읽기 (순수 sh, Python/yq 불필요)
_yaml_get() {
  _file="$1"; _key="$2"
  grep "^${_key}:" "$_file" 2>/dev/null | head -1 | sed "s/^${_key}:[[:space:]]*//" | tr -d '"'
}

_yaml_set() {
  _file="$1"; _key="$2"; _val="$3"
  if grep -q "^${_key}:" "$_file" 2>/dev/null; then
    # sed in-place (POSIX portable)
    _tmp="${_file}.tmp"
    sed "s|^${_key}:.*|${_key}: \"${_val}\"|" "$_file" > "$_tmp" && mv "$_tmp" "$_file"
  else
    printf '%s: "%s"\n' "$_key" "$_val" >> "$_file"
  fi
}

_ts() {
  date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ
}

_init_state() {
  mkdir -p "$LOOP_DIR"
  if [ ! -f "$CURRENT_FILE" ]; then
    cat > "$CURRENT_FILE" <<'YAML'
---
task_title: ""
iteration: 0
max_iterations: 3
status: idle
last_result: ""
last_error: ""
started_at: ""
updated_at: ""
YAML
  fi
  if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" <<'MD'
# 루프 히스토리

<!-- loop-runner.sh 가 자동 append. 수동 편집 금지. -->

| 날짜 | 태스크 | 반복 횟수 | 결과 | 수렴 여부 |
|------|--------|-----------|------|----------|
MD
  fi
}

_reset_state() {
  _yaml_set "$CURRENT_FILE" "iteration" "0"
  _yaml_set "$CURRENT_FILE" "status" "idle"
  _yaml_set "$CURRENT_FILE" "last_result" ""
  _yaml_set "$CURRENT_FILE" "last_error" ""
  _yaml_set "$CURRENT_FILE" "updated_at" "$(_ts)"
  printf '[loop-runner] 상태 초기화 완료\n' >&2
}

_append_history() {
  _task="$1"; _iter="$2"; _result="$3"; _converged="$4"
  printf '| %s | %s | %d | %s | %s |\n' \
    "$(_ts)" "$_task" "$_iter" "$_result" "$_converged" >> "$HISTORY_FILE"
}

_write_fail_context() {
  _iter="$1"; _max="$2"; _cmd="$3"; _err="$4"
  cat > "$CONTEXT_FAIL_FILE" <<MD
## 루프 실패 컨텍스트

- **반복 횟수**: ${_iter} / ${_max}
- **검증 명령**: \`${_cmd}\`
- **마지막 오류**:

\`\`\`
${_err}
\`\`\`

> 이 파일은 context-loader.sh가 다음 세션에 자동 주입합니다.
> 수정 후 loop-runner.sh --reset 으로 상태를 초기화하세요.
MD
}

cmd_status() {
  _init_state
  printf '=== 루프 상태 ===\n'
  cat "$CURRENT_FILE"
}

cmd_reset() {
  _init_state
  _reset_state
}

cmd_check() {
  _verify_cmd="$1"
  printf '[loop-runner] 검증 실행: %s\n' "$_verify_cmd" >&2
  _err_out=$( eval "$_verify_cmd" 2>&1 ) && _exit=0 || _exit=$?
  if [ "$_exit" = "0" ]; then
    printf '[loop-runner] PASS\n' >&2
  else
    printf '[loop-runner] FAIL (exit %d)\n' "$_exit" >&2
    printf '%s\n' "$_err_out" >&2
  fi
  return "$_exit"
}

cmd_run() {
  _verify_cmd="$1"
  _max="${2:-$DEFAULT_MAX}"
  _init_state

  _task_title=$(_yaml_get "$HARNESS_ROOT/.harness/session/task.md" "title" 2>/dev/null || echo "unknown")

  _yaml_set "$CURRENT_FILE" "task_title" "$_task_title"
  _yaml_set "$CURRENT_FILE" "max_iterations" "$_max"
  _yaml_set "$CURRENT_FILE" "status" "running"
  _yaml_set "$CURRENT_FILE" "started_at" "$(_ts)"

  _iter=0

  while [ "$_iter" -lt "$_max" ]; do
    _iter=$((_iter + 1))
    _yaml_set "$CURRENT_FILE" "iteration" "$_iter"
    _yaml_set "$CURRENT_FILE" "updated_at" "$(_ts)"

    printf '[loop-runner] 반복 %d/%d — 검증 중: %s\n' "$_iter" "$_max" "$_verify_cmd" >&2

    _err_out=$( eval "$_verify_cmd" 2>&1 ) && _exit=0 || _exit=$?

    if [ "$_exit" = "0" ]; then
      _yaml_set "$CURRENT_FILE" "status" "converged"
      _yaml_set "$CURRENT_FILE" "last_result" "PASS"
      _yaml_set "$CURRENT_FILE" "last_error" ""
      _yaml_set "$CURRENT_FILE" "updated_at" "$(_ts)"
      _append_history "$_task_title" "$_iter" "PASS" "YES"
      printf '[loop-runner] 수렴 성공 (%d회차)\n' "$_iter" >&2
      rm -f "$CONTEXT_FAIL_FILE"
      return 0
    fi

    printf '[loop-runner] 반복 %d 실패 (exit %d)\n' "$_iter" "$_exit" >&2
    printf '%s\n' "$_err_out" >&2
    _yaml_set "$CURRENT_FILE" "last_result" "FAIL"
    _yaml_set "$CURRENT_FILE" "last_error" "$_err_out"
  done

  # max 초과 — 수렴 실패
  _yaml_set "$CURRENT_FILE" "status" "failed"
  _yaml_set "$CURRENT_FILE" "updated_at" "$(_ts)"
  _append_history "$_task_title" "$_iter" "FAIL" "NO"
  _write_fail_context "$_iter" "$_max" "$_verify_cmd" "$_err_out"

  printf '[loop-runner] 수렴 실패 — %d회 시도 후 포기. C10 제약 위반.\n' "$_max" >&2
  printf '  → 태스크를 더 작은 단위로 분할하거나 검증 명령을 확인하세요.\n' >&2
  printf '  → 실패 컨텍스트: %s\n' "$CONTEXT_FAIL_FILE" >&2
  return 1
}

# 인수 파싱
MAX_ITER="$DEFAULT_MAX"
MODE=""
VERIFY_CMD=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)   _usage; exit 0 ;;
    --status)    MODE="status"; shift ;;
    --reset)     MODE="reset"; shift ;;
    --check)     MODE="check"; shift; VERIFY_CMD="$1"; shift ;;
    --run)       MODE="run"; shift; VERIFY_CMD="$1"; shift ;;
    --max)       shift; MAX_ITER="$1"; shift ;;
    *) printf 'loop-runner: 알 수 없는 옵션: %s\n' "$1" >&2; _usage; exit 2 ;;
  esac
done

if [ -z "$MODE" ]; then
  _usage; exit 2
fi

case "$MODE" in
  status) cmd_status ;;
  reset)  cmd_reset ;;
  check)  cmd_check "$VERIFY_CMD" ;;
  run)    cmd_run "$VERIFY_CMD" "$MAX_ITER" ;;
esac
