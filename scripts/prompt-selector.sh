#!/bin/sh
# prompt-selector.sh — 태스크 유형별 CoT 프롬프트 템플릿 선택 및 출력
#
# 사용법:
#   prompt-selector.sh --task-type feature   # feature 템플릿 출력
#   prompt-selector.sh --task-type bug       # bugfix 템플릿 출력
#   prompt-selector.sh --list                # 사용 가능한 템플릿 목록 출력
#   prompt-selector.sh --version             # 레지스트리 버전 출력

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROMPTS_DIR="${HARNESS_ROOT}/.harness/prompts"
EVENTS_DIR="${HARNESS_ROOT}/logs/events"

TASK_TYPE="general"
MODE="select"
_next=0

for _arg in "$@"; do
  case "$_arg" in
    --list)        MODE="list" ;;
    --version)     MODE="version" ;;
    --task-type)   _next=1 ;;
    feature|refactor|general)
      [ "$_next" = "1" ] && TASK_TYPE="$_arg" && _next=0 ;;
    bug|bugfix)
      [ "$_next" = "1" ] && TASK_TYPE="bugfix" && _next=0 ;;
    *)
      _next=0 ;;
  esac
done

_registry="${PROMPTS_DIR}/registry.yaml"
if [ ! -f "$_registry" ]; then
  printf 'ERROR: registry.yaml 없음: %s\n' "$_registry" >&2
  exit 1
fi

# ── list 모드 ─────────────────────────────────────────────────────────────────
if [ "$MODE" = "list" ]; then
  printf '사용 가능한 프롬프트 템플릿:\n'
  for _t in feature bugfix refactor general; do
    _path="${PROMPTS_DIR}/templates/${_t}.md"
    if [ -f "$_path" ]; then
      _ver=$(grep 'version:' "$_path" | head -1 | awk '{print $2}' | tr -d '"')
      printf '  %-12s v%s\n' "$_t" "$_ver"
    else
      printf '  %-12s (없음)\n' "$_t"
    fi
  done
  exit 0
fi

# ── version 모드 ──────────────────────────────────────────────────────────────
if [ "$MODE" = "version" ]; then
  grep 'schema_version:' "$_registry" | awk '{print $2}' | tr -d '"'
  exit 0
fi

# ── select 모드 ───────────────────────────────────────────────────────────────
_template="${PROMPTS_DIR}/templates/${TASK_TYPE}.md"
if [ ! -f "$_template" ]; then
  printf 'WARN: %s 템플릿 없음, general로 대체\n' "$TASK_TYPE" >&2
  _template="${PROMPTS_DIR}/templates/general.md"
  TASK_TYPE="general"
fi

# 이벤트 로깅 (observability)
mkdir -p "$EVENTS_DIR"
_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
_version=$(grep 'schema_version:' "$_registry" | awk '{print $2}' | tr -d '"')
printf '{"event":"prompt_selected","task_type":"%s","version":"%s","ts":"%s"}\n' \
  "$TASK_TYPE" "$_version" "$_ts" >> "${EVENTS_DIR}/prompt-events.jsonl"

printf '[prompt-selector] template=%s version=%s\n' "$TASK_TYPE" "$_version" >&2

cat "$_template"
