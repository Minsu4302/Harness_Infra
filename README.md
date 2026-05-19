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

**4. RAG + CoT 조합의 토큰 누적**
RAG로 관련 문서를 동적 주입하고, 태스크 유형별 CoT 템플릿으로 구조화된 추론을 유도하는 방식은 효과적이지만 토큰 소모가 급격히 증가한다. 원인은 CoT 템플릿이 매 턴 5단계 × 3개 서브질문(15개 항목)에 대한 답변을 강제해, 약 300 tokens의 추론 출력이 생성되고 이것이 다음 턴의 입력으로 그대로 누적되기 때문이다. 5턴짜리 세션에서 구조화 전후의 토큰 소모가 10,600 vs 5,940 tokens으로 벌어지는 것을 실측했다.

**5. RAG 재검색 비용과 검색 결과 중복**
세션마다 `rag-search.sh`가 14개 문서 전체를 키워드 × grep으로 재스캔한다. 동일한 task.md 제목이라면 결과가 항상 같음에도 캐시가 없어 매번 전체를 재처리한다. 또한 키워드 빈도만으로 top-K를 선별하면 유사 주제 문서가 중복 선택될 수 있다 — "constraint security" 쿼리에서 관련성 높은 Security Checklist 대신 Bootstrap Roadmap이 3위에 오르는 현상이 실측됐다. 세션이 새로 시작될 때마다 이전 완료 작업의 맥락도 초기화돼, 에이전트가 직전 세션의 결과를 다시 파악해야 하는 비용도 존재한다.

### 핵심 아이디어 — 환경 자체를 설계하자

| 레이어 | 정의 | 이 프로젝트의 구현 |
|--------|------|------------------|
| **프롬프트 엔지니어링** | 모델에게 *무엇을* 말할지 최적화 | 태스크 유형별 CoT 템플릿 + few-shot 예시 자동 주입 |
| **컨텍스트 엔지니어링** | 모델이 *무엇을* 볼지 관리 | 400줄 예산 관리, RAG로 현재 태스크 관련 문서 TOP 3 동적 주입 |
| **하네스 엔지니어링** | 모델이 *어디서* 작동하는지 설계 | C01~C09 린터, pre-commit 훅, 플러그인 아키텍처 |

