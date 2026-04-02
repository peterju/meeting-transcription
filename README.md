# 會議錄音轉逐字稿

會議錄音轉逐字稿工具集，支援錄音、後製降噪與 Whisper 語音轉文字功能。

## 功能

- **錄音設備偵測**：自動列出系統可用音訊輸入設備。
- **高品質錄製**：支援 MP3/M4A 格式，預設 M4A 192kbps。
- **後製降噪**：提供 Profile 模式的降噪處理（ARNNDN / Gate / Lowpass / Hipass）。
- **獨立播放**：內建 ffplay 播放器，可自由選擇並回放錄音檔。
- **語音轉文字**：支援 WhisperPS 離線轉錄。
- **自動化下載**：一鍵下載 FFmpeg、Whisper 模型與 ARNNDN 模型。
- **外部設定檔**：透過 `settings.json` 輕鬆調整所有參數。

## 前置條件

- Windows 10/11
- 已執行 `step1_download-dependencies.ps1` 下載必要工具

## 使用方式

### 1. 自訂設定 (選用)

您可以開啟 [`settings.json`](settings.json) 修改：

- **錄音格式**：audio.format、audio.m4aQuality
- **後製降噪Profile**：record.activeProfile、profiles.meeting、profiles.choir
- **轉錄提示詞**：transcription.prompt

### 2. 執行主選單

**CLI 版本（命令列）：**
```cmd
menuCli.cmd
```

**GUI 版本（圖形介面）：**
```cmd
menuGui.hta
```

選單選項：
1. 步驟 1：下載依賴工具（首次執行）
2. 步驟 2：錄音
3. 步驟 3：後製降噪
4. 步驟 4：播放錄音
5. 步驟 5：語音轉文字

### 3. 工作流程

```
[1] step1: 下載 FFmpeg + Whisper + bd.rnnn 模型
    ↓
[2] step2: 錄音（原始檔，無濾波）
    ↓
[3] step3: 後製降噪（根據 Profile 套用濾波器）
    ↓
[4] step4: 播放錄音（可用 ffplay 比較原始與降噪音軌）
    ↓
[5] step5: Whisper 轉文字（輸出 .txt 與 .srt）
```

### 4. Profile 說明

| Profile | ARNNDN | Gate | Lowpass | Hipass | 適用場景 |
|---------|--------|------|---------|--------|----------|
| meeting | 啟用 | -40dB | 0 | 0 | 一般會議錄音 |
| choir | 停用 | -50dB | 10000Hz | 70Hz | 合唱團錄音 |

---

## 專案結構

```
.
├── menuCli.cmd                         # 主選單入口 (CLI)
├── menuGui.hta                         # 主選單入口 (GUI)
├── settings.json                       # 集中設定檔 (JSON 格式)
├── step1_download-dependencies.ps1    # 自動化工具下載
├── step2_record-audio.ps1             # 錄音處理
├── step3_denoise-audio.ps1             # 後製降噪處理
├── step4_play-audio.ps1                # 音訊播放處理
├── step5_transcribe-audio.ps1          # Whisper 轉錄處理
├── README.md                           # 專案說明
├── FFmpeg/                             # FFmpeg 工具目錄 (含 bd.rnnn 模型)
└── WhisperDesktop/                     # Whisper 工具與模型目錄
```

## 故障排除

若執行腳本時發生編碼相關的語法錯誤，請確保：

1. 本專案的所有 `.ps1` 腳本均保持純英文註解。
2. [`settings.json`](settings.json) 必須以 **UTF-8** 格式儲存。

若選單中文顯示亂碼，請確認是從 `menuCli.cmd` 啟動，而不是直接執行 `.ps1` 檔案。

## 授權

本專案僅供個人使用。