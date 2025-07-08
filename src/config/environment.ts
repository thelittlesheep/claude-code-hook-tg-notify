import { config } from 'dotenv';
import { resolve } from 'path';

config({ path: resolve(process.cwd(), '.env') });

export interface TelegramConfig {
  botToken: string;
  defaultChatId?: string;
  allowedChatIds: string[];
  shutdownTimeoutMs: number;
}

export class EnvironmentConfig {
  private static instance: EnvironmentConfig;
  private config: TelegramConfig;

  private constructor() {
    this.config = this.loadConfig();
  }

  static getInstance(): EnvironmentConfig {
    if (!EnvironmentConfig.instance) {
      EnvironmentConfig.instance = new EnvironmentConfig();
    }
    return EnvironmentConfig.instance;
  }

  private loadConfig(): TelegramConfig {
    const botToken = process.env.TELEGRAM_BOT_TOKEN;
    if (!botToken) {
      throw new Error('TELEGRAM_BOT_TOKEN 環境變數未設定');
    }

    // Validate Bot Token format
    if (!this.isValidBotToken(botToken)) {
      throw new Error(
        'TELEGRAM_BOT_TOKEN 格式無效，應為 {bot_id}:{bot_token} 格式',
      );
    }

    const defaultChatId = process.env.CHAT_ID?.trim();
    const allowedChatIds = this.parseAllowedChatIds(
      process.env.ALLOWED_CHAT_IDS,
    );
    const shutdownTimeoutMs = this.parseShutdownTimeout(
      process.env.SHUTDOWN_TIMEOUT_MS,
    );

    return {
      botToken,
      defaultChatId,
      allowedChatIds,
      shutdownTimeoutMs,
    };
  }

  private parseAllowedChatIds(chatIds?: string): string[] {
    if (!chatIds?.trim()) {
      return [];
    }

    return chatIds
      .split(',')
      .map((id) => id.trim())
      .filter((id) => id.length > 0);
  }

  private parseShutdownTimeout(timeoutStr?: string): number {
    if (!timeoutStr?.trim()) {
      return 10000; // Default 10 seconds
    }

    const timeout = parseInt(timeoutStr, 10);
    if (isNaN(timeout) || timeout < 1000) {
      return 10000; // Default to 10 seconds if invalid
    }

    return timeout;
  }

  getConfig(): TelegramConfig {
    return { ...this.config };
  }

  getBotToken(): string {
    return this.config.botToken;
  }

  getDefaultChatId(): string | undefined {
    return this.config.defaultChatId;
  }

  getAllowedChatIds(): string[] {
    return [...this.config.allowedChatIds];
  }

  getShutdownTimeoutMs(): number {
    return this.config.shutdownTimeoutMs;
  }

  isRestrictedMode(): boolean {
    return this.config.allowedChatIds.length > 0;
  }

  isChatIdAllowed(chatId: string): boolean {
    if (!this.isRestrictedMode()) {
      return true;
    }
    return this.config.allowedChatIds.includes(chatId);
  }

  validateChatId(chatId?: string): string {
    const finalChatId = chatId || this.config.defaultChatId;

    if (!finalChatId) {
      throw new Error('未提供聊天室 ID，且未設定 CHAT_ID 環境變數');
    }

    if (!this.isChatIdAllowed(finalChatId)) {
      throw new Error(`聊天室 ID ${finalChatId} 不在允許清單中`);
    }

    return finalChatId;
  }

  /**
   * Validate Telegram Bot Token format
   * Format should be: {bot_id}:{bot_token}
   * Where bot_id is a number and bot_token is an alphanumeric string of at least 35 characters
   */
  private isValidBotToken(token: string): boolean {
    const botTokenRegex = /^[0-9]{8,10}:[a-zA-Z0-9_-]{35,}$/;
    return botTokenRegex.test(token);
  }
}

export const environmentConfig = EnvironmentConfig.getInstance();
