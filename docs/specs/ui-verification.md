---
title: UI 검증 기준 (C08)
watches:
  - linters/ui-check.sh
last_reviewed: 2026-04-29
---

# UI 검증 기준

C08 린터가 이 파일의 체크리스트를 기준으로 검증한다.
stab/prod 단계에서 아래 항목을 모두 확인한 후 이벤트를 기록해야 한다.

## 체크리스트

- [ ] 핵심 사용자 플로우 (happy path) 수동 테스트 완료
- [ ] 반응형 레이아웃 확인 (mobile / tablet / desktop)
- [ ] 접근성 기본 항목 확인 (키보드 내비게이션, 색상 대비)
- [ ] 에러 상태 UI 표시 확인 (네트워크 오류, 빈 상태)
- [ ] 로딩 상태 UI 표시 확인

## 검증 완료 이벤트 기록

체크리스트 항목을 모두 확인한 후 아래 명령으로 이벤트를 기록한다:

```sh
TODAY=$(date +%Y-%m-%d)
printf '{"timestamp":"%s","event_type":"ui_check_pass","constraint_id":"C08","severity":"INFO","detail":"manual verification complete"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> logs/events/${TODAY}.jsonl
```

## 자동화 연동 (선택)

Playwright, Cypress 등 E2E 테스트 프레임워크를 사용하는 경우
테스트 완료 후 위 이벤트를 자동으로 기록하도록 CI 파이프라인에 추가한다.
