@echo off
setlocal EnableExtensions
title Freekual Site - Install and Deploy

set "TARGET=C:\programming\freekual"
set "PARENT=C:\programming"
set "SELF=%~f0"
set "HERE=%~dp0"
set "ZIP="

echo.
echo  ============================================================
echo   FREEKUAL SITE - install and deploy
echo  ============================================================
echo.

rem ---- locate the archive -------------------------------------------------
if exist "%HERE%freekual-site.zip" set "ZIP=%HERE%freekual-site.zip"
if not defined ZIP if exist "%USERPROFILE%\Downloads\freekual-site.zip" set "ZIP=%USERPROFILE%\Downloads\freekual-site.zip"

if not defined ZIP (
  if exist "%HERE%index.html" (
    echo  [i] Archive not found, but project files are here. Using this folder.
    set "TARGET=%HERE:~0,-1%"
    goto :run
  )
  echo  [X] freekual-site.zip not found.
  echo      Put this .bat next to the zip file, or in your Downloads folder.
  echo.
  pause
  exit /b 1
)

echo  [1/4] Archive : %ZIP%
echo        Target  : %TARGET%
echo.

rem ---- make sure the parent folder is writable ----------------------------
if not exist "%PARENT%" mkdir "%PARENT%" 2>nul
if not exist "%PARENT%" (
  echo  [i] Cannot create %PARENT% - requesting administrator rights...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
  exit /b 0
)

rem ---- extract ------------------------------------------------------------
echo  [2/4] Extracting...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%PARENT%' -Force; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
  echo  [X] Extraction failed.
  echo.
  pause
  exit /b 1
)

if not exist "%TARGET%\index.html" (
  echo  [X] index.html missing after extraction: %TARGET%
  echo.
  pause
  exit /b 1
)

rem ---- keep this launcher together with the project -----------------------
if /I not "%SELF%"=="%TARGET%\Install-Freekual.bat" (
  copy /Y "%SELF%" "%TARGET%\Install-Freekual.bat" >nul 2>&1
  set "MOVED=1"
)

:run
echo  [3/4] Starting setup and deployment...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%\scripts\bootstrap.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo  [4/4] Done.
) else (
  echo  [4/4] Finished with errors. See %TARGET%\logs for the transcript.
)
echo.

rem ---- remove the copy that was left in Downloads --------------------------
if defined MOVED (
  if "%RC%"=="0" (
    start "" /min cmd /c "timeout /t 3 >nul & del /f /q \"%SELF%\""
  )
)

pause
exit /b %RC%
