<#
  check.ps1 - 배포 전 검수 게이트
  1) 금지어(구 브랜드) 노출 검사
  2) 법인 필수 표기 존재 검사
  3) 로컬 링크/에셋 경로 유효성 검사
  실패 시 종료코드 1 을 반환합니다.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$fail = 0

function Read-Utf8([string]$p) {
  return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}

Write-Host ""
Write-Host "  FREEKUAL - 검수" -ForegroundColor White
Write-Host ""

$targets = Get-ChildItem -Path $Root -Include *.html, *.css, *.js -Recurse -File |
           Where-Object { $_.FullName -notmatch '\\(dist|node_modules|\.git)\\' }

# 1) 금지어
$banned = @('Chrome Factory', 'ChromeFactory', 'CHROME FACTORY', '크롬팩토리', '크롬 팩토리')
Write-Host "  [1/3] 금지어 검사" -ForegroundColor Cyan
foreach ($f in $targets) {
  $t = Read-Utf8 $f.FullName
  foreach ($b in $banned) {
    if ($t -like "*$b*") {
      Write-Host "        X $($f.Name) 에 금지어 '$b' 발견" -ForegroundColor Red
      $fail = 1
    }
  }
}
if ($fail -eq 0) { Write-Host "        OK" -ForegroundColor Green }

# 2) 법인 필수 표기
Write-Host "  [2/3] 법인 표기 검사" -ForegroundColor Cyan
$index = Join-Path $Root 'index.html'
$html  = Read-Utf8 $index
$required = @(
  '주식회사 프리퀄',
  '478-86-00624',
  '서울특별시 서초구 논현로 161, 4층 401호',
  '홍석찬',
  '010-3654-5453',
  'straightedge85@gmail.com'
)
$missing = 0
foreach ($r in $required) {
  if (-not ($html -like "*$r*")) {
    Write-Host "        X 누락: $r" -ForegroundColor Red
    $missing = 1
    $fail = 1
  }
}
if ($missing -eq 0) { Write-Host "        OK (6개 항목 확인)" -ForegroundColor Green }

# 3) 로컬 경로
Write-Host "  [3/3] 로컬 링크 검사" -ForegroundColor Cyan
$broken = 0
$links = [regex]::Matches($html, '(?:href|src)="([^"]+)"')
foreach ($m in $links) {
  $u = $m.Groups[1].Value
  if ($u -match '^(https?:|mailto:|tel:|#|data:)') { continue }
  $p = Join-Path $Root ($u -replace '/', '\')
  if (-not (Test-Path $p)) {
    Write-Host "        X 없는 경로: $u" -ForegroundColor Red
    $broken = 1
    $fail = 1
  }
}
if ($broken -eq 0) { Write-Host "        OK" -ForegroundColor Green }

Write-Host ""
if ($fail -eq 0) {
  Write-Host "  검수 통과" -ForegroundColor Green
} else {
  Write-Host "  검수 실패 - 위 항목을 수정한 뒤 다시 실행하세요." -ForegroundColor Red
}
Write-Host ""
exit $fail
