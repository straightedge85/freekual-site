<#
  deploy.ps1 - 배포
  site.config.json 의 deploy.type 에 따라 동작합니다.
    "none"   : 안내만 출력 (기본값)
    "folder" : dist 내용을 deploy.target 경로로 복사 (로컬/네트워크 드라이브, 동기화 폴더)
    "git"    : 저장소 루트를 커밋 후 push (GitHub Pages 등)
#>
[CmdletBinding()]
param(
  [switch]$SkipBuild,
  [string]$Message = ""
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root 'dist'
$CfgPath = Join-Path $Root 'site.config.json'

Write-Host ""
Write-Host "  FREEKUAL - 배포" -ForegroundColor White
Write-Host ""

if (-not (Test-Path $CfgPath)) {
  Write-Host "  [오류] site.config.json 이 없습니다." -ForegroundColor Red
  exit 1
}
$cfg = Get-Content $CfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$type = $cfg.deploy.type

if (-not $SkipBuild) {
  & (Join-Path $PSScriptRoot 'build.ps1')
  if ($LASTEXITCODE -ne 0) { exit 1 }
}

switch ($type) {

  'folder' {
    $target = $cfg.deploy.target
    if ([string]::IsNullOrWhiteSpace($target)) {
      Write-Host "  [오류] deploy.target 이 비어 있습니다." -ForegroundColor Red
      exit 1
    }
    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
    robocopy $Dist $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
      Write-Host "  [오류] 복사 실패 (robocopy 코드 $LASTEXITCODE)" -ForegroundColor Red
      exit 1
    }
    Write-Host "  배포 완료 -> $target" -ForegroundColor Green
    exit 0
  }

  'git' {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
      Write-Host "  [오류] git 이 설치되어 있지 않습니다." -ForegroundColor Red
      exit 1
    }
    if (-not (Test-Path (Join-Path $Root '.git'))) {
      Write-Host "  [오류] git 저장소가 아닙니다. 먼저 아래를 실행하세요:" -ForegroundColor Red
      Write-Host "         git init; git remote add origin <저장소 URL>" -ForegroundColor DarkGray
      exit 1
    }
    if ([string]::IsNullOrWhiteSpace($Message)) {
      $Message = "site: update ({0})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }
    Push-Location $Root
    try {
      git add -A
      git commit -m $Message
      if ($LASTEXITCODE -ne 0) { Write-Host "  변경 사항 없음 (커밋 생략)" -ForegroundColor DarkGray }
      $branch = $cfg.deploy.branch
      if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'main' }
      git push origin $branch
      if ($LASTEXITCODE -ne 0) {
        Write-Host "  [오류] push 실패" -ForegroundColor Red
        exit 1
      }
      Write-Host "  push 완료 (origin/$branch)" -ForegroundColor Green
    } finally { Pop-Location }
    exit 0
  }

  default {
    Write-Host "  배포 대상이 아직 설정되지 않았습니다 (deploy.type = 'none')." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  산출물은 준비되어 있습니다:" -ForegroundColor White
    Write-Host "    - 단일 파일 업로드용 : $Dist\index.html" -ForegroundColor DarkGray
    Write-Host "    - 정적 호스팅용 루트 : $Root (index.html + assets)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  site.config.json 의 deploy.type 을 'folder' 또는 'git' 으로 바꾸고" -ForegroundColor DarkGray
    Write-Host "  target(또는 branch)을 채우면 이 스크립트로 바로 반영됩니다." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
  }
}
