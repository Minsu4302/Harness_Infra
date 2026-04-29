---
title: Reliability Standards
watches:
  - scripts/
  - linters/
last_reviewed: 2026-04-29
---

# Reliability Standards

## 목적

에러 처리, 재시도, 타임아웃의 기준을 정의하여 하네스 인프라의 신뢰성을 보장합니다.

## 에러 처리

### 필수 에러 처리

**파일 I/O**:
- 파일 부재: `if [[ ! -f "$file" ]]; then ... fi`
- 디렉토리 부재: `mkdir -p` 사용 또는 명시적 생성
- 파일 읽기 실패: `grep` 명령 시 `|| echo "default"`

**JSON 파싱**:
- `jq` 명령 실패: `command -v jq &> /dev/null` 검사
- 필드 부재: 기본값 제공

**환경 변수**:
- 모든 환경 변수는 기본값 설정: `${VAR:-default}`

### 에러 로깅

컨텍스트가 중요한 경우만 로깅:

```bash
if [[ $? -ne 0 ]]; then
  echo "ERROR:Cxx:작업 X 실패 - 원인: $reason" >&2
  exit 1
fi
```

## 재시도 정책

| 작업 | 재시도 횟수 | 지연 |
|------|-----------|------|
| 네트워크 요청 | 3회 | 1초 지수 백오프 |
| 파일 잠금 | 2회 | 100ms |
| 외부 API | 2회 | 2초 |
| 내부 스크립트 | 없음 | - |

## 타임아웃

| 대상 | 타임아웃 |
|-----|--------|
| 린터 단일 실행 | 30초 |
| 전체 constraint-check.sh | 5분 |
| 테스트 스위트 | 10분 |
| GC 스캔 | 2분 |

## 신뢰성 체크리스트

코드 작성 시:

- ✓ 모든 external 입력에 기본값 설정
- ✓ 파일 존재 확인 후 읽기
- ✓ JSON 파싱 전 도구 설치 확인
- ✓ 타임아웃 설정 (일괄 작업)
- ✓ 실패 경로에 명시적 exit code 설정
