# Whisper CLI (`main.exe`) 參考

`WhisperDesktop/main.exe` 是 Const-me/Whisper 專案提供的 C++ CLI 工具（對應 release 1.12.0 的 `cli.zip`）。
與 WhisperPS PowerShell 模組不同，此工具在 C++ 層正確請求 `eResultFlags::Timestamps`，因此輸出的 `.txt` / `.srt` 時間戳準確。

## 基本用法

```
main.exe -m <model> -l <lang> -f <audio> [options]
```

### step5 實際呼叫方式

```powershell
& $mainExePath -m $modelPath -l zh -otxt -osrt -nt -nc --prompt "..." -f "audio.mp4"
```

輸出檔案由 `PathCchRenameExtension` 產生，路徑與輸入檔案相同，僅替換副檔名：

- `-otxt` + `-nt` → `audio.txt`（純文字，不含時間戳，UTF-8 with BOM）
- `-osrt` → `audio.srt`（含正確時間戳，UTF-8 with BOM）

## 完整參數說明

| 短參數     | 長參數            | 預設值                    | 說明                                 |
| ---------- | ----------------- | ------------------------- | ------------------------------------ |
| `-h`       | `--help`          | —                         | 顯示說明後離開                       |
| `-la`      | `--list-adapters` | —                         | 列出 GPU 清單後離開                  |
| `-gpu`     | `--use-gpu`       | —                         | 指定 GPU 進行推論                    |
| `-t N`     | `--threads N`     | `4`                       | 計算執行緒數量                       |
| `-p N`     | `--processors N`  | `1`                       | 處理器數量                           |
| `-ot N`    | `--offset-t N`    | `0`                       | 時間偏移（毫秒）                     |
| `-on N`    | `--offset-n N`    | `0`                       | 片段索引偏移                         |
| `-d N`     | `--duration N`    | `0`                       | 處理音訊長度（毫秒，0 = 全部）       |
| `-mc N`    | `--max-context N` | `-1`                      | 最大文字 context token 數量          |
| `-ml N`    | `--max-len N`     | `0`                       | 每段最大字元數（0 = 不限）           |
| `-wt N`    | `--word-thold N`  | `0.01`                    | 字詞時間戳機率門檻                   |
| `-su`      | `--speed-up`      | `false`                   | 音訊加速 ×2（降低精準度）            |
| `-tr`      | `--translate`     | `false`                   | 翻譯為英文                           |
| `-di`      | `--diarize`       | `false`                   | 立體聲說話人辨識                     |
| `-otxt`    | `--output-txt`    | `false`                   | 輸出 `.txt`                          |
| `-ovtt`    | `--output-vtt`    | `false`                   | 輸出 `.vtt`（WebVTT）                |
| `-osrt`    | `--output-srt`    | `false`                   | 輸出 `.srt`（SubRip）                |
| `-owts`    | `--output-words`  | `false`                   | 輸出卡拉OK逐字時間戳腳本             |
| `-ps`      | `--print-special` | `false`                   | 印出特殊 token                       |
| `-nc`      | `--no-colors`     | `false`                   | 不使用 ANSI 顏色（建議在 PS 中啟用） |
| `-nt`      | `--no-timestamps` | `false`                   | 輸出不含時間戳                       |
| `-l LANG`  | `--language LANG` | `en`                      | 語言代碼（`zh`、`ja`、`en` 等）      |
| `-m FNAME` | `--model FNAME`   | `models/ggml-base.en.bin` | 模型路徑                             |
| `-f FNAME` | `--file FNAME`    | —                         | 輸入音訊路徑                         |
| `--prompt` | —                 | —                         | 初始提示詞（引導模型輸出風格）       |

## 常用語言代碼

| settings.json `language` | CLI `-l` |
| ------------------------ | -------- |
| `Chinese`                | `zh`     |
| `Japanese`               | `ja`     |
| `Korean`                 | `ko`     |
| `English`                | `en`     |
| `French`                 | `fr`     |
| `German`                 | `de`     |
| `Spanish`                | `es`     |

> step5 使用 `$langMap` 做對應轉換，詳見 `step5_transcribe-audio.ps1`。

## 注意事項

- 執行時需要 `Whisper.dll`（同目錄），由 `WhisperDesktop.zip` 提供
- 輸出檔案含 UTF-8 BOM，與大多數字幕播放器相容
- SRT 時間格式：`HH:MM:SS,mmm`（逗號）；VTT 時間格式：`HH:MM:SS.mmm`（點號）
- `-nc` 建議在 PowerShell 中呼叫時啟用，避免 ANSI escape code 殘留在輸出
