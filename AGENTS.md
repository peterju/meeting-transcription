# 專案規則

## 專案概覽

Windows 離線工具，用 FFmpeg + WhisperDesktop 完成「錄音 → 降噪 → 語音轉文字」全流程，無須上傳雲端。

**技術棧**：PowerShell 5.1 × FFmpeg（dshow 錄音、降噪濾波、音量分析）× WhisperPS 模組 × WhisperDesktop（ggml-medium 模型）

## 腳本分工

| 腳本                              | 功能                                                                  | 輸出                                     |
| --------------------------------- | --------------------------------------------------------------------- | ---------------------------------------- |
| `menuCli.cmd`                     | CLI 主選單，設定 `chcp 950` 後以 `powershell.exe` 啟動各 step         | —                                        |
| `menuGui.hta`                     | GUI 主選單（mshta.exe 32-bit），透過 `SysNative` 啟動 64-bit PS       | —                                        |
| `step1_download-dependencies.ps1` | 下載 FFmpeg、WhisperDesktop、ggml-medium.bin、WhisperPS 模組、bd.rnnn | `FFmpeg/`、`WhisperDesktop/`、PS Modules |
| `step2_record-audio.ps1`          | 列出 dshow 裝置、錄音、記憶上次裝置                                   | 根目錄 `{timestamp}.m4a/.mp3`            |
| `step3_denoise-audio.ps1`         | 依 active profile 套 ARNNDN + gate + lowpass/hipass                   | `{name}_denoised.{ext}`                  |
| `step4_play-audio.ps1`            | 用 ffplay 播放選定音訊                                                | —                                        |
| `step5_transcribe-audio.ps1`      | WhisperPS 語音轉文字                                                  | `{name}.txt` + `{name}.srt`              |
| `step6_manage-files.ps1`          | 列出/重新命名/刪除音訊（刪除時一併移除 .txt/.srt）                    | —                                        |
| `step7_volume-adjust.ps1`         | volumedetect 分析 + 增益調整                                          | `{name}_vol{n}dB.{ext}`                  |

> 新增步驟時，請讀取並遵循 [.github/skills/add-step/SKILL.md](.github/skills/add-step/SKILL.md) 的流程。

**重要路徑**：

- 音訊檔案：根目錄（`*.mp3`, `*.m4a` 等）
- FFmpeg 工具：`FFmpeg/ffmpeg.exe`、`FFmpeg/ffplay.exe`、`FFmpeg/bd.rnnn`
- Whisper 工具：`WhisperDesktop/WhisperDesktop.exe`、`WhisperDesktop/ggml-medium.bin`
- 中央設定：`settings.json`（每支腳本啟動時讀取，UTF-8）

## 檔案編碼與語言規則

1. **`.cmd` 腳本**：必須使用**繁體中文**、**Big5 (CP950) 編碼**，以及 **CRLF** 換行。
2. **`.ps1` 腳本**：必須使用**純英文註解**、**UTF-8 編碼**（無 BOM），以及 **CRLF** 換行。
3. **`settings.json`**：必須以 **UTF-8** 編碼儲存。

## Git 提交規範

- 所有 commit 訊息必須遵守 Conventional Commits：`<type>(<scope>): <description>`，描述使用祈使句。
- 詳細規範與範例請參閱 [CONVENTIONAL_COMMITS.md](doc/CONVENTIONAL_COMMITS.md)。

## 可用 CLI 工具

| 工具         | 用途               |
| ------------ | ------------------ |
| `bat`        | 查看檔案內容       |
| `yq`         | 處理 YAML          |
| `rg`         | 文字搜尋           |
| `fd`         | 尋找檔案           |
| `jq`         | 處理 JSON          |
| `git` / `gh` | Git 與 GitHub 操作 |

## 注意事項

- 絕對不可在 `.ps1` 檔案的註解中加入中文或非 ASCII 字元。
- 編輯 `.cmd` 檔時，必須以 Big5 編碼寫入。請使用 PowerShell：`[IO.File]::WriteAllText("path", $content, [System.Text.Encoding]::GetEncoding(950))`
- CLI 選單（`menuCli.cmd`）在啟動 `.ps1` 腳本前會設定 `chcp 950`；每支 `.ps1` 腳本必須自行覆蓋為 `chcp 65001`，以確保 UTF-8 主控台輸出正確。
- `menuGui.hta` 由 `mshta.exe`（強制 32-bit）執行；必須使用 `C:\Windows\SysNative\WindowsPowerShell\v1.0\powershell.exe` 啟動 `.ps1`，才能取得 64-bit PowerShell。`SysNative` 是 WOW64 提供給 32-bit 行程存取真實 64-bit System32 的虛擬路徑，**不可改為 System32**，否則會靜默降回 32-bit PS。
