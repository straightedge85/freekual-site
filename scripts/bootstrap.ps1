<#
  bootstrap.ps1 - 준비 -> Claude Code 무인 실행 -> 온라인 반영 -> 검증
  Install-Freekual.bat 이 호출합니다. 직접 실행해도 동일하게 동작합니다.
#>
[CmdletBinding()]
param(
  [switch]$SkipClaude,
  [switch]$NoOpen
)

$ErrorActionPreference = 'Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
$Root = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $Root 'logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$Log = Join-Path $LogDir ("deploy-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -Path $Log -Force | Out-Null } catch { }

function Say([string]$m, [string]$c = 'Gray') { Write-Host "  $m" -ForegroundColor $c }
function Step([string]$m) { Write-Host ""; Write-Host "  == $m" -ForegroundColor White }
function Ok([string]$m)   { Say "OK  - $m" 'Green' }
function Warn2([string]$m){ Say "..  - $m" 'Yellow' }
function Bad([string]$m)  { Say "X   - $m" 'Red' }

function Refresh-Path {
  $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $u = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = ($m, $u | Where-Object { $_ }) -join ';'
}

function Have([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Ensure-Winget([string]$id, [string]$exe, [string]$label) {
  if (Have $exe) { Ok "$label 설치됨"; return $true }
  if (-not (Have 'winget')) {
    Bad "$label 이(가) 없고 winget 도 없습니다. 수동 설치가 필요합니다."
    return $false
  }
  Warn2 "$label 설치 중... (winget)"
  winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
  Refresh-Path
  if (Have $exe) { Ok "$label 설치 완료"; return $true }
  Bad "$label 설치 실패"
  return $false
}

Write-Host ""
Write-Host "  FREEKUAL - 설치 및 배포" -ForegroundColor White
Say "프로젝트: $Root" 'DarkGray'
Say "로그: $Log" 'DarkGray'

# ---------------------------------------------------------------- 0. 설정
$CfgPath = Join-Path $Root 'site.config.json'
if (-not (Test-Path $CfgPath)) { Bad "site.config.json 없음"; try { Stop-Transcript | Out-Null } catch {}; exit 1 }
$cfg = Get-Content $CfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$RepoName = 'freekual-site'
if ($cfg.deploy.PSObject.Properties.Name -contains 'repo' -and $cfg.deploy.repo) { $RepoName = $cfg.deploy.repo }
$Branch = if ($cfg.deploy.branch) { $cfg.deploy.branch } else { 'main' }

# ---------------------------------------------------------------- 1. 필수 도구
Step "1. 필수 도구 확인"
$okGit  = Ensure-Winget 'Git.Git'        'git'  'Git'
$okGh   = Ensure-Winget 'GitHub.cli'     'gh'   'GitHub CLI'
if (-not (Have 'claude')) {
  if (-not (Have 'npm')) { [void](Ensure-Winget 'OpenJS.NodeJS.LTS' 'npm' 'Node.js') }
  if (Have 'npm') {
    Warn2 "Claude Code 설치 중... (npm)"
    npm install -g '@anthropic-ai/claude-code' 2>&1 | Out-Null
    Refresh-Path
  }
}
$okClaude = Have 'claude'
if ($okClaude) { Ok "Claude Code 설치됨" } else { Bad "Claude Code 미설치" }

if (-not $okGit -or -not $okGh) {
  Bad "Git 또는 GitHub CLI 없이는 온라인 반영을 진행할 수 없습니다."
  Say "수동 설치: https://git-scm.com  /  https://cli.github.com" 'DarkGray'
  try { Stop-Transcript | Out-Null } catch {}
  exit 1
}

# ---------------------------------------------------------------- 2. 인증
Step "2. 인증 확인"
Say "최초 1회에 한해 로그인 창이 열릴 수 있습니다. 이후 실행에는 필요 없습니다." 'DarkGray'

if ($okClaude) {
  claude auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Warn2 "Claude Code 로그인이 필요합니다. 로그인 창을 엽니다."
    claude auth login
    claude auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Warn2 "Claude Code 로그인 미완료 - 스크립트가 직접 배포합니다."; $okClaude = $false }
    else { Ok "Claude Code 로그인됨" }
  } else { Ok "Claude Code 로그인됨" }
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Warn2 "GitHub 로그인이 필요합니다. 브라우저 인증을 시작합니다."
  gh auth login --hostname github.com --git-protocol https --web
  gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Bad "GitHub 로그인 실패. 온라인 반영을 중단합니다."
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
  }
}
Ok "GitHub 로그인됨"
$Owner = (gh api user -q .login 2>$null)
if (-not $Owner) { Bad "GitHub 계정 확인 실패"; try { Stop-Transcript | Out-Null } catch {}; exit 1 }
Say "계정: $Owner" 'DarkGray'

