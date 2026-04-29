---
title: Bootstrap Roadmap
watches:
  - scripts/
  - linters/
  - HARNESS.md
last_reviewed: 2026-04-29
---

# Bootstrap Roadmap

## 목적

하네스 엔지니어링 인프라를 프로젝트에 점진적으로 도입하기 위한 로드맵입니다.

## 단계별 도입

### Phase 1: 기반 구축 (1-2일)
✓ **완료됨**
- AGENTS.md, CLAUDE.md, HARNESS.md 작성
- 디렉토리 구조 생성
- 기본 린터 템플릿 작성

### Phase 2: 린터 구현 (3-5일)
**상태**: 진행 중

- [x] C07 (session-checkpoint.sh) 구현
- [ ] C01 (harness-size.sh) - 파일 크기 검증
- [ ] C02 (dependency-check.sh) - 의존성 검증
- [ ] C03 (task-completeness.sh) - 작업 완성도 검증
- [ ] C04 (commit-gate.sh) - 커밋 메시지 검증
- [ ] C05 (adr-required.sh) - ADR 요구사항
- [ ] C06 (gc-frequency.sh) - GC 빈도 검증

### Phase 3: 통합 스크립트 (1-2일)
**상태**: 대기

- [ ] context-loader.sh 구현
- [ ] constraint-check.sh 구현 (모든 린터 통합)
- [ ] gc-agent.sh 구현 (완료)
- [ ] validators/completion-check.sh 구현

### Phase 4: 관측성 및 문서 (2-3일)
**상태**: 진행 중

- [x] logs/ 구조 및 README 작성
- [x] gc-agent.sh --collect 기능
- [ ] docs/reference/ 문서 작성
- [ ] docs/constraints/ 제약 사양 작성

### Phase 5: 실제 프로젝트 적용 (지속적)
**상태**: 대기

- [ ] 첫 번째 CLAUDE.md 규칙 적용
- [ ] 제약 검증 자동화
- [ ] 팀 피드백 수집 및 개선

## 핵심 마일스톤

| 마일스톤 | 기한 | 선행 조건 |
|---------|------|---------|
| 기반 완성 | 2026-04-30 | Phase 1 ✓ |
| Phase 2 린터 | 2026-05-05 | Phase 1 ✓ |
| 통합 검증 | 2026-05-07 | Phase 2, 3 ✓ |
| 프로덕션 적용 | 2026-05-10 | Phase 4 ✓ |

## 위험 요소

| 위험 | 영향 | 완화 전략 |
|------|------|---------|
| 스크립트 오류 | 린터 실패 | 모든 린터에 자동 테스트 |
| 성능 저하 | CI/CD 느림 | 병렬 실행 및 캐싱 |
| 팀 저항 | 채택 지연 | 명확한 문서와 교육 |

## 체크리스트

완료 기준:

- ✓ 모든 린터 구현 및 테스트
- ✓ 통합 스크립트 동작 확인
- ✓ 문서 작성 완료
- ✓ 팀 피드백 수집
- ✓ 프로덕션 배포 준비
