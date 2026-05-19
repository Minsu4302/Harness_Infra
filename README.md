# Harness Engineering + AI Orchestration

AI 에이전트의 실행 환경 전체를 구조화하는 컨텍스트 제어 인프라와, Claude·Gemini·GPT를 동적으로 조율하는 AI 오케스트레이션 서비스.

---

## 핵심 개념: 왜 "Harness"인가

대화가 길어질수록 초반에 내린 지침이 희석되거나 무시된다 — **Context Drift**.  
단일 `.md` 파일로 모든 지침을 제공하면, 파일이 커질수록 AI가 전체를 완벽히 준수하지 못하고 금지된 행동을 반복한다.  
이 문제는 "더 좋은 프롬프트 작성"이나 "컨텍스트 재설계"만으로는 해결되지 않는다.

| 레벨 | 개념 | 접근 |
|------|------|------|
| 1 | **프롬프트 엔지니어링** | 모델에게 *무엇을 말할지* 최적화 |
| 2 | **컨텍스트 엔지니어링** | 모델이 *무엇을 볼지* 관리 |
| 3 | **하네스 엔지니어링** | 모델이 *어디서 작동하는지* 설계 — 환경, 피드백 루프, 제어 시스템 전체를 구조화 |

**Harness = AI 에이전트를 둘러싼 스캐폴딩 + 제약 조건 + 피드백 루프의 총체적 환경**

단일 `.md` 파일에 모든 지침을 몰아넣는 방식 대신, **셸 스크립트 기반 제어 레이어 + 플러그인 방식의 모듈 아키텍처**로 이를 대체하는 것이 이 프로젝트의 목표다.

---

## 왜 만들었나

개발자들이 AI를 비효율적으로 사용해 하루 토큰 한도를 소진하면 당일 개발이 중단된다.

**문제 체인:** 비효율적 AI 사용 → 토큰 소진 → 당일 개발 중단 → 회사 비용 증가 + 능률 저하

**해결:**
- **Harness** — 셸 스크립트 제어 레이어가 컨텍스트 오염을 방지하고, 세션 예산을 자동 감시
- **Orchestration** — Claude Planner가 diff를 분석해 필요한 에이전트만 선택적으로 실행

---

## 전체 아키텍처

```
[개발자 PR 오픈]
      │
      ▼
GitHub Actions (orchestrate.yml)
      │  PR diff 전송
      ▼
┌─────────────────────────────────────────┐
│         Spring Boot (GCP e2-micro)       │
│                                          │
│  ContextPruner                           │
│  └─ lock·바이너리 제거, 8000자 트런케이트 │
│                                          │
│  OrchestratorService (Claude Planner)    │
│  └─ diff 분석 → 에이전트·모델 동적 결정  │
│                                          │
│  병렬 실행 (CompletableFuture, 120s 제한) │
│  ├─ review    → Claude Sonnet 4.6        │
│  ├─ security  → Gemini 1.5 Flash         │
│  └─ test-gen  → GPT-4o-mini              │
│                                          │
│  ConflictResolver                        │
│  └─ 에이전트 충돌 시 Claude 재위임        │
│                                          │
│  DeploymentGateService                   │
│  └─ APPROVED / REJECTED 판정             │
└─────────────────────────────────────────┘
      │
      ▼
PR Comment (<details> 접기/펼치기 리포트)
```

**CI/CD:** `push to main` → GitHub Actions → ghcr.io 이미지 빌드·푸시 → GCP SSH 자동 재배포

---

## 레이어 구조

### Harness — 컨텍스트 제어 레이어

| 레이어 | 내용 |
|--------|------|
| A2 | RAG 쿼리 해시 캐시 — 동일 쿼리 재검색 비용 0 (문서 변경 시 자동 무효화) |
| A3 | 문서 사전 압축 — 원문 51줄 → 요약 30줄 (-41%) |
| B1 | MMR 재랭킹 — 유사 문서 중복 페널티 (λ=0.5), 검색 결과 다양성 보장 |
| B2 | 세션 버퍼 — 완료 이력 60줄 → 1줄 (-98%), `current.md` +9줄 고정 주입 |

각 레이어는 독립된 셸 스크립트 모듈로 동작한다. 단일 지침 파일 대신 **스크립트가 AI가 볼 컨텍스트를 능동적으로 필터링·주입**한다.

```
scripts/
├── harness-init.sh       # 세션 환경 초기화 (phase 설정)
├── context-loader.sh     # CoT 템플릿 주입 + 세션 버퍼 로드
├── doc-compress.sh       # 문서 사전 압축 (A3)
├── constraint-check.sh   # 9개 제약 조건 자동 검증
└── gc-agent.sh           # 예산 감시 + 오래된 컨텍스트 GC
```

### Orchestration — AI 에이전트 게이트

| 레이어 | 내용 |
|--------|------|
| C-1 | Spring Boot 3.3 + Java 21 기반, 3 에이전트 + 게이트 구조 |
| C-2 | Claude + Gemini + GPT 멀티모델 라우팅 (`LlmGateway` 추상화) |
| C-3 | Context Pruning + CompletableFuture 병렬 실행 + 120s 타임아웃 가드 |
| C-4 | `<details>` PR Comment UI + Claude 기반 Conflict Resolution |
| C-5 | GPT-4o-mini 3번째 모델 추가 (test-gen 기본 배정) |
| C-6 | Docker 멀티스테이지 빌드 + GCP e2-micro + GitHub Actions CI/CD |

---

## 핵심 수치

