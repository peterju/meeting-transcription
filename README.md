# Meeting Transcription

會議錄音轉逐字稿工具集，支援錄音與語音轉文字功能。

## 功能

- 錄音設備偵測與選擇
- 音訊錄製（MP3 格式）
- 雜音消除與濾波處理
- 語音轉文字（需安裝 WhisperDesktop）

## 前置條件

- Windows 10/11
- 已執行 `download-dependencies.ps1` 下載必要工具

## 使用方式

### 1. 下載必要檔案

```powershell
.\download-dependencies.ps1
```

會自動下載：
- FFmpeg（音訊處理）
- WhisperDesktop（語音轉文字）
- ggml-medium.bin（語音辨識模型）

### 2. 錄音

```powershell
.\record-audio.ps1
```

1. 執行腳本後，選擇錄音設備
2. 開始錄音
3. 按 `Q` 停止錄音
4. 錄音檔案會以 `Record_MMdd_HHmm.mp3` 格式儲存

### 3. 語音轉文字

1. 執行 `WhisperDesktop\WhisperDesktop.exe`
2. 載入模型（`WhisperDesktop\ggml-medium.bin`）
3. 匯入錄音檔案進行轉換

## 專案結構

```
.
├── .gitignore
├── .gitattributes
├── README.md
├── record-audio.ps1         # 錄音腳本
├── download-dependencies.ps1 # 下載必要工具
├── FFmpeg/                   # FFmpeg（由下載腳本產生）
└── WhisperDesktop/          # WhisperDesktop（由下載腳本產生）
```

## 相關資源

- [WhisperDesktop](https://github.com/Const-me/Whisper)
- [Open Chinese Convert](https://github.com/BYVoid/OpenCC)
- [FFmpeg](https://ffmpeg.org/)

## 授權

本專案僅供個人使用。
