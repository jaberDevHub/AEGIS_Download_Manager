@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0" || goto :failed

set "AEGIS_ROOT=%~dp0"
set "SETUP_TMP=%TEMP%\AegisDownloadManager-Setup"
set "PYTHON_EXE="
set "VENV_DIR=.venv"

if not exist "%SETUP_TMP%" mkdir "%SETUP_TMP%"
if errorlevel 1 goto :failed

echo ========================================================
echo        Aegis Download Manager - Windows Setup
echo ========================================================
echo.

echo [1/4] Checking Python environment (Python 3.10+ required)...
call :find_python
if errorlevel 1 (
    echo Python 3.10+ was not found on your system.
    call :install_python
)
if errorlevel 1 goto :failed

echo [OK] Using Python: "%PYTHON_EXE%"
echo.

echo [2/4] Setting up Python virtual environment...
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
    if errorlevel 1 (
        echo Existing .venv uses an outdated Python version. Switching to .venv-aegis...
        set "VENV_DIR=.venv-aegis"
    )
)

if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo Creating virtual environment in "%VENV_DIR%"...
    "%PYTHON_EXE%" -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo Error: Failed to create virtual environment with "%PYTHON_EXE%".
        goto :failed
    )
    echo [OK] Virtual environment created successfully.
) else (
    echo [OK] Virtual environment is ready: "%VENV_DIR%".
)
set "PYTHON_EXE=%CD%\%VENV_DIR%\Scripts\python.exe"
echo.

echo [3/4] Checking FFmpeg for high-resolution video/audio merging...
call :ensure_ffmpeg
if errorlevel 1 goto :failed
echo.

echo [4/4] Installing Python dependencies from requirements.txt...
"%PYTHON_EXE%" -m pip install --upgrade pip --quiet
"%PYTHON_EXE%" -m pip install -r requirements.txt
if errorlevel 1 goto :failed
echo [OK] Dependencies are up to date.

echo.
echo ========================================================
echo Aegis setup complete. Launching Aegis Download Manager...
echo Executable: "%PYTHON_EXE%"
echo ========================================================
echo.

"%PYTHON_EXE%" main.py
if errorlevel 1 goto :failed
goto :done

:find_python
rem 1. Check existing virtual environment
if exist ".venv\Scripts\python.exe" (
    set "PYTHON_EXE=%CD%\.venv\Scripts\python.exe"
    call :validate_python
    if not errorlevel 1 exit /b 0
    set "PYTHON_EXE="
)

rem 2. Check Windows py launcher
where py.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%P in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do (
        set "PYTHON_EXE=%%P"
        call :validate_python
        if not errorlevel 1 exit /b 0
        set "PYTHON_EXE="
    )
)

rem 3. Check python.exe on PATH (ignoring WindowsApps redirector)
where python.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%P in ('where python.exe 2^>nul') do (
        echo "%%P" | findstr /i /c:"WindowsApps" >nul
        if errorlevel 1 (
            if not defined PYTHON_EXE (
                set "PYTHON_EXE=%%P"
                call :validate_python
                if not errorlevel 1 exit /b 0
                set "PYTHON_EXE="
            )
        )
    )
)

rem 4. Check common installation directories
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
        set "PYTHON_EXE=%%~D"
        call :validate_python
        if not errorlevel 1 exit /b 0
        set "PYTHON_EXE="
    )
)
exit /b 1

:validate_python
if not defined PYTHON_EXE exit /b 1
if not exist "%PYTHON_EXE%" exit /b 1
"%PYTHON_EXE%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
exit /b %errorlevel%

:install_python
echo Downloading the official Python installer (64-bit)...
set "PYTHON_INSTALLER=%SETUP_TMP%\python-3.13.1-amd64.exe"

rem If installer is already downloaded and valid (>25MB), reuse it
if exist "%PYTHON_INSTALLER%" (
    for %%A in ("%PYTHON_INSTALLER%") do (
        if %%~zA GTR 25000000 goto :run_python_installer
    )
    del /f /q "%PYTHON_INSTALLER%" >nul 2>&1
)

