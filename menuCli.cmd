@echo off
setlocal enabledelayedexpansion

:: 設定選單的程式路徑
cd /d "%~dp0"

:menu
:: 設定主控台編碼 (Big5)
chcp 950 >nul
cls
echo ========================================
echo       會議錄音轉逐字稿工具
echo ========================================
echo.
echo   [1] 步驟 1：下載依賴工具 (執行一次即可)
echo   [2] 步驟 2：錄音
echo   [3] 步驟 3：後製降噪
echo   [4] 步驟 4：播放錄音
echo   [5] 步驟 5：語音轉文字
echo   [Enter] 離開
echo.
echo ========================================
set "choice="
set /p choice=請輸入選項 [1-5] 或按 Enter 離開：

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
    call :run_step4
    goto :menu
)
if "!choice!"=="5" (
    call :run_step5
    goto :menu
)
if "!choice!"=="" (
    goto :eof
)

if not "!choice!"=="" (
    echo 無效的選項 [!choice!]，請重新輸入。
    timeout /t 2 >nul
)
goto :menu

:run_step1
echo.
echo 正在執行步驟 1：下載依賴工具...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step1_download-dependencies.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo 發生錯誤，請稍後重試。
    pause
)
goto :eof

:run_step2
echo.
echo 正在執行步驟 2：錄音...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step2_record-audio.ps1"
goto :eof

:run_step3
echo.
echo 正在執行步驟 3：後製降噪...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step3_denoise-audio.ps1"
goto :eof

:run_step4
echo.
echo 正在執行步驟 4：播放錄音...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step4_play-audio.ps1"
goto :eof

:run_step5
echo.
echo 正在執行步驟 5：語音轉文字...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step5_transcribe-audio.ps1"
goto :eof