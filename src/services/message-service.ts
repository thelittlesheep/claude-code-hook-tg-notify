import { TelegramService } from './telegram-service.js';
import { environmentConfig } from '../config/environment.js';

export interface MessageServiceConfig {
  maxHistorySize: number;
  defaultChatId?: string;
}

/**
 * 訊息服務
 * 處理訊息相關的業務邏輯
 */
export class MessageService {
  constructor(private telegramService: TelegramService) {}

  /**
   * Send text message
   */
  async sendTextMessage(
    chatId: string | number | undefined,
    text: string,
    options?: {
      parseMode?: 'HTML' | 'Markdown' | 'MarkdownV2';
      replyToMessageId?: number;
    },
  ) {
    const validatedChatId = environmentConfig.validateChatId(
      chatId?.toString(),
    );

    const result = await this.telegramService.sendMessage(
      validatedChatId,
      text,
      {
        parse_mode: options?.parseMode,
        reply_to_message_id: options?.replyToMessageId,
      },
    );

    return result;
  }
}
