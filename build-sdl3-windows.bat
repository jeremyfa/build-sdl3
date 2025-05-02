@echo off
setlocal enabledelayedexpansion

:: Get current directory
set SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%

:: Setup SDL3 if needed
if not exist SDL (
    call setup-sdl3-windows.bat
    if !ERRORLEVEL! NEQ 0 (
        echo Error setting up SDL3
        exit /b !ERRORLEVEL!
    )
)

:: Determine host architecture
if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set HOST_ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set HOST_ARCH=arm64
) else (
  set HOST_ARCH=x86
)

:: Determine target architecture
if "%1" equ "x64" (
  set TARGET_ARCH=x64
) else if "%1" equ "arm64" (
  set TARGET_ARCH=arm64
) else if "%1" neq "" (
  echo Unknown target "%1" architecture!
  exit /b 1
) else (
  set TARGET_ARCH=%HOST_ARCH%
)

echo Building SDL3 for Windows %TARGET_ARCH%...

:: Check for required tools
where cmake >nul 2>&1 || (
    echo CMake is required but not found in PATH.
    echo Please install CMake and add it to your PATH.
    exit /b 1
)

:: Create output directories
mkdir build\windows\%TARGET_ARCH%\bin 2>nul
mkdir build\windows\%TARGET_ARCH%\lib 2>nul
mkdir build\windows\%TARGET_ARCH%\include 2>nul

:: Create build directory
set BUILD_DIR=SDL\build_windows_%TARGET_ARCH%
mkdir %BUILD_DIR% 2>nul
cd %BUILD_DIR%

:: Set up architecture-specific variables
set GENERATOR=Visual Studio 17 2022
set CMAKE_ARGS=-G "%GENERATOR%" -A %TARGET_ARCH% -DVCPKG_TARGET_TRIPLET=%TARGET_ARCH%-windows

:: Run CMake to configure the build
echo Running CMake...
cmake .. %CMAKE_ARGS% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DSDL_SHARED=ON ^
    -DSDL_STATIC=ON ^
    -DSDL_TEST=OFF

:: Build both Debug and Release configurations
echo Building Debug configuration...
cmake --build . --config Debug
echo Building Release configuration...
cmake --build . --config Release

cd %SCRIPT_DIR%

:: Copy binaries and headers to output directory
echo Copying binaries and headers...

:: Copy DLLs
copy /Y %BUILD_DIR%\Release\SDL3.dll build\windows\%TARGET_ARCH%\bin\
copy /Y %BUILD_DIR%\Debug\SDL3d.dll build\windows\%TARGET_ARCH%\bin\

:: Copy import libraries
copy /Y %BUILD_DIR%\Release\SDL3.lib build\windows\%TARGET_ARCH%\lib\
copy /Y %BUILD_DIR%\Debug\SDL3d.lib build\windows\%TARGET_ARCH%\lib\

:: Copy static libraries
copy /Y %BUILD_DIR%\Release\SDL3-static.lib build\windows\%TARGET_ARCH%\lib\
copy /Y %BUILD_DIR%\Debug\SDL3-staticd.lib build\windows\%TARGET_ARCH%\lib\

:: Copy headers
xcopy /Y /S /I SDL\include\* build\windows\%TARGET_ARCH%\include\

:: Create a build info file
echo SDL3 for Windows %TARGET_ARCH% > build\windows\%TARGET_ARCH%\build_info.txt
echo Configuration: Debug and Release >> build\windows\%TARGET_ARCH%\build_info.txt
echo Shared Library: Yes >> build\windows\%TARGET_ARCH%\build_info.txt
echo Static Library: Yes >> build\windows\%TARGET_ARCH%\build_info.txt

:: Get the current SDL3 commit hash
cd SDL
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set CURRENT_SDL3_COMMIT=%%a
echo SDL3 Commit: %CURRENT_SDL3_COMMIT% >> ..\build\windows\%TARGET_ARCH%\build_info.txt
cd ..

echo Windows %TARGET_ARCH% build complete! Libraries and binaries are available in:
echo   - build\windows\%TARGET_ARCH%\bin\SDL3.dll (shared library)
echo   - build\windows\%TARGET_ARCH%\bin\SDL3d.dll (debug shared library)
echo   - build\windows\%TARGET_ARCH%\lib\SDL3.lib (import library)
echo   - build\windows\%TARGET_ARCH%\lib\SDL3d.lib (debug import library)
echo   - build\windows\%TARGET_ARCH%\lib\SDL3-static.lib (static library)
echo   - build\windows\%TARGET_ARCH%\lib\SDL3-staticd.lib (debug static library)
echo   - build\windows\%TARGET_ARCH%\include\ (headers)