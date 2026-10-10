@echo off
rem Card Rogue (DuckCardsRogue) - built-in self test
rem Runs the test suites that ship inside this build.
chcp 65001 >nul
pushd "%~dp0"
set "GAME=%~dp0DuckCardsRogue.exe"
if not exist "%GAME%" (
  echo [ERROR] DuckCardsRogue.exe not found next to this script.
  pause
  popd
  exit /b 1
)

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
echo  3/4  replay suite
echo ============================================================
"%GAME%" --headless --script res://scripts/test_replay.gd
echo.

echo ============================================================
echo  4/4  scene smoke test (windows will flash open)
echo ============================================================
"%GAME%" --script res://scripts/test_smoke.gd
echo.

echo ============================================================
echo  [done] every suite must print an "all passed" line.
echo         baseline: engine 2159 / reward 26 / replay 28 / smoke 25
echo ============================================================
pause
popd