# ---------------------------------------------------------------- 3. git 준비
Step "3. 저장소 준비"
Push-Location $Root
try {
  if (-not (git config user.email)) { git config --global user.email $cfg.company.email | Out-Null }
  if (-not (git config user.name))  { git config --global user.name  $cfg.company.englishName | Out-Null }

  if (-not (Test-Path (Join-Path $Root '.git'))) {
    git init 2>&1 | Out-Null
    git branch -M $Branch 2>&1 | Out-Null
    Ok "git 저장소 초기화"
  } else { Ok "기존 git 저장소 사용" }

  if (-not (Test-Path (Join-Path $Root '.nojekyll'))) {
    New-Item -ItemType File -Path (Join-Path $Root '.nojekyll') -Force | Out-Null
  }

  git add -A 2>&1 | Out-Null
  git commit -m "site: freekual 1page homepage" 2>&1 | Out-Null
} finally { Pop-Location }

# ---------------------------------------------------------------- 4. Claude Code 무인 실행
Step "4. Claude Code 실행"
if ($SkipClaude -or -not $okClaude) {
  Warn2 "건너뜀 - 스크립트가 직접 배포합니다."
} else {
  $task = @"
You are running unattended. Never ask questions. Never wait for input. Do the whole job and stop.

Project: a one-page static company website for 주식회사 프리퀄 at $Root.
Read CLAUDE.md first and obey every rule in it, especially the banned-brand rule and the fixed company details.

Do these in order:
1. Run: powershell -ExecutionPolicy Bypass -File scripts\check.ps1
   If it fails, fix the cause in index.html or assets\css\style.css and run it again until it passes.
   Do not weaken or edit check.ps1 to make it pass.
2. Run: powershell -ExecutionPolicy Bypass -File scripts\build.ps1
3. Commit everything: git add -A then git commit. Skip the commit if there is nothing to commit.
4. Publish to GitHub Pages, using the gh CLI, which is already authenticated as $Owner :
   - If the repo does not exist yet: gh repo create $RepoName --public --source . --remote origin --push
   - If origin already exists: git push -u origin $Branch
   - Enable Pages: gh api --method POST repos/$Owner/$RepoName/pages -f source[branch]=$Branch -f source[path]=/
     A 409 response means Pages is already on. Treat that as success and move on.
5. Print the final Pages URL on the last line, prefixed with PAGES_URL= and nothing else on that line.

Rules: do not add frameworks, bundlers or npm dependencies. Do not rewrite the company details. Do not invent new figures, clients or credentials. If a step fails twice, report the failure plainly and stop.
"@

  $flags = @('-p', $task,
             '--permission-mode', 'bypassPermissions',
             '--max-turns', '60',
             '--output-format', 'text',
             '--verbose')

  Push-Location $Root
  try {
    Say "무인 모드로 실행합니다. 몇 분 걸릴 수 있습니다." 'DarkGray'
    $out = & claude @flags ('--permission-prompts') ('none') 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and $out -match 'nknown option|nrecognized option|--permission-prompts') {
      Warn2 "이 버전은 --permission-prompts 를 지원하지 않습니다. 해당 옵션 없이 재시도합니다."
      $out = & claude @flags 2>&1 | Out-String
    }
    Write-Host $out
    if ($LASTEXITCODE -eq 0) { Ok "Claude Code 완료" } else { Warn2 "Claude Code 종료코드 $LASTEXITCODE - 스크립트가 이어서 처리합니다." }
  } catch {
    Warn2 "Claude Code 실행 오류: $($_.Exception.Message)"
  } finally { Pop-Location }
}