**하네스(Harness)** 는 AI 에이전트를 둘러싼 스캐폴딩, 제약 조건, 피드백 루프의 총체적 환경이다. 단일 `.md` 파일에 모든 지침을 몰아넣는 방식 대신, 세 레이어를 셸 스크립트와 구조화된 템플릿으로 분리해 구현한다.

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
│ prompt-selector  │ C01~C09 린터     │ logs/ 관측성     │
│ rag-search       │ pre-commit 훅    │ debt-report      │
│ CoT 템플릿 주입  │                  │                  │
│ 400줄 예산 관리  │                  │                  │
└──────────────────┴──────────────────┴──────────────────┘
```

### 토큰 최적화 레이어 — Skeleton-of-Thought + Conditional CoT

RAG + CoT 조합 도입 후 실측한 문제: CoT 5단계 추론이 매 턴 ~300 tokens의 출력을 생성하고, 이것이 다음 턴의 입력으로 쌓여 토큰 소모가 복리로 증가한다. 5턴 세션에서 총 **10,600 tokens** 소모.

**해결 1 — Skeleton-of-Thought (SoT)**

기존 CoT의 "5단계 × 3 서브질문 = 15개 답변 강제" 구조를, 3-Phase 스켈레톤-우선 방식으로 교체한다.

```
Phase 1 — 스켈레톤 (5줄, 1분 이내)   ← 모든 항목을 한 줄로만
Phase 2 — 선택적 심화                 ← 위험 항목에만 2-3줄 추가, 생략 가능
Phase 3 — EXEC_PLAN 작성             ← task.md 형식으로 바로 작성
```

**해결 2 — Conditional CoT**

`task.md`에 `complexity: low|medium|high` 필드를 추가해 태스크 복잡도에 따라 CoT 범위를 조정한다.

| complexity | 출력 내용 | 예상 출력 토큰 |
|---|---|---|
| `high` (기본) | Phase 1 + 2 + 3 | ~200 tokens |
| `medium` | Phase 1 + 3 (Phase 2 생략) | ~155 tokens |
| `low` | 완료 체크리스트만 | ~30 tokens |

**해결 3 — 토큰 측정 인프라**

`gc-agent --collect` 실행 시 `token_estimate_input` 메트릭을 `logs/metrics/{date}.jsonl`에 기록한다 (bytes / 3 추정). `current.md`의 Context Budget 섹션에도 표시된다.

**실측 절감 수치 (feature 태스크 기준):**

| 항목 | 구버전 (v1.0.0) | 신버전 SoT (v2.0.0) | 절감 |
|---|---|---|---|
| 템플릿 크기 | 1,801 bytes / 48줄 | 1,031 bytes / 36줄 | -43% |
| 컨텍스트 입력 토큰 | **1,220** | **963** | **-21%** |
| CoT 출력 토큰 (추정) | **~300** | **~75** | **-75%** |
| 5턴 누적 합계 | **10,600** | **5,940** | **-43%** |

> 입력 토큰은 `wc -c / 3`으로 실측. 출력 토큰은 템플릿 서브질문 수 기반 추정(15개→5개).

---

### RAG 검색 레이어 — 동적 컨텍스트 주입

`context-loader.sh`가 `current.md`를 컴파일할 때, 전체 문서를 고정 로딩하는 대신
`rag-search.sh`가 현재 `task.md`의 title·goal에서 키워드를 추출해 관련도 순으로 문서를 선별 주입한다.

| 항목 | 수치 |
|------|------|
| 검색 대상 문서 수 | 14개 (constraints 9 + decisions 1 + specs 4) |
| 주입 문서 수 (TOP K) | 3개 |
| 문서당 발췌 길이 | 원문 12줄 → 요약 5줄 (A3 사전 압축 시) |
| RAG 섹션 크기 | 원문 발췌 51줄 → 요약 30줄 (**-41%**, A3 적용) |
| 전체 컨텍스트 예산 사용 | **114 / 400줄 (29%)**  (세션 버퍼 포함) |
| 구현 방식 | POSIX sh 키워드 빈도 스코어링 + MMR 재랭킹 (외부 런타임 의존성 없음) |

### 캐싱 + 검색 최적화 레이어 — Layer A + B

RAG 재검색 비용과 컨텍스트 품질 문제를 4개 모듈로 해결한다.

**A2 — RAG 쿼리 해시 캐시**

키워드를 `cksum`으로 해시화해 `.harness/cache/rag/<hash>.md`에 결과를 저장한다.
동일 쿼리 재실행 시 14개 문서 전수 재스캔 없이 캐시를 즉시 반환한다.
소스 문서가 변경되면 `find -newer` 비교로 자동 무효화된다.

**A3 — 문서 사전 압축**

`doc-compress.sh`가 14개 문서에서 헤딩·불릿 중심 5줄 요약을 `.harness/cache/summaries/`에 사전 생성한다.
`rag-search.sh`가 요약 파일을 원문 발췌 대신 우선 사용한다.

| 항목 | 원문 발췌 | A3 요약 | 절감 |
|---|---|---|---|
| 문서당 줄수 | 12줄 | 5줄 | -58% |
| TOP 3 RAG 섹션 전체 | **51줄** | **30줄** | **-41%** |

**B1 — MMR 재랭킹 (Maximal Marginal Relevance)**

키워드 빈도 스코어만으로 top-K를 선택하면 유사 주제 문서가 연속 선정될 수 있다.
MMR은 각 후보 문서에 대해 `score(d) - λ × max_sim(d, selected)` 를 계산해
이미 선택된 문서와 키워드 중복이 많을수록 페널티를 부여한다.

```
MMR score(d) = 관련성 - λ × max(이미 선택된 문서와의 키워드 겹침 수)
               λ = 0.5 기본값  (0 = 관련성만, 1 = 다양성만)
