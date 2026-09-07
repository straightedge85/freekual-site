<#
  start.ps1 - 프리퀄 홈페이지 로컬 미리보기
  사용법: powershell -ExecutionPolicy Bypass -File C:\programming\freekual\scripts\start.ps1
#>
[CmdletBinding()]
param(
  [int]$Port = 5173,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Url  = "http://localhost:$Port/"

Write-Host ""
Write-Host "  FREEKUAL - 로컬 미리보기" -ForegroundColor White
Write-Host "  루트: $Root" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path (Join-Path $Root 'index.html'))) {
  Write-Host "  [오류] index.html 을 찾을 수 없습니다: $Root" -ForegroundColor Red
  exit 1
}

function Get-Exe([string[]]$Names) {
  foreach ($n in $Names) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  return $null
}

function Wait-Port([int]$p, [int]$tries = 40) {
  for ($i = 0; $i -lt $tries; $i++) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
      $client.Connect('127.0.0.1', $p)
      $client.Close()
      return $true
    } catch {
      Start-Sleep -Milliseconds 250
    } finally {
      $client.Dispose()
    }
  }
  return $false
}

$python = Get-Exe @('python', 'py', 'python3')
$node   = Get-Exe @('npx')

$proc = $null
$exe  = $null
$argList = $null

if ($python) {
  $exe  = $python
  $argList = @('-m', 'http.server', "$Port", '--bind', '127.0.0.1')
  Write-Host "  서버: python http.server" -ForegroundColor DarkGray
} elseif ($node) {
  $exe  = $node
  $argList = @('--yes', 'serve', '.', '-l', "$Port")
  Write-Host "  서버: npx serve" -ForegroundColor DarkGray
}

if ($exe) {
  $proc = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $Root -PassThru -WindowStyle Hidden
  if (Wait-Port $Port) {
    Write-Host "  주소: $Url" -ForegroundColor Green
    Write-Host ""
    if (-not $NoBrowser) { Start-Process $Url | Out-Null }
    Write-Host "  종료하려면 Enter 를 누르세요." -ForegroundColor DarkGray
    [void](Read-Host)
    if ($proc -and -not $proc.HasExited) { $proc.Kill() }
    Write-Host "  서버를 종료했습니다." -ForegroundColor DarkGray
    exit 0
  } else {
    Write-Host "  [경고] 포트 $Port 응답 없음. 파일로 직접 엽니다." -ForegroundColor Yellow
    if ($proc -and -not $proc.HasExited) { $proc.Kill() }
  }
} else {
  Write-Host "  [안내] python / npx 가 없어 파일로 직접 엽니다." -ForegroundColor Yellow
  Write-Host "         (정적 페이지라 file:// 로도 정상 동작합니다)" -ForegroundColor DarkGray
}

$local = Join-Path $Root 'index.html'
if (-not $NoBrowser) { Start-Process $local | Out-Null }
Write-Host "  열기: $local" -ForegroundColor Green
exit 0