# ---------------------------------------------------------------- 5. 결정적 배포 (보정)
Step "5. 배포 상태 보정"
Push-Location $Root
try {
  $hasRepo = $false
  gh repo view "$Owner/$RepoName" 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { $hasRepo = $true }

  if (-not $hasRepo) {
    Warn2 "저장소 생성: $Owner/$RepoName"
    gh repo create $RepoName --public --source . --remote origin --push 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Bad "저장소 생성 실패" } else { Ok "저장소 생성 및 push 완료" }
  } else {
    Ok "저장소 존재: $Owner/$RepoName"
    $remote = (git remote 2>$null) -join ' '
    if ($remote -notmatch 'origin') {
      git remote add origin "https://github.com/$Owner/$RepoName.git" 2>&1 | Out-Null
    }
    git add -A 2>&1 | Out-Null
    git commit -m ("site: update {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm')) 2>&1 | Out-Null
    git push -u origin $Branch 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "push 완료" } else { Warn2 "push 결과 코드 $LASTEXITCODE (변경 없음일 수 있음)" }
  }

  $pagesUrl = (gh api "repos/$Owner/$RepoName/pages" -q .html_url 2>$null)
  if (-not $pagesUrl) {
    Warn2 "GitHub Pages 활성화"
    gh api --method POST "repos/$Owner/$RepoName/pages" -f "source[branch]=$Branch" -f "source[path]=/" 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    $pagesUrl = (gh api "repos/$Owner/$RepoName/pages" -q .html_url 2>$null)
  }
  if ($pagesUrl) { Ok "Pages 주소: $pagesUrl" } else { Bad "Pages 주소를 확인하지 못했습니다." }
} finally { Pop-Location }

# ---------------------------------------------------------------- 6. 온라인 검증
Step "6. 온라인 반영 확인"
$live = $false
if ($pagesUrl) {
  Say "첫 빌드는 1~3분 걸립니다. 응답을 기다립니다..." 'DarkGray'
  for ($i = 1; $i -le 40; $i++) {
    try {
      $r = Invoke-WebRequest -Uri $pagesUrl -UseBasicParsing -TimeoutSec 15
      if ($r.StatusCode -eq 200) { $live = $true; break }
    } catch { }
    Start-Sleep -Seconds 15
  }
}

if ($live) {
  Ok "온라인 반영 완료"
  $cfg.deploy.type = 'git'
  $cfg.deploy.branch = $Branch
  if ($cfg.deploy.PSObject.Properties.Name -notcontains 'repo') {
    $cfg.deploy | Add-Member -NotePropertyName 'repo' -NotePropertyValue $RepoName -Force
  } else { $cfg.deploy.repo = $RepoName }
  $cfg.site.domain = $pagesUrl
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($CfgPath, ($cfg | ConvertTo-Json -Depth 6), $enc)
  Push-Location $Root
  try {
    git add site.config.json 2>&1 | Out-Null
    git commit -m "chore: record live url" 2>&1 | Out-Null
    git push 2>&1 | Out-Null
  } finally { Pop-Location }
  if (-not $NoOpen) { Start-Process $pagesUrl | Out-Null }
} else {
  Warn2 "아직 응답이 없습니다. 배포는 등록되었으나 빌드가 진행 중일 수 있습니다."
}

Write-Host ""
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
if ($pagesUrl) { Write-Host "   홈페이지 : $pagesUrl" -ForegroundColor Green }
Write-Host "   저장소   : https://github.com/$Owner/$RepoName" -ForegroundColor Gray
Write-Host "   프로젝트 : $Root" -ForegroundColor Gray
Write-Host "   로그     : $Log" -ForegroundColor DarkGray
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

try { Stop-Transcript | Out-Null } catch { }
if ($pagesUrl) { exit 0 } else { exit 1 }
