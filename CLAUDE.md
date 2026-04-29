# CLAUDE.md — Claude Code 워크플로 규칙

## 규칙 1. 코드 작성 전 EXEC_PLAN을 반드시 작성한다
- 작업 시작 전 EXEC_PLAN을 `.harness/session/task.md`에 기록한다
- 포맷과 작성 기준: `docs/PLAN_SYSTEM.md` 참조
- steps는 최대 7개. 초과 시 태스크를 분할한다

## 규칙 2. main 브랜치에서 직접 수정하지 않는다
- 모든 작업은 Git Worktree를 생성해서 진행한다
- Worktree 생성·관리 절차: `docs/specs/worktree-spec.md` 참조
- 커밋 전 C05 확인: `scripts/constraint-check.sh --only C05`

## 규칙 3. 구현한 기능에 대한 단위 테스트를 반드시 작성한다
- 신규 기능: happy path + edge case 최소 2개
- 버그 수정: 재현 테스트 먼저 작성 (실패 → 수정 → 통과)
- 리팩터링: 기존 테스트 전체 통과 확인으로 대체 가능
- 테스트가 통과하지 않으면 pre-commit 훅이 커밋을 차단한다

## 규칙 4. 완료 전 검증을 반드시 실행한다
건너뛸 수 없다. 검증을 통과하지 않으면 커밋하지 않는다.

```sh
scripts/constraint-check.sh
```

이 명령 하나로 아래 항목이 자동 검증된다:
- 의존성 단방향 (C01)
- done-condition 필드 존재 (C02)
- HARNESS.md 크기 (C03)
- GC 스캔 주기 (C04)
- main 직접 커밋 금지 (C05)
- 세션 체크포인트 (C07)
- 보안 규칙 (C09)

## 규칙 5. 커밋 컨벤션을 지킨다
형식: `type(scope): 설명`

| type | 용도 |
|------|------|
| `feat` | 신규 기능 |
| `fix` | 버그 수정 |
| `refactor` | 리팩터링 |
| `docs` | 문서 변경 |
| `chore` | 빌드·설정·기타 |

머지 후 `.harness/session/task.md`를 완료 상태로 갱신한다.

## 규칙 6. 컨텍스트 예산을 주기적으로 확인한다
- 세션 중 컨텍스트가 쌓이면 응답 품질이 저하된다
- 확인 명령:

```sh
scripts/context-loader.sh --verify
```

- WARN(320줄 초과) 시: `gc-agent.sh --scan --collect` 실행 후 세션 재시작 고려
- FAIL(400줄 초과) 시: 즉시 세션을 체크포인트하고 재시작

## 규칙 7. 세션 종료 전 미결 항목을 기록한다
- 해결되지 않은 질문·결정 사항을 `.harness/session/open-questions.md`에 추가한다
- 형식: `- [ ] 항목 내용`
- 5개 초과 시 C07 린터가 체크포인트를 강제한다 (HARNESS.md `open_questions_max` 기준)
