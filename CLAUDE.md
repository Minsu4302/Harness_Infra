# CLAUDE.md — Claude Code 워크플로 규칙

## 규칙 1. 계획 없이 코드를 작성하지 않는다
- 작업 시작 전 EXEC_PLAN을 작성한다
- 작성 방법: docs/reference/PLAN_SYSTEM.md 참조

## 규칙 2. main 브랜치에서 직접 수정하지 않는다
- 모든 작업은 Git Worktree를 생성해서 진행한다
- 커밋 전 C05 확인: `scripts/constraint-check.sh --only C05`

## 규칙 3. 구현한 기능에 대한 단위 테스트를 반드시 작성한다
- 새 기능: 정상 동작 + 엣지 케이스 + props 검증
- 버그 수정: 재현 테스트 (실패 → 수정 → 통과)
- 리팩터링: 기존 동작 보존 확인
- 테스트가 통과하지 않으면 pre-commit 훅이 커밋을 차단한다

## 규칙 4. 완료 전 검증을 반드시 실행한다
건너뛸 수 없다. 검증을 통과하지 않으면 커밋하지 않는다.

```bash
scripts/constraint-check.sh
```

이 명령 하나로 아래 항목이 자동 검증된다:
- 단위 테스트 통과 여부
- 린트
- 빌드
- 파일 크기 제한
- 아키텍처 의존성
- 문서 가드닝

## 규칙 5. 커밋 → 머지 → 완료 처리
- 커밋 메시지 형식: `feat(scope): 설명`
- 머지 후 `.harness/session/task.md`를 완료 상태로 갱신한다
