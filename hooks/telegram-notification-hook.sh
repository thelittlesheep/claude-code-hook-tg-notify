#!/usr/bin/env bash

# Telegram Notification Hook for Claude Code

# Load common utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/utils/common.sh"

# Load configuration and validate
if ! load_config; then
  log_error "Failed to load configuration"
  exit 1
fi

# Validate dependencies
if ! validate_dependencies; then
  exit 1
fi

# Set up paths
TELEGRAM_BOT_CLI="$(get_telegram_bot_cli)"
PROJECT_DIR="$(get_project_dir)"
EXTRACT_ENRICHED_DATA_SCRIPT="$SCRIPT_DIR/utils/extract-enriched-data.sh"

# Read JSON data from stdin
input=$(cat)

# Add timestamp
timestamp=$(get_timestamp)

# Extract project name and user inputs using unified script
enriched_data=$(echo "$input" | "$EXTRACT_ENRICHED_DATA_SCRIPT" --format=basic --limit=1 --reverse --include-multiline)

# Check if enriched data was successfully generated
if [ $? -ne 0 ] || [ -z "$enriched_data" ]; then
  # Fallback: validate original input and create minimal valid JSON structure
  if echo "$input" | jq . >/dev/null 2>&1; then
    # Original input is valid JSON, use it as base and ensure required fields exist
    enriched_data=$(
      echo "$input" | jq --arg default_project "$DEFAULT_PROJECT_NAME" --arg default_session "$DEFAULT_SESSION_ID" --arg default_message "$DEFAULT_MESSAGE" --arg default_user_input "$DEFAULT_USER_INPUT" '
      {
        project_name: (.project_name // $default_project),
        session_id: (.session_id // $default_session),
        message: (.message // $default_message),
        user_inputs: (.user_inputs // $default_user_input)
      } + .'
    )
  else
    # Original input is not valid JSON, create minimal structure with defaults
    enriched_data=$(
      jq -n --arg default_project "$DEFAULT_PROJECT_NAME" --arg default_session "$DEFAULT_SESSION_ID" --arg default_message "$DEFAULT_MESSAGE" --arg default_user_input "$DEFAULT_USER_INPUT" '
      {
        project_name: $default_project,
        session_id: $default_session,
        message: $default_message,
        user_inputs: $default_user_input
      }'
    )
  fi
fi

# Create structured static message from JSON data
project_name=$(echo "$enriched_data" | jq -r ".project_name // \"$DEFAULT_PROJECT_NAME\"")
message=$(echo "$enriched_data" | jq -r ".message // \"$DEFAULT_MESSAGE\"")
session_id=$(echo "$enriched_data" | jq -r ".session_id // \"$DEFAULT_SESSION_ID\"")
last_user_input=$(echo "$enriched_data" | jq -r ".user_inputs // \"$DEFAULT_USER_INPUT\"")

# Create structured message template
notification_message="
$NOTIFICATION_EMOJI Claude Code 通知
$PROJECT_EMOJI 專案: $project_name
$SESSION_EMOJI 會話: $session_id
$TIME_EMOJI 時間: $timestamp
$MESSAGE_EMOJI 訊息: $message
$USER_EMOJI 最近一次使用者輸入:
$last_user_input"

# Validate and send message via Telegram bot
# Validate message length
if ! validate_message_length "$notification_message"; then
  notification_message=$(truncate_message "$notification_message")
fi

# Send message
(cd "$PROJECT_DIR" && node "$TELEGRAM_BOT_CLI" --send-message "$notification_message")

# Log the result
if [ $? -eq 0 ]; then
  log_success "Telegram notification sent successfully"
else
  log_error "Failed to send Telegram notification"
  exit 1
fi
