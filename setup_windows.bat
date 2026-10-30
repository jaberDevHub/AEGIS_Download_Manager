@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0" || goto :failed

set "AEGIS_ROOT=%~dp0"
set "SETUP_TMP=%TEMP%\AegisDownloadManager-Setup"
set "BASE_PYTHON="
set "VENV_DIR=.venv"
set "VENV_PYTHON=%AEGIS_ROOT%%VENV_DIR%\Scripts\python.exe"

if not exist "%SETUP_TMP%" mkdir "%SETUP_TMP%" >nul 2>&1

echo ========================================================
echo     AEGIS DOWNLOAD MANAGER - SMART DEPENDENCY SCAN
echo ========================================================
echo   Scanning system for required dependencies...
echo.

rem ---------------------------------------------------------
rem 1. PYTHON SCAN & VALIDATION
rem ---------------------------------------------------------
echo [1/5] SCANNING PYTHON - 3.10+ with pip...
call :scan_python

if defined BASE_PYTHON (
    echo [FOUND] Valid Python detected: "%BASE_PYTHON%"
    echo [READY] Python verified. Skipping download.
) else (
    echo [MISSING] Compatible Python 3.10+ not found on system.
    call :install_python
    if errorlevel 1 goto :failed
)
echo.

rem ---------------------------------------------------------
rem 2. VIRTUAL ENVIRONMENT SCAN & VALIDATION
rem ---------------------------------------------------------
echo [2/5] SCANNING VIRTUAL ENVIRONMENT...
call :scan_venv
if errorlevel 1 goto :failed
echo.

rem ---------------------------------------------------------
rem 3. FFMPEG SCAN & VALIDATION
rem ---------------------------------------------------------
echo [3/5] SCANNING FFMPEG - media processing ^& DLL integrity...
call :scan_ffmpeg
if errorlevel 1 goto :failed
echo.

rem ---------------------------------------------------------
rem 4. PYTHON PACKAGES SCAN & VALIDATION
rem ---------------------------------------------------------
echo [4/5] SCANNING PYTHON DEPENDENCIES - requirements.txt...
call :scan_packages
if errorlevel 1 goto :failed
echo.

rem ---------------------------------------------------------
rem 5. FINAL SYSTEM VALIDATION
rem ---------------------------------------------------------
echo [5/5] RUNNING FINAL SYSTEM INTEGRITY VALIDATION...
call :final_validation
if errorlevel 1 goto :failed

echo.
echo ========================================================
echo [READY] ALL DEPENDENCIES VERIFIED AND READY!
echo Launching Aegis Download Manager...
echo ========================================================
echo.

"%VENV_PYTHON%" main.py
if errorlevel 1 goto :failed
goto :done

rem =========================================================
rem SUBROUTINES
rem =========================================================

:scan_python
rem Check Python launcher (py.exe)
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

rem Check python.exe on PATH (ignoring WindowsApps redirector)
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

rem Check common local and standard install paths
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

rem Reuse installer only if fully downloaded (>25MB)
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
    echo [ERROR] Failed to download Python installer. Check internet connection.
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
    echo [ERROR] Installed Python validation failed.
    exit /b 1
)
echo [READY] Python 3.13 successfully installed and verified.
exit /b 0

:scan_venv
if exist "%VENV_PYTHON%" (
    rem Test if venv Python is functioning and >= 3.10
    "%VENV_PYTHON%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
    if not errorlevel 1 (
        "%VENV_PYTHON%" -m pip --version >nul 2>&1
        if not errorlevel 1 (
            echo [FOUND] Valid virtual environment already exists in %VENV_DIR%.
            echo [READY] Virtual environment verified. Skipping creation.
            exit /b 0
        )
    )
    echo [INVALID] Virtual environment in %VENV_DIR% is corrupted or outdated. Repairing...
    rmdir /s /q "%VENV_DIR%" >nul 2>&1
) else (
    echo [MISSING] Virtual environment not found. Creating in %VENV_DIR%...
)

echo Creating clean virtual environment with "%BASE_PYTHON%"...
"%BASE_PYTHON%" -m venv "%VENV_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to create virtual environment.
    exit /b 1
)

rem Verify newly created venv
"%VENV_PYTHON%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Newly created virtual environment failed validation.
    exit /b 1
)
echo [READY] Virtual environment created and verified.
exit /b 0

:scan_ffmpeg
if not exist "tools" mkdir "tools" >nul 2>&1

rem Check project tools\ffmpeg.exe
if exist "tools\ffmpeg.exe" (
    "tools\ffmpeg.exe" -version >nul 2>&1
    if not errorlevel 1 (
        echo [FOUND] FFmpeg is already installed and working in tools\ffmpeg.exe.
        echo [READY] FFmpeg and DLL dependencies verified. Skipping download.
        exit /b 0
    ) else (
        echo [INVALID] tools\ffmpeg.exe exists but failed execution: broken or missing DLLs.
    )
)

rem Check system PATH for existing FFmpeg
set "SYS_FFMPEG="
for /f "delims=" %%F in ('where ffmpeg.exe 2^>nul') do (
    if not defined SYS_FFMPEG (
        "%%F" -version >nul 2>&1
        if not errorlevel 1 (
            set "SYS_FFMPEG=%%F"
        )
    )
)

