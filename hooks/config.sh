#!/usr/bin/env bash

# Configuration file for Telegram Notification Hooks
# This file contains all configurable settings for the notification system

# ============================================================================
# PATHS AND DIRECTORIES
# ============================================================================

# Detect script directory for relative path resolution
CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Telegram Bot CLI path (will be set during installation by init.sh)
TELEGRAM_BOT_CLI=""

# Project directory path (dynamically detected)
# Try to find the project root from TELEGRAM_BOT_CLI path
find_project_dir() {
  # If TELEGRAM_BOT_CLI is set and file exists, derive project directory from it
  if [ -n "$TELEGRAM_BOT_CLI" ] && [ -f "$TELEGRAM_BOT_CLI" ]; then
    # From /path/to/project/dist/index.js derive /path/to/project
    echo "$(dirname "$(dirname "$TELEGRAM_BOT_CLI")")"
    return 0
  fi
  
  # Fallback: try to find the project root by looking for package.json
  local current_dir="$CONFIG_SCRIPT_DIR"
  while [ "$current_dir" != "/" ]; do
    if [ -f "$current_dir/package.json" ] && [ -f "$current_dir/dist/index.js" ]; then
      echo "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done
  
  # Final fallback to parent of config directory
  echo "$(dirname "$CONFIG_SCRIPT_DIR")"
}

PROJECT_DIR="$(find_project_dir)"

# Claude Projects directory
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"

# ============================================================================
# MESSAGE CONFIGURATION
# ============================================================================

# Telegram message length limits
TELEGRAM_MAX_MESSAGE_LENGTH=4096
TELEGRAM_SAFE_MESSAGE_LENGTH=4000
TELEGRAM_CONTENT_TRUNCATE_LENGTH=3000

# User input processing settings
USER_INPUT_TRUNCATE_LENGTH=100
USER_INPUT_DEFAULT_LIMIT=10

# ============================================================================
# FORMATTING SETTINGS
# ============================================================================

# Default format for data extraction
DEFAULT_EXTRACT_FORMAT="basic"

# Message templates
NOTIFICATION_EMOJI="🔔"
STOP_EMOJI="🛑"
PROJECT_EMOJI="📁"
SESSION_EMOJI="🔑"
TIME_EMOJI="⏰"
MESSAGE_EMOJI="💬"
USER_EMOJI="👤"
WARNING_EMOJI="⚠️"

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Default fallback values
DEFAULT_PROJECT_NAME="unknown"
DEFAULT_SESSION_ID="unknown"
DEFAULT_MESSAGE="無訊息"
DEFAULT_USER_INPUT="無使用者輸入"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to load configuration (can be sourced by other scripts)
load_config() {
  # Get Telegram Bot CLI path
  local cli_path
  cli_path=$(get_telegram_bot_cli)
  if [ $? -ne 0 ]; then
    return 1
  fi

  # Validate Claude Projects directory
  if [ ! -d "$CLAUDE_PROJECTS_DIR" ]; then
    echo "Warning: Claude Projects directory not found at $CLAUDE_PROJECTS_DIR" >&2
    # This is just a warning, not a failure
  fi

  return 0
}

# Function to get telegram bot CLI path
get_telegram_bot_cli() {
  # If TELEGRAM_BOT_CLI is not set, try to find it
  if [ -z "$TELEGRAM_BOT_CLI" ] || [ ! -f "$TELEGRAM_BOT_CLI" ]; then
    local potential_cli="$PROJECT_DIR/dist/index.js"
    if [ -f "$potential_cli" ]; then
      TELEGRAM_BOT_CLI="$potential_cli"
    else
      echo "Error: Telegram Bot CLI not found" >&2
      return 1
    fi
  fi
  echo "$TELEGRAM_BOT_CLI"
}

# Function to get project directory path
get_project_dir() {
  echo "$PROJECT_DIR"
}

# Function to validate message length
validate_message_length() {
  local message="$1"
  local max_length=${2:-$TELEGRAM_SAFE_MESSAGE_LENGTH}

  if [ ${#message} -gt $max_length ]; then
    return 1
  fi
  return 0
}

# Function to truncate message if too long
truncate_message() {
  local message="$1"
  local max_length=${2:-$TELEGRAM_SAFE_MESSAGE_LENGTH}

  if [ ${#message} -gt $max_length ]; then
    echo "${message:0:$max_length}..."
  else
    echo "$message"
  fi
}
