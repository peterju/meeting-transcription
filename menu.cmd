@echo off
setlocal enabledelayedexpansion

:menu
:: 設定為繁體中文 Big5 編碼
chcp 950 >nul
rem cls
echo ========================================
echo       錄音+轉逐字稿工具
echo ========================================
echo.
echo   [1] 步驟 1：下載必要檔案
echo   [2] 步驟 2：錄音
echo   [3] 步驟 3：語音轉文字
echo   [4] 離開
echo.
echo ========================================
set /p choice=請輸入選項：

if "!choice!"=="1" (
    call :run_step1
    goto :menu
)
if "!choice!"=="2" (
    call :run_step2
    goto :menu
)
if "!choice!"=="3" (
    call :run_step3
    goto :menu
)
if "!choice!"=="4" (
    exit
)

echo 無效的選項，請重新輸入。
timeout /t 2 >nul
goto :menu

:run_step1
echo.
echo 正在執行步驟 1：下載必要檔案...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0step1_download-dependencies.ps1"
goto :eof

:run_step2
echo.
echo 正在執行步驟 2：錄音...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0step2_record-audio.ps1"
goto :eof

:run_step3
echo.
echo 正在執行步驟 3：語音轉文字...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0step3_transcribe-audio.ps1"
goto :eof
