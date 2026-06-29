---
project: Harness Engineering Infrastructure
version: "0.1.0"
phase: planning
context_budget:
  max_lines: 400
  warn_lines: 320
phase_constraints:
  planning: [C02, C03, C06]
  dev:      [C01, C02, C03, C07, C09, C10]
  stab:     [C01, C02, C03, C04, C07, C08, C09, C10]
  prod:     [C01, C02, C03, C04, C05, C07, C08, C09, C10]
c07:
  time_threshold_hours: 4
  context_budget_consecutive: 3
  open_questions_max: 5
---

# HARNESS.md — 하네스 제어 구조

## 구성 맵

| 구성 | 경로 | 역할 |
|------|------|------|
| 에이전트 인덱스 | AGENTS.md | 진입점 및 빠른 참조 |
| 워크플로 규칙 | CLAUDE.md | Claude Code 행동 기준 |
| 컨텍스트 로드 | scripts/context-loader.sh | 세션 시작 |
| 제약 검증 | scripts/constraint-check.sh | 완료 전 검증 |
| 부채 관리 | scripts/gc-agent.sh | 스캔 + 로그 수집 |
| 초기화 | scripts/harness-init.sh | 프로젝트 온보딩 |
| 문서 | docs/ | 아키텍처·계획·제약 |
| 관측성 | logs/ | 메트릭·트레이스·이벤트 |
| 세션 상태 | .harness/session/ | task.md, open-questions.md |

## 제약 조건

| ID | 이름 | 강제자 | 활성 |
|----|------|--------|------|
| C01 | 의존성 단방향 | dependency-check.sh | dev/stab/prod |
| C02 | done-condition 필수 | task-completeness.sh | 전체 |
| C03 | HARNESS.md 100줄 이하 | harness-size.sh | 전체 |
| C04 | GC 스캔 주 1회 이상 | gc-frequency.sh | stab/prod |
| C05 | main 직접 커밋 금지 | commit-gate.sh | prod |
| C06 | ADR 기록 | adr-required.sh | planning |
| C07 | 세션 체크포인트 | session-checkpoint.sh | dev/stab/prod |
| C08 | UI 검증 | ui-check.sh | stab/prod |
| C09 | 보안 규칙 | security-scan.sh | dev/stab/prod |
| C10 | 루프 수렴 | loop-convergence.sh | dev/stab/prod |

## 피드백 훅 순서

1. `context-loader.sh` — 세션 시작
2. 작업 (CLAUDE.md 규칙 1~5 준수)
3. `constraint-check.sh` — 커밋 전
4. `gc-agent.sh --scan --collect` — 정기 스캔
