#!/bin/sh
# tests/test-layer-a-cache.sh — Layer A 캐싱 기능 검증
# happy path + edge case 2개

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

_ok()  { printf '  PASS: %s\n' "$1"; PASS=$(( PASS + 1 )); }
_err() { printf '  FAIL: %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

echo "=== layer-a-cache 테스트 ==="

# ─────────────────────────────────────────────────────────────────────────────
# [1] happy path: doc-compress.sh 실행 후 summaries/ 파일 생성
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1] doc-compress.sh 요약 생성 ---"

SUMMARY_DIR="${HARNESS_ROOT}/.harness/cache/summaries"
rm -rf "$SUMMARY_DIR"

sh "${HARNESS_ROOT}/scripts/doc-compress.sh" >/dev/null 2>&1

_count=$(find "$SUMMARY_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
if [ "${_count:-0}" -gt 0 ]; then
  _ok "summaries/ 에 ${_count}개 요약 파일 생성"
else
  _err "summaries/ 파일 없음"
fi

# 요약이 5줄 이하인지 확인
_sample=$(find "$SUMMARY_DIR" -name "*.md" 2>/dev/null | head -1)
if [ -n "$_sample" ]; then
  _lines=$(wc -l < "$_sample" | tr -d '[:space:]')
  if [ "${_lines:-999}" -le 5 ]; then
    _ok "요약 파일 줄수 ${_lines} ≤ 5줄"
  else
    _err "요약 파일 줄수 ${_lines} > 5줄"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# [2] happy path: rag-search.sh 동일 쿼리 재실행 시 캐시 파일 생성 및 재사용
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2] RAG 쿼리 캐시 생성 및 재사용 ---"

CACHE_DIR="${HARNESS_ROOT}/.harness/cache/rag"
rm -rf "$CACHE_DIR"

# 첫 번째 실행 (캐시 미스)
sh "${HARNESS_ROOT}/scripts/rag-search.sh" --query "constraint worktree feature" \
  >/dev/null 2>&1 || true

_cache_count=$(find "$CACHE_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
if [ "${_cache_count:-0}" -gt 0 ]; then
  _ok "첫 실행 후 캐시 파일 ${_cache_count}개 생성"
else
  _err "첫 실행 후 캐시 파일 없음"
fi

# 두 번째 실행 — stderr에서 "cache hit" 확인
_log=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" --query "constraint worktree feature" \
  2>&1 >/dev/null || true)
if echo "$_log" | grep -q "cache hit"; then
  _ok "두 번째 실행에서 캐시 히트 확인"
else
  _err "두 번째 실행에서 캐시 히트 미감지 (log: ${_log})"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [3] edge case: --no-summaries 시 기본 발췌 사용 (출력이 summaries보다 김)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3] --no-summaries 플래그 동작 ---"

# 요약 있는 상태에서 summaries 사용 시 vs 미사용 시 줄수 비교
_with_sum=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" \
  --query "constraint worktree" --top 2 --no-cache 2>/dev/null | wc -l | tr -d '[:space:]')
_no_sum=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" \
  --query "constraint worktree" --top 2 --no-cache --no-summaries 2>/dev/null | \
  wc -l | tr -d '[:space:]')

if [ "${_with_sum:-0}" -le "${_no_sum:-0}" ]; then
  _ok "summaries 사용(${_with_sum}줄) ≤ 미사용(${_no_sum}줄) — 압축 효과 확인"
else
  _err "summaries 사용(${_with_sum}줄) > 미사용(${_no_sum}줄) — 예상과 반대"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [4] edge case: 소스 doc 변경 시 캐시 무효화
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4] 소스 doc 변경 시 캐시 무효화 ---"

# 초기 캐시 생성
CACHE_DIR="${HARNESS_ROOT}/.harness/cache/rag"
rm -rf "$CACHE_DIR"
sh "${HARNESS_ROOT}/scripts/rag-search.sh" --query "constraint worktree feature" \
  >/dev/null 2>&1 || true

# 캐시 파일 타임스탬프보다 최신인 doc 생성 (touch 사용)
_sample_doc="${HARNESS_ROOT}/docs/constraints/C01.md"
if [ -f "$_sample_doc" ]; then
  touch "$_sample_doc"
  _log2=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" --query "constraint worktree feature" \
    2>&1 >/dev/null || true)
  if echo "$_log2" | grep -q "invalidated"; then
    _ok "소스 doc 변경 후 캐시 무효화 확인"
  else
    _err "캐시 무효화 미감지 (log: ${_log2})"
  fi
else
  _err "테스트용 소스 doc 없음: ${_sample_doc}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 결과 요약
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== 결과: PASS=${PASS}, FAIL=${FAIL} ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
