---
task_type: feature
title: "C10 — Loop Convergence 제약 구현"
issue: "#8"
started_at: "2026-06-29T00:00:00Z"
done_condition:
  - "[auto] bash linters/loop-convergence.sh — iteration 3 이하 시 exit 0"
  - "[auto] bash linters/loop-convergence.sh — iteration 4 이상 시 exit 1"
  - "[auto] grep 'C10' HARNESS.md 성공"
  - "[auto] bash scripts/constraint-check.sh — C10 항목 포함 exit 0"
  - "[auto] bash tests/loop-convergence.test.sh 전체 통과"
open_questions: []
---

EXEC_PLAN:
goal: C10 Loop Convergence 제약 추가로 루프 무한 실행 방지
steps:
  - id: S1
    action: "docs/constraints/C10.md 제약 사양 문서 작성"
    output: "docs/constraints/C10.md"
    constraint: 없음
    done_condition: "ls docs/constraints/C10.md 성공"
  - id: S2
    action: "linters/loop-convergence.sh 작성 — current.yaml iteration 검사, 임계 초과 시 exit 1"
    output: "linters/loop-convergence.sh"
    constraint: C01
    done_condition: "bash linters/loop-convergence.sh exit 0 (정상 상태)"
  - id: S3
    action: "linters/_lib.sh 수정 — C10을 constraint_to_linter 매핑에 추가"
    output: "linters/_lib.sh (수정)"
    constraint: 없음
    done_condition: "grep 'C10' linters/_lib.sh 성공"
  - id: S4
    action: "HARNESS.md 제약 테이블에 C10 행 추가"
    output: "HARNESS.md (수정)"
    constraint: C03
    done_condition: "grep 'C10' HARNESS.md 성공 && HARNESS.md 100줄 이하"
  - id: S5
    action: "tests/loop-convergence.test.sh 작성 — happy path + edge case 2개"
    output: "tests/loop-convergence.test.sh"
    constraint: 없음
    done_condition: "bash tests/loop-convergence.test.sh exit 0"
  - id: S6
    action: "constraint-check.sh 실행하여 C10 포함 전체 PASS 확인"
    output: "exit 0"
    constraint: C01~C10
    done_condition: "bash scripts/constraint-check.sh exit 0"
