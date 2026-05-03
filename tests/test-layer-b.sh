#!/bin/sh
# tests/test-layer-b.sh — Layer B 기능 검증
# happy path + edge case 2개

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

_ok()  { printf '  PASS: %s\n' "$1"; PASS=$(( PASS + 1 )); }
_err() { printf '  FAIL: %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

echo "=== layer-b 테스트 ==="

# ─────────────────────────────────────────────────────────────────────────────
# [1] happy path: MMR ON/OFF 시 결과 순서가 달라질 수 있는지 확인
#     (단일 결과 쿼리에서는 동일, 다중 결과 쿼리에서 다를 수 있음)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1] MMR 재랭킹 동작 확인 ---"

# MMR과 no-MMR 모두 결과를 반환하는지 확인 (--no-summaries --no-cache로 캐시 영향 제외)
_mmr_out=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" \
  --query "constraint security" --top 3 --no-cache --no-summaries 2>/dev/null | wc -l | tr -d '[:space:]')
_nommmr_out=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" \
  --query "constraint security" --top 3 --no-cache --no-summaries --no-mmr 2>/dev/null | wc -l | tr -d '[:space:]')

if [ "${_mmr_out:-0}" -gt 0 ]; then
  _ok "MMR ON: ${_mmr_out}줄 출력"
else
  _err "MMR ON: 출력 없음"
fi

if [ "${_nommmr_out:-0}" -gt 0 ]; then
  _ok "MMR OFF: ${_nommmr_out}줄 출력"
else
  _err "MMR OFF: 출력 없음"
fi

# MMR stderr에 'MMR applied' 로그 확인
_mmr_log=$(sh "${HARNESS_ROOT}/scripts/rag-search.sh" \
  --query "constraint security" --top 3 --no-cache --no-summaries 2>&1 >/dev/null || true)
if echo "$_mmr_log" | grep -q "MMR applied"; then
  _ok "MMR 적용 로그 확인"
else
  _err "MMR 적용 로그 없음 (log: ${_mmr_log})"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [2] happy path: session-buffer.sh --append-from-task 로 완료 태스크 기록
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2] session-buffer.sh 완료 태스크 기록 ---"

BUFFER_FILE="${HARNESS_ROOT}/.harness/session/buffer.md"
rm -f "$BUFFER_FILE"

# 완료 상태 task.md 임시 생성
_tmp_task="${TMPDIR:-/tmp}/test_task_$$.md"
cat > "$_tmp_task" <<'TASK'
---
task_type: feature
title: "테스트 태스크"
status: completed
---
TASK

sh "${HARNESS_ROOT}/scripts/session-buffer.sh" --append-from-task "$_tmp_task" 2>/dev/null
rm -f "$_tmp_task"

if [ -f "$BUFFER_FILE" ] && grep -q "테스트 태스크" "$BUFFER_FILE"; then
  _ok "buffer.md에 완료 태스크 항목 기록"
else
  _err "buffer.md에 완료 태스크 없음"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [3] edge case: in_progress 태스크는 버퍼에 추가되지 않음
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3] 미완료 태스크 버퍼 제외 ---"

_buf_before=$(wc -l < "$BUFFER_FILE" 2>/dev/null | tr -d '[:space:]' || echo "0")

_tmp_task2="${TMPDIR:-/tmp}/test_task2_$$.md"
cat > "$_tmp_task2" <<'TASK'
---
task_type: feature
title: "진행 중 태스크"
status: in_progress
---
TASK

sh "${HARNESS_ROOT}/scripts/session-buffer.sh" --append-from-task "$_tmp_task2" 2>/dev/null
rm -f "$_tmp_task2"

_buf_after=$(wc -l < "$BUFFER_FILE" 2>/dev/null | tr -d '[:space:]' || echo "0")

if [ "${_buf_before:-0}" -eq "${_buf_after:-0}" ]; then
  _ok "in_progress 태스크는 버퍼 미추가 확인"
else
  _err "in_progress 태스크가 버퍼에 추가됨 (before=${_buf_before}, after=${_buf_after})"
fi

# ─────────────────────────────────────────────────────────────────────────────
# [4] edge case: context-loader.sh 실행 후 current.md에 '세션 버퍼' 섹션 포함
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4] context-loader.sh 세션 버퍼 섹션 주입 ---"

sh "${HARNESS_ROOT}/scripts/context-loader.sh" --task-type feature >/dev/null 2>&1 || true

CURRENT_MD="${HARNESS_ROOT}/.harness/context/current.md"
if [ -f "$CURRENT_MD" ] && grep -q "세션 버퍼" "$CURRENT_MD"; then
  _ok "current.md에 '세션 버퍼' 섹션 포함"
else
  _err "current.md에 '세션 버퍼' 섹션 없음"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 결과 요약
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== 결과: PASS=${PASS}, FAIL=${FAIL} ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
