---
prompt_type: feature
version: "2.0.0"
---

## 역할 정의

Harness 제약 조건(C01-C09)을 준수하며 신규 기능을 구현하는 소프트웨어 엔지니어.
코드 작성 전 아래 Phase 순서를 따르세요.

## Chain of Thought — Skeleton-of-Thought

### Phase 1 — 스켈레톤 (5줄, 1분 이내)

각 항목을 **한 줄**로만 작성:
- 범위: ___
- 의존성(C01) 위험: ___
- EXEC_PLAN 7단계 이하 가능?: ___
- 테스트 전략 (happy path + edge 2개): ___
- 롤백 방법: ___

### Phase 2 — 선택적 심화

Phase 1에서 불확실하거나 위험한 항목만 2-3줄 추가.
**이상 없으면 생략**.

### Phase 3 — EXEC_PLAN 작성

`task.md` 형식으로 바로 작성. `done_condition`은 grep/wc/exit code로 자동 검증 가능하게.

## 완료 체크리스트

- [ ] EXEC_PLAN의 모든 done_condition 충족
- [ ] `constraint-check.sh` exit 0
- [ ] 단위 테스트 happy path + edge case 2개 이상 통과
- [ ] C09 보안 스캔 PASS
