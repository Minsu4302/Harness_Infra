# Harness Engineering Infrastructure

AI 에이전트를 위한 컨텍스트 제어, 제약 강제, 피드백 루프 인프라

---

## 왜 만들었나 — 반복된 한계에서 시작된 프로젝트

AI를 활용한 중규모 이상의 개발 프로젝트를 진행하다 보면 세 가지 한계가 반복된다.

**1. Context Drift (컨텍스트 드리프트)**
대화가 길어질수록 초반에 내린 지침이 점차 희석된다. 세션 초반에는 잘 따르던 규칙을 후반부에는 AI가 조용히 무시한다. 명시적으로 지시해도 몇 번의 교환 후 다시 원래대로 돌아간다.

**2. 단일 파일 지침의 한계**
지침을 `.md` 파일 하나에 몰아넣으면, 파일이 커질수록 AI가 전체를 완벽히 준수하지 못한다. 금지한 행동이 반복되고, "이미 설명했다"고 상기시켜도 다음 턴에 또 발생한다.

**3. "더 좋은 프롬프트"로는 근본 해결이 안 된다**
이 문제는 프롬프트 품질의 문제가 아니다. 대화 세션 자체의 구조적 한계다.

### 핵심 아이디어 — 환경 자체를 설계하자

| 레이어 | 정의 | 한계 |
|--------|------|------|
| **프롬프트 엔지니어링** | 모델에게 *무엇을* 말할지 최적화 | 세션이 길어지면 희석 |
| **컨텍스트 엔지니어링** | 모델이 *무엇을* 볼지 관리 | 단일 파일 크기 한계 |
| **하네스 엔지니어링** | 모델이 *어디서* 작동하는지 설계 | 이 프로젝트가 해결하는 지점 |

**하네스(Harness)** 는 AI 에이전트를 둘러싼 스캐폴딩, 제약 조건, 피드백 루프의 총체적 환경이다. 단일 `.md` 파일에 모든 지침을 몰아넣는 방식 대신, 셸 스크립트 기반의 제어 레이어와 플러그인 방식의 모듈 아키텍처로 대체한다.

---

## 해결 — 세 모듈로 분리된 제어 구조

```
단일 CLAUDE.md (지침 덩어리)
    ↓ 분리
┌──────────────────┬──────────────────┬──────────────────┐
│  mod-context     │  mod-constraint  │  mod-feedback    │
│  컨텍스트 제어   │  제약 강제       │  피드백 루프     │
│                  │                  │                  │
│ context-loader   │ constraint-check │ gc-agent         │
│ HARNESS.md 설정  │ C01~C09 린터     │ logs/ 관측성     │
│ 400줄 예산 관리  │ pre-commit 훅    │ debt-report      │
└──────────────────┴──────────────────┴──────────────────┘
```

**CLAUDE.md는 행동 지침만** 담는다 — 검증은 `constraint-check.sh`에 위임한다.
**린터는 독립 실행 가능** — CI/CD, Git 훅, 수동 실행 모두 동일한 결과.
**플러그인으로 탈부착** — 프로젝트마다 필요한 모듈만 연결한다.

---

## 결과 — 실제로 달라지는 것

| 기존 방식 | 하네스 방식 |
|---------|-----------|
| AI가 지침을 점차 무시 | C07이 4시간마다 체크포인트 강제 |
| "하지 말라" 해도 반복 | 린터가 커밋 전 자동 차단 |
| 맥락이 세션마다 초기화 | current.md + debt-report.md로 지속 |
| 규칙이 파일 하나에 집중 | 역할별 분리, 400줄 예산 관리 |
| 부채가 쌓여도 몰라 | gc-agent가 주기적으로 스캔·기록 |

---

## 빠른 시작

### 신규 프로젝트 온보딩

```sh
# 1. 하네스 초기화
sh scripts/harness-init.sh . --phase=planning
export HARNESS_ROOT=$(pwd) HARNESS_PHASE=planning

# 2. 태스크 정의
vi .harness/session/task.md   # title, done_condition 작성

# 3. 컨텍스트 로드
sh scripts/context-loader.sh

# 4. 첫 검증
sh scripts/constraint-check.sh
```

### 일반 작업 사이클

```sh
# 세션 시작
sh scripts/context-loader.sh --task-type feature

# 작업 중 수시로
sh scripts/constraint-check.sh

# 예산 확인
sh scripts/context-loader.sh --verify

# 완료 전
sh validators/completion-check.sh
sh scripts/gc-agent.sh --scan --collect
```

### 예시 task.md

```yaml
---
task_type: feature
title: "OAuth 로그인 기능 추가"
started_at: "2026-04-29T12:00:00Z"
done_condition:
  - "[auto] test: constraint-check.sh PASS"
  - "[human] 보안 검토 완료"
open_questions: []
---

## 작업 내용
OAuth 2.0 인증 미들웨어 구현

## 결정 사항
```

---

## 자동화

### Git 훅에 constraint-check.sh 추가

커밋 전 자동으로 전체 제약 조건을 검증한다. 실패하면 커밋이 차단된다.

