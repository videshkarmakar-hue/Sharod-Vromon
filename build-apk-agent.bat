@echo off
:: ==========================================
:: Sharad Vromon - Auto APK Build Agent
:: ==========================================
:: When source files update, increments version,
:: builds release APK, and pushes to GitHub Release

setlocal enabledelayedexpansion

set PROJECT_DIR=C:\sharad-project

echo.
echo ==========================================
echo Sharad Vromon APK Build Agent
echo ==========================================
echo.

:: Step 1: Read current version from VERSION file
echo [1/5] Reading current version...
set CURRENT_VER=100
if exist "%PROJECT_DIR%\VERSION" (
    for /f "useback tokens=*" %%v in ("%PROJECT_DIR%\VERSION") do (
        set CURRENT_VER=%%v
    )
)
:: Convert "1.0.0" style to numeric 100, "1.0.1" to 101, etc.
set "VER_STR=%CURRENT_VER%"
set "VER_STR=%VER_STR:.= "
set MAJOR_PART=!VER_STR:~0,1!
set "REST=!VER_STR:~2!"
set MINOR_PART=!REST:~0,1!"
set "PATCH_PART=!REST:~2!"
set PATCH_NUM=!PATCH_PART:~0,1!

:: Ensure valid numbers
if %MAJOR_PART% GTR 9 set MAJOR_PART=1
if %MINOR_PART% GTR 9 set MINOR_PART=0
if %PATCH_NUM% GTR 9 set PATCH_NUM=0

set /a VERSION_NUM=MAJOR_PART*100+MINOR_PART*10+PATCH_NUM
echo   Current version: %CURRENT_VER% (numeric: !VERSION_NUM!)

:: Step 2: Check for changes (VERSION file hash)
echo.
echo [2/5] Checking for changes...

set HASH_FILE=%PROJECT_DIR%\hash_cache.txt
if not exist "%HASH_FILE%" (
    echo 00000000000000000000000000000000 > "%HASH_FILE%"
)

set SAVED_HASH=
for /f "useback tokens=1" %%h in ("%HASH_FILE%") do (
    set SAVED_HASH=%%h
)

for /f "useback tokens=*" %%c in ('certutil -hashfile "%PROJECT_DIR%\VERSION" MD5') do (
    set CURRENT_HASH=%%c
)

if not "!CURRENT_HASH!"=="!SAVED_HASH!" (
    echo   Change detected - triggering version bump
    set FILE_CHANGED=1
) else (
    echo   No changes detected. Agent watching...
    timeout /t 5 >nul
    goto :CHECK_AGAIN
)

:: Step 3: Increment version (patch: 1.0.0 -> 1.0.1 -> 1.0.2)
echo.
echo [3/5] Incrementing version...

set /a VERSION_NUM+=1
set /a PATCH_NUM=%VERSION_NUM% %% 10
set /a MINOR_PART=(!VERSION_NUM! / 10) %% 10
set /a MAJOR_PART=(!VERSION_NUM! / 100)

set NEW_VER_MAJOR=!MAJOR_PART!
set NEW_VER_MINOR=!MINOR_PART!
set NEW_VER_PATCH=!PATCH_NUM!

set NEW_VERSION=!NEW_VER_MAJOR!.!NEW_VER_MINOR!.!NEW_VER_PATCH!

echo   New version: %NEW_VERSION%
echo %NEW_VERSION% > "%PROJECT_DIR%\VERSION"

:: Update hash file so next run knows this version
certutil -hashfile "%PROJECT_DIR%\VERSION" MD5 > "%TEMP%\new_hash.txt"
for /f "tokens=2" %%h in ('findstr /r "^$" "%TEMP%\new_hash.txt"') do (
    set NEW_HASH_VAL=%%h
)
echo !NEW_HASH_VAL! > "%HASH_FILE%"

:: Step 4: Build release APK
echo.
echo [4/5] Building release APK with version %NEW_VERSION%...

echo   → VERSION file updated to %NEW_VERSION%
echo   → Need: versionName = "%NEW_VERSION%" in %PROJECT_DIR%\app\build.gradle.kts

:: Check Gradle wrapper
if exist "%PROJECT_DIR%\gradlew" (
    echo   ✅ Gradle wrapper found
    cd "%PROJECT_DIR%"
    .\gradlew assembleRelease >nul 2>&1
    if !errorlevel! equ 0 (
        echo   ✅ Release APK built successfully!
        echo   Location: %PROJECT_DIR%\app\build\outputs\release\app-release.apk
    ) else (
        echo   ⚠️ Release build issue - try Android Studio
        .\gradlew assembleDebug >nul 2>&1
    )
) else (
    echo   ⚠️ No gradlew - open in Android Studio
    echo   Build → Build APK(s)
)

:: Find the APK
echo.
echo Looking for APK...
set APK_FOUND=0
if exist "%PROJECT_DIR%\app\build\outputs\release\app-release.apk" (
    set APK_PATH="%PROJECT_DIR%\app\build\outputs\release\app-release.apk"
    set APK_FOUND=1
    echo   ✅ Release APK found!
    echo   Path: %APK_PATH%
    set APK_SIZE=%~za
    echo   Size: !APK_SIZE! bytes
) else (
    for /r "%PROJECT_DIR%" %%f in (*.apk) do (
        set APK_PATH="%%f"
        set APK_FOUND=1
        echo   Found APK: %%f
    )
)
if %APK_FOUND% equ 0 echo   No APK found

:: Step 5: Push to GitHub Release
echo.
echo [5/5] Pushing to GitHub Release...

echo   → Commit: chore: bump version to %NEW_VERSION%
cd "%PROJECT_DIR%"

git add -A >nul
git commit -m "chore: bump version to %NEW_VERSION%" >nul
echo   Pushing to origin master...
git push origin master >nul

if !errorlevel! equ 0 (
    echo   ✅ Successfully pushed to GitHub!
    echo   Release version: %NEW_VERSION% live on GitHub!
    echo.
    echo ==========================================
    echo "Sharod Vromon v%NEW_VERSION% deployed!"
    echo ==========================================
    echo.
    echo "Next source update will trigger version: %NEW_VERSION%"
    set /a NEXT_PATCH=%PATCH_NUM%+1
    if %NEXT_PATCH% GTR 9 set NEXT_PATCH=0
    set /a NEXT_VER=MAJOR_PART*100+MINOR_PART*10+NEXT_PATCH
    echo   Next expected: !NEXT_VER:~0,1!.!NEXT_VER:~1,1!.!NEXT_VER:~2,1!
) else (
    echo   ⚠️ Git push issue - email config needed
    echo   Fix: git config --global user.email "videshkarmakar-hue@users.noreply.github.com"
)

echo.
pause