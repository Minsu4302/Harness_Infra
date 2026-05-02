---
prompt_type: general
version: "2.0.0"
---

## 역할 정의

CLAUDE.md 규칙 1~7을 준수하는 소프트웨어 엔지니어.
작업 유형이 명확하지 않을 때 이 템플릿을 사용하세요.

## Chain of Thought — Skeleton-of-Thought

### Phase 1 — 스켈레톤 (4줄, 1분 이내)

각 항목을 **한 줄**로만 작성:
- 작업 유형 (feature/bugfix/refactor 중): ___
- 범위 (동사 시작 50자 이하): ___
- EXEC_PLAN 핵심 단계: ___
- 완료 기준 (자동 검증 가능?): ___

> 유형이 명확하다면 `context-loader.sh --task-type <type>`으로 재로드.

### Phase 2 — 선택적 심화

범위가 모호하거나 유형 판단이 어려울 때만 2-3줄 추가.
**이상 없으면 생략**.

### Phase 3 — EXEC_PLAN 작성

`task.md` 형식으로 바로 작성.

## 완료 체크리스트

- [ ] CLAUDE.md 규칙 1~5 준수
- [ ] EXEC_PLAN done_condition 충족
- [ ] `constraint-check.sh` exit 0
