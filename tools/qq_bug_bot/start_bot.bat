@echo off
chcp 65001 >nul
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo [1/2] 首次运行，正在创建虚拟环境...
    python -m venv .venv
    if errorlevel 1 goto fail
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt
    if errorlevel 1 goto fail
)

if not exist ".env" (
    echo [提示] 未找到 .env，已从 .env.example 复制一份
    copy ".env.example" ".env" >nul
)

echo [2/2] 启动机器人...
".venv\Scripts\python.exe" bot.py
pause
goto :eof

:fail
echo.
echo 启动失败：请确认 Python 3.10+ 已安装且在 PATH 中。
pause
