---
title: 보안 규칙 (C09)
watches:
  - linters/security-scan.sh
last_reviewed: 2026-04-29
---

# 보안 규칙 — C09

## 규칙 목록

| ID | 규칙 | 자동화 |
|----|------|--------|
| S1 | `.env` 파일을 git에 커밋하지 않는다 | C09 자동 감지 |
| S2 | 소스 코드에 API 키, 비밀번호, 토큰을 하드코딩하지 않는다 | C09 패턴 스캔 |
| S3 | `.gitignore`에 `.env*` 패턴을 포함한다 | C09 자동 감지 |
| S4 | 외부 입력을 셸 명령에 직접 전달하지 않는다 (인젝션 방지) | 수동 리뷰 |
| S5 | 민감 정보는 환경 변수 또는 시크릿 매니저를 통해 주입한다 | 수동 리뷰 |

## 위반 시 조치

1. `scripts/constraint-check.sh --only C09` 실행으로 상세 위반 목록 확인
2. 하드코딩된 시크릿이 발견된 경우:
   - git history에서 제거 (`git filter-branch` 또는 `git-filter-repo`)
   - 해당 시크릿 즉시 폐기 및 재발급
3. `.env` 파일이 git에 포함된 경우:
   - `git rm --cached .env`
   - `.gitignore` 업데이트
   - 커밋 히스토리 정리

## 허용 패턴

- `example_api_key = "your_key_here"` — 예시 문자열은 허용
- `password = os.getenv("PASSWORD")` — 환경 변수 참조는 허용
- `# secret: 설명` — 주석 내 단어는 허용

## 참조

- [OWASP Secrets Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [git-filter-repo](https://github.com/newren/git-filter-repo)
