#!/bin/sh
# harness-init.sh — 하네스 초기화 및 플러그인 관리
#
# 사용법:
#   harness-init.sh [PROJECT_DIR] [--phase=planning|dev|stab|prod]
#   harness-init.sh --list-plugins
#   harness-init.sh --add-plugin PLUGIN_DIR
#   harness-init.sh --remove-plugin PLUGIN_NAME

set -eu

HARNESS_SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 옵션 파싱
PROJECT_DIR="."
PHASE="planning"
CMD="init"
PLUGIN_ARG=""

for _arg in "$@"; do
  case "$_arg" in
    --phase=*)       PHASE="${_arg#--phase=}" ;;
    --list-plugins)  CMD="list-plugins" ;;
    --add-plugin)    CMD="add-plugin"; _next_plugin=1 ;;
    --remove-plugin) CMD="remove-plugin"; _next_plugin=1 ;;
    /*)              [ "${_next_plugin:-0}" = "1" ] && PLUGIN_ARG="$_arg" && _next_plugin=0 || PROJECT_DIR="$_arg" ;;
    ./*|../*|[A-Za-z]*)
      [ "${_next_plugin:-0}" = "1" ] && PLUGIN_ARG="$_arg" && _next_plugin=0 || PROJECT_DIR="$_arg" ;;
  esac
done

PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")"
PLUGINS_DIR="${PROJECT_DIR}/plugins"

# ── 플러그인 목록 ─────────────────────────────────────────────────────────────
list_plugins() {
  printf '=== 등록된 플러그인 ===\n'
  if [ ! -d "$PLUGINS_DIR" ]; then
    printf '  (없음)\n'
    return
  fi
  _count=0
  for _yaml in "$PLUGINS_DIR"/*/plugin.yaml; do
    [ -f "$_yaml" ] || continue
    _name=$(grep '^name:' "$_yaml" | sed 's/name:[[:space:]]*//' | tr -d '"' | head -1)
    _ver=$(grep '^version:' "$_yaml" | sed 's/version:[[:space:]]*//' | tr -d '"' | head -1)
    _hooks=$(grep -A 20 '^hooks:' "$_yaml" | grep '^\s*-' | tr -d ' -' | tr '\n' ',' | sed 's/,$//')
    printf '  [%s] v%s  hooks: %s\n' "${_name:-unknown}" "${_ver:-?}" "${_hooks:-(없음)}"
    _count=$((_count + 1))
  done
  [ "$_count" -eq 0 ] && printf '  (없음)\n'
}

# ── 플러그인 추가 ─────────────────────────────────────────────────────────────
add_plugin() {
  _src="$1"
  if [ ! -f "${_src}/plugin.yaml" ]; then
    printf 'ERROR: %s/plugin.yaml 없음\n' "$_src" >&2
    exit 1
  fi
  _name=$(grep '^name:' "${_src}/plugin.yaml" | sed 's/name:[[:space:]]*//' | tr -d '"' | head -1)
  _dest="${PLUGINS_DIR}/${_name}"
  mkdir -p "$_dest"
  cp -r "${_src}/." "$_dest/"
  printf 'plugin [%s] 추가됨 → %s\n' "$_name" "$_dest"
}

# ── 플러그인 제거 ─────────────────────────────────────────────────────────────
remove_plugin() {
  _name="$1"
  _dest="${PLUGINS_DIR}/${_name}"
  if [ ! -d "$_dest" ]; then
    printf 'ERROR: 플러그인 [%s] 없음\n' "$_name" >&2
    exit 1
  fi
  rm -rf "$_dest"
  printf 'plugin [%s] 제거됨\n' "$_name"
}

# ── 초기화 ────────────────────────────────────────────────────────────────────
do_init() {
  printf '=== harness-init [project=%s, phase=%s] ===\n' "$PROJECT_DIR" "$PHASE"

  # 필수 디렉토리
  for _d in scripts linters validators plugins docs/decisions docs/constraints \
             docs/specs docs/reference logs/metrics logs/traces logs/events \
             .harness/session .harness/context .harness/reports/history; do
    mkdir -p "${PROJECT_DIR}/${_d}"
  done

  # HARNESS.md 없으면 기본 생성
  _hmd="${PROJECT_DIR}/HARNESS.md"
  if [ ! -f "$_hmd" ]; then
    cat > "$_hmd" <<HEOF
---
project: $(basename "$PROJECT_DIR")
version: "0.1.0"
phase: ${PHASE}
context_budget:
  max_lines: 400
  warn_lines: 320
phase_constraints:
  planning: [C02, C03, C06]
  dev:      [C01, C02, C03, C07, C09]
  stab:     [C01, C02, C03, C04, C07, C08, C09]
  prod:     [C01, C02, C03, C04, C05, C07, C08, C09]
c07:
  time_threshold_hours: 4
  context_budget_consecutive: 3
  open_questions_max: 5
---

# HARNESS.md
HEOF
    printf '  HARNESS.md 생성됨\n'
  fi

  # task.md 없으면 기본 생성
  _task="${PROJECT_DIR}/.harness/session/task.md"
  if [ ! -f "$_task" ]; then
    cat > "$_task" <<TEOF
---
task_type: general
title: ""
started_at: ""
done_condition:
  - "[auto] test: "
  - "[human] "
open_questions: []
---

## 작업 내용

## 결정 사항
TEOF
    printf '  .harness/session/task.md 생성됨\n'
  fi

  # 하네스 스크립트를 project에 심볼릭 링크 또는 복사
  if [ "$PROJECT_DIR" != "$HARNESS_SELF_DIR" ]; then
    for _f in scripts linters validators; do
      if [ ! -e "${PROJECT_DIR}/${_f}" ]; then
        cp -r "${HARNESS_SELF_DIR}/${_f}" "${PROJECT_DIR}/${_f}"
        printf '  %s/ 복사됨\n' "$_f"
      fi
    done
  fi

  # 플러그인 훅 등록
  _hook_count=0
  for _yaml in "${PLUGINS_DIR}"/*/plugin.yaml; do
    [ -f "$_yaml" ] || continue
    _name=$(grep '^name:' "$_yaml" | sed 's/name:[[:space:]]*//' | tr -d '"' | head -1)
    printf '  plugin [%s] 훅 등록됨\n' "${_name:-?}"
    _hook_count=$((_hook_count + 1))
  done

  printf '\n초기화 완료 (플러그인: %d개)\n' "$_hook_count"
  printf 'phase=%s 로 시작하려면:\n' "$PHASE"
  printf '  export HARNESS_ROOT=%s HARNESS_PHASE=%s\n' "$PROJECT_DIR" "$PHASE"
  printf '  scripts/context-loader.sh\n'
}

# 명령 분기
case "$CMD" in
  list-plugins)  list_plugins ;;
  add-plugin)    add_plugin "$PLUGIN_ARG" ;;
  remove-plugin) remove_plugin "$PLUGIN_ARG" ;;
  init)          do_init ;;
esac