```

실측 (`"constraint security"` 쿼리, TOP 3):

| 순위 | MMR OFF | MMR ON (λ=0.5) |
|---|---|---|
| 1 | C01-Harness Size | C01-Harness Size |
| 2 | Bootstrap Roadmap | Security Checklist ← 관련성 복원 |
| 3 | Security Checklist | Bootstrap Roadmap |

→ 키워드 중복이 적은 Security Checklist가 2위로 승격 (Bootstrap Roadmap과 순서 교체).

**B2 — 세션 버퍼 메모리 (Session Buffer Memory)**

`session-buffer.sh`가 `status: completed` 태스크를 `.harness/session/buffer.md`에 1줄 요약으로 기록한다.
`context-loader.sh`가 태스크 백업 시 자동 수집하고, `current.md`에 `## 세션 버퍼` 섹션으로 주입한다.

| 항목 | 기존 (수동 history/ 참조) | B2 세션 버퍼 |
|---|---|---|
| 이전 세션 1개 참조 비용 | ~60줄 (task 백업 파일 전체) | 1줄 |
| 10개 세션 이력 전체 | ~600줄 | 10줄 (**-98%**) |
| current.md 추가 비용 | 0줄 (별도 참조) | **+9줄** (고정) |

`current.md` 컴파일 결과 구조 (업데이트):

```
## 활성 제약 조건   — 전체 제약 ID 목록 (정적, 약 7줄)
## 관련 문서 (RAG) — 현재 태스크 관련 문서 TOP 3 (동적, 30줄, A3+B1 적용)
## 기술 부채 요약  — CRITICAL/WARN 섹션 발췌
## 세션 버퍼       — 완료된 태스크 이력 요약 (최대 10줄, B2)
## 태스크 프롬프트 — 태스크 유형별 CoT 템플릿 (~50줄)
## Context Budget  — 예산 사용 현황 + token_estimate_input
```

---

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
| 프롬프트가 맥락 없이 단순 나열 | 태스크 유형별 CoT 템플릿이 세션에 자동 주입 |
| 프로젝트 규모가 커져도 문서 전체 로딩 | RAG가 현재 태스크 관련 문서 14개 중 TOP 3만 선별 (114/400줄, 29%) |
| RAG + CoT 조합으로 토큰 누적 폭증 | SoT가 CoT 출력 75% 절감, 5턴 누적 43% 감소 (10,600→5,940 tokens) |
| 동일 쿼리도 매 세션 14개 문서 전수 재스캔 | A2 캐시가 재검색 비용 0으로 처리 (문서 변경 시 자동 무효화) |
| 유사 주제 문서가 연속 선택돼 컨텍스트 중복 | B1 MMR(λ=0.5)이 키워드 중복 페널티로 다양성 보장 |
| 세션마다 이전 완료 작업 맥락 재파악 필요 | B2 세션 버퍼가 10개 이력을 9줄로 자동 압축 주입 |

---

## 한눈에 보는 수치

| 항목 | 수치 |
|------|------|
| 자동화 제약 | 9개 (C01~C09) — 8개 완전 자동, 1개 반자동 (자동화율 **89%**) |
| 핵심 스크립트 | 8개 (context-loader / prompt-selector / rag-search / constraint-check / gc-agent / harness-init / doc-compress / session-buffer) |
| 독립 린터 | 9개 — CI·Git 훅·수동 실행 모두 동일 결과 |
| E2E 테스트 | 8개 (T01~T08) |
| 컨텍스트 예산 | 최대 **400줄** (WARN 320줄 / FAIL 400줄) |
| CoT 프롬프트 템플릿 | 4종, 3-Phase Skeleton-of-Thought (v2.0.0) |
| CoT complexity 분기 | `low` / `medium` / `high` — 출력 토큰 ~30 / ~155 / ~200 |
| RAG 검색 대상 | **14개** 문서 → TOP **3** 동적 주입 (컨텍스트 29% 사용) |
| 토큰 절감 (feature, 5턴) | 구 **10,600** → 신 **5,940** tokens (**-43%**, SoT 적용) |
| 입력 토큰 추정 | `token_estimate_input` 메트릭 자동 기록 (gc-agent --collect) |
| RAG 문서 압축 (A3) | 원문 발췌 **51줄** → 요약 **30줄** (**-41%**, doc-compress.sh 사전 생성) |
| RAG 쿼리 캐시 (A2) | 동일 쿼리 재실행 시 재검색 비용 **0** (cksum 해시, 문서 변경 시 자동 무효화) |
| MMR 재랭킹 (B1) | λ=**0.5** 기본값, 키워드 중복 문서 페널티 → 검색 결과 다양성 보장 |
| 세션 버퍼 (B2) | 완료 이력 최대 **10개**, current.md **+9줄** (태스크당 60줄 → 1줄, **-98%**) |
| 세션 시간 제한 | **4시간** 초과 시 C07 체크포인트 강제 |
| EXEC_PLAN steps 제한 | 최대 **7단계** (초과 시 태스크 분할) |
| 미결 항목 제한 | `open-questions.md` **5개** 초과 시 체크포인트 강제 |

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

