---
type: few-shot-positive
title: "좋은 EXEC_PLAN 예시"
---

# Few-shot: 좋은 EXEC_PLAN

측정 가능하고 단일 목표를 가진 EXEC_PLAN의 예시입니다.

## 예시 1: 스크립트에 함수 추가 (feature)

```
EXEC_PLAN:
goal: gc-agent.sh에 run_plugin_hooks 함수 추가
steps:
  - id: S1
    action: gc-agent.sh 하단에 run_plugin_hooks 함수 작성
    output: scripts/gc-agent.sh
    constraint: 없음
    done_condition: sh gc-agent.sh --scan 후 traces/ 에 .log 파일 생성 확인
  - id: S2
    action: harness-test.sh T06 실행하여 hook 연동 확인
    output: exit 0
    constraint: C09
    done_condition: sh scripts/harness-test.sh --only T06 exit 0
  - id: S3
    action: constraint-check.sh 실행
    output: exit 0
    constraint: C03
    done_condition: sh scripts/constraint-check.sh exit 0
```

**핵심 특징:**
- goal: 동사 시작, 50자 이하, 단일 목표
- output: 구체적 파일 경로
- done_condition: sh 명령으로 자동 검증 가능

---

## 예시 2: 버그 수정 (bugfix)

```
EXEC_PLAN:
goal: context-loader.sh --verify 시 잘못된 줄 수 계산 수정
steps:
  - id: S1
    action: 버그 재현 테스트 작성 — verify 모드에서 실패하는 케이스 확인
    output: tests/test-context-loader.sh
    constraint: 없음
    done_condition: sh tests/test-context-loader.sh exit 1 (수정 전 실패 확인)
  - id: S2
    action: context-loader.sh 줄 수 계산 로직 수정
    output: scripts/context-loader.sh
    constraint: 없음
    done_condition: sh tests/test-context-loader.sh exit 0
  - id: S3
    action: constraint-check.sh 실행
    output: exit 0
    constraint: C03
    done_condition: sh scripts/constraint-check.sh exit 0
```

**핵심 특징:**
- S1이 재현 테스트 작성 (수정 전 실패 확인 포함)
- done_condition이 각 step마다 독립적으로 검증 가능
