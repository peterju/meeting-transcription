---
name: add-step
description: "Add a new step script to the meeting-transcription project. Use when: adding a new step, creating a new stepN ps1 script, new menu item, extending the workflow with a new stage."
argument-hint: 'Step number and purpose, e.g. "step8 export to docx"'
---

# 新增工作流程步驟

## 使用時機

- 新增 `stepN_xxx.ps1` 腳本到工作流程
- 新步驟需要同時在 `menuCli.cmd` 與 `menuGui.hta` 加入選單項目

## 關鍵限制

| 檔案            | 編碼                    | 注釋語言          | 重要規則                                                              |
| --------------- | ----------------------- | ----------------- | --------------------------------------------------------------------- |
| `stepN_xxx.ps1` | UTF-8 **無 BOM** + CRLF | 純英文            | 啟動時必須呼叫 `chcp 65001`                                           |
| `menuCli.cmd`   | **Big5 (CP950)** + CRLF | 繁體中文          | 必須用 `[IO.File]::WriteAllText(..., Encoding.GetEncoding(950))` 寫入 |
| `menuGui.hta`   | UTF-8                   | JScript (IE 舊版) | 保留 `SysNative` 路徑 — **絕對不可改為 System32**                     |

## 執行步驟

### 步驟 1 — 建立 PS1 腳本

以 [assets/step-template.ps1](./assets/step-template.ps1) 為基礎：

1. 複製樣板到專案根目錄，重新命名為 `stepN_description.ps1`
2. 將 `# TODO` 替換為實際邏輯
3. 確認：UTF-8 無 BOM、CRLF 換行、純英文注釋

### 步驟 2 — 新增至 `menuCli.cmd`（Big5 編碼）

先讀取現有檔案了解結構，再：

1. 找到 `echo` 區塊與 `if "!choice!"` 區塊
2. 依照現有格式在兩處新增步驟項目
3. 在檔案底部新增 `:run_stepN` 子程序
4. **只能用 Big5 編碼寫入**：

```powershell
$content = [System.IO.File]::ReadAllText("menuCli.cmd", [System.Text.Encoding]::GetEncoding(950))
# ... 修改 $content ...
[System.IO.File]::WriteAllText("menuCli.cmd", $newContent, [System.Text.Encoding]::GetEncoding(950))
```

### 步驟 3 — 新增至 `menuGui.hta`

1. 找到 `openFolder` 按鈕前的最後一個 `<button class="step-btn" ...>` 區塊
2. 複製既有按鈕區塊並更新：`onclick="runStep(N)"`、圖示 emoji、步驟名稱、說明文字、`border-left-color`
3. 在 `<script>` 的 `names` 物件新增步驟名稱：
   ```js
   var names = { ..., N: "新步驟名稱" };
   ```
4. 在 `scripts` 物件新增腳本檔名：
   ```js
   var scripts = { ..., N: "stepN_xxx.ps1" };
   ```
5. **不可更動** `psPath` 那行 — `SysNative` 必須保留原樣

### 步驟 4 — 驗證

- [ ] `stepN_xxx.ps1` 儲存為 UTF-8 無 BOM，且接近頂部有 `chcp 65001 | Out-Null`
- [ ] `menuCli.cmd` 在 cmd 中正常開啟，無亂碼
- [ ] `menuGui.hta` 按鈕出現，且能在 64-bit PowerShell 視窗中啟動正確的 PS1
