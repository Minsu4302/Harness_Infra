---
title: 하네스 부트스트랩 로드맵
watches:
  - HARNESS.md
  - scripts/harness-init.sh
last_reviewed: 2026-04-29
---

# 하네스 부트스트랩 로드맵

`harness-init.sh` 실행 후 신규 프로젝트 온보딩 순서.

## Day 1 — 초기화

```sh
# 1. 하네스 초기화
scripts/harness-init.sh . --phase=planning

# 2. 환경 변수 설정
export HARNESS_ROOT=$(pwd)
export HARNESS_PHASE=planning

# 3. task.md 작성
vi .harness/session/task.md  # title, done_condition 채우기

# 4. 첫 constraint-check 실행
scripts/constraint-check.sh
```

**Day 1 체크리스트:**
- [ ] `harness-init.sh` 실행 완료 (디렉토리 구조 생성)
- [ ] `HARNESS.md` phase=planning 확인
- [ ] `.harness/session/task.md` title·done_condition 기입
- [ ] `scripts/constraint-check.sh` → C02/C03/C06 PASS
- [ ] `scripts/context-loader.sh` → current.md 생성 확인

## Week 1 — planning phase 안정화

목표: C02·C03·C06 지속 PASS, EXEC_PLAN 작성 습관 형성

**주요 작업:**
1. `docs/decisions/` 에 첫 번째 ADR 작성 (C06 충족)
2. `HARNESS.md` 100줄 이하 유지 (C03 모니터링)
3. 매 태스크마다 `docs/PLAN_SYSTEM.md` 포맷으로 EXEC_PLAN 작성

**Week 1 체크리스트:**
- [ ] ADR 1개 이상 작성 (`docs/decisions/`)
- [ ] `gc-agent.sh --scan --collect` 최초 실행
- [ ] `logs/events/` 파일 생성 확인
- [ ] open-questions 5개 이하 유지

## Week 2+ — dev phase 전환

**전환 조건 (모두 충족):**
- [ ] C02·C03·C06 연속 3회 이상 PASS
- [ ] EXEC_PLAN 작성이 자연스러워짐 (체크 없이도 작성)
- [ ] `gc-agent.sh --scan` 1회 이상 실행 완료
- [ ] `debt-report.md` CRITICAL 항목 0개

**전환 명령:**
```sh
# HARNESS.md의 phase 변경
sed -i 's/^phase: planning/phase: dev/' HARNESS.md
export HARNESS_PHASE=dev

# dev phase 제약 조건 전체 확인
scripts/constraint-check.sh
# 기대: C01 C02 C03 C07 C09 PASS
```

## Phase 전환 기준 요약

| 전환 | 조건 | 추가 제약 |
|------|------|---------|
| planning → dev | C02·C03·C06 안정, ADR 1개 | +C01, +C07, +C09 |
| dev → stab | C07 30일 무발동, 테스트 커버리지 기준 충족 | +C04, +C08 |
| stab → prod | C08 UI 검증 완료, 성능 SLO 충족 | +C05 |

## 플러그인 추가 (선택)

외부 관측성 시스템 연동 시:
```sh
# plugin.yaml이 있는 디렉토리를 추가
scripts/harness-init.sh --add-plugin /path/to/my-plugin

# 등록 확인
scripts/harness-init.sh --list-plugins
```

## 참조

- 격리 환경 (Worktree): `docs/specs/worktree-spec.md`
- EXEC_PLAN 작성법: `docs/PLAN_SYSTEM.md`
- 제약 조건 상세: `docs/constraints/`
- 관측성 쿼리: `docs/reference/observability.md`
