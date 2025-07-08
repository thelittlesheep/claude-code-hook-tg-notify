#!/usr/bin/env bash

# Telegram Stop Hook for Claude Code

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

# Extract project name and user inputs using unified script (show only first user input)
enriched_data=$(echo "$input" | "$EXTRACT_ENRICHED_DATA_SCRIPT" --format=basic --limit=1 --include-multiline)

# Check if enriched data was successfully generated
if [ $? -ne 0 ] || [ -z "$enriched_data" ]; then
  # Fallback: validate original input and create minimal valid JSON structure
  if echo "$input" | jq . >/dev/null 2>&1; then
    # Original input is valid JSON, use it as base and ensure required fields exist
    enriched_data=$(
      echo "$input" | jq --arg default_project "$DEFAULT_PROJECT_NAME" --arg default_session "$DEFAULT_SESSION_ID" --arg default_user_input "$DEFAULT_USER_INPUT" '
      {
        project_name: (.project_name // $default_project),
        session_id: (.session_id // $default_session),
        user_inputs: (.user_inputs // $default_user_input)
      } + .'
    )
  else
    # Original input is not valid JSON, create minimal structure with defaults
    enriched_data=$(
      jq -n --arg default_project "$DEFAULT_PROJECT_NAME" --arg default_session "$DEFAULT_SESSION_ID" --arg default_user_input "$DEFAULT_USER_INPUT" '
      {
        project_name: $default_project,
        session_id: $default_session,
        user_inputs: $default_user_input
      }'
    )
  fi
fi

# Create structured static message from JSON data
project_name=$(echo "$enriched_data" | jq -r ".project_name // \"$DEFAULT_PROJECT_NAME\"")
session_id=$(echo "$enriched_data" | jq -r ".session_id // \"$DEFAULT_SESSION_ID\"")
user_inputs=$(echo "$enriched_data" | jq -r ".user_inputs // \"$DEFAULT_USER_INPUT\"")

# Format user inputs - use as is if available, otherwise use default
if [ "$user_inputs" != "$DEFAULT_USER_INPUT" ] && [ -n "$user_inputs" ]; then
  formatted_inputs="$user_inputs"
else
  formatted_inputs="$DEFAULT_USER_INPUT"
fi

# Create structured message template
stop_message="
$STOP_EMOJI Claude Code 停止通知
$PROJECT_EMOJI 專案: $project_name
$SESSION_EMOJI 會話: $session_id
$TIME_EMOJI 時間: $timestamp
$USER_EMOJI 本次會話首句輸入：
$formatted_inputs"

# Validate and truncate message if necessary
if ! validate_message_length "$stop_message"; then
  stop_message=$(truncate_message "$stop_message")
fi

# Send message via Telegram bot
(cd "$PROJECT_DIR" && node "$TELEGRAM_BOT_CLI" --send-message "$stop_message")

# Log the result
if [ $? -eq 0 ]; then
  log_success "Telegram stop notification sent successfully"
else
  log_error "Failed to send Telegram stop notification"
  exit 1
fi
