import { CLIHandler } from './cli/cli-handler.js';
import { BaseError } from './errors/base-error.js';
import { ValidationError } from './errors/validation-errors.js';
import {
  TelegramAPIError,
  MessageSendError,
  BotPermissionError,
  ChatNotFoundError,
  InvalidBotTokenError,
} from './errors/telegram-errors.js';
import { environmentConfig } from './config/environment.js';

// Simple logging system
class Logger {
  static info(message: string, meta?: any) {
    console.log(
      `[INFO] ${new Date().toISOString()}: ${message}`,
      meta ? JSON.stringify(meta) : '',
    );
  }

  static error(message: string, error?: Error | any, meta?: any) {
    const errorMessage = error ? `: ${error.message}` : '';
    const stackTrace = error && error.stack ? `\n${error.stack}` : '';
    const metaInfo = meta ? `\n${JSON.stringify(meta, null, 2)}` : '';
    console.error(
      `[ERROR] ${new Date().toISOString()}: ${message}${errorMessage}${stackTrace}${metaInfo}`,
    );
  }

  static warn(message: string, meta?: any) {
    console.warn(
      `[WARN] ${new Date().toISOString()}: ${message}`,
      meta ? JSON.stringify(meta) : '',
    );
  }

  static debug(message: string, meta?: any) {
    if (process.env.NODE_ENV === 'development' || process.env.DEBUG) {
      console.debug(
        `[DEBUG] ${new Date().toISOString()}: ${message}`,
        meta ? JSON.stringify(meta) : '',
      );
    }
  }
}

// Error classification and handling
class ErrorHandler {
  static handleError(error: any): { exitCode: number; logMessage: string } {
    if (error instanceof ValidationError) {
      return {
        exitCode: 2,
        logMessage: `配置驗證失敗: ${error.message}`,
      };
    }

    if (error instanceof TelegramAPIError) {
      return {
        exitCode: 3,
        logMessage: `Telegram API error: ${error.message}`,
      };
    }

    if (error instanceof MessageSendError) {
      return {
        exitCode: 4,
        logMessage: `Message send failed: ${error.message}`,
      };
    }

    if (error instanceof BotPermissionError) {
      return {
        exitCode: 6,
        logMessage: `Bot permission error: ${error.message}`,
      };
    }

    if (error instanceof ChatNotFoundError) {
      return {
        exitCode: 7,
        logMessage: `Chat not found: ${error.message}`,
      };
    }

    if (error instanceof InvalidBotTokenError) {
      return {
        exitCode: 8,
        logMessage: `Invalid bot token: ${error.message}`,
      };
    }

    if (error instanceof BaseError) {
      return {
        exitCode: 5,
        logMessage: `應用程式錯誤: ${error.message}`,
      };
    }

    // 未知錯誤
    return {
      exitCode: 1,
      logMessage: `未知錯誤: ${error.message || error}`,
    };
  }
}

// Graceful shutdown handling
class GracefulShutdown {
  private static isShuttingDown = false;

  static setup() {
    process.on('SIGINT', () => this.handleSignal('SIGINT'));
    process.on('SIGTERM', () => this.handleSignal('SIGTERM'));
    process.on('uncaughtException', (error) => {
      Logger.error('未捕獲的異常', error);
      this.shutdown(1);
    });
    process.on('unhandledRejection', (reason, promise) => {
      Logger.error('未處理的 Promise 拒絕', reason, { promise });
      this.shutdown(1);
    });
  }

  private static handleSignal(signal: string) {
    if (this.isShuttingDown) {
      Logger.warn('已在關閉程序中，強制退出');
      process.exit(1);
    }

    Logger.info(`收到 ${signal} 信號，開始優雅關閉`);
    this.isShuttingDown = true;
    this.shutdown(0);
  }

  private static shutdown(exitCode: number) {
    const shutdownTimeout = environmentConfig.getShutdownTimeoutMs();
    setTimeout(() => {
      Logger.error('Shutdown timeout, forcing exit');
      process.exit(1);
    }, shutdownTimeout);

    process.exit(exitCode);
  }
}

// Pre-startup environment validation
async function validateEnvironment(): Promise<void> {
  Logger.debug('開始環境驗證');

  // Check required environment variables
  const requiredEnvVars = ['TELEGRAM_BOT_TOKEN'];
  const missingVars = requiredEnvVars.filter(
    (varName) => !process.env[varName],
  );

  if (missingVars.length > 0) {
    throw new ValidationError(`缺少必要的環境變數: ${missingVars.join(', ')}`);
  }

  // Check Node.js version
  const nodeVersion = process.version;
  const majorVersion = parseInt(nodeVersion.slice(1).split('.')[0]);
  if (majorVersion < 18) {
    Logger.warn(`建議使用 Node.js 18 或更高版本，目前版本: ${nodeVersion}`);
  }

  Logger.debug('環境驗證完成');
}

async function main() {
  try {
    // Setup graceful shutdown
    GracefulShutdown.setup();

    Logger.info('Telegram CLI Bot 啟動中...');

    // Validate environment settings
    await validateEnvironment();

    // Parse command line arguments
    const cliArgs = CLIHandler.parseArgs();
    Logger.debug('命令列參數解析完成', cliArgs);

    if (cliArgs.isCLIMode) {
      Logger.info('以 CLI 模式運行');
      await CLIHandler.runCLI(cliArgs);
      Logger.info('CLI 模式執行完成');
      return;
    }

    // If not in CLI mode, show usage instructions
    Logger.info('這是一個 CLI 工具，請使用 --send-message 參數發送訊息');
    Logger.info('使用範例：node dist/index.js --send-message "Hello World"');
    process.exit(0);
  } catch (error: any) {
    const { exitCode, logMessage } = ErrorHandler.handleError(error);
    Logger.error('應用程式啟動失敗', error, { exitCode });

    // In production, don't expose full error stack
    if (process.env.NODE_ENV === 'production') {
      console.error(logMessage);
    }

    process.exit(exitCode);
  }
}

// Application entry point
main().catch((error) => {
  Logger.error('main 函式發生未捕獲的錯誤', error);
  process.exit(1);
});
