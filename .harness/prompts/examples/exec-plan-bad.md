---
type: few-shot-negative
title: "피해야 할 EXEC_PLAN 패턴"
---

# Few-shot: 피해야 할 패턴

흔히 범하는 잘못된 EXEC_PLAN 패턴과 올바른 대응 방법입니다.

---

## 패턴 1: 목표가 여러 개

**나쁜 예:**
```
EXEC_PLAN:
goal: 기능을 추가하고 문서를 정리하고 테스트한다
```

**문제:** goal에 "하고...하고...한다" → 태스크 분할 신호  
**올바른 대응:** 태스크를 feat/add-feature, docs/update-docs, test/add-tests로 분리

---

## 패턴 2: 측정 불가능한 done_condition

**나쁜 예:**
```
steps:
  - id: S1
    action: 기능 작업
    output: 코드
    constraint: 없음
    done_condition: 잘 됨
```

**문제:** "잘 됨"은 자동 검증 불가  
**올바른 대응:** `sh scripts/xxx.sh exit 0` 또는 `grep 'KEY' FILE 성공` 으로 구체화

---

## 패턴 3: action이 추상적

**나쁜 예:**
```
steps:
  - id: S1
    action: 기능 작업
    output: 코드
```

**문제:** "기능 작업"은 무엇을 작성/수정/삭제하는지 불명확  
**올바른 대응:** `gc-agent.sh 하단에 run_plugin_hooks 함수 작성` — 동사 + 위치 + 대상

---

## 패턴 4: steps 과다 (7개 초과)

**나쁜 예:**
```
EXEC_PLAN:
goal: 로그인 기능 구현
steps:
  - id: S1 ~ S10  # 10개 steps
```

**문제:** 7단계 초과는 태스크 분할 신호  
**올바른 대응:**
- `feat/login-ui` — UI 컴포넌트 (S1~S4)
- `feat/login-api` — API 연동 (S1~S4)
- `feat/login-test` — 통합 테스트 (S1~S3)

---

## 패턴 5: C01 위반 의존성

**나쁜 예:**
```
steps:
  - id: S1
    action: UI 컴포넌트에서 직접 DB 쿼리 호출
```

**문제:** UI → DB 직접 접근은 C01 단방향 의존성 위반  
**올바른 대응:** UI → Service → Repository → DB 계층을 통해 접근
