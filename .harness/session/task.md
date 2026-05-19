---
task_type: feature
title: "Layer C-6 — Docker + GCP + GitHub Actions CI/CD"
complexity: medium
started_at: "2026-05-19T05:00:00Z"
status: completed
done_condition:
  - "Dockerfile 멀티스테이지 빌드 (JDK21 builder + JRE21 runtime)"
  - "deploy.yml — push to main → ghcr.io 이미지 push → GCP SSH 배포"
  - "orchestrate.yml — PR 이벤트 → GCP:8080 호출 → PR Comment 게시"
  - "constraint-check.sh exit 0"
open_questions: []
---

## 개요

Spring Boot 서비스를 Docker 컨테이너로 패키징하고 GCP e2-micro에 배포한다.
GitHub Actions 두 개 워크플로우로 CI/CD를 완성한다.

1. deploy.yml  — main push 시 ghcr.io에 이미지 빌드·푸시 → GCP SSH로 재배포
2. orchestrate.yml — PR 오픈/업데이트 시 GCP 서비스 호출 → PR Comment에 AI 리포트 게시

GCP 설정은 수동 작업 필요 (아래 지침 참고).

EXEC_PLAN:
goal: "Docker 컨테이너화 + GCP 배포 + GitHub Actions CI/CD"
steps:
  - id: S1
    action: "Git Worktree 생성 (feat/deploy)"
    output: "worktree at ../harness-deploy"
    constraint: C05
    done_condition: "git worktree list에 feat/deploy 확인"
  - id: S2
    action: "Dockerfile 작성 (orchestration-service/Dockerfile)"
    output: "Dockerfile"
    constraint: C01
    done_condition: "멀티스테이지 빌드 파일 존재"
  - id: S3
    action: ".github/workflows/deploy.yml 작성"
    output: "deploy.yml"
    constraint: C01
    done_condition: "push to main → ghcr.io + GCP 배포 워크플로우"
  - id: S4
    action: ".github/workflows/orchestrate.yml 작성"
    output: "orchestrate.yml"
    constraint: C01
    done_condition: "PR 이벤트 → AI 게이트 → PR Comment 워크플로우"
  - id: S5
    action: "constraint-check.sh PASS 후 main 머지, worktree 정리"
    output: "main 브랜치 머지 커밋"
    constraint: C05
    done_condition: "constraint-check.sh exit 0 && 머지 커밋 확인"
