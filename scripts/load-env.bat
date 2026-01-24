@echo off
REM ============================================
REM STREAMFLIX - Load Environment Variables (CMD)
REM ============================================
REM Run this script before starting the application
REM Usage: scripts\load-env.bat
REM ============================================

echo Loading environment variables from .env...

if not exist ".env" (
    echo ERROR: .env file not found!
    echo Please copy .env.example to .env and fill in your values
    echo   copy .env.example .env
    exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    REM Skip comments and empty lines
    echo %%a | findstr /r "^#" >nul
    if errorlevel 1 (
        if not "%%a"=="" (
            set "%%a=%%b"
            echo   Set: %%a
        )
    )
)

echo.
echo Environment variables loaded!
echo.
echo You can now run:
echo   mix deps.clean bcrypt_elixir
echo   mix deps.get
echo   mix ecto.migrate
echo   mix phx.server
