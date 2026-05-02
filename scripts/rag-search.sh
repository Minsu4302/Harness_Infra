#!/bin/sh
# scripts/rag-search.sh — 키워드 기반 RAG 문서 검색
#
# 사용법:
#   rag-search.sh --task-file path/to/task.md [--top K] [--excerpt N]
#   rag-search.sh --query "keyword1 keyword2" [--top K] [--excerpt N]
#
# 출력: 관련 문서 발췌 (마크다운, current.md 주입용)
# 종료코드: 0 (항상 — 검색 결과 없어도 정상)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TOP_K=3
EXCERPT_LINES=12
QUERY=""
TASK_FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --top)       TOP_K="$2";         shift 2 ;;
    --excerpt)   EXCERPT_LINES="$2"; shift 2 ;;
    --query)     QUERY="$2";         shift 2 ;;
    --task-file) TASK_FILE="$2";     shift 2 ;;
    *) shift ;;
  esac
done

# task.md YAML 헤더에서 쿼리 추출
if [ -n "$TASK_FILE" ] && [ -f "$TASK_FILE" ]; then
  _title=$(awk '/^title:/{gsub(/^title:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$TASK_FILE")
  _type=$(awk '/^task_type:/{gsub(/^task_type:[[:space:]]*/,""); print; exit}' "$TASK_FILE")
  _goal=$(awk '/^goal:/{gsub(/^goal:[[:space:]]*/,""); print; exit}' "$TASK_FILE")
  QUERY="${_title} ${_type} ${_goal}"
fi

[ -z "$QUERY" ] && { printf '[rag-search] WARN: 쿼리 없음\n' >&2; exit 0; }

# 3자 이상 유의미한 키워드 추출 (영문·한국어 stopword 제거)
_keywords=$(printf '%s' "$QUERY" | tr -cs 'a-zA-Z가-힣0-9' '\n' | \
  awk 'length >= 3' | \
  grep -viE '^(the|and|for|with|this|that|from|have|are|its|was|been|has|not|but|can|will|all|get|set|use|run|how|each|per|via|path|file|dir)$' | \
  sort -u | tr '\n' ' ' | sed 's/ *$//')

[ -z "$_keywords" ] && { printf '[rag-search] WARN: 유효 키워드 없음\n' >&2; exit 0; }

printf '[rag-search] keywords: %s\n' "$_keywords" >&2

# ── 검색 대상 문서 수집 및 스코어링 ──────────────────────────────────────────

_tmp="${TMPDIR:-/tmp}/rag_$$"

for _dir in \
  "${HARNESS_ROOT}/docs/constraints" \
  "${HARNESS_ROOT}/docs/decisions" \
  "${HARNESS_ROOT}/docs/specs"; do
  [ -d "$_dir" ] || continue
  for _doc in "$_dir"/*.md; do
    [ -f "$_doc" ] || continue
    [ -s "$_doc" ] || continue  # .gitkeep 등 빈 파일 스킵

    _score=0
    for _kw in $_keywords; do
      # grep -c는 no-match 시 exit 1을 반환하므로 파이프로 exit code 격리
      _cnt=$(grep -ic "$_kw" "$_doc" 2>/dev/null | tr -d '[:space:]')
      _score=$(( _score + ${_cnt:-0} ))
    done

    [ "$_score" -gt 0 ] && printf '%04d %s\n' "$_score" "$_doc"
  done
done | sort -rn > "$_tmp" 2>/dev/null || true

# 결과 없으면 조용히 종료
if [ ! -s "$_tmp" ]; then
  printf '[rag-search] 관련 문서 없음\n' >&2
  rm -f "$_tmp"
  exit 0
fi

# ── 상위 K 문서 발췌 출력 ────────────────────────────────────────────────────

_rank=0
while IFS=' ' read -r _score _doc; do
  _rank=$(( _rank + 1 ))
  [ "$_rank" -gt "$TOP_K" ] && break

  _rel=$(printf '%s' "$_doc" | sed "s|${HARNESS_ROOT}/||g")
  _doc_title=$(awk '/^title:/{gsub(/^title:[[:space:]]*/,""); gsub(/"/,""); print; exit}' \
    "$_doc" 2>/dev/null)
  [ -z "$_doc_title" ] && _doc_title=$(basename "$_doc" .md)
  # score 앞의 0 패딩 제거
  _score_clean=$(printf '%s' "$_score" | sed 's/^0*//')
  [ -z "$_score_clean" ] && _score_clean=0

  printf '\n### [%d] %s\n\n> `%s` | relevance: %s\n\n' \
    "$_rank" "$_doc_title" "$_rel" "$_score_clean"

  # YAML frontmatter 제외하고 본문 EXCERPT_LINES 줄 출력
  awk -v n="$EXCERPT_LINES" '
    BEGIN { in_fm=0; body=0; out=0 }
    NR==1 && /^---$/ { in_fm=1; next }
    in_fm && /^---$/ { in_fm=0; body=1; next }
    in_fm { next }
    body && out < n { print; out++ }
  ' "$_doc"
done < "$_tmp"

rm -f "$_tmp"
