@echo off
setlocal enabledelayedexpansion

echo Loading .env variables...

for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
    if not "%%a"=="" (
        set "%%a=%%b"
    )
)

echo Running create admin quick script...
mix run scripts/create_admin_quick.exs

endlocal
