# 會議錄音轉逐字稿

會議錄音轉逐字稿工具集，支援錄音與 Whisper 語音轉文字功能。

## 功能

- **錄音設備偵測**：自動列出系統可用音訊輸入設備。
- **高品質錄製**：支援 MP3/M4A 格式，內建高通/低通濾波與降噪處理。
- **獨立播放選單**：內建音訊播放器，可自由選擇並回放錄音檔。
- **自動化組件下載**：一鍵下載最新版 FFmpeg 與 Whisper 模型。
- **外部設定檔**：透過 `settings.json` 輕鬆調整所有參數，無需修改程式碼。

## 前置條件

- Windows 10/11
- 已執行 `step1_download-dependencies.ps1` 下載必要工具

## 使用方式

### 1. 自訂設定 (選用)

您可以開啟 [`settings.json`](settings.json) 修改錄音品質、轉錄提示詞或下載連結。該檔案採用 UTF-8 編碼，並包含中文說明欄位（`purpose`）引導您進行設定。

### 2. 執行主選單

```cmd
menu.cmd
```

透過主選單，您可以依序執行各個步驟：

1. **下載必要組件** (初次使用時執行)
2. **開始錄音**
3. **播放音訊檔案**
4. **語音轉文字**

---

### 專案結構

```
.
├── menu.cmd                          # 主選單入口
├── settings.json                     # 集中設定檔 (JSON 格式)
├── step1_download-dependencies.ps1   # 自動化工具下載
├── step2_record-audio.ps1            # 錄音處理
├── step3_play-audio.ps1              # 音訊回放處理
├── step4_transcribe-audio.ps1        # Whisper 轉錄處理
├── README.md                         # 專案說明
├── FFmpeg/                           # FFmpeg 工具目錄
└── WhisperDesktop/                   # Whisper 工具與模型目錄
```

## 故障排除

若執行腳本時發生編碼相關的語法錯誤，請確保：

1. 本專案的所有 `.ps1` 腳本均保持純英文註解。
2. [`settings.json`](settings.json) 必須以 **UTF-8**（不含 BOM）格式儲存。

若選單中文顯示亂碼，請確認是從 `menu.cmd` 啟動，而不是直接執行 `.ps1` 檔案。

若找不到錄音檔案，請確認錄音檔存放在專案根目錄（與 `menu.cmd` 同層），而非子資料夾中。

## 授權

本專案僅供個人使用。
