---
title: Reliability Standards
watches:
  - scripts/
  - linters/
  - .harness/reports/debt-report.md
last_reviewed: 2026-04-29
---

# Reliability Standards

`validators/completion-check.sh`와 `gc-agent` 피드백의 판단 기준 문서.

## SLO 정의 템플릿

프로젝트별로 아래 표를 채워 넣는다. 빈 칸은 팀 합의 후 기입.

| SLO 항목 | 목표 | 측정 방법 | 경보 임계값 |
|---------|------|---------|-----------|
| 가용성 | ___% | (모니터링 도구) | ___% 미만 |
| 응답시간 p50 | ___ms | (APM 도구) | ___ms 초과 |
| 응답시간 p99 | ___ms | (APM 도구) | ___ms 초과 |
| 에러율 | ___% | (로그 집계) | ___% 초과 |
| 배포 성공률 | ___% | CI/CD 기록 | ___% 미만 |

### 하네스 자체 SLO

| 항목 | 목표 | 경보 |
|------|------|------|
| constraint-check.sh 실행 시간 | 5분 이내 | 5분 초과 |
| context_budget_pct | 80% 미만 유지 | 3회 연속 초과 (C07) |
| GC 스캔 주기 | 주 1회 | 7일 초과 (C04) |

## 복구 절차 (Runbook)

각 장애 유형별 Runbook 링크를 아래에 기입한다.

| 장애 유형 | Runbook | 담당자 |
|---------|---------|-------|
| constraint-check 전체 FAIL | (링크) | (팀) |
| context 예산 초과 | `scripts/context-loader.sh --verify` → gc-agent 실행 | AI Agent |
| C07 체크포인트 강제 | `.harness/session/` 스냅샷 확인 후 재시작 | AI Agent |
| 빌드 실패 | (링크) | (팀) |

## 기술 부채 임계값 (gc-agent 판단 기준)

`gc-agent.sh --scan`이 `debt-report.md`를 생성할 때 사용하는 기준.

### 파일 크기

| 기준 | 판정 |
|------|------|
| 스크립트 > 1000줄 | CRITICAL |
| 스크립트 > 800줄 | WARN |
| HARNESS.md > 100줄 | WARN (C03 위반 예고) |

### 세션 상태

| 기준 | 판정 |
|------|------|
| task.md started_at 경과 > 4h | WARN → C07 FAIL |
| open-questions.md 항목 > 5개 | WARN → C07 FAIL |
| budget_warn_streak > 3회 | WARN → C07 FAIL |

### 제약 조건 누적 FAIL

| 기준 | 판정 |
|------|------|
| 동일 C번호 3회 연속 FAIL | CRITICAL |
| 전체 pass_rate < 80% | WARN |
| 전체 pass_rate < 60% | CRITICAL |

## 에러 처리 기준

**파일 I/O:** 파일 부재 → 기본값 또는 skip, exit 1 금지  
**환경 변수:** 모든 변수에 기본값 설정 `${VAR:-default}`  
**외부 명령:** `command -v tool` 체크 후 없으면 WARN 출력, skip

## 타임아웃 기준

| 대상 | 타임아웃 |
|------|--------|
| 린터 단일 실행 | 30초 |
| constraint-check.sh 전체 | 5분 |
| gc-agent --scan | 2분 |
| harness-test.sh E2E | 10분 |
