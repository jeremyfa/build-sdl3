@echo off
setlocal enabledelayedexpansion

:: Get current directory
set SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%

:: Setup SDL3 if needed
if not exist SDL (
    echo SDL3 not found. Running setup script...
    call setup-sdl3-windows.bat
    if %ERRORLEVEL% NEQ 0 (
        echo Setup failed. Exiting.
        exit /b 1
    )
)

:: Determine which architecture to build
if "%BUILD_ARCH%"=="" (
    echo BUILD_ARCH environment variable not set. Building for x64 by default.
    set BUILD_ARCH=x64
)

echo Building for architecture: %BUILD_ARCH%

:: Create output directories for the specified architecture
if not exist build\windows\%BUILD_ARCH%\bin mkdir build\windows\%BUILD_ARCH%\bin
if not exist build\windows\%BUILD_ARCH%\lib mkdir build\windows\%BUILD_ARCH%\lib
if not exist build\windows\%BUILD_ARCH%\include mkdir build\windows\%BUILD_ARCH%\include

:: Build for Windows with the specified architecture
echo Building SDL3 for Windows %BUILD_ARCH%...
cd %SCRIPT_DIR%
if not exist SDL\build_%BUILD_ARCH% mkdir SDL\build_%BUILD_ARCH%
cd SDL\build_%BUILD_ARCH%

if "%BUILD_ARCH%"=="arm64" (
    :: For ARM64, we need to use a different generator and specify the architecture
    cmake .. -G "Visual Studio 17 2022" -A ARM64 ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DSDL_SHARED=ON ^
        -DSDL_STATIC=ON ^
        -DCMAKE_INSTALL_PREFIX=%SCRIPT_DIR%\build\windows\%BUILD_ARCH%\install
) else (
    :: For x64, we can use Ninja as before
    cmake .. -G Ninja ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DSDL_SHARED=ON ^
        -DSDL_STATIC=ON ^
        -DCMAKE_INSTALL_PREFIX=%SCRIPT_DIR%\build\windows\%BUILD_ARCH%\install
)

if %ERRORLEVEL% NEQ 0 (
    echo Failed to generate %BUILD_ARCH% build files. Exiting.
    exit /b 1
)

if "%BUILD_ARCH%"=="arm64" (
    :: For ARM64, use cmake --build instead of ninja
    cmake --build . --config Release
) else (
    :: For x64, use ninja as before
    ninja
)

if %ERRORLEVEL% NEQ 0 (
    echo Failed to build %BUILD_ARCH% version. Exiting.
    exit /b 1
)

if "%BUILD_ARCH%"=="arm64" (
    :: For ARM64, use cmake --install instead of ninja install
    cmake --install . --config Release
) else (
    :: For x64, use ninja install as before
    ninja install
)

if %ERRORLEVEL% NEQ 0 (
    echo Failed to install %BUILD_ARCH% version. Exiting.
    exit /b 1
)

:: Copy the DLLs, libs, and headers to build directory
echo Copying %BUILD_ARCH% files to build directory...
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\%BUILD_ARCH%\install\bin\*.dll %SCRIPT_DIR%\build\windows\%BUILD_ARCH%\bin\
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\%BUILD_ARCH%\install\lib\*.lib %SCRIPT_DIR%\build\windows\%BUILD_ARCH%\lib\
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\%BUILD_ARCH%\install\include\* %SCRIPT_DIR%\build\windows\%BUILD_ARCH%\include\

:: Return to script directory
cd %SCRIPT_DIR%

echo.
echo Windows %BUILD_ARCH% build complete! Files are available in:
echo   - build\windows\%BUILD_ARCH%\bin (DLLs)
echo   - build\windows\%BUILD_ARCH%\lib (Libraries)
echo   - build\windows\%BUILD_ARCH%\include (Headers)