export interface TelegramConfig {
  botToken: string;
  defaultChatId?: string;
  allowedChatIds: string[];
}

// Telegram API Response Types
export interface TelegramUser {
  id: number;
  is_bot: boolean;
  first_name: string;
  last_name?: string;
  username?: string;
  language_code?: string;
}

export interface TelegramChat {
  id: number;
  type: 'private' | 'group' | 'supergroup' | 'channel';
  title?: string;
  username?: string;
  first_name?: string;
  last_name?: string;
}

export interface TelegramMessage {
  message_id: number;
  from?: TelegramUser;
  date: number;
  chat: TelegramChat;
  text?: string;
  caption?: string;
  photo?: Array<{
    file_id: string;
    file_unique_id: string;
    width: number;
    height: number;
    file_size?: number;
  }>;
}

export interface TelegramSendMessageResponse {
  ok: boolean;
  result?: TelegramMessage;
  error_code?: number;
  description?: string;
}

export interface TelegramGetUpdatesResponse {
  ok: boolean;
  result?: Array<{
    update_id: number;
    message?: TelegramMessage;
  }>;
  error_code?: number;
  description?: string;
}

// Message record for bot's internal message tracking
export interface MessageRecord {
  id: number;
  chatId: number;
  text: string;
  from: {
    id: number;
    username?: string;
    first_name: string;
  };
  date: Date;
}
