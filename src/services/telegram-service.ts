import { Telegraf } from 'telegraf';
import { Chat } from '@telegraf/types';
import { TelegramMessage, TelegramUser } from '../types.js';

export interface TelegramServiceConfig {
  botToken: string;
  pollingTimeout?: number;
  webhookDomain?: string;
}

export interface SendMessageOptions {
  parse_mode?: 'HTML' | 'Markdown' | 'MarkdownV2';
  reply_to_message_id?: number;
  disable_web_page_preview?: boolean;
  disable_notification?: boolean;
}

export interface SendPhotoOptions {
  caption?: string;
  parse_mode?: 'HTML' | 'Markdown' | 'MarkdownV2';
  disable_notification?: boolean;
}

export interface RetryOptions {
  maxRetries?: number;
  baseDelay?: number;
  maxDelay?: number;
  retryableErrors?: number[];
}

/**
 * Low-level Telegram API service
 * Handles all direct interactions with Telegram API
 */
export class TelegramService {
  private bot: Telegraf;
  private defaultRetryOptions: RetryOptions = {
    maxRetries: 3,
    baseDelay: 1000,
    maxDelay: 10000,
    retryableErrors: [429, 500, 502, 503, 504],
  };

  constructor(private config: TelegramServiceConfig) {
    this.bot = new Telegraf(this.config.botToken);
  }

  /**
   * Generic retry wrapper for API calls
   */
  private async withRetry<T>(
    operation: () => Promise<T>,
    options: RetryOptions = {},
  ): Promise<T> {
    const opts = { ...this.defaultRetryOptions, ...options };
    let lastError: any;

    for (let attempt = 0; attempt <= opts.maxRetries!; attempt++) {
      try {
        return await operation();
      } catch (error: any) {
        lastError = error;

        // Don't retry on the last attempt
        if (attempt === opts.maxRetries) {
          break;
        }

        // Check if error is retryable
        const errorCode = error.response?.error_code || error.code;
        if (errorCode && !opts.retryableErrors!.includes(errorCode)) {
          break;
        }

        // Calculate delay with exponential backoff
        const delay = Math.min(
          opts.baseDelay! * Math.pow(2, attempt),
          opts.maxDelay!,
        );

        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }

    throw lastError;
  }

  /**
   * Type guard for TelegramUser
   */
  private isTelegramUser(obj: any): obj is TelegramUser {
    return (
      typeof obj === 'object' &&
      obj !== null &&
      typeof obj.id === 'number' &&
      typeof obj.is_bot === 'boolean' &&
      typeof obj.first_name === 'string'
    );
  }

  /**
   * Type guard for TelegramMessage
   */
  private isTelegramMessage(obj: any): obj is TelegramMessage {
    return (
      typeof obj === 'object' &&
      obj !== null &&
      typeof obj.message_id === 'number' &&
      typeof obj.date === 'number' &&
      typeof obj.chat === 'object' &&
      obj.chat !== null &&
      typeof obj.chat.id === 'number'
    );
  }

  /**
   * Type guard for Updates array
   */
  private isValidUpdatesArray(
    obj: any,
  ): obj is Array<{ update_id: number; message?: TelegramMessage }> {
    return (
      Array.isArray(obj) &&
      obj.every(
        (update) =>
          typeof update === 'object' &&
          update !== null &&
          typeof update.update_id === 'number' &&
          (update.message === undefined ||
            this.isTelegramMessage(update.message)),
      )
    );
  }

  /**
   * Send text message
   */
  async sendMessage(
    chatId: string | number,
    text: string,
    options?: SendMessageOptions,
  ): Promise<TelegramMessage> {
    return this.withRetry(async () => {
      const response = await this.bot.telegram.sendMessage(
        chatId,
        text,
        options,
      );
      if (!this.isTelegramMessage(response)) {
        throw new Error('Invalid response format from sendMessage API');
      }
      return response;
    });
  }

  /**
   * Send photo
   */
  async sendPhoto(
    chatId: string | number,
    photo: string,
    options?: SendPhotoOptions,
  ): Promise<TelegramMessage> {
    return this.withRetry(async () => {
      const response = await this.bot.telegram.sendPhoto(
        chatId,
        photo,
        options,
      );
      if (!this.isTelegramMessage(response)) {
        throw new Error('Invalid response format from sendPhoto API');
      }
      return response;
    });
  }

  /**
   * Send document
   */
  async sendDocument(
    chatId: string | number,
    document: string,
    options?: { caption?: string },
  ): Promise<TelegramMessage> {
    return this.withRetry(async () => {
      const response = await this.bot.telegram.sendDocument(
        chatId,
        document,
        options,
      );
      if (!this.isTelegramMessage(response)) {
        throw new Error('Invalid response format from sendDocument API');
      }
      return response;
    });
  }

  /**
   * Get chat info
   */
  async getChat(chatId: string | number): Promise<Chat> {
    return this.withRetry(async () => {
      return await this.bot.telegram.getChat(chatId);
    });
  }

  /**
   * Get updates
   */
  async getUpdates(options?: {
    offset?: number;
    limit?: number;
    timeout?: number;
  }): Promise<Array<{ update_id: number; message?: TelegramMessage }>> {
    return this.withRetry(async () => {
      const response = await this.bot.telegram.callApi('getUpdates', {
        offset: options?.offset,
        limit: options?.limit,
        timeout: options?.timeout || this.config.pollingTimeout,
      });
      if (!this.isValidUpdatesArray(response)) {
        throw new Error('Invalid response format from getUpdates API');
      }
      return response;
    });
  }

  /**
   * Get bot info
   */
  async getBotInfo(): Promise<TelegramUser> {
    return this.withRetry(async () => {
      const response = await this.bot.telegram.getMe();
      if (!this.isTelegramUser(response)) {
        throw new Error('Invalid response format from getMe API');
      }
      return response;
    });
  }

  /**
   * 設定 Webhook
   */
  async setWebhook(url: string, options?: any) {
    return await this.bot.telegram.setWebhook(url, options);
  }

  /**
   * 刪除 Webhook
   */
  async deleteWebhook() {
    return await this.bot.telegram.deleteWebhook();
  }

  /**
   * 取得 Telegraf 實例（用於進階功能）
   */
  getTelegrafInstance(): Telegraf {
    return this.bot;
  }
}