# 4. 문서 요약 사전 생성 (A3, RAG 발췌 -41%)
sh scripts/doc-compress.sh

# 5. 첫 검증
sh scripts/constraint-check.sh
```

### 일반 작업 사이클

```sh
# 세션 시작 — --task-type 지정 시 해당 CoT 템플릿이 컨텍스트에 자동 주입됨
sh scripts/context-loader.sh --task-type feature   # 기능 개발
sh scripts/context-loader.sh --task-type bug       # 버그 수정
sh scripts/context-loader.sh --task-type refactor  # 리팩터링

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
complexity: high        # low | medium | high — CoT 출력 범위 조정 (기본: high)
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

**자동화율: 8/9 = 89% 완전 자동** (C06 아키텍처 결정 기록만 반자동)

C07 트리거 조건 (하나라도 충족 시 FAIL):
- 태스크 시작 후 **4시간** 초과
- 컨텍스트 예산(400줄) **80%** 초과가 **3회** 연속
- `open-questions.md` 미결 항목 **5개** 초과

---

## 디렉토리 구조

```
harness-infra/
├── HARNESS.md              # 설정 및 활성 제약 (YAML frontmatter)
├── CLAUDE.md               # Claude Code 워크플로 규칙 (7개)
├── AGENTS.md               # 에이전트 진입점 인덱스
│
├── scripts/
│   ├── context-loader.sh   # compile / --verify 모드, 400줄 예산 + CoT + RAG 주입
│   ├── prompt-selector.sh  # 태스크 유형별 CoT 템플릿 선택 및 이벤트 로깅
│   ├── rag-search.sh       # 키워드 RAG 검색, A2 캐시·A3 요약·B1 MMR 통합 (POSIX sh)
│   ├── doc-compress.sh     # A3 문서 사전 압축 (docs/ → .harness/cache/summaries/)
│   ├── session-buffer.sh   # B2 세션 버퍼 관리 (완료 이력 최대 10개)
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
│   ├── metrics/            # context_budget_pct, token_estimate_input, task_duration_hours
│   ├── traces/             # 스크립트 실행 기록
│   └── events/             # constraint_fail, checkpoint_triggered, prompt_selected 등
│
└── .harness/
    ├── session/
    │   ├── task.md         # 현재 작업 (EXEC_PLAN 포함)
    │   ├── buffer.md       # B2 세션 버퍼 (완료 이력 최대 10줄)
    │   └── open-questions.md
    ├── cache/
    │   ├── rag/            # A2 쿼리 해시 캐시 (<hash>.md)
    │   └── summaries/      # A3 문서 사전 압축 (5줄 요약, docs/ 구조 미러)
    ├── context/
    │   └── current.md      # 로드된 컨텍스트 (400줄 예산, RAG·CoT·버퍼 포함)
    ├── prompts/
    │   ├── registry.yaml   # 프롬프트 버전 레지스트리
    │   ├── templates/
    │   │   ├── feature.md  # 기능 개발 — 3-Phase SoT v2.0.0 (complexity 분기 지원)
    │   │   ├── bugfix.md   # 버그 수정 — 3-Phase SoT v2.0.0 (재현 우선)
    │   │   ├── refactor.md # 리팩터링 — 3-Phase SoT v2.0.0 (동작 보존)
    │   │   └── general.md  # 범용 — 3-Phase SoT v2.0.0
    │   └── examples/
    │       ├── exec-plan-good.md  # few-shot positive
    │       └── exec-plan-bad.md   # few-shot negative (안티패턴)
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

| 현재 → 목표 | 활성 제약 수 | 추가 제약 | 전환 조건 |
|------------|:-----------:|---------|---------|
| planning → dev | 3개 → 5개 | C01, C07, C09 | C02·C03·C06 안정, ADR 1개 이상 |
| dev → stab | 5개 → 7개 | C04, C08 | C07 무발동 지속, 테스트 커버리지 기준 |
| stab → prod | 7개 → 8개 | C05 | C08 UI 검증 완료, SLO 충족 |

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

## AI Orchestration — Layer C

Harness 인프라 위에 올라가는 AI 에이전트 오케스트레이션 레이어.
Claude가 PR diff를 분석해 어떤 에이전트를 어떤 모델로 실행할지 동적으로 결정하고,
결과를 GitHub PR Comment로 자동 게시하며, 에이전트 간 충돌 시 Claude가 직접 중재한다.

### 동기

개발자들이 AI를 비효율적으로 사용해 하루 토큰 한도를 소진하면 당일 개발이 중단된다.
AI Orchestration은 최소한의 에이전트만 실행해 토큰 낭비를 방지하고, Harness가 그 환경을 최적화한다.

> "AI 토큰 효율화 → 회사 지출 절감 + 개발자 능률 향상"

### 파이프라인 흐름

```
POST /api/orchestrate  ← GitHub Actions (PR 이벤트)
  ↓
