@echo off
:: ==========================================
:: Sharad Vromon - Auto APK Build Agent
:: ==========================================
:: This agent monitors source files, increments version,
:: builds release APK, and pushes to GitHub Release section.

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR:.=%

echo.
echo ==========================================
echo Sharad Vromon APK Build Agent
echo ==========================================
echo.

:: Step 1: Read current version
echo [1/5] Reading current version...
if exist "%PROJECT_DIR%\VERSION" (
    set /a CURRENT_VERSION=0
    for /f "useback tokens=*" %%v in (("%PROJECT_DIR%\VERSION")) do (
        set CURRENT_VERSION=%%v
        echo   Current version: %%v
    )
) else (
    echo   WARNING: VERSION file not found, using 1.0.0
    set CURRENT_VERSION=100
)

:: Parse version numbers
set /a MAJOR=%CURRENT_VERSION:~0,1%
set /a MINOR=%CURRENT_VERSION:~1,1%
set /a PATCH=0

if "%CURRENT_VERSION%"=="100" (
    set MAJOR=1
    set MINOR=0
    set PATCH=0
)

echo   Parsed: Major=%MAJOR% Minor=%MINOR% Patch=%PATCH%

:: Step 2: Check for source file changes
echo.
echo [2/5] Checking for source file changes...

set FILE_HASH_FILE=%PROJECT_DIR%.hash_cache
set NEW_HASH=

:: Get current hash of important source files
for %%f in (
    "app/build.gradle.kts"
    "build.gradle.kts"
    "README.md"
    "VERSION"
) do (
    if exist "%PROJECT_DIR%\%%f" (
        setlocal enabledelayedexpansion
        for /f "useback tokens=*" %%h in ('certutil -hashfile "%PROJECT_DIR%\%%f" MD5') do (
            set NEW_HASH=!%%h!
        )
        endlocal
        
        if exist "%FILE_HASH_FILE%" (
            set /p OLD_HASH=<"%FILE_HASH_FILE%"
            if not "!NEW_HASH!"=="!OLD_HASH!" (
                echo   CHANGED: %%f
                set FILE_CHANGED=1
            )
        ) else (
            echo   NEW FILE: %%f (will be tracked from now on)
        )
        echo !NEW_HASH! >> "%FILE_HASH_FILE%"
    )
)

if not defined FILE_CHANGED (
    echo   No source file changes detected.
    echo   Agent will remain active, watching for changes...
    timeout /t 5 >nul
    goto :CHECK_AGAIN
)

:: Step 3: Increment version (patch version: 1.0.0 -> 1.0.1 -> 1.0.2)
echo.
echo [3/5] Incrementing version...
set /a PATCH=%PATCH%+1
if %PATCH% GTR 9 set PATCH=0
set /a MINOR=%MINOR%+1
if %MINOR% GTR 9 set MINOR=0
set NEW_VERSION=%MAJOR%.%MINOR%.%PATCH%

echo   New version: %NEW_VERSION%
echo %NEW_VERSION% > "%PROJECT_DIR%\VERSION"

:: Step 4: Build release APK
echo.
echo [4/5] Building release APK with version %NEW_VERSION%...

:: Update build.gradle.kts versionName
sed -i "s/versionName = \"[^\"]*\"/versionName = \"%NEW_VERSION%\"/" "%PROJECT_DIR%\app\build.gradle.kts"

:: Try to build with Gradle if available
if exist "%PROJECT_DIR%\gradlew" (
    echo   Using Gradle wrapper...
    cd "%PROJECT_DIR%"
    .\gradlew assembleRelease >nul 2>&1
    if %errorlevel% equ 0 (
        echo   ✅ Release APK built successfully!
    ) else (
        echo   ⚠️ Gradle build had issues, checking if debug build works...
        .\gradlew assembleDebug >nul 2>&1
    )
) else (
    echo   ⚠️ No gradlew found, project needs Android Studio build
    echo   Please run: cd "%PROJECT_DIR%" && ./gradlew assembleRelease
)

:: Find the built APK
set APK_PATH=""
for /r "%PROJECT_DIR%" %%a in (*-release.apk) do (
    set APK_PATH=%%~fa
    goto :APK_FOUND
)
if not defined APK_PATH (
    for /r "%PROJECT_DIR%" %%a in (*.apk) do (
        set APK_PATH=%%~fa
        goto :APK_FOUND
    )
)

:APK_FOUND
if defined APK_PATH (
    echo   APK Location: %APK_PATH%
    echo   APK Size: %~za bytes
) else (
    echo   ⚠️ No APK found - build may have failed
)

:: Step 5: Push to GitHub Release
echo.
echo [5/5] Preparing GitHub release push...

echo   Current GitHub repo: https://github.com/videshkarmakar-hue/Sharod-Vromon.git
echo   Version to release: %NEW_VERSION%

:: Git operations
cd "%PROJECT_DIR%"

:: Stage all changes
git add -A >nul 2>&1

:: Commit version change
git commit -m "chore: bump version to %NEW_VERSION%" >nul 2>&1

:: Push to GitHub
echo   Pushing to GitHub...
git push origin master >nul 2>&1

if %errorlevel% equ 0 (
    echo   ✅ Successfully pushed to GitHub!
    echo   Release version: %NEW_VERSION%
    echo.
    echo ==========================================
    echo "Sharod Vromon v%NEW_VERSION% is now live!"
    echo ==========================================
else (
    echo   ⚠️ Git push had issues (may need email config fix)
    echo   Try: git config --global user.email "videshkarmakar-hue@users.noreply.github.com"
)

echo.
pause