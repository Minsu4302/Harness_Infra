#!/bin/sh
# scripts/doc-compress.sh — 문서별 5줄 요약 사전 생성
#
# 사용법:
#   doc-compress.sh           docs/ 전체 처리 (변경된 파일만)
#   doc-compress.sh --force   모든 파일 강제 재생성
#
# 출력: .harness/cache/summaries/<rel-path>
# 종료코드: 0 (항상)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SUMMARY_DIR="${HARNESS_ROOT}/.harness/cache/summaries"
SUMMARY_LINES=5
FORCE=0

for _arg in "$@"; do
  case "$_arg" in
    --force) FORCE=1 ;;
  esac
done

_processed=0
_skipped=0

for _dir in \
  "${HARNESS_ROOT}/docs/constraints" \
  "${HARNESS_ROOT}/docs/decisions" \
  "${HARNESS_ROOT}/docs/specs"; do
  [ -d "$_dir" ] || continue
  for _doc in "$_dir"/*.md; do
    [ -f "$_doc" ] || continue
    [ -s "$_doc" ] || continue

    _rel=$(printf '%s' "$_doc" | sed "s|${HARNESS_ROOT}/||g")
    _out="${SUMMARY_DIR}/${_rel}"

    # 요약 파일이 최신이면 스킵 (--force 아닌 경우)
    if [ "$FORCE" = "0" ] && [ -f "$_out" ] && [ "$_out" -nt "$_doc" ] 2>/dev/null; then
      _skipped=$(( _skipped + 1 ))
      continue
    fi

    mkdir -p "$(dirname "$_out")"

    # frontmatter 제외 후 핵심 줄 추출:
    # # 또는 ## 헤딩, 불릿(- 또는 *), 비어있지 않은 일반 텍스트 — 최대 SUMMARY_LINES줄
    awk -v n="$SUMMARY_LINES" '
      BEGIN { in_fm=0; body=0; out=0 }
      NR==1 && /^---$/ { in_fm=1; next }
      in_fm && /^---$/ { in_fm=0; body=1; next }
      in_fm { next }
      !body { next }
      out >= n { exit }
      /^[[:space:]]*$/ { next }
      /^(#|##|###|-|\*)/ { print; out++; next }
      out == 0 { print; out++ }
    ' "$_doc" > "$_out"

    _processed=$(( _processed + 1 ))
  done
done

printf '[doc-compress] processed: %d, skipped (up-to-date): %d\n' "$_processed" "$_skipped" >&2
exit 0