ContextPruner          lock·바이너리 제거, 8000자 트런케이트 (토큰 절감)
  ↓
OrchestratorService    Claude가 에이전트·모델 동적 결정 (Supervisor-Worker)
  ↓
executeAgentsInParallel  CompletableFuture 3개 병렬, 타임아웃 120s → WARN SKIP
  ├── review    → Claude Sonnet 4.6   복잡한 코드 추론
  ├── security  → Gemini 1.5 Flash    패턴 매칭·빠른 취약점 스캔
  └── test-gen  → GPT-4o-mini         코드 생성·테스트 스캐폴딩
  ↓
ConflictResolver       review↔security 충돌(XOR FAIL) 시 Claude 재위임
  ↓
DeploymentGateService  <details><summary> PR Comment 리포트 생성
  ↓
GitHub PR Comment      APPROVED / REJECTED
```

### Layer C 구현 이력

| 레이어 | 내용 | 핵심 결과물 |
|--------|------|------------|
| C-1 | Spring Boot AI Orchestration 기반 — 3 에이전트 + 멀티엔드포인트 | `OrchestratorService`, `AgentRequest/Result/GateResult` |
| C-2 | Orchestrator + 멀티모델 라우팅 (Claude + Gemini) | `AnthropicGateway`, `GeminiGateway`, `ModelRouter`, `OrchestrationPlan` |
| C-3 | Context Pruning + 병렬 실행·타임아웃 가드 | `ContextPruner`, `PruneResult`, `CompletableFuture.orTimeout(120s)` |
| C-4 | PR Comment UI (`<details>`) + Conflict Resolution | `ConflictResolver`, `ConflictResolution`, 접기/펼치기 마크다운 |
| C-5 | GPT-4o-mini 3번째 모델 추가 | `OpenAiGateway`, `ModelRouter` gpt 라우팅 |
| C-6 | Docker + GCP e2-micro + GitHub Actions CI/CD | `Dockerfile`, `deploy.yml`, `orchestrate.yml` |

### 모델 분담 (Orchestrator가 동적 결정)

| 모델 | 기본 에이전트 | 이유 |
|------|-------------|------|
| Claude Sonnet 4.6 | review | 복잡한 코드 추론·아키텍처 판단 |
| Gemini 1.5 Flash | security | 패턴 매칭·빠른 취약점 스캔 |
| GPT-4o-mini | test-gen | 코드 생성·테스트 스캐폴딩 (가성비) |

> Orchestrator가 diff 분석 후 에이전트별 최적 모델을 동적으로 선택. docs-only diff면 review만, security-sensitive 변경이면 security 필수 포함.

### Conflict Resolution — Claude 중재

review와 security가 상반된 결론(한쪽만 FAIL)을 낼 때, 규칙이 아닌 Claude가 최종 판단한다.

```
review=FAIL, security=PASS  →  Claude가 양쪽 요약을 받아 APPROVED / REJECTED 결정
review=PASS, security=FAIL  →  동일
review=FAIL, security=FAIL  →  충돌 없음 → 즉시 REJECTED
review=PASS, security=PASS  →  충돌 없음 → 즉시 APPROVED
```

### PR Comment 출력 형식

```markdown
## 🤖 AI Orchestration Gate Report

