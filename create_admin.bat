@echo off
setlocal enabledelayedexpansion

echo Loading .env variables...

for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
    if not "%%a"=="" (
        set "%%a=%%b"
    )
)

echo Running create admin script...
mix run scripts/create_admin.exs

endlocal
