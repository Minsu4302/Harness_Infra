#!/bin/sh
# prompt-selector.sh — 태스크 유형별 CoT 프롬프트 템플릿 선택 및 출력
#
# 사용법:
#   prompt-selector.sh --task-type feature   # feature 템플릿 출력
#   prompt-selector.sh --task-type bug       # bugfix 템플릿 출력
#   prompt-selector.sh --list                # 사용 가능한 템플릿 목록 출력
#   prompt-selector.sh --version             # 레지스트리 버전 출력
#
# Conditional CoT: task.md의 complexity 필드에 따라 출력 범위 조정
#   low    → 완료 체크리스트만 출력 (CoT 생략)
#   medium → Phase 1 + Phase 3 + 체크리스트 (Phase 2 생략)
#   high   → 전체 템플릿 (기본값)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROMPTS_DIR="${HARNESS_ROOT}/.harness/prompts"
EVENTS_DIR="${HARNESS_ROOT}/logs/events"
TASK_FILE="${HARNESS_ROOT}/.harness/session/task.md"

TASK_TYPE="general"
COMPLEXITY=""
MODE="select"
_next=0

for _arg in "$@"; do
  case "$_arg" in
    --list)        MODE="list" ;;
    --version)     MODE="version" ;;
    --task-type)   _next=1 ;;
    --complexity)  _next=2 ;;
    feature|refactor|general)
      [ "$_next" = "1" ] && TASK_TYPE="$_arg" && _next=0 ;;
    bug|bugfix)
      [ "$_next" = "1" ] && TASK_TYPE="bugfix" && _next=0 ;;
    low|medium|high)
      [ "$_next" = "2" ] && COMPLEXITY="$_arg" && _next=0 ;;
    *)
      _next=0 ;;
  esac
done

# --complexity 미지정 시 task.md에서 읽기 (기본값 high)
if [ -z "$COMPLEXITY" ]; then
  COMPLEXITY="high"
  if [ -f "$TASK_FILE" ]; then
    _c=$(awk '/^complexity:/{gsub(/^complexity:[[:space:]]*/,""); gsub(/"/,""); print; exit}' \
      "$TASK_FILE" 2>/dev/null || true)
    case "${_c:-}" in
      low|medium|high) COMPLEXITY="$_c" ;;
    esac
  fi
fi

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
printf '{"event":"prompt_selected","task_type":"%s","complexity":"%s","version":"%s","ts":"%s"}\n' \
  "$TASK_TYPE" "$COMPLEXITY" "$_version" "$_ts" >> "${EVENTS_DIR}/prompt-events.jsonl"

printf '[prompt-selector] template=%s complexity=%s version=%s\n' "$TASK_TYPE" "$COMPLEXITY" "$_version" >&2

# complexity에 따른 조건부 출력
case "$COMPLEXITY" in
  low)
    # CoT 전체 생략 — 완료 체크리스트만 출력
    awk '/^## 완료 체크리스트/,0' "$_template"
    ;;
  medium)
    # Phase 2(선택적 심화) 블록을 제거하고 출력
    awk '
      /^### Phase 2/ { skip=1; next }
      skip && /^### Phase/ { skip=0 }
      !skip { print }
    ' "$_template"
    ;;
  *)
    # high 또는 미지정 — 전체 템플릿 출력
    cat "$_template"
    ;;
esac