✅ **APPROVED**

<details>
<summary>📋 Code Review — ⚠️ WARN</summary>

**Summary:** Minor naming convention issues

**Issues:**
- Variable name too short
</details>

<details>
<summary>🔒 Security Scan — ✅ PASS</summary>

**Summary:** No vulnerabilities detected
</details>

<details>
<summary>🧪 Test Generation — ✅ PASS</summary>

**Summary:** Tests generated for new methods

```java
@Test
void testProcessPayment() { ... }
```
</details>
```

### AI Orchestration 수치

| 항목 | 수치 |
|------|------|
| 에이전트 수 | 3개 (review, security, test-gen) |
| 지원 모델 | 3개 (Claude Sonnet, Gemini Flash, GPT-4o-mini) |
| Context Pruning 한계 | 8,000자 트런케이트 |
| 필터링 확장자 | 18종 (.lock, .png, .jar, .class 등) |
| 필터링 경로 | node_modules/, .gradle/, build/, dist/ 등 |
| 병렬 타임아웃 | 120초 (초과 시 WARN SKIP, 파이프라인 계속) |
| 배포 환경 | GCP e2-micro us-central1 (Always Free) |
| CI/CD 트리거 | push to main → 자동 배포 / PR 이벤트 → AI 게이트 |
| 단위 테스트 | 30개+ (ContextPruner, ConflictResolver, DeploymentGate 등) |

---

## GCP + GitHub Actions 설정 가이드

### 사전 요구사항

- GCP 계정 (e2-micro + us-central1 = Always Free)
- GitHub 리포지토리
- API 키 3개: `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`

### Step 1 — GCP VM 생성

GCP Console → Compute Engine → VM 인스턴스 만들기

```
이름: harness-orchestrator
리전: us-central1 (Always Free 조건)
머신 유형: e2-micro
OS: Ubuntu 22.04 LTS
디스크 유형: 표준 영구 디스크 (pd-standard, Free Tier 조건)
디스크 크기: 10~30GB
방화벽: HTTP / HTTPS 허용 체크
```

> **주의:** 예상 가격 ~$7/월로 표시되지만 e2-micro + us-central1 + pd-standard 조합은 Always Free 적용 시 실제 청구 $0.

### Step 2 — 방화벽 규칙 (포트 8080)

VPC 네트워크 → 방화벽 → 방화벽 규칙 만들기

```
이름: allow-8080
트래픽 방향: 수신 (Ingress)
소스 IP 범위: 0.0.0.0/0
프로토콜/포트: TCP 8080
```

### Step 3 — VM 초기 설정

GCP Console → VM 상세 → SSH 버튼 클릭 (브라우저 터미널)

```bash
# Docker 설치
sudo apt update && sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# API 키 파일 생성
sudo mkdir -p /opt/harness
sudo tee /opt/harness/secrets.env << 'EOF'
ANTHROPIC_API_KEY=your_anthropic_key
GEMINI_API_KEY=your_gemini_key
OPENAI_API_KEY=your_openai_key
EOF
sudo chmod 600 /opt/harness/secrets.env
```

### Step 4 — GitHub Actions SSH 키 생성

```bash
# GCP VM SSH 터미널에서 실행
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions -N ""
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 아래 출력 전체를 GitHub Secret에 등록
cat ~/.ssh/github_actions
```

### Step 5 — GitHub Secrets 등록

GitHub 리포지토리 → Settings → Secrets and variables → Actions → New repository secret

| Secret 이름 | 값 |
|------------|---|
| `GCP_INSTANCE_IP` | VM 외부 IP (예: `35.255.235.55`) |
| `GCP_USERNAME` | VM 사용자명 (`whoami` 결과) |
| `GCP_SSH_KEY` | 프라이빗 키 전체 (`-----BEGIN OPENSSH PRIVATE KEY-----` 포함) |
| `ANTHROPIC_API_KEY` | Anthropic API 키 |
| `GEMINI_API_KEY` | Google Gemini API 키 |
| `OPENAI_API_KEY` | OpenAI API 키 |

### Step 6 — GitHub Container Registry 이미지 공개

최초 push 후 이미지가 생성되면:

GitHub → Packages → `orchestration-service` → Package settings → **Change visibility → Public**

> 비공개 상태면 GCP VM에서 pull 시 인증 실패. Public으로 변경하면 별도 인증 없이 pull 가능.

### Step 7 — 동작 확인

```bash
# main 브랜치 push 후 GitHub Actions 탭에서 "Build and Deploy" green 확인

