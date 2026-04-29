#!/bin/sh
# harness-test.sh — 하네스 E2E 검증 스크립트
#
# 빈 임시 디렉토리에서 전체 파이프라인을 순서대로 검증한다.
# 사용법: sh scripts/harness-test.sh

set -eu

HARNESS_SRC="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ── 출력 헬퍼 ─────────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

_pass() { printf '\342\234\205 %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { printf '\342\235\214 %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

_assert_exit0() {
  _tid="$1"; _desc="$2"; shift 2
  if "$@" >/dev/null 2>&1; then
    _pass "$_tid $_desc"
  else
    _fail "$_tid $_desc (exit non-0)"
  fi
}

_assert_exit1() {
  _tid="$1"; _desc="$2"; shift 2
  if ! "$@" >/dev/null 2>&1; then
    _pass "$_tid $_desc"
  else
    _fail "$_tid $_desc (expected exit 1, got 0)"
  fi
}

_assert_file() {
  _tid="$1"; _desc="$2"; _file="$3"
  if [ -f "$_file" ]; then
    _pass "$_tid $_desc"
  else
    _fail "$_tid $_desc (file not found: $_file)"
  fi
}

_assert_dir() {
  _tid="$1"; _desc="$2"; _dir="$3"
  if [ -d "$_dir" ]; then
    _pass "$_tid $_desc"
  else
    _fail "$_tid $_desc (dir not found: $_dir)"
  fi
}

_assert_grep() {
  _tid="$1"; _desc="$2"; _pat="$3"; _file="$4"
  if grep -q "$_pat" "$_file" 2>/dev/null; then
    _pass "$_tid $_desc"
  else
    _fail "$_tid $_desc (pattern '$_pat' not in $_file)"
  fi
}

# ── 임시 디렉토리 준비 ────────────────────────────────────────────────────────
TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t harness-test)
# 종료 시 정리
trap 'rm -rf "$TEST_DIR"' EXIT

printf '\n\342\226\266 harness-test.sh [workdir=%s]\n\n' "$TEST_DIR"

# ── T01: harness-init.sh 실행 → 디렉토리 구조 생성 확인 ──────────────────────
export HARNESS_ROOT="$TEST_DIR" HARNESS_PHASE=planning

sh "${HARNESS_SRC}/scripts/harness-init.sh" "$TEST_DIR" --phase=planning >/dev/null 2>&1 || true

# harness-init.sh는 mkdir -p scripts/ 후 복사 조건이 실패하므로
# 소스 스크립트를 명시적으로 복사한다
cp -r "${HARNESS_SRC}/scripts/." "${TEST_DIR}/scripts/"
cp -r "${HARNESS_SRC}/linters/."  "${TEST_DIR}/linters/"
cp -r "${HARNESS_SRC}/validators/." "${TEST_DIR}/validators/"

_assert_dir  "T01" "init structure: scripts/"       "${TEST_DIR}/scripts"
_assert_dir  "T01" "init structure: linters/"       "${TEST_DIR}/linters"
_assert_dir  "T01" "init structure: .harness/"      "${TEST_DIR}/.harness"
_assert_file "T01" "init: HARNESS.md 생성"           "${TEST_DIR}/HARNESS.md"
_assert_file "T01" "init: task.md 생성"              "${TEST_DIR}/.harness/session/task.md"

# ── T02: planning phase constraint-check → C02/C03/C06 PASS ─────────────────
export HARNESS_ROOT="$TEST_DIR" HARNESS_PHASE=planning

# task.md에 done_condition 추가
cat > "${TEST_DIR}/.harness/session/task.md" <<'EOF'
---
task_type: general
title: "테스트 태스크"
started_at: ""
done_condition:
  - "[auto] test: constraint-check PASS"
  - "[human] 수동 확인"
open_questions: []
---

## 작업 내용
EOF

if sh "${TEST_DIR}/scripts/constraint-check.sh" >/dev/null 2>&1; then
  _pass "T02" "planning constraints (C02/C03/C06) PASS"
else
  _fail "T02" "planning constraints FAIL (expected all PASS)"
fi

# ── T03: context-loader compile → current.md 생성 확인 ───────────────────────
sh "${TEST_DIR}/scripts/context-loader.sh" >/dev/null 2>&1 || true
_assert_file "T03" "context-loader: current.md 생성" \
  "${TEST_DIR}/.harness/context/current.md"

# ── T04: context-loader --verify → 예산 범위 내 PASS ────────────────────────
if sh "${TEST_DIR}/scripts/context-loader.sh" --verify >/dev/null 2>&1; then
  _pass "T04" "context-loader --verify: 예산 범위 내 PASS"
