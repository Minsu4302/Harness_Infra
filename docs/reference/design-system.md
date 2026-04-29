---
title: Design System 참조 구조
watches:
  - src/styles/
  - src/tokens/
last_reviewed: 2026-04-29
---

# Design System 참조 구조

`context-loader.sh --task-type ui` 실행 시 세션에 자동 주입되는 문서.
실제 토큰 값은 프로젝트별로 아래 자리에 채워 넣는다.

## Color Tokens

```
-- 채우는 방법: src/styles/tokens.css 또는 tailwind.config.js 참조 --

primary:       #______   (브랜드 메인 색상)
primary-hover: #______
secondary:     #______
surface:       #______   (배경)
surface-alt:   #______   (카드·패널 배경)
border:        #______
text-primary:  #______
text-muted:    #______
error:         #______
warning:       #______
success:       #______
```

## Typography

```
-- 채우는 방법: 프로젝트 폰트 시스템 참조 --

font-family-sans:  (예: 'Pretendard', system-ui)
font-family-mono:  (예: 'JetBrains Mono', monospace)

font-size-xs:   __rem   (12px)
font-size-sm:   __rem   (14px)
font-size-base: __rem   (16px)
font-size-lg:   __rem   (18px)
font-size-xl:   __rem   (20px)
font-size-2xl:  __rem   (24px)

font-weight-regular: 400
font-weight-medium:  500
font-weight-bold:    700

line-height-tight:  1.25
line-height-normal: 1.5
line-height-loose:  1.75
```

## Spacing

```
-- 4pt 그리드 기준 --

space-1:  4px
space-2:  8px
space-3:  12px
space-4:  16px
space-5:  20px
space-6:  24px
space-8:  32px
space-10: 40px
space-12: 48px
space-16: 64px
```

## Component Naming Convention

| 규칙 | 예시 |
|------|------|
| PascalCase | `Button`, `InputField`, `ModalDialog` |
| 접두사로 도메인 표현 | `AuthLoginForm`, `DashboardCard` |
| 변형은 prop으로 | `<Button variant="primary" size="sm" />` |
| 상태는 suffix | `ButtonLoading`, `InputError` (파일명만) |

### 레이어별 위치

```
src/
├── components/          # 재사용 가능한 공통 컴포넌트
│   ├── ui/              # 원자 단위 (Button, Input, Badge)
│   └── layout/          # 레이아웃 (Container, Grid, Stack)
├── features/            # 도메인별 컴포넌트 (C01 의존성 단방향)
└── styles/
    └── tokens.css       # CSS 변수 선언
```

## 프로젝트별 커스터마이징

1. 이 파일을 복사해 프로젝트 루트 `docs/reference/design-system.md`에 배치한다
2. `Color Tokens` 섹션의 `#______`를 실제 값으로 채운다
3. `Typography`의 폰트 패밀리·사이즈를 프로젝트 기준으로 업데이트한다
4. `last_reviewed` 날짜를 갱신하고 `watches`에 실제 토큰 파일 경로를 추가한다
5. `gc-agent.sh`가 `watches` 경로의 변경을 감지해 문서 부패를 알린다

## 참조

프로젝트에 이미 디자인 시스템이 있다면 해당 문서 URL을 아래에 기입한다:

- Figma: (URL)
- Storybook: (URL)
- 디자인 토큰 패키지: (npm package 또는 경로)
