@echo off
REM ============================================================
REM Copy only the files from "scripts/" folder of the repo
REM into a local directory called "FOG"
REM ============================================================

REM Set repository local path (where the repo exists or will be cloned)
set REPO_DIR=C:\Users\SIDMAR\FOG\m000-st-fog-repository
set FOG_DIR=C:\Users\SIDMAR\FOG

REM Check if Git is installed
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed or not in PATH.
    pause
    exit /b 1
)

REM Clone repo if it does not exist
if not exist "%REPO_DIR%\.git" (
    echo [INFO] Cloning repository...
    git clone https://github.com/santiagotoro2023/m000-st-fog-repository.git "%REPO_DIR%"
)

REM Ensure FOG directory exists
if not exist "%FOG_DIR%" mkdir "%FOG_DIR%"

REM Copy all files from scripts/ to FOG
echo [INFO] Copying files from scripts/ to FOG...
xcopy "%REPO_DIR%\scripts\*" "%FOG_DIR%\" /s /i /y

echo [SUCCESS] Files copied to "%FOG_DIR%".
pause