# GCP VM SSH에서 컨테이너 상태 확인
docker ps
docker logs orchestration-service

# 직접 호출 테스트
curl -X POST http://localhost:8080/api/orchestrate \
  -H "Content-Type: application/json" \
  -d '{"diff": "+public class Hello {}"}'
```

---

## 트러블슈팅 — AI Orchestration

### deploy.yml: SSH 접속 실패

```
증상: appleboy/ssh-action 에러 "ssh: handshake failed"
원인: GCP_SSH_KEY가 잘못 등록됨

확인:
- 프라이빗 키를 -----BEGIN OPENSSH PRIVATE KEY----- 부터
  -----END OPENSSH PRIVATE KEY----- 까지 전체 복사했는지 확인
- 줄바꿈 포함 전체 내용이 Secret에 들어갔는지 확인
```

### deploy.yml: docker pull 실패 (unauthorized)

```
증상: "unauthorized: unauthenticated" 에러
원인: ghcr.io 패키지가 비공개 상태

해결: GitHub → Packages → orchestration-service
      → Package settings → Change visibility → Public
```

### orchestrate.yml: curl: Connection refused

```
원인 1: VM 중지 또는 포트 8080 방화벽 규칙 미적용
  확인: GCP Console → VM 상태 "실행 중" 확인
        방화벽 규칙 allow-8080 존재 확인

원인 2: Docker 컨테이너 미실행
  확인: VM SSH → docker ps (orchestration-service 없으면 미실행)
        docker logs orchestration-service (시작 실패 원인 확인)
```

### orchestrate.yml: curl timeout (300초 초과)

```
원인: LLM API 응답 지연 또는 API 키 오류
확인: docker logs orchestration-service | grep -E "ERROR|WARN"
      /opt/harness/secrets.env 키 값 유효성 확인
```

### 외부 IP가 변경됨

```
증상: deploy.yml SSH 접속 실패, orchestrate.yml curl 실패
원인: GCP e2-micro 외부 IP는 임시(Ephemeral) — VM 재시작 시 변경 가능

해결 1 (무료): GitHub Secret GCP_INSTANCE_IP 업데이트
해결 2 (소액 과금): GCP Console → VPC 네트워크 → 외부 IP 주소
                    → 고정(Static) IP 예약
```

### Spring Boot 시작 실패: API 키 없음

```
증상: docker logs에서 아래 메시지 확인
  "Could not resolve placeholder 'ANTHROPIC_API_KEY'"

확인:
  cat /opt/harness/secrets.env    # 파일 내용 확인
  docker inspect orchestration-service  # --env-file 옵션 포함 여부 확인
```

### Orchestrator가 항상 3개 에이전트를 실행한다

```
증상: docs-only diff인데 review/security/test-gen 모두 실행됨
원인: Claude의 plan() 응답 파싱 실패 → defaultPlan() 폴백 동작

확인: docker logs orchestration-service | grep "plan parse failed"
      → 파싱 실패 원인 확인 (Claude 응답 형식 문제)
```

---

## 라이선스

이 하네스 인프라는 공개 사용 가능하며 자유롭게 수정·배포할 수 있다.
