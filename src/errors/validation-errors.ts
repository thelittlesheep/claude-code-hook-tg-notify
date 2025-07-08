import { BaseError, ErrorCategory } from './base-error.js';

/**
 * 驗證錯誤基礎類別
 */
export class ValidationError extends BaseError {
  get code() {
    return 'VALIDATION_ERROR';
  }
  readonly category = ErrorCategory.VALIDATION;

  constructor(
    message: string,
    public readonly field?: string,
    public readonly value?: any,
    context?: Record<string, any>,
  ) {
    super(message, { ...context, field, value });
  }

  isRetryable(): boolean {
    return false; // 驗證錯誤不可重試
  }
}

/**
 * 必要參數缺失錯誤
 */
export class RequiredFieldError extends ValidationError {
  get code() {
    return 'REQUIRED_FIELD_ERROR';
  }

  constructor(field: string, context?: Record<string, any>) {
    super(`缺少必要參數：${field}`, field, undefined, context);
  }
}

/**
 * 參數類型錯誤
 */
export class InvalidTypeError extends ValidationError {
  get code() {
    return 'INVALID_TYPE_ERROR';
  }

  constructor(
    field: string,
    expectedType: string,
    actualValue: any,
    context?: Record<string, any>,
  ) {
    super(
      `參數 ${field} 類型錯誤，期望 ${expectedType}，實際收到 ${typeof actualValue}`,
      field,
      actualValue,
      { ...context, expectedType, actualType: typeof actualValue },
    );
  }
}

/**
 * 參數值超出範圍錯誤
 */
export class ValueOutOfRangeError extends ValidationError {
  get code() {
    return 'VALUE_OUT_OF_RANGE_ERROR';
  }

  constructor(
    field: string,
    value: any,
    min?: number,
    max?: number,
    context?: Record<string, any>,
  ) {
    const rangeText =
      min !== undefined && max !== undefined
        ? `${min} 到 ${max}`
        : min !== undefined
          ? `大於等於 ${min}`
          : `小於等於 ${max}`;

    super(
      `參數 ${field} 的值 ${value} 超出有效範圍：${rangeText}`,
      field,
      value,
      { ...context, min, max },
    );
  }
}

/**
 * 無效格式錯誤
 */
export class InvalidFormatError extends ValidationError {
  get code() {
    return 'INVALID_FORMAT_ERROR';
  }

  constructor(
    field: string,
    value: any,
    expectedFormat: string,
    context?: Record<string, any>,
  ) {
    super(`參數 ${field} 格式錯誤，期望格式：${expectedFormat}`, field, value, {
      ...context,
      expectedFormat,
    });
  }
}

/**
 * 聊天室 ID 驗證錯誤
 */
export class InvalidChatIdError extends ValidationError {
  get code() {
    return 'INVALID_CHAT_ID_ERROR';
  }

  constructor(chatId: any, context?: Record<string, any>) {
    super(
      `無效的聊天室 ID：${chatId}。聊天室 ID 必須是數字或以 '@' 開頭的字串`,
      'chatId',
      chatId,
      context,
    );
  }
}
