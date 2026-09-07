<#
  build.ps1 - 배포용 산출물 생성
  CSS 를 인라인으로 합쳐 dist\index.html 단일 파일을 만듭니다.
  (웹호스팅 FTP 업로드처럼 파일 하나만 올려야 하는 경우용)
#>
[CmdletBinding()]
param(
  [switch]$SkipCheck
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root 'dist'

function Read-Utf8([string]$p) {
  return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}
function Write-Utf8([string]$p, [string]$t) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $t, $enc)
}

Write-Host ""
Write-Host "  FREEKUAL - 빌드" -ForegroundColor White
Write-Host ""

if (-not $SkipCheck) {
  & (Join-Path $PSScriptRoot 'check.ps1')
  if ($LASTEXITCODE -ne 0) {
    Write-Host "  검수 실패로 빌드를 중단합니다." -ForegroundColor Red
    exit 1
  }
}

if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Path $Dist | Out-Null

$html = Read-Utf8 (Join-Path $Root 'index.html')
$css  = Read-Utf8 (Join-Path $Root 'assets\css\style.css')
$link = '<link rel="stylesheet" href="assets/css/style.css">'

if ($html.Contains($link)) {
  $html = $html.Replace($link, "<style>`r`n$css`r`n</style>")
  Write-Host "  CSS 인라인 처리 완료" -ForegroundColor DarkGray
} else {
  Write-Host "  [경고] style.css 링크 태그를 찾지 못했습니다. 인라인 없이 진행합니다." -ForegroundColor Yellow
}

Write-Utf8 (Join-Path $Dist 'index.html') $html

# 이미지 등 정적 에셋 복사
$img = Join-Path $Root 'assets\img'
if ((Test-Path $img) -and ((Get-ChildItem $img -File -ErrorAction SilentlyContinue).Count -gt 0)) {
  $target = Join-Path $Dist 'assets\img'
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  Copy-Item (Join-Path $img '*') $target -Recurse -Force
  Write-Host "  이미지 에셋 복사 완료" -ForegroundColor DarkGray
}

foreach ($extra in @('robots.txt', 'sitemap.xml', 'favicon.ico')) {
  $src = Join-Path $Root $extra
  if (Test-Path $src) { Copy-Item $src $Dist -Force }
}

$size = [math]::Round((Get-Item (Join-Path $Dist 'index.html')).Length / 1KB, 1)
Write-Host ""
Write-Host "  완료: dist\index.html ($size KB)" -ForegroundColor Green
Write-Host ""
exit 0
