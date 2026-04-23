# 專案規則

## 專案概覽

Windows 離線工具，用 FFmpeg + WhisperDesktop 完成「錄音 → 降噪 → 語音轉文字」全流程，無須上傳雲端。

**技術棧**：PowerShell 5.1 × FFmpeg（dshow 錄音、降噪濾波、音量分析）× WhisperDesktop `main.exe` CLI（ggml-medium 模型）

## 腳本分工

| 腳本                              | 功能                                                                                            | 輸出                          |
| --------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------- |
| `menuCli.cmd`                     | CLI 主選單，設定 `chcp 950` 後以 `powershell.exe` 啟動各 step                                   | —                             |
| `menuGui.hta`                     | GUI 主選單（mshta.exe 32-bit），透過 `SysNative` 啟動 64-bit PS                                 | —                             |
| `step1_download-dependencies.ps1` | 下載 FFmpeg、WhisperDesktop（含 `main.exe` CLI）、ggml-medium.bin、bd.rnnn                      | `FFmpeg/`、`WhisperDesktop/`  |
| `step2_record-audio.ps1`          | 列出 dshow 裝置、錄音、記憶上次裝置                                                             | 根目錄 `{timestamp}.m4a/.mp3` |
| `step3_play-audio.ps1`            | 用 ffplay 播放選定音訊（支援音訊與影片）                                                        | —                             |
| `step4_transcribe-audio.ps1`      | silencedetect 圖週 offset 切除首尾靜音 + EBU R128 兩程 loudnorm，再送 `main.exe` CLI 語音轉文字 | `{name}.txt` + `{name}.srt`   |
| `uty1_manage-files.ps1`           | 依 basename 分組瀏覽媒體與逐字稿，可播放、預覽、刪除整組或刪除單檔                              | —                             |
| `uty2_volume-adjust.ps1`          | EBU R128 兩段式 loudnorm 音量分析與正規化                                                       | `{name}_norm.{ext}`           |
| `uty3_denoise-audio.ps1`          | 依 active profile 套 ARNNDN + gate + lowpass/hipass（可選）                                     | `{name}_denoised.{ext}`       |

> 新增步驟時，請讀取並遵循 [.github/skills/add-step/SKILL.md](.github/skills/add-step/SKILL.md) 的流程。

> `menuGui.hta` 由 `mshta.exe`（強制 32-bit）執行；必須使用 `C:\Windows\SysNative\WindowsPowerShell\v1.0\powershell.exe` 啟動 `.ps1`，才能取得 64-bit PowerShell。`SysNative` 是 WOW64 提供給 32-bit 行程存取真實 64-bit System32 的虛擬路徑，**不可改為 System32**，否則會靜默降回 32-bit PS。

**重要路徑**：

- 音訊檔案：根目錄（`*.mp3`, `*.m4a` 等）
- FFmpeg 工具：`FFmpeg/ffmpeg.exe`、`FFmpeg/ffplay.exe`、`FFmpeg/bd.rnnn`
- Whisper 工具：`WhisperDesktop/WhisperDesktop.exe`、`WhisperDesktop/main.exe`（CLI，step4 用）、`WhisperDesktop/ggml-medium.bin`
- 中央設定：`settings.json`（本機實際設定）、`settings.json.example`（版控範本，UTF-8）

## 檔案編碼與語言規則

| 檔案類型        | 編碼                    | 注釋語言                           | 強制規則                                                                |
| --------------- | ----------------------- | ---------------------------------- | ----------------------------------------------------------------------- |
| `.cmd`          | Big5 (CP950) + CRLF     | 繁體中文                           | 寫入時必須用 `[IO.File]::WriteAllText(..., Encoding.GetEncoding(950))`  |
| `.ps1`          | UTF-8 **無 BOM** + CRLF | **純英文**（不可含中文或非 ASCII） | 啟動時必須呼叫 `chcp 65001 \| Out-Null`，覆蓋 CLI 選單設定的 `chcp 950` |
| `settings.json` | UTF-8                   | —                                  | —                                                                       |

## Git 提交規範

- 所有 commit 訊息必須遵守 Conventional Commits：`<type>(<scope>): <description>`，描述使用祈使句。
- 詳細規範與範例請參閱 [conventional_commits.md](doc/conventional_commits.md)。

## 可用 CLI 工具

| 工具         | 用途               |
| ------------ | ------------------ |
| `bat`        | 查看檔案內容       |
| `yq`         | 處理 YAML          |
| `rg`         | 文字搜尋           |
| `fd`         | 尋找檔案           |
| `jq`         | 處理 JSON          |
| `git` / `gh` | Git 與 GitHub 操作 |
