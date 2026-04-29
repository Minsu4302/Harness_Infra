---
title: Logs & Observability
watches:
  - logs/
  - scripts/gc-agent.sh
last_reviewed: 2026-04-29
---

# logs/ — 관측성 레이어

## 목적

이 디렉토리는 `gc-agent.sh --collect`가 `.harness/reports/`의 데이터를 읽어 정리한 관측 데이터를 저장합니다.

외부 시스템(Victoria Logs, Prometheus 등) 연동은 `plugins/observability/`에서 담당합니다.

## 주의

**직접 편집 금지** — `gc-agent --collect`가 자동으로 기록합니다.

## 파일 구조

### metrics/{YYYY-MM-DD}.jsonl
한 줄 = 하나의 수치 이벤트

```json
{"timestamp":"2026-04-29T14:30:00Z","metric_name":"context_budget_pct","value":65.5,"unit":"%","source":"context-loader"}
{"timestamp":"2026-04-29T14:30:15Z","metric_name":"task_duration_hours","value":2.5,"unit":"h","source":"task.md"}
{"timestamp":"2026-04-29T14:30:20Z","metric_name":"constraint_pass_rate","value":100.0,"unit":"%","source":"constraint-check"}
```

### traces/{YYYY-MM-DD}.jsonl
한 줄 = 스크립트 실행 하나

```json
{"timestamp":"2026-04-29T14:30:00Z","script":"scripts/constraint-check.sh","mode":"full","duration_ms":1240,"exit_code":0}
{"timestamp":"2026-04-29T14:35:00Z","script":"scripts/gc-agent.sh","mode":"scan","duration_ms":890,"exit_code":0}
```

### events/{YYYY-MM-DD}.jsonl
한 줄 = 하나의 이벤트

```json
{"timestamp":"2026-04-29T14:30:00Z","event_type":"constraint_fail","constraint_id":"C03","severity":"WARN","detail":"..."}
{"timestamp":"2026-04-29T14:35:00Z","event_type":"checkpoint_triggered","constraint_id":"C07","severity":"INFO","detail":"max_hours exceeded"}
{"timestamp":"2026-04-29T14:40:00Z","event_type":"gc_scan_complete","constraint_id":null,"severity":"INFO","detail":"debt-report updated"}
{"timestamp":"2026-04-29T14:41:00Z","event_type":"budget_warn","constraint_id":"C07","severity":"WARN","detail":"budget_warn_streak: 3"}
```

## 수집 이벤트 유형

| 유형 | 설명 |
|------|------|
| `constraint_fail` | 제약 조건 검증 실패 |
| `checkpoint_triggered` | 체크포인트 조건 충족 |
| `gc_scan_complete` | GC 스캔 완료 |
| `budget_warn` | 컨텍스트 예산 경고 |
