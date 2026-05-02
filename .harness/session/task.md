---
task_type: feature
title: "RAG 검색 레이어 구현"
started_at: "2026-05-02T00:00:00Z"
done_condition:
  - "[auto] test: sh scripts/rag-search.sh --query 'feature constraint C01' 실행 시 docs 경로 출력"
  - "[auto] test: context-loader.sh 실행 후 current.md에 '## 관련 문서 (RAG)' 포함 확인"
  - "[auto] test: constraint-check.sh exit 0"
  - "[human] top-3 검색 결과가 현재 태스크와 의미적으로 관련 있는지 확인"
open_questions: []
---

## 개요

현재 `context-loader.sh`는 400줄 고정 예산으로 모든 제약·문서를 정적으로 로딩한다.
RAG(Retrieval-Augmented Generation) 레이어를 도입해 현재 태스크와 의미적으로
관련된 제약·ADR·스펙 문서만 동적으로 검색해 컨텍스트에 주입한다.

구현 방식: 벡터 임베딩 대신 키워드 빈도 스코어링 (문서 < 30개 규모에서 충분).
설계 결정: Python/Node 미도입 — 셸 스크립트 정체성 유지 (POSIX sh).

EXEC_PLAN:
goal: RAG 검색 레이어 구현 및 context-loader.sh 동적 로딩 연동
steps:
  - id: S1
    action: Git Worktree 생성 (feat/rag-layer)
    output: c:\harness-rag 워크트리
    constraint: C05
    done_condition: "git worktree list에 feat/rag-layer 브랜치 확인"
  - id: S2
    action: scripts/rag-search.sh 작성 — 키워드 추출·스코어링·발췌 출력
    output: scripts/rag-search.sh
    constraint: C01, C09
    done_condition: "sh scripts/rag-search.sh --query 'feature constraint' 시 문서 경로 출력"
  - id: S3
    action: context-loader.sh 수정 — task.md 쿼리 추출 후 rag-search.sh 호출·주입
    output: scripts/context-loader.sh (수정)
    constraint: C01
    done_condition: "context-loader.sh 실행 후 current.md에 '## 관련 문서 (RAG)' 포함"
  - id: S4
    action: constraint-check.sh 실행하여 전체 PASS 확인
    output: exit 0
    constraint: 전체
    done_condition: "scripts/constraint-check.sh exit 0"
  - id: S5
    action: feat/rag-layer 커밋 후 main에 머지, worktree 정리
    output: main 브랜치 머지 커밋
    constraint: C05
    done_condition: "git log main --oneline HEAD~1 에 머지 커밋 확인"
