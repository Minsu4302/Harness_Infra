---
title: Git Worktree 격리 환경 명세
watches:
  - CLAUDE.md
last_reviewed: 2026-04-29
---

# Git Worktree 격리 환경

## 목적

모든 작업은 `main` 브랜치를 직접 수정하지 않고 Worktree 격리 환경에서 진행한다.
이는 CLAUDE.md 규칙 2를 강제하며, C05 린터(main 직접 커밋 금지)가 자동 감지한다.

## 워크트리 생성

```sh
# 새 기능 작업
git worktree add ../feature-xyz -b feat/xyz

# 버그 수정
git worktree add ../fix-abc -b fix/abc

# 작업 완료 후 정리
git worktree remove ../feature-xyz
```

## 환경 변수 설정

```sh
export HARNESS_ROOT=$(pwd)
export HARNESS_PHASE=dev
scripts/context-loader.sh --task-type feature
```

## 규칙

1. Worktree 브랜치명 형식: `{type}/{scope}` (예: `feat/auth`, `fix/login-bug`)
2. 각 Worktree는 독립적인 `.harness/session/task.md`를 가진다
3. 머지 전 `scripts/constraint-check.sh` 전체 통과 필수
4. 머지 후 Worktree 제거 및 `task.md` 완료 상태로 갱신

## Claude Code에서 사용

Claude Code의 `/worktree` 기능 또는 `EnterWorktree` 명령으로 격리 환경 생성.
각 Worktree는 독립적인 Claude Code 세션으로 관리된다.