if defined SYS_FFMPEG (
    echo [FOUND] Detected working system FFmpeg at "%SYS_FFMPEG%".
    echo Copying system FFmpeg to tools\ to avoid downloading...
    copy /y "%SYS_FFMPEG%" "tools\ffmpeg.exe" >nul 2>&1
    "tools\ffmpeg.exe" -version >nul 2>&1
    if not errorlevel 1 (
        for %%D in ("%SYS_FFMPEG%") do (
            if exist "%%~dpDffprobe.exe" copy /y "%%~dpDffprobe.exe" "tools\ffprobe.exe" >nul 2>&1
        )
        echo [READY] FFmpeg copied and verified. Skipping download.
        exit /b 0
    )
    echo [INVALID] Copied FFmpeg failed to execute standalone. Proceeding to fresh download...
)

rem Download verified FFmpeg essentials build
echo [MISSING] Downloading verified Windows FFmpeg essentials build...
call :download_ffmpeg
if errorlevel 1 exit /b 1

"tools\ffmpeg.exe" -version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Downloaded FFmpeg failed verification or missing system DLLs.
    exit /b 1
)
echo [READY] FFmpeg successfully installed and verified.
exit /b 0

:download_ffmpeg
set "FFMPEG_ZIP=%SETUP_TMP%\ffmpeg-release-essentials.zip"
set "FFMPEG_DIR=%SETUP_TMP%\ffmpeg-extracted"

rem Check partial / existing download (>30MB)
if exist "%FFMPEG_ZIP%" (
    for %%A in ("%FFMPEG_ZIP%") do (
        if %%~zA GTR 30000000 goto :extract_ffmpeg
    )
    del /f /q "%FFMPEG_ZIP%" >nul 2>&1
)

where curl.exe >nul 2>&1
if not errorlevel 1 (
    echo Downloading from high-speed CDN mirror...
    curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 15 -# -o "%FFMPEG_ZIP%" "https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip"
    if errorlevel 1 (
        echo Primary CDN mirror failed. Trying secondary mirror...
        curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 15 -# -o "%FFMPEG_ZIP%" "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    )
) else (
    echo Downloading via PowerShell WebClient...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object System.Net.WebClient; try { $wc.DownloadFile('https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip', '%FFMPEG_ZIP%') } catch { $wc.DownloadFile('https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip', '%FFMPEG_ZIP%') }"
)

if not exist "%FFMPEG_ZIP%" (
    echo [ERROR] Failed to download FFmpeg archive.
    exit /b 1
)

:extract_ffmpeg
echo Extracting FFmpeg binaries...
if exist "%FFMPEG_DIR%" rmdir /s /q "%FFMPEG_DIR%" >nul 2>&1
mkdir "%FFMPEG_DIR%" >nul 2>&1

where tar.exe >nul 2>&1
if not errorlevel 1 (
    tar.exe -xf "%FFMPEG_ZIP%" -C "%FFMPEG_DIR%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%FFMPEG_ZIP%' -DestinationPath '%FFMPEG_DIR%' -Force"
)

set "FOUND_FFMPEG="
for /r "%FFMPEG_DIR%" %%I in (ffmpeg.exe) do (
    if exist "%%I" (
        if not defined FOUND_FFMPEG (
            set "FOUND_FFMPEG=%%I"
            copy /y "%%I" "tools\ffmpeg.exe" >nul 2>&1
        )
    )
)
for /r "%FFMPEG_DIR%" %%I in (ffprobe.exe) do (
    if exist "%%I" (
        copy /y "%%I" "tools\ffprobe.exe" >nul 2>&1
    )
)

del /f /q "%FFMPEG_ZIP%" >nul 2>&1
rmdir /s /q "%FFMPEG_DIR%" >nul 2>&1

if not exist "tools\ffmpeg.exe" (
    echo [ERROR] ffmpeg.exe was not found inside the downloaded archive.
    exit /b 1
)
exit /b 0

:scan_packages
rem Validate if all required dependencies can already be imported
"%VENV_PYTHON%" -c "import sys, PyQt6.QtWidgets, yt_dlp, bs4; sys.exit(0)" >nul 2>&1
if not errorlevel 1 (
    echo [FOUND] Required packages are already installed and functional.
    echo [READY] Dependencies verified. Skipping pip install.
    exit /b 0
)

echo [MISSING] Required packages not yet installed or incomplete.
echo Installing packages from requirements.txt...
"%VENV_PYTHON%" -m pip install --upgrade pip --quiet
"%VENV_PYTHON%" -m pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Failed to install requirements from requirements.txt.
    exit /b 1
)

"%VENV_PYTHON%" -c "import sys, PyQt6.QtWidgets, yt_dlp, bs4; sys.exit(0)" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Package installation finished but import verification failed.
    exit /b 1
)
echo [READY] Python packages installed and verified.
exit /b 0

:final_validation
echo Checking Python runtime...
"%VENV_PYTHON%" -c "import sys; sys.stdout.write('  Python ' + sys.version.split()[0] + ' OK\n')" || exit /b 1

echo Checking pip package manager...
"%VENV_PYTHON%" -m pip --version >nul 2>&1 || exit /b 1
echo   pip package manager OK

echo Checking FFmpeg executable and DLL integrity...
"tools\ffmpeg.exe" -version >nul 2>&1 || exit /b 1
echo   FFmpeg and DLL dependencies OK

echo Checking core GUI and downloader modules...
"%VENV_PYTHON%" -c "import PyQt6.QtWidgets, yt_dlp, bs4; print('  PyQt6, yt-dlp, BeautifulSoup4 OK')" || exit /b 1
exit /b 0

:failed
echo.
echo ========================================================
echo [FAILED] Aegis setup failed during dependency verification.
echo Please review the errors above.
echo ========================================================
pause
exit /b 1

:done
endlocal
