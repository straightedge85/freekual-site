# CLAUDE.md — 프리퀄 홈페이지

Claude Code 가 이 저장소에서 작업할 때 반드시 지켜야 할 규칙입니다.

## 프로젝트

주식회사 프리퀄(Freekual)의 **1페이지 회사 홈페이지**.
빌드 도구 없는 순수 정적 사이트. HTML 1개 + CSS 1개. JS 없음.

## 절대 규칙 (위반 시 작업 중단)

1. **구 브랜드명 금지.** `Chrome Factory` / `크롬팩토리` 등 표기를 어떤 파일에도 넣지 않는다.
   브랜드는 `FREEKUAL` / `주식회사 프리퀄` 하나뿐이다.
2. **법인 정보는 아래 값에서 한 글자도 바꾸지 않는다.**
   - 법인명: 주식회사 프리퀄 (Freekual)
   - 대표이사: 홍석찬
   - 사업자등록번호: 478-86-00624
   - 주소: 서울특별시 서초구 논현로 161, 4층 401호
   - 대표번호: 010-3654-5453
   - 이메일: straightedge85@gmail.com
3. **실적 수치·경력·가격은 임의로 만들지 않는다.** 근거는 `docs/CONTENT.md` 뿐이다.
   거기에 없는 숫자, 고객사, 수상 이력, 직원 수를 새로 쓰지 말 것.
4. **프레임워크·번들러를 도입하지 않는다.** React, Tailwind, Vite, npm 의존성 추가 금지.
   요청이 있어도 먼저 사용자에게 확인할 것.
5. **작업 후 반드시 `scripts\check.ps1` 을 실행해 통과시킨다.**

## 파일 구조

```
freekual/
  index.html              마크업 + 카피 (유일한 페이지)
  assets/css/style.css    전체 스타일. :root 에 디자인 토큰
  assets/img/             이미지 (현재 비어 있음)
  site.config.json        법인 정보 원본 + 배포 설정
  docs/CONTENT.md         카피의 사실 근거 원장
  scripts/                PowerShell 실행 스크립트
  dist/                   빌드 산출물 (git 무시)
```

## 디자인 토큰

색·서체는 `assets/css/style.css` 의 `:root` 가 **유일한 권위 있는 출처**다.
새 색상값을 인라인이나 개별 규칙에 하드코딩하지 말고 변수로 추가한 뒤 참조할 것.

| 변수 | 값 | 용도 |
|---|---|---|
| `--ink` | `#0D0809` | 기본 배경 (웜블랙) |
| `--ink-2` | `#150E0F` | 상승 표면 (문의 섹션) |
| `--bone` | `#EAE1D3` | 본문 텍스트 |
| `--dim` / `--dim-2` | `#948B82` / `#6B635C` | 보조 텍스트 |
| `--red` | `#E11D24` | 강조 1색 |
| `--line` / `--line-soft` | bone 13% / 7% | 구분선 |

- 한글 본문: Pretendard Variable (`--sans`)
- 라틴 로고·인덱스: Chakra Petch (`--tech`)
- 둘 다 CDN 로드. 오프라인 확인이 필요하면 로컬 서브셋 반입을 먼저 제안할 것.

## 레이아웃 원칙

- 섹션 순서: 히어로 → 01 서비스 → 02 왜 프리퀄 → 03 실적 → 04 진행 절차 → 05 패키지 → 06 문의 → 푸터
- 번호(01~06)는 **실제 순서가 있는 콘텐츠에만** 붙인다. 장식용 번호 금지.
- 카드에 그림자·둥근 모서리를 쓰지 않는다. 구분은 헤어라인과 여백으로만.
- 애니메이션은 히어로의 노드 발광 하나뿐. 스크롤 등장 효과를 추가하지 말 것.
- `prefers-reduced-motion` 대응은 이미 있다. 제거 금지.
- 브레이크포인트: 900 / 820 / 780 / 700 / 640 / 520px. 새로 만들지 말고 기존 것을 쓸 것.

## 명령어

```powershell
# 미리보기 (브라우저 자동 실행)
powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\start.ps1

# 검수 (금지어 / 법인표기 / 링크)
powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\check.ps1

# 빌드 (dist\index.html 단일 파일 생성, 내부에서 check 먼저 실행)
powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\build.ps1

# 배포 (site.config.json 의 deploy 설정에 따름)
powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\deploy.ps1

# 전체 자동화 (준비 → 무인 실행 → GitHub Pages 반영 → 검증)
powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\bootstrap.ps1
```

## 무인 실행으로 호출된 경우

`bootstrap.ps1` 이 `claude -p` 로 너를 호출했다면 질문하지 말고 끝까지 진행한다.
작업 순서는 `check.ps1` 통과 → `build.ps1` → 커밋 → `gh` 로 GitHub Pages 배포다.
`check.ps1` 이 실패하면 **스크립트가 아니라 콘텐츠를 고친다.** 검사를 느슨하게 만들어 통과시키지 않는다.
한 단계가 두 번 실패하면 상황을 그대로 보고하고 멈춘다. 마지막 줄에 `PAGES_URL=<주소>` 를 출력한다.

## 작업 순서

1. `docs/CONTENT.md` 로 사실 확인
2. `index.html` 또는 `assets/css/style.css` 수정
3. `check.ps1` 통과
4. `start.ps1` 로 데스크톱·모바일 폭 모두 육안 확인
5. 필요 시 `build.ps1` → `deploy.ps1`

## 아직 비어 있는 것

- 로고 이미지 (`assets/img/`) — 현재 워드마크는 텍스트
- favicon, 도메인, `robots.txt`, `sitemap.xml` — 도메인 확정 후 추가
- OG 이미지 — 도메인 확정 후 절대경로로 추가
