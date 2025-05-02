@echo off
setlocal enabledelayedexpansion

:: Use environment variables for commits if specified, otherwise use latest
if defined SDL3_COMMIT (
    set SDL3_COMMIT_TO_USE=%SDL3_COMMIT%
    echo Using specified SDL3 commit: %SDL3_COMMIT_TO_USE%
) else (
    set SDL3_COMMIT_TO_USE=
    echo Using latest SDL3 commit
)

:: Get current directory
set SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%

:: Check for required tools
where cmake >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo CMake is required but not found in PATH.
    echo Please install CMake and add it to your PATH.
    exit /b 1
)

where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Git is required but not found in PATH.
    echo Please install Git and add it to your PATH.
    exit /b 1
)

:: Clone or update SDL3
if not exist SDL (
    echo Cloning SDL repository...
    git clone --depth 1 https://github.com/libsdl-org/SDL.git

    :: Checkout specific commit if provided
    if defined SDL3_COMMIT_TO_USE (
        cd SDL
        git fetch --depth 1 origin %SDL3_COMMIT_TO_USE%
        git checkout %SDL3_COMMIT_TO_USE%
        cd ..
    )
) else (
    echo SDL directory already exists, updating...
    cd SDL

    if defined SDL3_COMMIT_TO_USE (
        git fetch --depth 1 origin %SDL3_COMMIT_TO_USE%
        git checkout %SDL3_COMMIT_TO_USE%
    ) else (
        git pull
    )
    cd ..
)

:: Store the current SDL3 commit hash for reference
cd SDL
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set CURRENT_SDL3_COMMIT=%%a
echo Current SDL3 commit: %CURRENT_SDL3_COMMIT%
echo %CURRENT_SDL3_COMMIT%> ..\.sdl3_commit

cd %SCRIPT_DIR%
echo SDL3 setup complete!