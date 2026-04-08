# 慣例式提交（Conventional Commits）規範

參考：[conventionalcommits.org](https://www.conventionalcommits.org/zh-hant/v1.0.0/)

---

## 1. 訊息標準格式

```
<type>(<scope>): <description>
<type>!: <description>   # 重大變更（Breaking Change）在冒號前加 !

[body]

[footer(s)]
```

| 欄位            | 填寫規則                                                   |
| --------------- | ---------------------------------------------------------- |
| **type**        | 必填，說明改動性質（見下表）                               |
| **scope**       | 選填，小括號包裹，說明影響模組（如 `audio`, `api`, `ui`）  |
| **description** | 必填，祈使句描述（如 `add`、`fix`，而非 `added`、`fixed`） |
| **body**        | 選填，詳細說明動機或背景                                   |
| **footer**      | 選填，關聯 Issue（如 `Fixes #123`）                        |

### 完整格式範例

```text
feat(db): 加入產學合作相關資料表

為了配合 2024 年度校企對接計畫，新增 IndustryProjects 與
ProjectPartners 兩張實體表，並建立多對多關聯。

Refs: #102
Fixes: PROJ-45
```

---

## 2. 常用類型（Type）與版本關聯

| 類型         | 說明                                                 | SemVer 影響 |
| :----------- | :--------------------------------------------------- | :---------- |
| **feat**     | 新增功能                                             | MINOR       |
| **fix**      | 修復 Bug                                             | PATCH       |
| **docs**     | 僅修改文件（README、Swagger 等）                     | 無 / PATCH  |
| **style**    | 程式碼格式調整，不影響邏輯（縮排、Prettier）         | 無          |
| **refactor** | 重構，既非新功能也非修 Bug                           | 無          |
| **perf**     | 改善效能                                             | PATCH       |
| **test**     | 新增或修改測試碼                                     | 無          |
| **chore**    | 建置流程、工具或依賴庫更動（套件更新、`.gitignore`） | 無          |
| **ci**       | CI/CD 設定檔變動（GitHub Actions、Jenkins）          | 無          |
| **(Any)!**   | 重大變更（Breaking Change）                          | MAJOR       |

---

## 3. 常用範圍（Scope）範例

| 分類      | 常用 Scope                           | 範例                                               |
| --------- | ------------------------------------ | -------------------------------------------------- |
| 資料庫層  | `db`, `schema`, `migration`, `model` | `feat(db): add products table`                     |
| 業務邏輯  | `api`, `service`, `core`, `logic`    | `fix(api): handle null reference in order query`   |
| 身分驗證  | `auth`, `jwt`, `identity`            | `feat(auth): implement refresh token`              |
| 介面/前端 | `ui`, `component`, `css`, `view`     | `style(ui): adjust primary button color`           |
| 設定檔    | `config`, `env`, `settings`          | `chore(config): update connection string for prod` |

---

## 4. 實際應用範例

### 一般功能與修復

- `feat(api): 實作產品分頁查詢功能`
- `fix(auth): 修正 Token 過期時間計算錯誤`
- `refactor(service): 簡化訂單驗證邏輯`

### 重大變更（Breaking Changes）

- `feat(api)!: 移除 v1 版本廢棄的 User API`
- `chore(config)!: 將資料庫最低版本需求提升至 SQL Server 2022`
