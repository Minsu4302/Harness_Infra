---
title: Execution Plan System
watches:
  - .harness/session/
last_reviewed: 2026-04-29
---

# Execution Plan System

## 목적

작업 시작 전에 실행 계획(EXEC_PLAN)을 작성하여 우발적 편차를 방지합니다.

CLAUDE.md 규칙 1을 구현합니다.

## 계획 구조

계획은 다음 섹션으로 구성됩니다:

```markdown
---
task_type: feature | bugfix | refactor
title: 작업 제목
done_condition:
  - "[auto] test: 검증 항목"
  - "[human] 검수자 확인"
---

## 개요
(50자 이내의 한 문장 설명)

## 단계
1. 준비: 파일 읽기 및 분석
2. 구현: 코드 작성
3. 검증: 테스트 실행
4. 머지: PR 생성 및 병합

## 위험 요소
- 예상되는 문제점
- 완화 전략

## 정의
- Key 결정사항
```

## done_condition 형식

**[auto] test**: 자동 검증 가능한 항목
- 예: `test: C03 PASS`, `test: 커버리지 > 85%`

**[human]**: 사람의 확인이 필요한 항목
- 예: `human: 코드 리뷰 통과`, `human: 디자인 검증`

## 검증 체크리스트

계획 검증 기준:

1. ✓ done_condition이 모두 명시적으로 기술되어 있는가?
2. ✓ 단계별 시간 추정이 4시간 이내인가? (C07 한계)
3. ✓ 위험 요소가 최소 2개 이상 식별되어 있는가?
4. ✓ 아키텍처 규칙 위반이 없는가? (ARCHITECTURE.md 참조)

## 계획 작성 시점

- **작업 시작 전**: 항상 작성
- **진행 중 변경**: 필요 시 갱신 후 문서화
- **완료 후**: task.md에 최종 상태 기록
