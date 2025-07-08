import { BaseError, ErrorCategory } from './base-error.js';

/**
 * Telegram API 相關錯誤
 */
export class TelegramAPIError extends BaseError {
  get code() {
    return 'TELEGRAM_API_ERROR';
  }
  readonly category = ErrorCategory.SERVER;

  constructor(
    message: string,
    public readonly apiCode?: number,
    context?: Record<string, any>,
    cause?: Error,
  ) {
    super(message, { ...context, apiCode }, cause);
  }

  isRetryable(): boolean {
    // 某些 API 錯誤碼是可重試的（如速率限制）
    return this.apiCode === 429 || this.apiCode === 500 || this.apiCode === 502;
  }
}

/**
 * 訊息發送錯誤
 */
export class MessageSendError extends BaseError {
  get code() {
    return 'MESSAGE_SEND_ERROR';
  }
  readonly category = ErrorCategory.BUSINESS;

  constructor(
    message: string,
    public readonly chatId: string | number,
    context?: Record<string, any>,
    cause?: Error,
  ) {
    super(message, { ...context, chatId }, cause);
  }

  isRetryable(): boolean {
    return false; // 訊息發送錯誤通常不可重試
  }
}

/**
 * Bot 權限錯誤
 */
export class BotPermissionError extends BaseError {
  get code() {
    return 'BOT_PERMISSION_ERROR';
  }
  readonly category = ErrorCategory.CLIENT;

  constructor(
    message: string,
    public readonly permission: string,
    context?: Record<string, any>,
  ) {
    super(message, { ...context, permission });
  }

  isRetryable(): boolean {
    return false; // 權限錯誤不可重試
  }
}

/**
 * 聊天室不存在錯誤
 */
export class ChatNotFoundError extends BaseError {
  get code() {
    return 'CHAT_NOT_FOUND';
  }
  readonly category = ErrorCategory.CLIENT;

  constructor(
    public readonly chatId: string | number,
    context?: Record<string, any>,
  ) {
    super(`找不到聊天室：${chatId}`, { ...context, chatId });
  }

  isRetryable(): boolean {
    return false; // 聊天室不存在不可重試
  }
}

/**
 * Bot Token 無效錯誤
 */
export class InvalidBotTokenError extends BaseError {
  get code() {
    return 'INVALID_BOT_TOKEN';
  }
  readonly category = ErrorCategory.CLIENT;

  constructor(context?: Record<string, any>) {
    super('Bot Token 無效或已過期', context);
  }

  isRetryable(): boolean {
    return false; // Token 無效不可重試
  }
}
