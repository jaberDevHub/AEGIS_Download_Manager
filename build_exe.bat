@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0" || goto :failed

set "AEGIS_ROOT=%~dp0"
set "SETUP_TMP=%TEMP%\AegisDownloadManager-Setup"
set "BASE_PYTHON="
set "VENV_DIR=.venv"
set "BUILD_PYTHON=%AEGIS_ROOT%%VENV_DIR%\Scripts\python.exe"

if not exist "%SETUP_TMP%" mkdir "%SETUP_TMP%" >nul 2>&1

echo ========================================================
echo   AEGIS DOWNLOAD MANAGER - STANDALONE BUILD SYSTEM
echo ========================================================
echo.

rem ---------------------------------------------------------
rem 1. SCAN & VALIDATE PYTHON RUNTIME
rem ---------------------------------------------------------
echo [1/6] SCANNING PYTHON ENVIRONMENT...
call :scan_python

if defined BASE_PYTHON (
    echo [FOUND] Python runtime detected: "%BASE_PYTHON%"
) else (
    echo [MISSING] Python 3.10+ not found on this PC.
    call :install_python
    if errorlevel 1 goto :failed
)
echo.

rem ---------------------------------------------------------
rem 2. SCAN & VALIDATE BUILD VIRTUAL ENVIRONMENT
rem ---------------------------------------------------------
echo [2/6] SCANNING BUILD ENVIRONMENT...
call :scan_venv
if errorlevel 1 goto :failed
echo.

rem ---------------------------------------------------------
rem 3. SCAN & VALIDATE CORE DEPENDENCIES
rem ---------------------------------------------------------
echo [3/6] SCANNING APPLICATION DEPENDENCIES...
call :scan_dependencies
if errorlevel 1 goto :failed
echo.

rem ---------------------------------------------------------
rem 4. SCAN & VALIDATE PYINSTALLER PACKAGER
rem ---------------------------------------------------------
echo [4/6] SCANNING PYINSTALLER PACKAGER...
call :scan_pyinstaller
if errorlevel 1 goto :failed
echo.

rem ---------------------------------------------------------
rem 5. BUILD STANDALONE APPLICATION EXECUTABLE
rem ---------------------------------------------------------
echo [5/6] PACKAGING STANDALONE APPLICATION EXECUTABLE...

if not exist "tools\qjs.exe" (
    echo [ERROR] Required JavaScript runtime is missing: tools\qjs.exe
    echo Please ensure tools\qjs.exe exists in the repository before building.
    goto :failed
)

if not exist "icon.ico" (
    echo [WARNING] icon.ico not found. Continuing without custom icon...
    set "ICON_PARAM="
) else (
    set "ICON_PARAM=--icon icon.ico"
)

"%BUILD_PYTHON%" -m PyInstaller --noconfirm --clean --noconsole --onefile ^
    --name "Aegis Download Manager" ^
    %ICON_PARAM% ^
    --add-data "database.py;." ^
    --add-data "engine.py;." ^
    --add-data "ui.py;." ^
    --add-data "ipc_server.py;." ^
    --add-data "icon.ico;." ^
    --add-data "icon.png;." ^
    --add-data "tools\qjs.exe;tools" ^
    --add-data "tools\QUICKJS-NG-LICENSE.txt;licenses" ^
    --hidden-import "PyQt6" ^
    --hidden-import "sqlite3" ^
    --collect-all "yt_dlp" ^
    --collect-all "yt_dlp_ejs" ^
    --copy-metadata "yt-dlp" ^
    --copy-metadata "yt-dlp-ejs" ^
    main.py

if errorlevel 1 (
    echo [ERROR] PyInstaller failed during application build.
    goto :failed
)

if not exist "dist\Aegis Download Manager.exe" (
    echo [ERROR] Expected output executable was not found: dist\Aegis Download Manager.exe
    goto :failed
)
echo [READY] Successfully created: dist\Aegis Download Manager.exe
echo.

rem ---------------------------------------------------------
rem 6. BUILD NATIVE HOST & PACKAGE EXTENSION
rem ---------------------------------------------------------
echo [6/6] BUILDING BROWSER INTEGRATION ^& EXTENSION...
if exist "aegis_host.py" (
    echo Building Python-free native messaging host...
    "%BUILD_PYTHON%" -m PyInstaller --noconfirm --clean --onefile --name aegis_host ^
        --distpath "browser_extension" ^
        --workpath "build\native-host" ^
        --specpath "build\native-host" ^
        aegis_host.py
    if errorlevel 1 (
        echo [ERROR] Native messaging host build failed.
        goto :failed
    )
)

if exist "package_browser_extension.ps1" (
    echo Packaging browser extension...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_browser_extension.ps1"
)

if exist "sync_website_release.ps1" (
    echo Updating website release copy...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_website_release.ps1"
)

echo.
echo ========================================================
echo [SUCCESS] STANDALONE BUILD COMPLETED!
echo Application Executable: dist\Aegis Download Manager.exe
if exist "dist\Aegis-Browser-Extension.zip" (
    echo Browser Extension:     dist\Aegis-Browser-Extension.zip
)
echo ========================================================
pause
exit /b 0

rem =========================================================
rem SUBROUTINES
rem =========================================================

:scan_python
rem Check existing venv
if exist "%BUILD_PYTHON%" (
    set "CANDIDATE=%BUILD_PYTHON%"
    call :test_python_candidate
    if not errorlevel 1 (
        set "BASE_PYTHON=%BUILD_PYTHON%"
        exit /b 0
    )
)

rem Check py.exe launcher
where py.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%P in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do (
        set "CANDIDATE=%%P"
        call :test_python_candidate
        if not errorlevel 1 (
            set "BASE_PYTHON=%%P"
            exit /b 0
        )
    )
)

