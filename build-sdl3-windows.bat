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

:: Create output directories
if not exist build\windows\x64\bin mkdir build\windows\x64\bin
if not exist build\windows\x64\lib mkdir build\windows\x64\lib
if not exist build\windows\x64\include mkdir build\windows\x64\include
if not exist build\windows\arm64\bin mkdir build\windows\arm64\bin
if not exist build\windows\arm64\lib mkdir build\windows\arm64\lib
if not exist build\windows\arm64\include mkdir build\windows\arm64\include

:: Build for Windows x64
echo Building SDL3 for Windows x64...
cd %SCRIPT_DIR%
if not exist SDL\build_x64 mkdir SDL\build_x64
cd SDL\build_x64

cmake .. -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DSDL_SHARED=ON ^
    -DSDL_STATIC=ON ^
    -DCMAKE_INSTALL_PREFIX=%SCRIPT_DIR%\build\windows\x64\install

if %ERRORLEVEL% NEQ 0 (
    echo Failed to generate x64 build files. Exiting.
    exit /b 1
)

ninja
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build x64 version. Exiting.
    exit /b 1
)

ninja install
if %ERRORLEVEL% NEQ 0 (
    echo Failed to install x64 version. Exiting.
    exit /b 1
)

:: Copy the DLLs, libs, and headers to build directory
echo Copying x64 files to build directory...
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\x64\install\bin\*.dll %SCRIPT_DIR%\build\windows\x64\bin\
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\x64\install\lib\*.lib %SCRIPT_DIR%\build\windows\x64\lib\
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\x64\install\include\* %SCRIPT_DIR%\build\windows\x64\include\

:: Build for Windows ARM64
echo Building SDL3 for Windows ARM64...
cd %SCRIPT_DIR%
if not exist SDL\build_arm64 mkdir SDL\build_arm64
cd SDL\build_arm64

cmake .. -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DSDL_SHARED=ON ^
    -DSDL_STATIC=ON ^
    -DCMAKE_INSTALL_PREFIX=%SCRIPT_DIR%\build\windows\arm64\install ^
    -A ARM64

if %ERRORLEVEL% NEQ 0 (
    echo Failed to generate ARM64 build files. Exiting.
    exit /b 1
)

ninja
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build ARM64 version. Exiting.
    exit /b 1
)

ninja install
if %ERRORLEVEL% NEQ 0 (
    echo Failed to install ARM64 version. Exiting.
    exit /b 1
)

:: Copy the DLLs, libs, and headers to build directory
echo Copying ARM64 files to build directory...
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\arm64\install\bin\*.dll %SCRIPT_DIR%\build\windows\arm64\bin\
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\arm64\install\lib\*.lib %SCRIPT_DIR%\build\windows\arm64\lib\
xcopy /Y /E /I %SCRIPT_DIR%\build\windows\arm64\install\include\* %SCRIPT_DIR%\build\windows\arm64\include\

:: Return to script directory
cd %SCRIPT_DIR%

echo.
echo Windows builds complete! Files are available in:
echo   - build\windows\x64\bin (DLLs for Windows x64)
echo   - build\windows\x64\lib (Libraries for Windows x64)
echo   - build\windows\x64\include (Headers for Windows x64)
echo   - build\windows\arm64\bin (DLLs for Windows ARM64)
echo   - build\windows\arm64\lib (Libraries for Windows ARM64)
echo   - build\windows\arm64\include (Headers for Windows ARM64)