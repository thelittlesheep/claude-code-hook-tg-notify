import { TelegramBotManager } from '../telegram-bot.js';
import { environmentConfig } from '../config/environment.js';
import { ErrorFactory } from '../errors/index.js';
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

export interface CLIArgs {
  sendMessage?: string;
  chatId?: string;
  help?: boolean;
  version?: boolean;
  isCLIMode: boolean;
}

export class CLIHandler {
  static parseArgs(): CLIArgs {
    const args = process.argv.slice(2);
    const result: CLIArgs = { isCLIMode: false };

    for (let i = 0; i < args.length; i++) {
      const arg = args[i];

      if (arg === '--help' || arg === '-h') {
        result.help = true;
        result.isCLIMode = true;
      } else if (arg === '--version' || arg === '-v') {
        result.version = true;
        result.isCLIMode = true;
      } else if (arg === '--send-message' || arg === '-m') {
        result.isCLIMode = true;
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          result.sendMessage = args[i + 1];
          i++; // 跳過下一個參數，因為它是訊息內容
        }
      } else if (arg === '--chat-id' || arg === '-c') {
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          result.chatId = args[i + 1];
          i++; // 跳過下一個參數，因為它是 chat ID
        }
      }
    }

    return result;
  }

  static async runCLI(args: CLIArgs): Promise<void> {
    // 處理 help 選項
    if (args.help) {
      this.showHelp();
      return;
    }

    // 處理 version 選項
    if (args.version) {
      this.showVersion();
      return;
    }

    // 處理發送訊息
    if (args.sendMessage !== undefined) {
      await this.handleSendMessage(args);
      return;
    }

    // 如果沒有任何有效的選項，顯示說明
    this.showUsage();
  }

  private static showHelp(): void {
    console.log(`
Telegram CLI Bot - 命令列 Telegram 機器人工具

使用方式:
  telegram-cli-bot [選項]

選項:
  -m, --send-message <訊息>    發送文字訊息
  -c, --chat-id <ID>          指定聊天室 ID（選填，預設使用環境變數）
  -h, --help                  顯示此說明
  -v, --version               顯示版本資訊

範例:
  telegram-cli-bot --send-message "Hello World"
  telegram-cli-bot -m "Hello" -c "123456789"

環境變數:
  TELEGRAM_BOT_TOKEN          Telegram Bot Token（必需）
  CHAT_ID                     預設聊天室 ID（建議設定）
  ALLOWED_CHAT_IDS            允許的聊天室 ID 清單（選填）
`);
  }

  private static showVersion(): void {
    try {
      // Get the current file path and find package.json
      const __filename = fileURLToPath(import.meta.url);
      const __dirname = dirname(__filename);
      const packageJsonPath = join(__dirname, '../../package.json');

      // Read and parse package.json
      const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf-8'));
      console.log(`${packageJson.name} version ${packageJson.version}`);
    } catch (error) {
      console.log(
        'telegram-cli-bot version unknown (could not read package.json)',
      );
    }
  }

  private static showUsage(): void {
    console.log('使用 --help 或 -h 查看詳細說明');
  }

  private static async handleSendMessage(args: CLIArgs): Promise<void> {
    const botToken = environmentConfig.getBotToken();
    const targetChatId = args.chatId || environmentConfig.getDefaultChatId();

    if (!targetChatId) {
      throw ErrorFactory.createValidationError(
        'chatId',
        '請提供聊天室 ID (--chat-id) 或設定 CHAT_ID 環境變數',
      );
    }

    if (!args.sendMessage || args.sendMessage.trim() === '') {
      throw ErrorFactory.createValidationError(
        'sendMessage',
        '請提供要發送的訊息內容',
      );
    }

    const bot = new TelegramBotManager(botToken);
    // 在 CLI 模式下不需要啟動 polling，直接發送訊息

    try {
      const result = await bot.sendMessage(targetChatId, args.sendMessage);
      console.log(`訊息已成功發送。訊息 ID：${result.message_id}`);
    } catch (error) {
      throw ErrorFactory.fromTelegramError(error, { chatId: targetChatId });
    }
  }
}
