#!/bin/sh
# scripts/rag-search.sh — 키워드 기반 RAG 문서 검색
#
# 사용법:
#   rag-search.sh --task-file PATH [--top K] [--excerpt N]
#   rag-search.sh --query "keyword1 keyword2" [--top K] [--excerpt N]
#   rag-search.sh --no-cache        캐시 무시 (강제 재검색)
#   rag-search.sh --no-summaries    요약 캐시 미사용 (전체 발췌)
#   rag-search.sh --no-mmr          MMR 재랭킹 비활성화
#   rag-search.sh --lambda 0.5      MMR 다양성 가중치 (0=관련성, 1=다양성, 기본 0.5)
#
# 출력: 관련 문서 발췌 (마크다운, current.md 주입용)
# 종료코드: 0 (항상)

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TOP_K=3
EXCERPT_LINES=12
QUERY=""
TASK_FILE=""
NO_CACHE=0
USE_SUMMARIES=1
USE_MMR=1
LAMBDA="0.5"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --top)           TOP_K="$2";         shift 2 ;;
    --excerpt)       EXCERPT_LINES="$2"; shift 2 ;;
    --query)         QUERY="$2";         shift 2 ;;
    --task-file)     TASK_FILE="$2";     shift 2 ;;
    --no-cache)      NO_CACHE=1;         shift ;;
    --no-summaries)  USE_SUMMARIES=0;    shift ;;
    --no-mmr)        USE_MMR=0;          shift ;;
    --lambda)        LAMBDA="$2";        shift 2 ;;
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

# ── A2: 쿼리 해시 캐시 확인 ─────────────────────────────────────────────────

_cache_dir="${HARNESS_ROOT}/.harness/cache/rag"
_cache_key=$(printf '%s' "${_keywords} ${TOP_K} ${USE_MMR}" | cksum | cut -d' ' -f1)
_cache_file="${_cache_dir}/${_cache_key}.md"

if [ "$NO_CACHE" = "0" ] && [ -f "$_cache_file" ]; then
  _newer=$(find "${HARNESS_ROOT}/docs" -name "*.md" -newer "$_cache_file" 2>/dev/null | head -1)
  if [ -z "$_newer" ]; then
    printf '[rag-search] cache hit: %s\n' "$_cache_key" >&2
    cat "$_cache_file"
    exit 0
  fi
  printf '[rag-search] cache invalidated (docs changed)\n' >&2
fi

# ── 검색: 스코어링 + B1 MMR용 키워드 인덱스 수집 ────────────────────────────
# 임시 파일 형식: score<TAB>doc_path<TAB>kw_idx_list (공백 구분)

_tmp="${TMPDIR:-/tmp}/rag_$$"

for _dir in \
  "${HARNESS_ROOT}/docs/constraints" \
  "${HARNESS_ROOT}/docs/decisions" \
  "${HARNESS_ROOT}/docs/specs"; do
  [ -d "$_dir" ] || continue
  for _doc in "$_dir"/*.md; do
    [ -f "$_doc" ] || continue
    [ -s "$_doc" ] || continue

    _score=0
    _kw_idx=0
    _matches=""
    for _kw in $_keywords; do
      _cnt=$(grep -ic "$_kw" "$_doc" 2>/dev/null | tr -d '[:space:]')
      if [ "${_cnt:-0}" -gt 0 ]; then
        _score=$(( _score + _cnt ))
        _matches="${_matches}${_kw_idx} "
      fi
      _kw_idx=$(( _kw_idx + 1 ))
    done

    [ "$_score" -gt 0 ] && printf '%04d\t%s\t%s\n' "$_score" "$_doc" "${_matches% }"
  done
done | sort -rn > "$_tmp" 2>/dev/null || true

if [ ! -s "$_tmp" ]; then
  printf '[rag-search] 관련 문서 없음\n' >&2
  rm -f "$_tmp"
  exit 0
fi

# ── B1: MMR 재랭킹 ───────────────────────────────────────────────────────────
# MMR score(d) = relevance(d) - λ × max_sim(d, selected)
# max_sim = 선택된 문서들 중 키워드 인덱스 최대 겹침 수

_ranked="${TMPDIR:-/tmp}/rag_ranked_$$"

if [ "$USE_MMR" = "1" ]; then
  awk -F'\t' -v k="$TOP_K" -v lam="$LAMBDA" '
  BEGIN { total=0 }
  { score[++total]=$1+0; doc[total]=$2; kws[total]=$3 }
  END {
    for (round=1; round<=k && round<=total; round++) {
      best=-1; best_val=-9999999
      for (i=1; i<=total; i++) {
        if (i in used) continue
        if (round==1) {
          s = score[i]
        } else {
          max_sim=0
          n1=split(kws[i], a1, " ")
          for (j in used) {
            n2=split(kws[j], a2, " ")
            sim=0
            for (x=1; x<=n1; x++)
              for (y=1; y<=n2; y++)
                if (a1[x]!="" && a1[x]==a2[y]) sim++
            if (sim>max_sim) max_sim=sim
          }
          s = score[i] - lam * max_sim
        }
        if (s > best_val) { best_val=s; best=i }
      }
      if (best>0) { printf "%04d\t%s\n", score[best], doc[best]; used[best]=1 }
    }
  }
  ' "$_tmp" > "$_ranked"
  printf '[rag-search] MMR applied (lambda=%s)\n' "$LAMBDA" >&2
else
  awk -F'\t' -v k="$TOP_K" 'NR<=k{printf "%s\t%s\n",$1,$2}' "$_tmp" > "$_ranked"
fi

rm -f "$_tmp"

# ── 상위 K 문서 발췌 출력 ────────────────────────────────────────────────────

_out="${TMPDIR:-/tmp}/rag_out_$$"

_rank=0
while IFS='	' read -r _score _doc; do
  _rank=$(( _rank + 1 ))

  _rel=$(printf '%s' "$_doc" | sed "s|${HARNESS_ROOT}/||g")
  _doc_title=$(awk '/^title:/{gsub(/^title:[[:space:]]*/,""); gsub(/"/,""); print; exit}' \
    "$_doc" 2>/dev/null)
  [ -z "$_doc_title" ] && _doc_title=$(basename "$_doc" .md)
  _score_clean=$(printf '%s' "$_score" | sed 's/^0*//')
  [ -z "$_score_clean" ] && _score_clean=0

  printf '\n### [%d] %s\n\n> `%s` | relevance: %s\n\n' \
    "$_rank" "$_doc_title" "$_rel" "$_score_clean"

  # A3: summaries/ 캐시 우선 사용
  _summary="${HARNESS_ROOT}/.harness/cache/summaries/${_rel}"
  if [ "$USE_SUMMARIES" = "1" ] && [ -f "$_summary" ]; then
    cat "$_summary"
  else
    awk -v n="$EXCERPT_LINES" '
      BEGIN { in_fm=0; body=0; out=0 }
      NR==1 && /^---$/ { in_fm=1; next }
      in_fm && /^---$/ { in_fm=0; body=1; next }
      in_fm { next }
      body && out < n { print; out++ }
    ' "$_doc"
  fi
done < "$_ranked" > "$_out"

rm -f "$_ranked"

# ── A2: 결과 캐시 저장 ────────────────────────────────────────────────────────

if [ "$NO_CACHE" = "0" ]; then
  mkdir -p "$_cache_dir"
  cp "$_out" "$_cache_file"
  printf '[rag-search] cache written: %s\n' "$_cache_key" >&2
fi

cat "$_out"
rm -f "$_out"
