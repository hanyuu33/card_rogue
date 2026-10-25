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
echo  [done] expected baseline inside this pack:/r/necho         reward / bgm : all passed
echo         smoke        : 51 passed / 4 failed
echo         engine       : 12 failed
echo         -- every one of those failures is a guard that reads .gd source text.
echo            A pack ships compiled scripts, so those guards cannot pass here by design.
echo            Any OTHER failure is a real problem.
echo ============================================================
pause
popd
