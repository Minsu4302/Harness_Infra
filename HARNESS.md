---
project: Harness Engineering Infrastructure
version: "2.0"
scale: single-repo
phase: implementation
active_modules:
  - mod-context
  - mod-constraint
  - mod-feedback
phase_constraints:
  planning:
    - "C02"
    - "C03"
    - "C06"
  development:
    - "C01"
    - "C02"
    - "C03"
    - "C07"
  stabilization:
    - "C01"
    - "C02"
    - "C03"
    - "C04"
    - "C07"
  production:
    - "C01"
    - "C02"
    - "C03"
    - "C04"
    - "C05"
    - "C07"
checkpoint_config:
  max_hours: 4
  max_open_questions: 5
  budget_warn_streak: 3
---

# HARNESS.md — 하네스 엔지니어링 제어 구조

## 개요

이 하네스는 AI 에이전트를 둘러싼 컨텍스트 제어, 제약 강제, 피드백 루프의 총체적 환경을 정의합니다.

## 주요 구성

| 구성 | 경로 | 역할 |
|------|------|------|
| 에이전트 인덱스 | AGENTS.md | 진입점 및 빠른 참조 |
| 워크플로 규칙 | CLAUDE.md | Claude Code 행동 기준 |
| 컨텍스트 스캔 | scripts/context-loader.sh | 세션 시작 시 환경 로드 |
| 제약 검증 | scripts/constraint-check.sh | 완료 전 모든 조건 확인 |
| 기술 부채 관리 | scripts/gc-agent.sh | 정기적 스캔 및 로그 수집 |
| 문서 | docs/ | 아키텍처, 계획, 제약 사양 |
| 관측성 | logs/ | 메트릭, 트레이스, 이벤트 |
| 세션 상태 | .harness/session/ | 현재 태스크 추적 |

## 제약 조건 (C01 ~ C07)

| 제약 | 설명 | 강제자 | 활성 Phase |
|-----|------|--------|-----------|
| C01 | 파일 크기 제한 (max 1000 줄) | harness-size.sh | dev, stab, prod |
| C02 | 의존성 검증 | dependency-check.sh | plan, dev, stab, prod |
| C03 | 아키텍처 검증 | task-completeness.sh | plan, dev, stab, prod |
| C04 | 커밋 게이트 | commit-gate.sh | stab, prod |
| C05 | ADR 요구사항 | adr-required.sh | prod |
| C06 | GC 빈도 | gc-frequency.sh | plan |
| C07 | 세션 체크포인트 | session-checkpoint.sh | dev, stab, prod |

## 피드백 훅 실행 순서

1. `context-loader.sh` - 세션 시작 시 컨텍스트 로드
2. 개발자 작업 (규칙 1~5 준수)
3. `constraint-check.sh` - 커밋 전 검증
4. `gc-agent.sh --scan --collect` - 정기 스캔 및 로그 수집