```sh
# .git/hooks/pre-commit 생성
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
HARNESS_ROOT="$(git rev-parse --show-toplevel)"
HARNESS_PHASE="${HARNESS_PHASE:-dev}"
export HARNESS_ROOT HARNESS_PHASE

sh "${HARNESS_ROOT}/scripts/constraint-check.sh"
EOF

chmod +x .git/hooks/pre-commit
```

특정 제약만 커밋 훅에 걸고 싶다면:

```sh
# main 직접 커밋만 차단 (prod phase 팀)
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
HARNESS_ROOT="$(git rev-parse --show-toplevel)"
HARNESS_PHASE=prod
export HARNESS_ROOT HARNESS_PHASE
sh "${HARNESS_ROOT}/scripts/constraint-check.sh" --only C05
EOF
```

### CI/CD에 통합

**GitHub Actions 예시:**

```yaml
# .github/workflows/harness.yml
name: Harness Constraint Check

on: [push, pull_request]

jobs:
  harness:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run constraint check
        run: |
          export HARNESS_ROOT=${{ github.workspace }}
          export HARNESS_PHASE=dev   # 브랜치별로 조정
          sh scripts/constraint-check.sh

      - name: Run E2E harness test
        run: |
          export HARNESS_ROOT=${{ github.workspace }}
          sh scripts/harness-test.sh
```

**GitLab CI 예시:**

```yaml
# .gitlab-ci.yml
harness-check:
  stage: test
  script:
    - export HARNESS_ROOT=$CI_PROJECT_DIR
    - export HARNESS_PHASE=dev
    - sh scripts/constraint-check.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

**주간 GC 자동화 (cron):**

```yaml
# GitHub Actions — 주간 기술 부채 스캔
name: Weekly GC Scan

on:
  schedule:
    - cron: '0 9 * * 1'   # 매주 월요일 오전 9시

jobs:
  gc-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: GC scan and collect
        run: |
          export HARNESS_ROOT=${{ github.workspace }}
          sh scripts/gc-agent.sh --scan --collect
      - name: Upload logs
        uses: actions/upload-artifact@v4
        with:
          name: harness-logs
          path: logs/
```

---

## 제약 조건 (C01 ~ C09)

| ID | 이름 | 활성 Phase | 자동화 |
|----|------|-----------|--------|
| C01 | 의존성 단방향 (Types→Config→Service→UI) | dev/stab/prod | 완전 자동 |
| C02 | done-condition 필드 필수 | 전체 | 완전 자동 |
| C03 | HARNESS.md 100줄 이하 | 전체 | 완전 자동 |
| C04 | GC 스캔 주 1회 이상 | stab/prod | 완전 자동 |
| C05 | main 직접 커밋 금지 | prod | 완전 자동 |
| C06 | 아키텍처 결정 ADR 기록 | planning | 반자동 |
| C07 | 세션 체크포인트 강제 | dev/stab/prod | 완전 자동 |
| C08 | UI 검증 기준 충족 | stab/prod | 완전 자동 |
| C09 | 보안 규칙 (secrets 노출 금지) | dev/stab/prod | 완전 자동 |

C07 트리거 조건 (하나라도 충족 시 FAIL):
- 태스크 시작 후 4시간 초과
- 컨텍스트 예산(400줄) 80% 초과가 3회 연속
- `open-questions.md` 미결 항목 5개 초과

---

## 디렉토리 구조

```
harness-infra/
├── HARNESS.md              # 설정 및 활성 제약 (YAML frontmatter)
├── CLAUDE.md               # Claude Code 워크플로 규칙 (7개)
├── AGENTS.md               # 에이전트 진입점 인덱스
│
├── scripts/
│   ├── context-loader.sh   # compile / --verify 모드, 400줄 예산
│   ├── constraint-check.sh # C01~C09 오케스트레이터
│   ├── gc-agent.sh         # --scan --collect, plugin hook 실행
│   ├── harness-init.sh     # 프로젝트 초기화 + 플러그인 관리
│   └── harness-test.sh     # E2E 검증 (T01~T08)
│
├── linters/
│   ├── _lib.sh             # POSIX sh 공통 헬퍼
│   ├── dependency-check.sh # C01
│   ├── task-completeness.sh # C02
│   ├── harness-size.sh     # C03
│   ├── gc-frequency.sh     # C04
│   ├── commit-gate.sh      # C05
│   ├── adr-required.sh     # C06
│   ├── session-checkpoint.sh # C07
│   ├── ui-check.sh         # C08
│   └── security-scan.sh    # C09
│
├── validators/
│   └── completion-check.sh
│
├── plugins/
│   └── observability/
│       └── plugin.yaml     # post-scan 훅 선언
│
├── docs/
│   ├── PLAN_SYSTEM.md      # EXEC_PLAN 포맷 명세
│   ├── decisions/          # ADR 문서 (C06)
│   ├── constraints/        # C01~C09 상세 기준
│   ├── specs/
│   │   ├── worktree-spec.md
│   │   └── ui-verification.md
│   └── reference/
│       ├── ARCHITECTURE.md
│       ├── PLAN_SYSTEM.md
│       ├── design-system.md
│       ├── reliability.md
│       ├── observability.md
│       └── bootstrap-roadmap.md
│
├── logs/                   # gc-agent --collect 자동 기록
│   ├── metrics/            # context_budget_pct, task_duration_hours
│   ├── traces/             # 스크립트 실행 기록
│   └── events/             # constraint_fail, checkpoint_triggered 등
│
└── .harness/
    ├── session/
    │   ├── task.md         # 현재 작업 (EXEC_PLAN 포함)
    │   └── open-questions.md
    ├── context/
    │   └── current.md      # 로드된 컨텍스트 (400줄 예산)
    └── reports/
        ├── debt-report.md
        ├── last-check.json
        └── history/        # 이전 task.md 백업
