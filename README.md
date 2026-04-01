# 會議錄音轉逐字稿

會議錄音轉逐字稿工具集，支援錄音與 Whisper 語音轉文字功能。

## 功能

- 錄音設備偵測與選擇
- 音訊錄製（MP3/M4A 格式）
- 雜音消除與濾波處理
- 語音轉文字（WhisperPS / WhisperDesktop）

## 前置條件

- Windows 10/11
- 已執行 `step1_download-dependencies.ps1` 下載必要工具

## 使用方式

### 執行主選單

```cmd
menu.cmd
```

或直接執行各步驟腳本：

### Step 1: 下載必要檔案

```powershell
.\step1_download-dependencies.ps1
```

會自動下載：
- FFmpeg（音訊處理）
- WhisperDesktop（語音轉文字）
- ggml-medium.bin（語音辨識模型）
- WhisperPS PowerShell 模組

### Step 2: 錄音

```powershell
.\step2_record-audio.ps1
```

1. 執行腳本後，選擇錄音設備
2. 開始錄音
3. 按 `Q` 停止錄音
4. 錄音檔案會以 `Record_MMdd_HHmm.mp3` 格式儲存

可選擇輸出格式（mp3/m4a）及音訊濾波器（高通/低通/雜訊消除）

### Step 3: 語音轉文字

```powershell
.\step3_transcribe-audio.ps1
```

自動偵測音訊檔案並轉換為文字（.txt）與字幕（.srt）

## 專案結構

```
.
├── menu.cmd                          # 主選單
├── step1_download-dependencies.ps1   # 下載必要工具
├── step2_record-audio.ps1            # 錄音腳本
├── step3_transcribe-audio.ps1        # 轉文字腳本
├── README.md
├── .gitignore
├── .gitattributes
├── FFmpeg/                           # FFmpeg（由 step1 產生）
└── WhisperDesktop/                   # WhisperDesktop（由 step1 產生）
```

## 相關資源

- [WhisperDesktop](https://github.com/Const-me/Whisper)
- [FFmpeg](https://ffmpeg.org/)

## 授權

本專案僅供個人使用。