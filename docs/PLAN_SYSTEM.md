---
title: EXEC_PLAN 작성 시스템
watches:
  - .harness/session/task.md
last_reviewed: 2026-04-29
---

# EXEC_PLAN 작성 시스템

CLAUDE.md 규칙 1이 참조하는 문서.
모든 코드 작업 전 EXEC_PLAN을 작성하여 우발적 편차를 방지한다.

## EXEC_PLAN 포맷

```
EXEC_PLAN:
goal: (한 문장 — 동사로 시작, 50자 이하)
steps:
  - id: S1
    action: (동사로 시작하는 구체적 행동)
    output: (결과물 파일 또는 상태)
    constraint: (해당 C번호 또는 없음)
    done_condition: (측정 가능한 기준)
  - id: S2
    ...
```

## 작성 규칙

1. **steps 최대 7개** — 초과 시 태스크를 분할한다
2. **goal은 한 문장** — "A하고 B하고 C한다"는 분할 신호다
3. **action은 동사로 시작** — "추가", "생성", "제거", "수정", "검증"
4. **done_condition은 측정 가능해야 한다** — grep·wc·exit code로 확인 가능한 기준

## done_condition 작성 기준

| 유형 | 좋은 예 | 나쁜 예 |
|------|---------|---------|
| 파일 존재 | `docs/PLAN_SYSTEM.md 파일 생성 확인` | `문서 작성됨` |
| 스크립트 결과 | `constraint-check.sh exit 0 확인` | `테스트 통과` |
| 줄 수 | `HARNESS.md 100줄 이하 확인` | `파일이 짧음` |
| 패턴 포함 | `grep 'EXEC_PLAN' docs/PLAN_SYSTEM.md 성공` | `내용이 맞음` |

## 나쁜 예 / 좋은 예

**나쁜 예** — 측정 불가, steps 과다, action 모호:
```
EXEC_PLAN:
goal: 여러 기능을 추가하고 문서를 정리하고 테스트한다
steps:
  - id: S1
    action: 기능 작업
    output: 코드
    constraint: 없음
    done_condition: 잘 됨
```

**좋은 예** — 단일 목표, 측정 가능:
```
EXEC_PLAN:
goal: gc-agent.sh에 run_plugin_hooks 함수 추가
steps:
  - id: S1
    action: gc-agent.sh 하단에 run_plugin_hooks 함수 작성
    output: gc-agent.sh (plugin hook 실행 연동)
    constraint: 없음
    done_condition: sh gc-agent.sh --scan 후 traces/ 에 .log 파일 생성 확인
  - id: S2
    action: constraint-check.sh 실행하여 전체 PASS 확인
    output: exit 0
    constraint: C03
    done_condition: constraint-check.sh exit 0
```

## task.md 연동

EXEC_PLAN은 `.harness/session/task.md`의 YAML 헤더와 함께 관리한다:

```yaml
---
task_type: feature
title: "gc-agent plugin hook 연동"
started_at: "2026-04-29T12:00:00Z"
done_condition:
  - "[auto] test: constraint-check.sh PASS"
  - "[human] traces/ 에 hook 로그 생성 확인"
open_questions: []
---
```

## 체크포인트 시점

- steps 완료 후 예상과 달라진 경우 → EXEC_PLAN 갱신 후 계속
- 3개 이상의 steps가 변경될 경우 → 태스크 분할 검토
- 4시간 경과 또는 open-questions 5개 초과 → C07 체크포인트 강제 (HARNESS.md 기준)
