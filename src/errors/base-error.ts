/**
 * 基礎錯誤類別
 * 提供錯誤的分類和結構化處理
 */
export abstract class BaseError extends Error {
  abstract get code(): string;
  abstract readonly category: ErrorCategory;
  readonly timestamp: Date;
  readonly context?: Record<string, any>;

  constructor(message: string, context?: Record<string, any>, cause?: Error) {
    super(message);
    this.name = this.constructor.name;
    this.timestamp = new Date();
    this.context = context;

    if (cause) {
      this.stack += '\n\nCaused by: ' + cause.stack;
    }

    // 確保 stack trace 正確
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }

  /**
   * 轉換為 JSON 格式
   */
  toJSON() {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      category: this.category,
      timestamp: this.timestamp.toISOString(),
      context: this.context,
      stack: this.stack,
    };
  }

  /**
   * 是否為可重試的錯誤
   */
  abstract isRetryable(): boolean;

  /**
   * 是否為客戶端錯誤
   */
  isClientError(): boolean {
    return this.category === ErrorCategory.CLIENT;
  }

  /**
   * 是否為伺服器錯誤
   */
  isServerError(): boolean {
    return this.category === ErrorCategory.SERVER;
  }
}

export enum ErrorCategory {
  CLIENT = 'CLIENT', // 客戶端錯誤（400-499）
  SERVER = 'SERVER', // 伺服器錯誤（500-599）
  NETWORK = 'NETWORK', // 網路錯誤
  VALIDATION = 'VALIDATION', // 驗證錯誤
  BUSINESS = 'BUSINESS', // 業務邏輯錯誤
  SYSTEM = 'SYSTEM', // 系統錯誤
}

/**
 * 通用錯誤類別
 * 用於處理無法歸類到其他錯誤類型的一般錯誤
 */
export class GenericError extends BaseError {
  get code() {
    return 'GENERIC_ERROR';
  }
  readonly category = ErrorCategory.SYSTEM;

  isRetryable(): boolean {
    return false;
  }
}
