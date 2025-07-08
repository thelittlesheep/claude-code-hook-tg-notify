import { Telegraf } from 'telegraf';
import { TelegramMessage } from './types.js';

export class TelegramBotManager {
  private bot: Telegraf;

  constructor(botToken: string) {
    this.bot = new Telegraf(botToken);
  }

  async sendMessage(
    chatId: string | number,
    text: string,
    options?: any,
  ): Promise<TelegramMessage> {
    return (await this.bot.telegram.sendMessage(
      chatId,
      text,
      options,
    )) as TelegramMessage;
  }

  async start(): Promise<void> {
    try {
      await this.bot.launch();
      console.log('Telegram bot started successfully');
    } catch (error) {
      console.error('Failed to start Telegram bot:', error);
      throw error;
    }
  }

  stop() {
    this.bot.stop();
  }
}