```

---

## 트러블슈팅

### constraint-check.sh가 FAIL을 반환한다

```sh
# 1. 어떤 제약이 실패했는지 확인
sh scripts/constraint-check.sh

# 2. 특정 제약만 단독 실행 (상세 메시지 확인)
HARNESS_ROOT=. sh linters/session-checkpoint.sh

# 3. 해당 C번호 문서 읽기
cat docs/constraints/C07.md
```

### C07 체크포인트가 계속 FAIL 된다

```sh
# 원인 1: 태스크 시간 초과
# → .harness/session/task.md의 started_at 갱신
date -u +%Y-%m-%dT%H:%M:%SZ  # 현재 시각 복사 후 task.md에 붙여넣기

# 원인 2: open-questions 누적
# → 미결 항목 해소 또는 정리
vi .harness/session/open-questions.md

# 원인 3: budget_warn_streak 누적
# → gc-agent 실행으로 streak 계산 갱신
sh scripts/gc-agent.sh --scan --collect
```

### 컨텍스트 예산(budget)이 초과됐다

```sh
# 현재 상태 확인
sh scripts/context-loader.sh --verify

# WARN(320줄 초과): gc-agent로 정리 후 세션 재시작 고려
sh scripts/gc-agent.sh --scan --collect

# FAIL(400줄 초과): 체크포인트 후 새 세션 시작
# 1. 미결 항목 open-questions.md에 기록
# 2. task.md 완료 상태로 업데이트
# 3. 새 세션에서 context-loader.sh 재실행
```

### Git 훅 pre-commit이 느리다

constraint-check.sh는 기본적으로 활성 phase의 모든 린터를 실행한다.
빠른 훅이 필요하다면 핵심 제약만 선택한다:

```sh
# pre-commit에서 C05(main 커밋 금지)만 체크
sh scripts/constraint-check.sh --only C05
```

### `harness-init.sh` 이후 scripts/가 비어 있다

`harness-init.sh`는 `scripts/` 디렉토리를 먼저 생성한 뒤 복사 조건을 확인하는 구조상,
자동 복사가 생략될 수 있다. 수동으로 복사한다:

```sh
HARNESS_SRC=/path/to/harness-infra
cp -r "$HARNESS_SRC/scripts/."    ./scripts/
cp -r "$HARNESS_SRC/linters/."    ./linters/
cp -r "$HARNESS_SRC/validators/." ./validators/
```

### 플러그인 hook.sh가 실행되지 않는다

```sh
# 1. plugin.yaml hooks 필드 확인
cat plugins/observability/plugin.yaml

# 2. hook.sh 존재 여부 확인
ls plugins/observability/hook.sh

# 3. requires_env 환경변수 설정 여부 확인
# → plugin.yaml의 requires_env 항목에 해당하는 환경변수가 설정돼 있어야 한다

# 4. trace 로그에서 skip 원인 확인
ls logs/traces/
cat logs/traces/*observability*.log
```

---

## Phase 전환 가이드

| 현재 → 목표 | 추가 제약 | 전환 조건 |
|------------|---------|---------|
| planning → dev | C01, C07, C09 | C02·C03·C06 안정, ADR 1개 이상 |
| dev → stab | C04, C08 | C07 무발동 지속, 테스트 커버리지 기준 |
| stab → prod | C05 | C08 UI 검증 완료, SLO 충족 |

```sh
# HARNESS.md phase 변경 후 환경변수 갱신
sed -i 's/^phase: planning/phase: dev/' HARNESS.md
export HARNESS_PHASE=dev
sh scripts/constraint-check.sh
```

---

## 적용 대상

**적합한 프로젝트:**
- AI 에이전트를 반복적으로 활용하는 중규모 이상 프로젝트
- 세션이 길어지고 여러 명이 AI와 협업하는 환경
- 컨텍스트 드리프트로 인해 지침 준수율이 떨어지는 경우

**적합하지 않은 프로젝트:**
- 단발성 스크립트·소규모 프로젝트 (오버헤드가 이점을 초과)
- AI를 보조 도구로만 사용하고 세션이 짧은 경우

---

## 라이선스

이 하네스 인프라는 공개 사용 가능하며 자유롭게 수정·배포할 수 있다.
