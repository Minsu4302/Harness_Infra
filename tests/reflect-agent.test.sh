#!/bin/sh
# tests/reflect-agent.test.sh — reflect-agent.sh 검증
# happy path: reflection.md 생성 + 필수 섹션 존재
# edge case 1: --dry-run 시 파일 미생성
# edge case 2: 히스토리 없을 때도 exit 0

set -eu

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
AGENT="${HARNESS_ROOT}/scripts/reflect-agent.sh"
REFLECTION="${HARNESS_ROOT}/.harness/reports/reflection.md"
PASS=0
FAIL=0

_ok()  { printf '  PASS: %s\n' "$1"; PASS=$(( PASS + 1 )); }
_err() { printf '  FAIL: %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

echo "=== reflect-agent 테스트 ==="

# ─────────────────────────────────────────────────────────────────────────────
# [0] --help exit 0
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [0] --help exit 0 ---"
sh "$AGENT" --help > /dev/null 2>&1 && _ok "--help exit 0" || _err "--help exit 0 실패"

# ─────────────────────────────────────────────────────────────────────────────
# [1] happy path: reflection.md 생성 + 필수 섹션 존재
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [1] happy path: reflection.md 생성 ---"

rm -f "$REFLECTION"
sh "$AGENT" > /dev/null 2>&1
_exit=$?

[ "$_exit" = "0" ] && _ok "exit 0" || _err "exit $_exit (기대: 0)"

[ -f "$REFLECTION" ] && _ok "reflection.md 생성됨" || _err "reflection.md 미생성"

# 필수 섹션 존재 확인
for _section in "반성 인사이트" "태스크 통계" "루프 통계" "인사이트"; do
  grep -q "$_section" "$REFLECTION" 2>/dev/null \
    && _ok "섹션 존재: ${_section}" \
    || _err "섹션 없음: ${_section}"
done

# ─────────────────────────────────────────────────────────────────────────────
# [2] edge case 1: --dry-run 시 파일 내용 변경 없음
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [2] edge case 1: --dry-run 파일 미수정 ---"

# 현재 파일 수정 시각 기록
_before=$(date -r "$REFLECTION" +%s 2>/dev/null || stat -c %Y "$REFLECTION" 2>/dev/null || echo "0")

# 1초 대기 없이 dry-run 실행 (타임스탬프 비교용)
sh "$AGENT" --dry-run > /dev/null 2>&1
_exit=$?

_after=$(date -r "$REFLECTION" +%s 2>/dev/null || stat -c %Y "$REFLECTION" 2>/dev/null || echo "0")

[ "$_exit" = "0" ] && _ok "--dry-run exit 0" || _err "--dry-run exit $_exit"

# dry-run은 파일을 건드리지 않아야 함 (수정 시각 동일)
[ "$_before" = "$_after" ] \
  && _ok "--dry-run 후 reflection.md 수정 시각 불변" \
  || _err "--dry-run 후 파일이 수정됨 (before=${_before}, after=${_after})"

# ─────────────────────────────────────────────────────────────────────────────
# [3] edge case 2: 히스토리 디렉토리 없어도 exit 0
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [3] edge case 2: 히스토리 없어도 정상 동작 ---"

_tmp_history="${HARNESS_ROOT}/.harness/reports/history"
_backup="${HARNESS_ROOT}/.harness/reports/history_bak_$$"

# 히스토리 임시 이동 (없는 상황 시뮬레이션)
[ -d "$_tmp_history" ] && mv "$_tmp_history" "$_backup" || true

sh "$AGENT" > /dev/null 2>&1
_exit=$?

[ "$_exit" = "0" ] && _ok "히스토리 없어도 exit 0" || _err "히스토리 없을 때 exit $_exit"
[ -f "$REFLECTION" ] && _ok "히스토리 없어도 reflection.md 생성" || _err "reflection.md 미생성"

# 복원
[ -d "$_backup" ] && mv "$_backup" "$_tmp_history" || true

# ─────────────────────────────────────────────────────────────────────────────
# [4] context-loader.sh 반성 인사이트 주입 확인
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- [4] context-loader.sh 반성 인사이트 주입 ---"

grep -q "반성 인사이트" "${HARNESS_ROOT}/scripts/context-loader.sh" \
  && _ok "context-loader.sh에 반성 인사이트 주입 코드 존재" \
  || _err "context-loader.sh에 반성 인사이트 주입 코드 없음"

# ─────────────────────────────────────────────────────────────────────────────
# 결과
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== 결과: PASS=${PASS} FAIL=${FAIL} ==="

[ "$FAIL" = "0" ] && exit 0 || exit 1
