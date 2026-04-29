---
title: Security Checklist
watches:
  - scripts/
  - linters/
last_reviewed: 2026-04-29
---

# Security Checklist

## 목적

하네스 인프라의 기본 보안 기준을 정의합니다.

## 쉘 스크립트 보안

### 입력 검증

```bash
# ❌ 위험: 무검증 변수 확장
rm -rf $user_input

# ✅ 안전: 인용부호로 보호
rm -rf "$user_input"

# ✅ 안전: 명시적 검증
if [[ "$file" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
  rm "$file"
fi
```

### 파이프 실패 감지

```bash
# ❌ 위험: 파이프 중간 실패 무시
cat file | grep pattern | wc -l

# ✅ 안전: 파이프 실패 감지
set -o pipefail
cat file | grep pattern | wc -l
```

### 정의되지 않은 변수

```bash
# ❌ 위험: 정의되지 않은 변수 사용
rm -rf $UNSET_VAR

# ✅ 안전: 정의되지 않은 변수 사용 금지
set -u
rm -rf "${UNSET_VAR:-.}"
```

## 파일 권한

| 파일 | 권한 | 이유 |
|------|------|------|
| `scripts/*.sh` | 755 | 실행 가능 |
| `.harness/reports/` | 755 | 자동 생성 |
| `.harness/context/` | 755 | 컨텍스트 저장 |
| `.harness/session/task.md` | 644 | 읽기 전용 (자동 갱신) |

## 민감 정보

### 금지 항목

- 하드코딩된 API 키
- 비밀 토큰을 스크립트에 저장
- 개인정보(이메일, 전화번호) 로깅

### 안전한 처리

- 환경 변수에서만 로드: `API_KEY="${API_KEY:-}"`
- 로그에 마스킹: `echo "token: ${token:0:4}****"`
- 민감 파일은 `.gitignore`에 추가

## 보안 체크리스트

코드 작성/검토 시:

- ✓ `set -euo pipefail` 설정
- ✓ 모든 변수를 인용부호로 감싸기
- ✓ 외부 입력은 화이트리스트로 검증
- ✓ 민감 정보 로깅 금지
- ✓ 파일 권한 명시적 설정
