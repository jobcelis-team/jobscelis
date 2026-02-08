@echo off
setlocal enabledelayedexpansion

echo Loading .env variables...

if not exist ".env" (
    echo ERROR: .env file not found!
    echo Copy .env.example to .env and fill in your values:
    echo   copy .env.example .env
    pause
    exit /b 1
)

for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
    if not "%%a"=="" (
        set "%%a=%%b"
    )
)

echo Starting Jobscelis server...
mix phx.server

endlocal
