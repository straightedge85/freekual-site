# 프리퀄 홈페이지

주식회사 프리퀄(Freekual) 1페이지 회사 홈페이지. 빌드 도구 없는 정적 사이트입니다.

## 원클릭 설치 + 배포

`Install-Freekual.bat` 하나만 실행하면 끝납니다.

1. `freekual-site.zip` 과 `Install-Freekual.bat` 을 같은 폴더(보통 다운로드)에 둔다
2. `Install-Freekual.bat` 을 더블클릭

배치가 하는 일: 압축 해제(`C:\programming\freekual`) → 자기 자신을 프로젝트 폴더로 이동 →
Git / GitHub CLI / Node / Claude Code 설치 확인(없으면 winget·npm 으로 설치) →
Claude Code 를 무인 모드로 실행해 검수·빌드·커밋·GitHub Pages 배포 →
스크립트가 결과를 독립 검증하고 주소가 살아날 때까지 대기 → 브라우저로 열기.

**최초 1회만 로그인 창이 뜹니다.** Claude Code 계정과 GitHub 계정 인증은 사람이 직접 해야 하며
자동화할 수 없습니다. 두 번째 실행부터는 처음부터 끝까지 무인으로 진행됩니다.

실행 기록은 `logs\deploy-*.log` 에 남습니다.

## 바로 실행 (미리보기만)

```powershell
powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\start.ps1
```

python 이나 npx 가 있으면 `http://localhost:5173` 로 서버를 띄우고,
없으면 `index.html` 을 브라우저로 바로 엽니다. 어느 쪽이든 동일하게 동작합니다.

## 스크립트

| 명령 | 하는 일 |
|---|---|
| `scripts\start.ps1` | 로컬 미리보기 (포트 변경: `-Port 8080`) |
| `scripts\check.ps1` | 금지어·법인표기·링크 검수. 실패 시 종료코드 1 |
| `scripts\build.ps1` | CSS 인라인해 `dist\index.html` 단일 파일 생성 |
| `scripts\deploy.ps1` | `site.config.json` 설정대로 배포 |

## 배포 설정

`site.config.json` 의 `deploy.type` 을 바꿉니다.

- `"none"` — 기본값. 산출물 위치만 안내
- `"folder"` — `target` 경로로 `dist` 복사 (네트워크 드라이브, 동기화 폴더)
- `"git"` — 저장소 루트를 커밋 후 push (GitHub Pages)

GitHub Pages 로 올릴 경우 루트에 `index.html` 과 `assets/` 가 그대로 있으므로
빌드 없이 저장소만 연결하면 됩니다.

웹호스팅(카페24·가비아 등)에 FTP 로 올릴 때는 `build.ps1` 후
`dist\index.html` 파일 하나만 올리면 됩니다.

## 수정할 때

- 문구·구조: `index.html`
- 색·타이포·간격: `assets/css/style.css` (`:root` 토큰 우선)
- 숫자·실적·가격: 반드시 `docs/CONTENT.md` 근거 확인 후

Claude Code 로 작업한다면 `CLAUDE.md` 에 규칙이 정리돼 있습니다.
