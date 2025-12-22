@echo off
REM SMS Gateway - Setup and Run Script for Windows

echo.
echo ========================================
echo SMS Gateway - Setup & Run Script
echo ========================================
echo.

REM Check if Flutter is in PATH
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Flutter is not installed or not in PATH
    echo.
    echo Please follow these steps:
    echo 1. Download Flutter from https://flutter.dev/docs/get-started/install/windows
    echo 2. Extract to C:\flutter (or your preferred location)
    echo 3. Add Flutter to your PATH:
    echo    - Open Environment Variables
    echo    - Add C:\flutter\bin to PATH
    echo 4. Run this script again
    echo.
    pause
    exit /b 1
)

echo Step 1: Navigating to project directory...
cd /d "C:\Users\LwenaTechWare\Desktop\sms_getway"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Could not navigate to project directory
    pause
    exit /b 1
)

echo Step 2: Checking Flutter installation...
echo.
flutter doctor
echo.

echo Step 3: Getting Flutter dependencies...
echo Please wait, this may take a few minutes...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo Step 4: Checking connected devices...
echo.
flutter devices
echo.

echo.
echo ========================================
echo Ready to run on Android device!
echo ========================================
echo.
echo Command to run: flutter run
echo.
echo If you want to run now, type: flutter run
echo Press Enter to close this window...
echo.

pause
