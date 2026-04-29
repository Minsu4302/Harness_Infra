---
title: 관측성 가이드
watches:
  - logs/
  - scripts/gc-agent.sh
  - plugins/observability/plugin.yaml
last_reviewed: 2026-04-29
---

# 관측성 — Observability

## 아키텍처

```
gc-agent --scan --collect
    │
    ├── .harness/reports/debt-report.md   (스캔 결과)
    ├── .harness/reports/last-check.json  (constraint 결과)
    │
    └── logs/
        ├── metrics/{date}.jsonl          (수치 메트릭)
        ├── traces/{date}.jsonl           (스크립트 실행 트레이스)
        └── events/{date}.jsonl           (이벤트 스트림)
```

## 주요 메트릭

| metric_name | 단위 | 설명 |
|-------------|------|------|
| `context_budget_pct` | % | 컨텍스트 예산 사용률 (400줄 기준) |
| `task_duration_hours` | h | 현재 태스크 경과 시간 |
| `constraint_pass_rate` | % | 제약 조건 통과율 |

## 주요 이벤트 유형

| event_type | severity | 설명 |
|------------|----------|------|
| `constraint_fail` | WARN | 제약 조건 실패 |
| `checkpoint_triggered` | INFO | C07 체크포인트 발동 |
| `gc_scan_complete` | INFO | GC 스캔 완료 |
| `budget_warn` | WARN | 컨텍스트 예산 경고 |
| `debt_detected` | CRITICAL | 기술 부채 감지 |
| `ui_check_pass` | INFO | UI 검증 완료 (C08) |

## 쿼리 예시

```sh
# 오늘 FAIL 이벤트 목록
grep constraint_fail logs/events/$(date +%Y-%m-%d).jsonl

# context_budget_pct 추이
grep context_budget_pct logs/metrics/$(date +%Y-%m-%d).jsonl | grep -o '"value":[0-9]*'

# budget_warn_streak 현재값
grep budget_warn_streak .harness/reports/last-check.json
```

## 외부 연동

`plugins/observability/plugin.yaml`의 `external_endpoint`를 설정하면
`post-scan` 훅을 통해 외부 로그 시스템으로 데이터를 전송할 수 있다.
