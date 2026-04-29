---
title: Architecture Rules
watches:
  - scripts/
  - linters/
last_reviewed: 2026-04-29
---

# Architecture Rules

## 목적

하네스 엔지니어링 인프라의 아키텍처 원칙과 의존성 제약을 정의합니다.

## 핵심 원칙

1. **모듈 독립성**: 각 린터는 독립적으로 실행 가능해야 함
2. **명시적 인터페이스**: 모든 스크립트는 표준 출력/종료 코드를 따름
3. **설정 중앙화**: HARNESS.md에서 모든 임계값 관리
4. **로깅 구조화**: logs/는 자동 생성, 수동 편집 금지

## 의존성 그래프

```
constraint-check.sh
  ├── linters/dependency-check.sh
  ├── linters/task-completeness.sh
  ├── linters/harness-size.sh
  ├── linters/gc-frequency.sh
  ├── linters/commit-gate.sh
  ├── linters/adr-required.sh
  └── linters/session-checkpoint.sh

context-loader.sh
  ├── HARNESS.md (읽기)
  ├── .harness/reports/debt-report.md (읽기)
  └── .harness/context/current.md (쓰기)

gc-agent.sh
  ├── .harness/reports/debt-report.md (쓰기)
  ├── logs/ (쓰기)
  └── .harness/reports/last-check.json (읽기/쓰기)
```

## 린터 계약 (Interface)

모든 린터는 다음 계약을 준수해야 합니다:

```bash
# 입력
$HARNESS_ROOT - 루트 디렉토리
$HARNESS_PHASE - 현재 phase (planning, development, stabilization, production)

# 출력 (stdout)
PASS:Cxx:메시지
FAIL:Cxx:메시지
WARN:Cxx:메시지

# 종료 코드
0 = 성공 (PASS/WARN)
1 = 실패 (FAIL)
```

## Phase 활성화

| Phase | 활성 Linters |
|-------|-------------|
| planning | C02, C03, C06 |
| development | C01, C02, C03, C07 |
| stabilization | C01, C02, C03, C04, C07 |
| production | C01, C02, C03, C04, C05, C07 |
