---
task_type: feature
title: "PEV 루프 (Plan-Execute-Verify) 구현"
issue: "#6"
started_at: "2026-06-27T00:00:00Z"
done_condition:
  - "[auto] bash scripts/loop-runner.sh --help exit 0"
  - "[auto] bash scripts/loop-runner.sh 3회 초과 시 exit 1 확인"
  - "[auto] tests/loop-runner.test.sh 전체 통과"
  - "[auto] constraint-check.sh exit 0"
open_questions: []
---

EXEC_PLAN:
goal: loop-runner.sh 구현으로 PEV 자동 재시도 루프 추가
steps:
  - id: S1
    action: ".harness/loop/ 디렉토리 생성 및 current.yaml, history.md 초기 파일 작성"
    output: ".harness/loop/current.yaml, .harness/loop/history.md"
    constraint: 없음
    done_condition: "ls .harness/loop/current.yaml .harness/loop/history.md 성공"
  - id: S2
    action: "scripts/loop-runner.sh 작성 — done_condition 검증·재시도·상태 기록 로직"
    output: "scripts/loop-runner.sh"
    constraint: C01
    done_condition: "bash scripts/loop-runner.sh --help exit 0"
  - id: S3
    action: "context-loader.sh 확장 — 루프 실패 컨텍스트 섹션(## 루프 실패 컨텍스트) 주입"
    output: "scripts/context-loader.sh (수정)"
    constraint: C01
    done_condition: "grep '루프 실패 컨텍스트' scripts/context-loader.sh 성공"
  - id: S4
    action: "tests/loop-runner.test.sh 작성 — happy path(3회 이내 수렴) + edge case(4회 초과) 2개"
    output: "tests/loop-runner.test.sh"
    constraint: 없음
    done_condition: "bash tests/loop-runner.test.sh exit 0"
  - id: S5
    action: "constraint-check.sh 실행하여 전체 PASS 확인"
    output: "exit 0"
    constraint: C01~C09
    done_condition: "bash scripts/constraint-check.sh exit 0"
