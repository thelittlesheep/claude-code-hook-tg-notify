// 匯出所有錯誤類別
export * from './base-error.js';
export * from './telegram-errors.js';
export * from './validation-errors.js';

// 錯誤工廠函數
import { BaseError, GenericError } from './base-error.js';
import { TelegramAPIError, MessageSendError } from './telegram-errors.js';
import { ValidationError, RequiredFieldError } from './validation-errors.js';

export class ErrorFactory {
  /**
   * 從 Telegram API 錯誤創建適當的錯誤實例
   */
  static fromTelegramError(
    error: any,
    context?: Record<string, any>,
  ): BaseError {
    const message =
      error.message || error.description || '未知的 Telegram API 錯誤';
    const code = error.error_code || error.code;

    if (code === 400) {
      return new ValidationError(message, undefined, undefined, context);
    } else if (code === 401) {
      return new TelegramAPIError('Bot Token 無效', code, context);
    } else if (code === 403) {
      return new TelegramAPIError('Bot 權限不足', code, context);
    } else if (code === 404) {
      return new TelegramAPIError('聊天室或訊息不存在', code, context);
    } else if (code === 429) {
      return new TelegramAPIError('請求過於頻繁', code, context);
    } else {
      return new TelegramAPIError(message, code, context);
    }
  }

  /**
   * 從一般錯誤創建適當的錯誤實例
   */
  static fromError(error: Error, context?: Record<string, any>): BaseError {
    if (error instanceof BaseError) {
      return error;
    }

    // 嘗試根據錯誤訊息判斷錯誤類型
    const message = error.message.toLowerCase();

    if (message.includes('required') || message.includes('missing')) {
      return new RequiredFieldError('unknown', context);
    }

    if (message.includes('telegram') || message.includes('bot')) {
      return new TelegramAPIError(error.message, undefined, context, error);
    }

    // 預設為一般錯誤
    return new GenericError(error.message, context, error);
  }

  /**
   * 創建驗證錯誤
   */
  static createValidationError(
    field: string,
    message: string,
    value?: any,
    context?: Record<string, any>,
  ): ValidationError {
    return new ValidationError(message, field, value, context);
  }
}