where curl.exe >nul 2>&1
if not errorlevel 1 (
    curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 15 -# -o "%PYTHON_INSTALLER%" "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='Continue'; (New-Object System.Net.WebClient).DownloadFile('https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe', '%PYTHON_INSTALLER%')"
)

if not exist "%PYTHON_INSTALLER%" (
    echo Error: Failed to download the Python installer.
    exit /b 1
)

:run_python_installer
echo Installing Python 3.13 silently (this may take 1-2 minutes)...
start /wait "" "%PYTHON_INSTALLER%" /quiet InstallAllUsers=0 TargetDir="%LOCALAPPDATA%\Programs\Python\Python313" PrependPath=1 Include_pip=1 Include_launcher=1 Include_test=0 Include_doc=0 Shortcuts=0
if errorlevel 1 (
    echo Error: Python installer exited with an error.
    exit /b 1
)

set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
call :validate_python
if errorlevel 1 (
    echo Error: Python was installed but validation failed.
    exit /b 1
)
echo [OK] Python 3.13 installed successfully.
exit /b 0

:ensure_ffmpeg
if not exist "tools" mkdir "tools"

rem 1. Check if tools\ffmpeg.exe is already present and working
if exist "tools\ffmpeg.exe" (
    "tools\ffmpeg.exe" -version >nul 2>&1
    if not errorlevel 1 (
        echo [OK] FFmpeg is ready in tools\ffmpeg.exe
        exit /b 0
    )
)

rem 2. Check if FFmpeg is already installed on the system PATH
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
    echo [OK] Detected system FFmpeg at: "%SYS_FFMPEG%"
    echo Copying FFmpeg to project tools folder...
    copy /y "%SYS_FFMPEG%" "tools\ffmpeg.exe" >nul 2>&1
    if exist "tools\ffmpeg.exe" (
        "tools\ffmpeg.exe" -version >nul 2>&1
        if not errorlevel 1 (
            for %%D in ("%SYS_FFMPEG%") do (
                if exist "%%~dpDffprobe.exe" copy /y "%%~dpDffprobe.exe" "tools\ffprobe.exe" >nul 2>&1
            )
            echo [OK] FFmpeg is ready in tools\ffmpeg.exe
            exit /b 0
        )
    )
)

rem 3. Download FFmpeg essentials build
goto :install_ffmpeg

:install_ffmpeg
echo FFmpeg was not found. Downloading the Windows essentials build...
set "FFMPEG_ZIP=%SETUP_TMP%\ffmpeg-release-essentials.zip"
set "FFMPEG_DIR=%SETUP_TMP%\ffmpeg-extracted"

rem Download using curl with visible progress bar and automatic fallback
where curl.exe >nul 2>&1
if not errorlevel 1 (
    echo Downloading from fast mirror (GitHub CDN)...
    curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 15 -# -o "%FFMPEG_ZIP%" "https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip"
    if errorlevel 1 (
        echo Primary mirror failed. Trying secondary mirror (gyan.dev)...
        curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 15 -# -o "%FFMPEG_ZIP%" "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    )
) else (
    echo Downloading FFmpeg via PowerShell WebClient...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object System.Net.WebClient; try { $wc.DownloadFile('https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip', '%FFMPEG_ZIP%') } catch { $wc.DownloadFile('https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip', '%FFMPEG_ZIP%') }"
)

if not exist "%FFMPEG_ZIP%" (
    echo Error: Failed to download FFmpeg archive.
    exit /b 1
)

echo Extracting FFmpeg...
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
    echo Error: ffmpeg.exe was not found in the downloaded archive.
    exit /b 1
)

"tools\ffmpeg.exe" -version >nul 2>&1
if errorlevel 1 (
    echo Error: Downloaded tools\ffmpeg.exe failed to execute.
    exit /b 1
)

echo [OK] FFmpeg installed successfully in tools folder.
exit /b 0

:failed
echo.
echo ========================================================
echo Aegis setup or launch failed.
echo Please review the errors above and ensure an active internet connection.
echo ========================================================
pause
exit /b 1

:done
endlocal
