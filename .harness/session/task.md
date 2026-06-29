---
task_type: feature
title: "Reflection Agent 구현"
issue: "#7"
started_at: "2026-06-27T00:00:00Z"
done_condition:
  - "[auto] bash scripts/reflect-agent.sh exit 0"
  - "[auto] .harness/reports/reflection.md 생성 확인"
  - "[auto] grep '반성 인사이트' scripts/context-loader.sh 성공"
  - "[auto] tests/reflect-agent.test.sh 전체 통과"
  - "[auto] constraint-check.sh exit 0"
open_questions: []
---

EXEC_PLAN:
goal: reflect-agent.sh 구현으로 세션 반성 루프 추가
steps:
  - id: S1
    action: "scripts/reflect-agent.sh 작성 — task 히스토리 분석·패턴 집계·reflection.md 생성"
    output: "scripts/reflect-agent.sh"
    constraint: C01
    done_condition: "bash scripts/reflect-agent.sh exit 0"
  - id: S2
    action: ".harness/reports/reflection.md 초기 파일 작성 (템플릿)"
    output: ".harness/reports/reflection.md"
    constraint: 없음
    done_condition: "ls .harness/reports/reflection.md 성공"
  - id: S3
    action: "context-loader.sh 확장 — '## 반성 인사이트 (Reflection)' 섹션 동적 주입"
    output: "scripts/context-loader.sh (수정)"
    constraint: C01
    done_condition: "grep '반성 인사이트' scripts/context-loader.sh 성공"
  - id: S4
    action: "tests/reflect-agent.test.sh 작성 — happy path + edge case 2개"
    output: "tests/reflect-agent.test.sh"
    constraint: 없음
    done_condition: "bash tests/reflect-agent.test.sh exit 0"
  - id: S5
    action: "constraint-check.sh 실행하여 전체 PASS 확인"
    output: "exit 0"
    constraint: C01~C09
    done_condition: "bash scripts/constraint-check.sh exit 0"