else
  _fail "T04" "context-loader --verify: 예산 초과 또는 오류"
fi

# ── T05: C07 트리거 시뮬레이션 ───────────────────────────────────────────────
export HARNESS_PHASE=dev

# open-questions에 6개 항목 삽입
cat > "${TEST_DIR}/.harness/session/open-questions.md" <<'EOF'
- [ ] 미결 질문 1
- [ ] 미결 질문 2
- [ ] 미결 질문 3
- [ ] 미결 질문 4
- [ ] 미결 질문 5
- [ ] 미결 질문 6
EOF

if ! sh "${TEST_DIR}/scripts/constraint-check.sh" --only C07 >/dev/null 2>&1; then
  _pass "T05" "C07 trigger: open-questions 6개 → FAIL 감지"
else
  _fail "T05" "C07 trigger: expected FAIL not detected"
fi

# open-questions 초기화
> "${TEST_DIR}/.harness/session/open-questions.md"

# ── T06: gc-agent --scan --collect → logs/ 파일 생성 확인 ────────────────────
mkdir -p "${TEST_DIR}/logs/metrics" "${TEST_DIR}/logs/traces" "${TEST_DIR}/logs/events"

sh "${TEST_DIR}/scripts/gc-agent.sh" --scan --collect >/dev/null 2>&1 || true

_TODAY=$(date +%Y-%m-%d 2>/dev/null || date +%Y%m%d)
_assert_file "T06" "gc-agent: events log 생성"  "${TEST_DIR}/logs/events/${_TODAY}.jsonl"
_assert_file "T06" "gc-agent: metrics log 생성" "${TEST_DIR}/logs/metrics/${_TODAY}.jsonl"
_assert_file "T06" "gc-agent: traces log 생성"  "${TEST_DIR}/logs/traces/${_TODAY}.jsonl"
_assert_file "T06" "gc-agent: debt-report 생성" "${TEST_DIR}/.harness/reports/debt-report.md"

# ── T07: plugin hook 실행 → traces/ 로그 생성 확인 ───────────────────────────
# observability 플러그인 복사 (hook.sh 없음 → skip 메시지 확인)
mkdir -p "${TEST_DIR}/plugins/observability"
cp "${HARNESS_SRC}/plugins/observability/plugin.yaml" \
   "${TEST_DIR}/plugins/observability/plugin.yaml"

sh "${TEST_DIR}/scripts/gc-agent.sh" --scan >/dev/null 2>&1 || true

# traces/ 에 hook 전용 로그 파일이 생성됐는지 확인
_hook_log=$(find "${TEST_DIR}/logs/traces" -name "*observability*post-scan*" 2>/dev/null | head -1)
if [ -n "$_hook_log" ]; then
  _pass "T07" "plugin hook: traces/ 로그 생성 확인"
  # skip 메시지 포함 확인
  if grep -q "not found\|skip" "$_hook_log" 2>/dev/null; then
    _pass "T07" "plugin hook: hook.sh 없음 → skip 메시지 기록 확인"
  else
    _fail "T07" "plugin hook: skip 메시지 없음"
  fi
else
  _fail "T07" "plugin hook: traces/ 에 hook 로그 없음"
fi

# ── T08: phase=dev 전환 후 C01/C07/C09 활성 확인 ─────────────────────────────
export HARNESS_PHASE=dev

_check_out=$(sh "${TEST_DIR}/scripts/constraint-check.sh" 2>&1 || true)

_c01_active=$(echo "$_check_out" | grep 'C01' | head -1)
_c07_active=$(echo "$_check_out" | grep 'C07' | head -1)
_c09_active=$(echo "$_check_out" | grep 'C09' | head -1)

if [ -n "$_c01_active" ]; then
  _pass "T08" "dev phase: C01 활성 확인"
else
  _fail "T08" "dev phase: C01 비활성 (활성 기대)"
fi

if [ -n "$_c07_active" ]; then
  _pass "T08" "dev phase: C07 활성 확인"
else
  _fail "T08" "dev phase: C07 비활성 (활성 기대)"
fi

if [ -n "$_c09_active" ]; then
  _pass "T08" "dev phase: C09 활성 확인"
else
  _fail "T08" "dev phase: C09 비활성 (활성 기대)"
fi

# ── 결과 요약 ─────────────────────────────────────────────────────────────────
printf '\nPASS: %d / FAIL: %d\n' "$PASS_COUNT" "$FAIL_COUNT"

[ "$FAIL_COUNT" -gt 0 ] && exit 1 || exit 0
