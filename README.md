# Telegram CLI Bot

一個命令列 Telegram Bot 工具，支援直接從終端發送訊息和管理機器人。

## 功能特色

- 📱 **命令列介面**：支援直接從終端發送訊息
- 📨 **訊息發送**：快速發送文字訊息到指定聊天室
- 🔒 **安全機制**：聊天室 ID 白名單驗證
- ⚙️ **彈性配置**：環境變數配置，支援預設聊天室
- 🪝 **Hooks 系統**：與 Claude Code 整合，自動化通知工作流程
- 🛠️ **多種選項**：
  - `--send-message, -m`：發送文字訊息
  - `--chat-id, -c`：指定聊天室 ID
  - `--help, -h`：顯示說明
  - `--version, -v`：顯示版本
- 🔧 **簡單易用**：單一命令即可發送訊息
- 🚀 **自動化整合**：透過 hooks 系統自動發送專案狀態和用戶輸入通知

## 快速開始

### 1. 建立 Telegram Bot

1. 在 Telegram 中搜尋 [@BotFather](https://t.me/botfather)
2. 發送 `/newbot` 命令
3. 按照指示設定 bot 名稱和用戶名
4. 保存取得的 Bot Token

### 2. 安裝專案

```bash
# 克隆專案
git clone <your-repo-url>
cd telegram-notification

# 安裝依賴
pnpm install

# 複製環境變數範例
cp .env.example .env
```

### 3. 設定環境變數

編輯 `.env` 檔案：

```env
# Telegram Bot Token
TELEGRAM_BOT_TOKEN=你的_bot_token

# 預設聊天室 ID (用於 CLI 模式)
CHAT_ID=你的_預設聊天室ID
```

### 4. 取得聊天室 ID

要取得聊天室 ID，可以：

1. 向你的 bot 發送任何訊息
2. 訪問：`https://api.telegram.org/bot<你的BOT_TOKEN>/getUpdates`
3. 在回應中找到 `"chat":{"id":聊天室ID}`

### 5. 建構和執行

```bash
# 建構專案
pnpm build

# 開發模式（自動重新載入）
pnpm dev

# 生產模式
pnpm start
```

### 6. 設定 Hooks 系統

如果你想要與 Claude Code 整合，可以設定 hooks 系統：

```bash
# 執行初始化腳本
./init.sh

# 或手動設定
chmod +x hooks/*.sh
chmod +x hooks/utils/*.sh
```

設定完成後，hooks 系統將會：

- 自動發送 Claude Code 會話狀態通知
- 提取並發送用戶輸入內容
- 在專案啟動/停止時發送通知

## 使用範例

### 基本用法

```bash
# 顯示說明
telegram-cli-bot --help

# 顯示版本
telegram-cli-bot --version

# 發送訊息到預設聊天室
telegram-cli-bot --send-message "Hello World!"

# 發送訊息到指定聊天室
telegram-cli-bot --send-message "Hello" --chat-id "123456789"

# 使用短參數
telegram-cli-bot -m "Hello" -c "123456789"
```

### 進階用法

```bash
# 發送多行訊息
telegram-cli-bot -m "這是第一行
這是第二行
這是第三行"

# 發送包含特殊字符的訊息
telegram-cli-bot -m "支援 emoji 😄 和特殊符號 ✨"

# 使用環境變數設定預設聊天室
export CHAT_ID="123456789"
telegram-cli-bot -m "發送到預設聊天室"
```

### Hooks 系統使用

當與 Claude Code 整合時，hooks 系統會自動運作：

```bash
# 手動測試 hooks（開發用）
./hooks/telegram-notification-hook.sh < test-hook-data.json

# 查看 hooks 配置
cat hooks/config.sh

# 檢查 hooks 狀態
ls -la hooks/

# 重新初始化 hooks 系統
./init.sh
```

**自動化功能**：

- 📝 **會話開始**：自動發送專案名稱和初始狀態
- 💬 **用戶輸入**：提取並發送用戶的重要輸入內容
- 🔄 **狀態更新**：定期發送會話進度和變更
- 🛑 **會話結束**：發送完成通知和摘要

## 開發指南

### 專案結構

```
telegram-notification/
├── src/
│   ├── index.ts                    # CLI 主程式入口
│   ├── cli/
│   │   └── cli-handler.ts          # CLI 參數處理和執行
│   ├── config/
│   │   └── environment.ts          # 環境變數配置管理
│   ├── errors/                     # 錯誤處理系統
│   │   ├── base-error.ts
│   │   ├── telegram-errors.ts
│   │   ├── validation-errors.ts
│   │   └── index.ts
│   ├── services/                   # 服務層
│   │   ├── telegram-service.ts     # Telegram API 服務
│   │   └── message-service.ts      # 訊息管理服務
│   ├── telegram-bot.ts             # Telegram Bot 管理器
│   └── types.ts                    # TypeScript 類型定義
├── hooks/                          # Claude Code Hooks 系統
│   ├── config.sh                   # Hooks 配置文件
│   ├── telegram-notification-hook.sh  # 主要通知 hook
│   ├── telegram-stop-hook.sh       # 停止通知 hook
│   └── utils/                      # Hooks 工具函數
│       ├── common.sh               # 通用函數
│       └── extract-enriched-data.sh # 資料提取工具
├── dist/                           # 編譯輸出目錄
├── init.sh                         # Hooks 系統初始化腳本
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

### 可用的 npm 腳本

- `pnpm build`：編譯 TypeScript
- `pnpm dev`：開發模式（自動重新載入）
- `pnpm start`：執行編譯後的程式
- `pnpm clean`：清理編譯輸出

### 擴展功能

要新增更多 CLI 功能，可以：

1. 在 `types.ts` 中定義新的類型
2. 在 `cli-handler.ts` 中新增新的命令列選項
3. 在 `telegram-service.ts` 中實作新的 Telegram API 方法
4. 更新 `CLIArgs` 介面以支援新的參數

### 自定義 Hooks 系統

要自定義 hooks 系統的行為：

#### 1. 修改配置

編輯 `hooks/config.sh` 來調整設定：

```bash
# 修改訊息格式
export MESSAGE_FORMAT="detailed"  # basic, detailed, json

# 調整訊息長度限制
export USER_INPUT_TRUNCATE_LENGTH=500

# 設定預設聊天室
export CHAT_ID="your-chat-id"
```

#### 2. 自定義通知內容

修改 `hooks/telegram-notification-hook.sh` 來自定義通知格式：

```bash
# 自定義專案名稱顯示
format_project_name() {
  local project_name="$1"
  echo "🚀 專案：$project_name"
}

# 自定義用戶輸入格式
format_user_input() {
  local input="$1"
  echo "💬 用戶輸入：$input"
}
```

#### 3. 擴展資料提取

修改 `hooks/utils/extract-enriched-data.sh` 來擴展資料提取功能：

```bash
# 新增自定義資料提取
extract_custom_data() {
  local input="$1"
  # 在此處新增自定義邏輯
}
```

## 安全注意事項

1. **保護 Bot Token**：絕對不要將 Bot Token 提交到版本控制系統
2. **驗證輸入**：CLI 工具會自動驗證所有輸入參數
3. **錯誤處理**：所有 API 呼叫都有適當的錯誤處理和重試機制
4. **環境變數管理**：使用 `.env` 檔案管理敏感資訊，不要在命令列中直接暴露

## 疑難排解

### CLI 工具無法啟動

- 確認 Node.js 版本 >= 18
- 確認已執行 `pnpm install` 安裝相依性
- 確認已執行 `pnpm build` 編譯程式

### 無法發送訊息

- 確認 Bot Token 正確且有效
- 確認聊天室 ID 正確
- 確認 Bot 已被加入到群組聊天（若發送到群組）
- 檢查網路連線

### 環境變數問題

- 確認 `.env` 檔案存在且格式正確
- 確認 `TELEGRAM_BOT_TOKEN` 已設定
- 如使用預設聊天室，確認 `CHAT_ID` 已設定

### 權限錯誤

- 確認 Bot 有發送訊息到目標聊天室的權限

## 授權

MIT License
