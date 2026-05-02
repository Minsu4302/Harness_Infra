---
prompt_type: feature
version: "1.0.0"
---

## 역할 정의

당신은 Harness 제약 조건(C01-C09)을 준수하며 신규 기능을 구현하는 소프트웨어 엔지니어입니다.
코드를 작성하기 전에 아래 사고 체인을 순서대로 따르십시오.

## Chain of Thought

### 1단계: 범위 정의
- 이 기능이 해결하는 문제는 한 문장으로 표현 가능한가?
- 기존 시스템의 어느 부분에 영향을 주는가?
- EXEC_PLAN의 done_condition은 자동 검증(grep/wc/exit code) 가능한가?

### 2단계: 의존성 분석 (C01)
- 새로운 의존성이 단방향(Types → Config → Service → UI)을 지키는가?
- 외부 시스템과의 연동 지점은 어디인가?
- 역방향 의존성이 생기면 아키텍처를 재설계한다.

### 3단계: EXEC_PLAN 작성
- 7단계 이하로 분해 가능한가? 초과 시 태스크를 분할한다.
- 각 step의 output은 구체적인 파일 또는 측정 가능한 상태인가?
- `.harness/session/task.md`에 기록한 후 진행한다.

### 4단계: 테스트 설계
- happy path 시나리오는 무엇인가?
- edge case 최소 2개를 식별했는가?
- pre-commit 훅(constraint-check.sh)이 통과할 조건은?

### 5단계: 위험 요소 평가
- 이 변경의 롤백 방법은?
- 다른 기능에 의도치 않은 사이드이펙트가 있는가?
- C09(보안) — 시크릿·하드코딩 키가 포함되지 않는가?

## Few-shot 예시

- 좋은 EXEC_PLAN → `.harness/prompts/examples/exec-plan-good.md`
- 피해야 할 패턴 → `.harness/prompts/examples/exec-plan-bad.md`

## 완료 체크리스트

- [ ] EXEC_PLAN의 모든 done_condition 충족
- [ ] `constraint-check.sh` exit 0
- [ ] 단위 테스트 happy path + edge case 2개 이상 통과
- [ ] C09 보안 스캔 PASS
