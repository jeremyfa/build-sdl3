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

:: Clean and create build directory
set BUILD_DIR=SDL\build_windows_%TARGET_ARCH%
if exist %BUILD_DIR% (
    echo Cleaning existing build directory...
    rmdir /S /Q %BUILD_DIR%
)
mkdir %BUILD_DIR%
cd %BUILD_DIR%

:: Set up architecture-specific variables for GitHub Actions
if "%TARGET_ARCH%"=="arm64" (
    set CMAKE_ARCH=-A ARM64
) else if "%TARGET_ARCH%"=="x64" (
    set CMAKE_ARCH=-A x64
) else (
    set CMAKE_ARCH=-A Win32
)

echo Using CMAKE_ARCH=%CMAKE_ARCH%

:: Run CMake to configure the build
echo Running CMake...
cmake .. -G "Visual Studio 17 2022" %CMAKE_ARCH% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DSDL_SHARED=ON ^
    -DSDL_STATIC=ON ^
    -DSDL_TEST=OFF

if %ERRORLEVEL% NEQ 0 (
    echo CMake configuration failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

:: Display CMake configuration
echo.
echo CMAKE CONFIGURATION:
cmake -L . | findstr SDL_
echo.

:: Build Release configuration
echo Building Release configuration...
cmake --build . --config Release

if %ERRORLEVEL% NEQ 0 (
    echo Build failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

:: Display build outputs
echo.
echo Build outputs:
dir /B /S Release\*.dll
dir /B /S Release\*.lib
echo.

:: Copy SDL files to output directory
echo Copying binaries to output directory...

:: Try to find DLL files in various locations
echo Searching for DLLs...
set DLL_FOUND=0

:: Check in Release folder
if exist Release\SDL3.dll (
    echo Found DLL in Release folder
    copy /Y Release\SDL3.dll "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\bin\"
    set DLL_FOUND=1
)

:: Check in bin folder
if exist bin\Release\SDL3.dll (
    echo Found DLL in bin\Release folder
    copy /Y bin\Release\SDL3.dll "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\bin\"
    set DLL_FOUND=1
)

:: If not found in common locations, search recursively
if %DLL_FOUND%==0 (
    echo DLL not found in common locations, searching recursively...
    for /r %%f in (SDL3.dll) do (
        if exist "%%f" (
            echo Found DLL: %%f
            copy /Y "%%f" "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\bin\"
            set DLL_FOUND=1
        )
    )
)

:: Check if we found the DLL
if %DLL_FOUND%==0 (
    echo WARNING: SDL3.dll not found
)

:: Try to find LIB files in various locations
echo Searching for LIBs...
set LIB_FOUND=0

:: Check in Release folder
if exist Release\SDL3.lib (
    echo Found import lib in Release folder
    copy /Y Release\SDL3.lib "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\lib\"
    set LIB_FOUND=1
)

:: Check in Release folder for static lib
if exist Release\SDL3-static.lib (
    echo Found static lib in Release folder
    copy /Y Release\SDL3-static.lib "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\lib\"
)

:: Check in lib folder
if exist lib\Release\SDL3.lib (
    echo Found import lib in lib\Release folder
    copy /Y lib\Release\SDL3.lib "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\lib\"
    set LIB_FOUND=1
)

:: Check in lib folder for static lib
if exist lib\Release\SDL3-static.lib (
    echo Found static lib in lib\Release folder
    copy /Y lib\Release\SDL3-static.lib "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\lib\"
)

:: If not found in common locations, search recursively
if %LIB_FOUND%==0 (
    echo LIB not found in common locations, searching recursively...
    for /r %%f in (SDL3.lib) do (
        if exist "%%f" (
            echo Found import lib: %%f
            copy /Y "%%f" "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\lib\"
            set LIB_FOUND=1
        )
    )

    for /r %%f in (SDL3-static.lib) do (
        if exist "%%f" (
            echo Found static lib: %%f
            copy /Y "%%f" "%SCRIPT_DIR%\build\windows\%TARGET_ARCH%\lib\"
        )
    )
)

:: Check if we found the LIB
if %LIB_FOUND%==0 (
    echo WARNING: SDL3.lib not found
)

cd %SCRIPT_DIR%

:: Copy headers
echo Copying headers...
xcopy /Y /E /I SDL\include\* build\windows\%TARGET_ARCH%\include\

:: Create a build info file
echo SDL3 for Windows %TARGET_ARCH% > build\windows\%TARGET_ARCH%\build_info.txt
echo Configuration: Release >> build\windows\%TARGET_ARCH%\build_info.txt
echo Shared Library: Yes >> build\windows\%TARGET_ARCH%\build_info.txt
echo Static Library: Yes >> build\windows\%TARGET_ARCH%\build_info.txt

:: Get the current SDL3 commit hash
cd SDL
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set CURRENT_SDL3_COMMIT=%%a
echo SDL3 Commit: %CURRENT_SDL3_COMMIT% >> ..\build\windows\%TARGET_ARCH%\build_info.txt
cd ..

:: Verify files exist
echo.
echo Verifying output files...
set MISSING_FILES=0

if not exist build\windows\%TARGET_ARCH%\bin\SDL3.dll (
    echo MISSING: build\windows\%TARGET_ARCH%\bin\SDL3.dll
    set /a MISSING_FILES+=1
) else (
    echo FOUND: build\windows\%TARGET_ARCH%\bin\SDL3.dll
)

if not exist build\windows\%TARGET_ARCH%\lib\SDL3.lib (
    echo MISSING: build\windows\%TARGET_ARCH%\lib\SDL3.lib
    set /a MISSING_FILES+=1
) else (
    echo FOUND: build\windows\%TARGET_ARCH%\lib\SDL3.lib
)

if not exist build\windows\%TARGET_ARCH%\include\SDL.h (
    echo MISSING: build\windows\%TARGET_ARCH%\include\SDL.h
    set /a MISSING_FILES+=1
) else (
    echo FOUND: build\windows\%TARGET_ARCH%\include\SDL.h
)

echo.
echo Final directory structure:
if exist build\windows\%TARGET_ARCH%\bin (
    echo Contents of bin directory:
    dir /B build\windows\%TARGET_ARCH%\bin
) else (
    echo bin directory doesn't exist
)

if exist build\windows\%TARGET_ARCH%\lib (
    echo Contents of lib directory:
    dir /B build\windows\%TARGET_ARCH%\lib
) else (
    echo lib directory doesn't exist
)

if exist build\windows\%TARGET_ARCH%\include (
    echo Headers directory exists
    dir /B /S build\windows\%TARGET_ARCH%\include | find "SDL.h"
) else (
    echo include directory doesn't exist
)

if %MISSING_FILES% GTR 0 (
    echo WARNING: %MISSING_FILES% expected files are missing from the build.
) else (
    echo All expected files were successfully built and copied.
)

echo.
echo Windows %TARGET_ARCH% build complete! Libraries and binaries are available in:
echo   - build\windows\%TARGET_ARCH%\bin\SDL3.dll (shared library)
echo   - build\windows\%TARGET_ARCH%\lib\SDL3.lib (import library)
echo   - build\windows\%TARGET_ARCH%\lib\SDL3-static.lib (static library)
echo   - build\windows\%TARGET_ARCH%\include\ (headers)