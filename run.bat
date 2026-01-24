@echo off
REM ============================================
REM STREAMFLIX - Run with Environment Variables
REM ============================================

REM Load environment variables from .env
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "%%a"=="" (
            set "%%a=%%b"
        )
    )
)

REM Enable delayed expansion for the loop
setlocal enabledelayedexpansion

for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    set "firstchar=%%a"
    set "firstchar=!firstchar:~0,1!"
    if not "!firstchar!"=="#" (
        if not "%%a"=="" (
            endlocal
            set "%%a=%%b"
            setlocal enabledelayedexpansion
        )
    )
)
endlocal

REM Run the command passed as argument, or show help
if "%1"=="" (
    echo Usage: run.bat [command]
    echo.
    echo Commands:
    echo   migrate    - Run database migrations
    echo   server     - Start Phoenix server
    echo   setup      - Get deps, migrate, seed
    echo   seed       - Run seeds
    echo   console    - Start IEx console
    echo.
) else if "%1"=="migrate" (
    mix ecto.migrate
) else if "%1"=="server" (
    mix phx.server
) else if "%1"=="setup" (
    mix deps.get
    mix ecto.migrate
    mix run apps/streamflix_core/priv/repo/seeds.exs
) else if "%1"=="seed" (
    mix run apps/streamflix_core/priv/repo/seeds.exs
) else if "%1"=="console" (
    iex -S mix
) else (
    echo Running: %*
    %*
)
