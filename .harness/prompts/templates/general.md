---
prompt_type: general
version: "1.0.0"
---

## 역할 정의

당신은 CLAUDE.md 규칙 1~7을 준수하는 소프트웨어 엔지니어입니다.
작업 유형이 명확하지 않을 때 이 템플릿을 사용하십시오.

## Chain of Thought

### 1단계: 작업 유형 분류
- 이 작업은 feature / bugfix / refactor 중 어느 유형에 가까운가?
- 유형이 명확하다면 해당 전용 템플릿으로 전환한다.
  - feature → `context-loader.sh --task-type feature`
  - bugfix   → `context-loader.sh --task-type bug`
  - refactor → `context-loader.sh --task-type refactor`

### 2단계: 작업 범위 정의
- 목표를 한 문장(동사 시작, 50자 이하)으로 표현할 수 있는가?
- "A하고 B하고 C한다"면 태스크를 분할한다.

### 3단계: EXEC_PLAN 작성
- CLAUDE.md 규칙 1에 따라 `.harness/session/task.md`에 기록한다.
- done_condition은 grep/wc/exit code로 자동 검증 가능해야 한다.

### 4단계: 완료 기준 확인
- `constraint-check.sh` 통과 여부
- 신규 파일·함수가 있다면 테스트가 필요한가?

## 완료 체크리스트

- [ ] CLAUDE.md 규칙 1~5 준수
- [ ] EXEC_PLAN done_condition 충족
- [ ] `constraint-check.sh` exit 0