| 항목 | 수치 |
|------|------|
| 토큰 절감 (feature 태스크, 5턴) | 10,600 → 5,940 tokens **(-43%)** |
| CoT 출력 토큰 절감 (SoT 적용) | ~300 → ~75 tokens **(-75%)** |
| RAG 문서 압축 (A3) | 51줄 → 30줄 **(-41%)** |
| 세션 이력 압축 (B2) | 태스크당 60줄 → 1줄 **(-98%)** |
| RAG 재검색 비용 (A2 캐시 hit) | **0** (문서 변경 시 자동 무효화) |
| 제약 자동화율 | 9개 중 8개 완전 자동 **(89%)** |
| Context Pruning 한계 | **8,000자** 트런케이트 |
| 에이전트 타임아웃 | **120초** 초과 시 WARN SKIP, 파이프라인 계속 |
| 지원 모델 | **3개** (Claude Sonnet, Gemini Flash, GPT-4o-mini) |
| 배포 비용 | GCP e2-micro us-central1 **$0/월** (Always Free) |

---

## GCP + GitHub Actions 설정

### 1. GCP VM 생성

```
Compute Engine → VM 인스턴스 만들기
이름: harness-orchestrator / 리전: us-central1 / 머신: e2-micro
OS: Ubuntu 22.04 LTS / 디스크: 표준 영구 디스크 10GB
방화벽: HTTP + HTTPS 허용
```

> 예상 가격 ~$7/월로 표시되지만 e2-micro + us-central1 + 표준 디스크 조합은 실제 청구 **$0**.

### 2. 방화벽 규칙 (포트 8080)

VPC 네트워크 → 방화벽 → 규칙 만들기: `수신 / 0.0.0.0/0 / TCP 8080`

### 3. VM 초기 설정 (GCP Console SSH)

```bash
sudo apt update && sudo apt install -y docker.io
sudo systemctl enable --now docker && sudo usermod -aG docker $USER

sudo mkdir -p /opt/harness
sudo tee /opt/harness/secrets.env << 'EOF'
ANTHROPIC_API_KEY=your_key
GEMINI_API_KEY=your_key
OPENAI_API_KEY=your_key
EOF
sudo chmod 600 /opt/harness/secrets.env && sudo chown $USER /opt/harness/secrets.env
```

### 4. GitHub Actions SSH 키

```bash
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions -N ""
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/github_actions   # 이 내용을 GCP_SSH_KEY Secret에 등록
```

### 5. GitHub Secrets 등록

`Settings → Secrets and variables → Actions`

| Secret | 값 |
|--------|---|
| `GCP_INSTANCE_IP` | VM 외부 IP |
| `GCP_USERNAME` | `whoami` 결과 |
| `GCP_SSH_KEY` | 프라이빗 키 전체 (`-----BEGIN...END-----` 포함) |
| `ANTHROPIC_API_KEY` | Anthropic API 키 |
| `GEMINI_API_KEY` | Gemini API 키 |
| `OPENAI_API_KEY` | OpenAI API 키 |

### 6. 이미지 공개 설정

최초 push 후: `GitHub → Packages → orchestration-service → Package settings → Make public`

---

## Harness 빠른 시작

```bash
# 초기화
sh scripts/harness-init.sh . --phase=planning
export HARNESS_ROOT=$(pwd) HARNESS_PHASE=dev

# 세션 시작 (CoT 템플릿 자동 주입)
sh scripts/context-loader.sh --task-type feature

# 문서 압축 사전 생성 (A3, RAG -41%)
sh scripts/doc-compress.sh

# 커밋 전 제약 검증
sh scripts/constraint-check.sh
```

---

## 트러블슈팅

**`constraint-check.sh` FAIL**
```bash
sh scripts/constraint-check.sh          # 어떤 제약인지 확인
HARNESS_ROOT=. sh linters/session-checkpoint.sh  # C07 단독 실행
```

**C07 체크포인트 반복 실패**
```bash
date -u +%Y-%m-%dT%H:%M:%SZ             # 결과를 task.md started_at에 갱신
sh scripts/gc-agent.sh --scan --collect  # budget_warn_streak 초기화
```

**deploy.yml: SSH timeout (`i/o timeout`)**
```
원인 1: 외부 IP 변경 (임시 IP는 VM 재시작 시 바뀜)
  → GCP Console에서 현재 IP 확인 후 GCP_INSTANCE_IP Secret 업데이트
원인 2: 포트 22 방화벽 규칙 누락
  → VPC 네트워크 → 방화벽에서 default-allow-ssh 확인
```

**deploy.yml: `docker pull` unauthorized**
```
→ GitHub → Packages → orchestration-service → Package settings → Make public
```

**orchestrate.yml: curl 500 에러**
```bash
docker logs orchestration-service 2>&1 | grep -E "ERROR|Caused by"
# Jackson 버전 충돌 시: build.gradle에 ext { set('jackson-bom.version', '2.18.1') } 추가
```

**Spring Boot 시작 실패 (API 키 없음)**
```bash
cat /opt/harness/secrets.env            # 파일 내용 확인
ls -la /opt/harness/secrets.env         # 소유자/권한 확인 (chown $USER 필요)
```

---

## 제약 조건

| ID | 내용 | 활성 |
|----|------|------|
| C01 | 의존성 단방향 | dev+ |
| C02 | done-condition 필드 필수 | 전체 |
| C03 | HARNESS.md 100줄 이하 | 전체 |
| C04 | GC 스캔 주 1회 이상 | stab+ |
| C05 | main 직접 커밋 금지 | prod |
| C06 | ADR 기록 | planning |
| C07 | 세션 체크포인트 (4h / 예산 80% × 3회 / 미결 5개 초과) | dev+ |
| C08 | UI 검증 | stab+ |
| C09 | 보안 규칙 (secrets 노출 금지) | dev+ |

---

## 라이선스

이 프로젝트는 공개 사용 가능하며 자유롭게 수정·배포할 수 있다.
