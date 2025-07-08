#!/bin/bash

# init.sh - 安裝 Claude Code Hooks 腳本
# 此腳本將 hooks 目錄複製到 $HOME/.claude/hooks 並設置執行權限

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 項目根目錄
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HOOKS_DIR="$PROJECT_DIR/hooks"
TARGET_HOOKS_DIR="$HOME/.claude/hooks"
TELEGRAM_BOT_CLI_PATH="$PROJECT_DIR/dist/index.js"

# 檢測操作系統以處理 sed 兼容性
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  SED_INPLACE="sed -i ''"
else
  # Linux
  SED_INPLACE="sed -i"
fi

echo -e "${BLUE}開始安裝 Claude Code Hooks...${NC}"
echo -e "${YELLOW}項目目錄: $PROJECT_DIR${NC}"

# 檢測包管理器
echo -e "${YELLOW}檢測包管理器...${NC}"
if [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
  PACKAGE_MANAGER="pnpm"
  BUILD_CMD="pnpm build"
  INSTALL_CMD="pnpm install"
elif [ -f "$PROJECT_DIR/yarn.lock" ]; then
  PACKAGE_MANAGER="yarn"
  BUILD_CMD="yarn build"
  INSTALL_CMD="yarn install"
elif [ -f "$PROJECT_DIR/package-lock.json" ]; then
  PACKAGE_MANAGER="npm"
  BUILD_CMD="npm run build"
  INSTALL_CMD="npm install"
else
  PACKAGE_MANAGER="npm"
  BUILD_CMD="npm run build"
  INSTALL_CMD="npm install"
fi
echo -e "${GREEN}使用包管理器: $PACKAGE_MANAGER${NC}"

# 檢查依賴是否已安裝
echo -e "${YELLOW}檢查依賴...${NC}"
if [ ! -d "$PROJECT_DIR/node_modules" ]; then
  echo -e "${RED}錯誤: node_modules 不存在，請先運行 $INSTALL_CMD${NC}"
  exit 1
fi
echo -e "${GREEN}依賴已安裝${NC}"

# 檢查是否需要構建
echo -e "${YELLOW}檢查構建文件...${NC}"
if [ ! -f "$TELEGRAM_BOT_CLI_PATH" ]; then
  echo -e "${YELLOW}dist/index.js 不存在，開始構建...${NC}"
  cd "$PROJECT_DIR"
  if ! $BUILD_CMD; then
    echo -e "${RED}構建失敗${NC}"
    exit 1
  fi
  echo -e "${GREEN}構建完成${NC}"
else
  echo -e "${GREEN}構建文件已存在${NC}"
fi

# 檢查源目錄是否存在
if [ ! -d "$SOURCE_HOOKS_DIR" ]; then
  echo -e "${RED}錯誤: 源目錄 $SOURCE_HOOKS_DIR 不存在${NC}"
  exit 1
fi

# 檢查源目錄是否有文件
if [ -z "$(ls -A "$SOURCE_HOOKS_DIR")" ]; then
  echo -e "${RED}錯誤: 源目錄 $SOURCE_HOOKS_DIR 是空的${NC}"
  exit 1
fi

# 檢查並創建目標目錄
echo -e "${YELLOW}檢查目標目錄: $TARGET_HOOKS_DIR${NC}"
if [ ! -d "$TARGET_HOOKS_DIR" ]; then
  echo -e "${YELLOW}創建目錄: $TARGET_HOOKS_DIR${NC}"
  mkdir -p "$TARGET_HOOKS_DIR"
else
  echo -e "${GREEN}目標目錄已存在${NC}"

  # 如果目標目錄已存在且有文件，詢問是否覆蓋
  if [ -n "$(ls -A "$TARGET_HOOKS_DIR")" ]; then
    echo -e "${YELLOW}目標目錄不是空的，是否要覆蓋現有文件？ (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}操作已取消${NC}"
      exit 0
    fi
  fi
fi

# 複製所有文件
echo -e "${YELLOW}複製 hooks 文件...${NC}"
cp -r "$SOURCE_HOOKS_DIR/"* "$TARGET_HOOKS_DIR/"

# 動態替換 TELEGRAM_BOT_CLI 路徑
echo -e "${YELLOW}更新 TELEGRAM_BOT_CLI 路徑...${NC}"
OLD_PATH="" # Empty placeholder that will be replaced
NEW_PATH="$TELEGRAM_BOT_CLI_PATH"

# 替換 config.sh 中的 TELEGRAM_BOT_CLI 路徑
if [ -f "$TARGET_HOOKS_DIR/config.sh" ]; then
  echo -e "${BLUE}  更新 config.sh${NC}"
  $SED_INPLACE "s|TELEGRAM_BOT_CLI=\"\"|TELEGRAM_BOT_CLI=\"$NEW_PATH\"|g" "$TARGET_HOOKS_DIR/config.sh"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}    ✓ 路徑更新成功${NC}"
  else
    echo -e "${RED}    ✗ 路徑更新失敗${NC}"
  fi
fi

# 清理 macOS sed 創建的備份文件
if [[ "$OSTYPE" == "darwin"* ]]; then
  rm -f "$TARGET_HOOKS_DIR"/*.sh\'\'
fi

# 設置執行權限
echo -e "${YELLOW}設置執行權限...${NC}"
find "$TARGET_HOOKS_DIR" -name "*.sh" -exec chmod +x {} \;

# 列出複製的文件
echo -e "${GREEN}已複製的文件:${NC}"
ls -la "$TARGET_HOOKS_DIR"

# 驗證權限
echo -e "${GREEN}驗證執行權限:${NC}"
for file in "$TARGET_HOOKS_DIR"/*.sh; do
  if [ -x "$file" ]; then
    echo -e "${GREEN}✓ $(basename "$file") 可執行${NC}"
  else
    echo -e "${RED}✗ $(basename "$file") 不可執行${NC}"
  fi
done

echo -e "${GREEN}Claude Code Hooks 安裝完成！${NC}"
echo -e "${BLUE}Hooks 已安裝到: $TARGET_HOOKS_DIR${NC}"
echo -e "${BLUE}TELEGRAM_BOT_CLI 路徑已更新為: $TELEGRAM_BOT_CLI_PATH${NC}"
