@echo off
rem Card Rogue (DuckCardsRogue) - built-in self test
rem Runs the test suites that ship inside this build.
chcp 65001 >nul
pushd "%~dp0"
rem R477: dist only keeps versioned packs (DuckCardsRogue_R<round>.exe).
rem Try the plain name first, then fall back to the highest DuckCardsRogue_R*.exe
rem (sort by NAME, not by mtime -- a freshly copied old pack would win on mtime).
set "GAME=%~dp0DuckCardsRogue.exe"
rem R612: --release build ships as DuckCardsRogue_release.exe (progressive unlock).
if not exist "%GAME%" if exist "%~dp0DuckCardsRogue_release.exe" set "GAME=%~dp0DuckCardsRogue_release.exe"
set "PICK="
if not exist "%GAME%" (
  for /f "delims=" %%F in ('dir /b /o-n "%~dp0DuckCardsRogue_R*.exe" 2^>nul') do (
    if not defined PICK set "PICK=%%F"
  )
)
if defined PICK set "GAME=%~dp0%PICK%"
if not exist "%GAME%" (
  echo [ERROR] DuckCardsRogue.exe / DuckCardsRogue_R*.exe not found next to this script.
  pause
  popd
  exit /b 1
)
echo [run] %GAME%

echo ============================================================
echo  1/4  engine + rules suite
echo ============================================================
"%GAME%" --headless --script res://scripts/test_engine.gd
echo.

echo ============================================================
echo  2/4  reward + rarity suite
echo ============================================================
"%GAME%" --headless --script res://scripts/test_reward.gd
echo.

echo ============================================================
echo  3/4  bgm suite
echo ============================================================
"%GAME%" --headless --script res://scripts/test_bgm.gd
echo.

echo ============================================================
echo  4/4  scene smoke test (windows will flash open)
echo ============================================================
"%GAME%" --script res://scripts/test_smoke.gd
echo.

echo ============================================================
echo  [done] what to expect inside this pack:
echo         all four suites should end with "all passed" / "0 failed".
echo         checks that read .gd source text are skipped automatically here --
echo         a pack ships compiled scripts only, so they cannot run by design.
echo         Anything red is a real problem.
echo ============================================================
pause
popd
