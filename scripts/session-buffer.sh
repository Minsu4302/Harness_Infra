#!/bin/sh
# scripts/session-buffer.sh — 세션 완료 이력 버퍼 관리
#
# 사용법:
#   session-buffer.sh --export                현재 버퍼 출력 (context 주입용)
#   session-buffer.sh --append "요약 텍스트"   항목 추가 (최신이 맨 위)
#   session-buffer.sh --append-from-task PATH  완료된 task.md에서 자동 추출
#   session-buffer.sh --clear                  버퍼 초기화
#
# 저장 위치: .harness/session/buffer.md
# 최대 항목: 10개 (FIFO, 초과 시 오래된 항목 제거)
# 종료코드: 0 (항상)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BUFFER_FILE="${HARNESS_ROOT}/.harness/session/buffer.md"
MAX_ENTRIES=10

CMD=""
ARG=""
_next_arg=0
for _a in "$@"; do
  case "$_a" in
    --export)           CMD="export" ;;
    --clear)            CMD="clear" ;;
    --append)           CMD="append";      _next_arg=1 ;;
    --append-from-task) CMD="append-task"; _next_arg=1 ;;
    *)
      if [ "$_next_arg" = "1" ]; then ARG="$_a"; _next_arg=0; fi ;;
  esac
done

# 버퍼에 항목 추가 (최신이 맨 위, MAX_ENTRIES 초과 시 하단 제거)
_append_entry() {
  _date=$(date +%Y-%m-%d 2>/dev/null || echo "unknown")
  _new_line="- [${_date}] $1"
  mkdir -p "$(dirname "$BUFFER_FILE")"

  if [ ! -f "$BUFFER_FILE" ]; then
    printf '%s\n' "$_new_line" > "$BUFFER_FILE"
  else
    _existing=$(grep -v '^$' "$BUFFER_FILE" 2>/dev/null | head -$(( MAX_ENTRIES - 1 )) || true)
    { printf '%s\n' "$_new_line"; printf '%s\n' "$_existing"; } > "$BUFFER_FILE"
  fi
  printf '[session-buffer] appended: %s\n' "$1" >&2
}

case "$CMD" in
  export)
    if [ -f "$BUFFER_FILE" ]; then
      cat "$BUFFER_FILE"
    else
      printf '(완료된 세션 이력 없음)\n'
    fi
    ;;

  append)
    [ -n "$ARG" ] && _append_entry "$ARG"
    ;;

  append-task)
    if [ -n "$ARG" ] && [ -f "$ARG" ]; then
      _title=$(awk '/^title:/{gsub(/^title:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$ARG")
      _status=$(awk '/^status:/{gsub(/^status:[[:space:]]*/,""); print; exit}' "$ARG")
      _task_type=$(awk '/^task_type:/{gsub(/^task_type:[[:space:]]*/,""); print; exit}' "$ARG")
      if [ "$_status" = "completed" ] && [ -n "$_title" ]; then
        _append_entry "${_task_type}(${_status}): ${_title}"
      fi
    fi
    ;;

  clear)
    rm -f "$BUFFER_FILE"
    printf '[session-buffer] buffer cleared\n' >&2
    ;;

  *)
    printf 'usage: session-buffer.sh --export|--append TEXT|--append-from-task PATH|--clear\n' >&2
    exit 1
    ;;
esac
exit 0