rem Check python.exe on PATH (ignoring WindowsApps)
where python.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%P in ('where python.exe 2^>nul') do (
        echo "%%P" | findstr /i /c:"WindowsApps" >nul
        if errorlevel 1 (
            set "CANDIDATE=%%P"
            call :test_python_candidate
            if not errorlevel 1 (
                set "BASE_PYTHON=%%P"
                exit /b 0
            )
        )
    )
)

rem Check standard Python installation directories
for %%D in (
    "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
    "C:\Program Files\Python313\python.exe"
    "C:\Program Files\Python312\python.exe"
    "C:\Program Files\Python311\python.exe"
    "C:\Program Files\Python310\python.exe"
) do (
    if exist "%%~D" (
        set "CANDIDATE=%%~D"
        call :test_python_candidate
        if not errorlevel 1 (
            set "BASE_PYTHON=%%~D"
            exit /b 0
        )
    )
)
exit /b 1

:test_python_candidate
if not defined CANDIDATE exit /b 1
if not exist "%CANDIDATE%" exit /b 1
"%CANDIDATE%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if errorlevel 1 exit /b 1
"%CANDIDATE%" -m pip --version >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:install_python
echo [MISSING] Installing official Python 3.13 64-bit...
set "PYTHON_INSTALLER=%SETUP_TMP%\python-3.13.1-amd64.exe"

if exist "%PYTHON_INSTALLER%" (
    for %%A in ("%PYTHON_INSTALLER%") do (
        if %%~zA GTR 25000000 goto :run_python_installer
    )
    del /f /q "%PYTHON_INSTALLER%" >nul 2>&1
)

where curl.exe >nul 2>&1
if not errorlevel 1 (
    echo Downloading Python installer with live progress...
    curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 15 -# -o "%PYTHON_INSTALLER%" "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe"
) else (
    echo Downloading Python installer via WebClient...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='Continue'; (New-Object System.Net.WebClient).DownloadFile('https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe', '%PYTHON_INSTALLER%')"
)

if not exist "%PYTHON_INSTALLER%" (
    echo [ERROR] Failed to download Python installer.
    exit /b 1
)

:run_python_installer
echo Running silent Python setup adding to user PATH...
start /wait "" "%PYTHON_INSTALLER%" /quiet InstallAllUsers=0 TargetDir="%LOCALAPPDATA%\Programs\Python\Python313" PrependPath=1 Include_pip=1 Include_launcher=1 Include_test=0 Include_doc=0 Shortcuts=0
if errorlevel 1 (
    echo [ERROR] Python installer exited with code %errorlevel%.
    exit /b 1
)

set "BASE_PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
set "CANDIDATE=%BASE_PYTHON%"
call :test_python_candidate
if errorlevel 1 (
    echo [ERROR] Python validation failed after installation.
    exit /b 1
)
echo [READY] Python 3.13 successfully installed.
exit /b 0

:scan_venv
if exist "%BUILD_PYTHON%" (
    "%BUILD_PYTHON%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
    if not errorlevel 1 (
        "%BUILD_PYTHON%" -m pip --version >nul 2>&1
        if not errorlevel 1 (
            echo [FOUND] Valid virtual environment detected in %VENV_DIR%.
            echo [READY] Using build environment: "%BUILD_PYTHON%"
            exit /b 0
        )
    )
    echo [INVALID] Virtual environment in %VENV_DIR% is corrupted. Rebuilding...
    rmdir /s /q "%VENV_DIR%" >nul 2>&1
) else (
    echo [MISSING] Virtual environment not found. Creating %VENV_DIR%...
)

echo Creating clean build virtual environment...
"%BASE_PYTHON%" -m venv "%VENV_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to create build virtual environment.
    exit /b 1
)

"%BUILD_PYTHON%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Build virtual environment validation failed.
    exit /b 1
)
echo [READY] Build virtual environment ready.
exit /b 0

:scan_dependencies
"%BUILD_PYTHON%" -c "import sys, PyQt6.QtWidgets, yt_dlp, bs4, yt_dlp_ejs; sys.exit(0)" >nul 2>&1
if not errorlevel 1 (
    echo [FOUND] All core application dependencies are installed.
    echo [READY] Application modules verified.
    exit /b 0
)

echo [MISSING] Installing required packages into build environment...
"%BUILD_PYTHON%" -m pip install --upgrade pip --quiet
"%BUILD_PYTHON%" -m pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Failed to install application dependencies.
    exit /b 1
)

"%BUILD_PYTHON%" -c "import sys, PyQt6.QtWidgets, yt_dlp, bs4, yt_dlp_ejs; sys.exit(0)" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Dependency installation completed but import verification failed.
    exit /b 1
)
echo [READY] Application dependencies successfully installed and verified.
exit /b 0

:scan_pyinstaller
"%BUILD_PYTHON%" -m PyInstaller --version >nul 2>&1
if not errorlevel 1 (
    echo [FOUND] PyInstaller is already installed in the build environment.
    echo [READY] PyInstaller verified.
    exit /b 0
)

echo [MISSING] Installing PyInstaller into build environment...
"%BUILD_PYTHON%" -m pip install pyinstaller
if errorlevel 1 (
    echo [ERROR] Failed to install PyInstaller.
    exit /b 1
)

"%BUILD_PYTHON%" -m PyInstaller --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PyInstaller was installed but failed validation.
    exit /b 1
)
echo [READY] PyInstaller installed and verified.
exit /b 0

:failed
echo.
echo ========================================================
echo [FAILED] Executable build failed.
echo Please review the errors above and ensure network connectivity.
echo ========================================================
pause
exit /b 1