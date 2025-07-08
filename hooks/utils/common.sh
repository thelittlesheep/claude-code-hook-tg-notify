#!/usr/bin/env bash

# Common utility functions for Telegram notification hooks
# This file contains shared functions used by both notification and stop hooks

# ============================================================================
# BASH VERSION CHECK
# ============================================================================

# Check bash version for compatibility
BASH_MAJOR_VERSION=${BASH_VERSION%%.*}
if [ "$BASH_MAJOR_VERSION" -lt 3 ]; then
  echo "Error: This script requires bash 3.0 or higher. Current version: $BASH_VERSION" >&2
  exit 1
fi

# ============================================================================
# INITIALIZATION AND CONFIGURATION
# ============================================================================

# Enable strict error handling
set -euo pipefail

# Platform detection
is_macos() {
  case "$OSTYPE" in
    darwin*) return 0 ;;
    *) return 1 ;;
  esac
}

is_linux() {
  case "$OSTYPE" in
    linux-gnu*) return 0 ;;
    *) return 1 ;;
  esac
}

# Cross-platform compatibility functions
get_realpath() {
  if command -v realpath &>/dev/null; then
    realpath "$1"
  elif command -v greadlink &>/dev/null; then
    greadlink -f "$1"
  else
    # Fallback for systems without realpath
    python -c "import os; print(os.path.realpath('$1'))"
  fi
}

# Load configuration from the parent directory
COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$(dirname "$COMMON_SCRIPT_DIR")/config.sh"

if [ -f "$CONFIG_PATH" ]; then
  source "$CONFIG_PATH"
else
  echo "Error: config.sh not found at $CONFIG_PATH" >&2
  exit 1
fi

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Current log level (can be overridden by environment variable)
CURRENT_LOG_LEVEL=${TELEGRAM_HOOK_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Function to get timestamp (cross-platform)
get_timestamp() {
  if is_macos; then
    # macOS date command
    date "+%Y-%m-%d %H:%M:%S"
  else
    # GNU date (Linux)
    date "+%Y-%m-%d %H:%M:%S"
  fi
}

# Function to log messages with different levels
log_message() {
  local level=$1
  local message=$2
  local timestamp=$(get_timestamp)

  case $level in
    $LOG_LEVEL_DEBUG)
      [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ] && echo "[$timestamp] [DEBUG] $message" >&2
      ;;
    $LOG_LEVEL_INFO)
      [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ] && echo "[$timestamp] [INFO] $message" >&2
      ;;
    $LOG_LEVEL_WARN)
      [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ] && echo "[$timestamp] [WARN] $message" >&2
      ;;
    $LOG_LEVEL_ERROR)
      [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ] && echo "[$timestamp] [ERROR] $message" >&2
      ;;
  esac
}

log_debug() {
  log_message $LOG_LEVEL_DEBUG "$1"
}

log_info() {
  log_message $LOG_LEVEL_INFO "$1"
}

log_warn() {
  log_message $LOG_LEVEL_WARN "$1"
}

log_error() {
  log_message $LOG_LEVEL_ERROR "$1"
}

log_success() {
  log_message $LOG_LEVEL_INFO "[SUCCESS] $1"
}

# Function to validate dependencies
validate_dependencies() {
  local deps=("node" "jq")
  local missing_deps=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    log_error "Missing dependencies: ${missing_deps[*]}"
    log_error "Please install the missing dependencies before running this script"
    return 1
  fi

  return 0
}

# Function to validate and sanitize paths
validate_path() {
  local path="$1"
  local path_type="${2:-file}" # file or directory

  # Check for path traversal attempts
  case "$path" in
    *..*)
      log_error "Invalid path: potential directory traversal detected"
      return 1
      ;;
  esac

  # Check if path exists
  if [ "$path_type" = "file" ]; then
    if [ ! -f "$path" ]; then
      log_error "File not found: $path"
      return 1
    fi
  elif [ "$path_type" = "directory" ]; then
    if [ ! -d "$path" ]; then
      log_error "Directory not found: $path"
      return 1
    fi
  fi

  # Ensure path is absolute for security
  case "$path" in
    /*)
      # Path is absolute, good
      ;;
    *)
      log_warn "Path is not absolute: $path"
      ;;
  esac

  return 0
}

# Function to safely execute commands
safe_execute() {
  local command="$1"
  local description="$2"

  log_debug "Executing: $description"

  local output
  local exit_code

  output=$(eval "$command" 2>&1)
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to $description: $output"
    return $exit_code
  fi

  echo "$output"
  return 0
}

# ============================================================================
# DATA EXTRACTION AND PROCESSING
# ============================================================================

# Function to extract enriched data with robust error handling
extract_enriched_data_with_fallback() {
  local input="$1"
  local format_args="$2"

  log_debug "Extracting enriched data with args: $format_args"

  # Extract data using the unified script
  local enriched_data
  enriched_data=$(echo "$input" | "$EXTRACT_ENRICHED_DATA_SCRIPT" $format_args 2>&1) || {
    log_warn "Failed to extract enriched data: $enriched_data"
    enriched_data=""
  }

  # Check if enriched data was successfully generated
  if [ -z "$enriched_data" ]; then
    log_info "Using fallback for enriched data extraction"
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

  echo "$enriched_data"
}

# Function to extract JSON fields with fallback values
extract_json_field() {
  local data="$1"
  local field="$2"
  local default_value="$3"

  echo "$data" | jq -r ".${field} // \"$default_value\""
}

# Function to extract standard fields from enriched data
extract_standard_fields() {
  local enriched_data="$1"

  # Extract standard fields
  PROJECT_NAME=$(extract_json_field "$enriched_data" "project_name" "$DEFAULT_PROJECT_NAME")
  SESSION_ID=$(extract_json_field "$enriched_data" "session_id" "$DEFAULT_SESSION_ID")
  MESSAGE=$(extract_json_field "$enriched_data" "message" "$DEFAULT_MESSAGE")
  USER_INPUTS=$(extract_json_field "$enriched_data" "user_inputs" "$DEFAULT_USER_INPUT")
}

# ============================================================================
# MESSAGE FORMATTING
# ============================================================================

# Function to format user inputs for display
format_user_inputs() {
  local user_inputs="$1"
  local default_input="$2"

  if [ "$user_inputs" != "$default_input" ] && [ -n "$user_inputs" ]; then
    echo "$user_inputs"
  else
    echo "$default_input"
  fi
}

# Function to create notification message
create_notification_message() {
  local project_name="$1"
  local session_id="$2"
  local timestamp="$3"
  local message="$4"
  local user_inputs="$5"

  cat <<EOF
$NOTIFICATION_EMOJI Claude Code 通知
$PROJECT_EMOJI 專案: $project_name
$SESSION_EMOJI 會話: $session_id
$TIME_EMOJI 時間: $timestamp
$MESSAGE_EMOJI 訊息: $message
$USER_EMOJI 最近一次使用者輸入:
$user_inputs
EOF
}

# Function to create stop notification message
create_stop_message() {
  local project_name="$1"
  local session_id="$2"
  local timestamp="$3"
  local user_inputs="$4"

  cat <<EOF
$STOP_EMOJI Claude Code 停止通知
$PROJECT_EMOJI 專案: $project_name
$SESSION_EMOJI 會話: $session_id
$TIME_EMOJI 時間: $timestamp
$USER_EMOJI 本次會話首句輸入：
$user_inputs
EOF
}

# Function to create truncated stop message
create_truncated_stop_message() {
  local project_name="$1"
  local session_id="$2"
  local timestamp="$3"
  local truncated_inputs="$4"

  cat <<EOF
$STOP_EMOJI Claude Code 停止通知

$PROJECT_EMOJI 專案: $project_name
$SESSION_EMOJI 會話: $session_id
$TIME_EMOJI 時間: $timestamp

$USER_EMOJI 本次會話使用者輸入：
$truncated_inputs

$WARNING_EMOJI (訊息已截斷，完整內容請查看會話檔案)
EOF
}

# ============================================================================
# MESSAGE SENDING
# ============================================================================

# Function to send message via Telegram bot
send_telegram_message() {
  local message="$1"
  local message_type="$2"

  log_info "Sending $message_type to Telegram"

  # Validate message length
  if ! validate_message_length "$message"; then
    log_warn "Message too long, truncating"
    message=$(truncate_message "$message")
  fi

  # Send message with error capture
  local output
  local exit_code

  output=$(cd "$PROJECT_DIR" && node "$TELEGRAM_BOT_CLI" --send-message "$message" 2>&1)
  exit_code=$?

  if [ $exit_code -eq 0 ]; then
    log_success "$message_type sent successfully"
  else
    log_error "Failed to send $message_type: $output"
  fi

  # Return the exit code
  return $exit_code
}

# Function to handle stop message with potential truncation
send_stop_message_with_truncation() {
  local project_name="$1"
  local session_id="$2"
  local timestamp="$3"
  local formatted_inputs="$4"

  # Create initial message
  local stop_message=$(create_stop_message "$project_name" "$session_id" "$timestamp" "$formatted_inputs")

  # Check message length and truncate if necessary
  local message_length=${#stop_message}
  if [ $message_length -gt $TELEGRAM_SAFE_MESSAGE_LENGTH ]; then
    # Truncate the message if it's too long
    local truncated_inputs=$(echo "$formatted_inputs" | head -c $TELEGRAM_CONTENT_TRUNCATE_LENGTH)
    stop_message=$(create_truncated_stop_message "$project_name" "$session_id" "$timestamp" "$truncated_inputs")
  fi

  # Send the message
  send_telegram_message "$stop_message" "stop notification"
}

# ============================================================================
# MAIN WORKFLOW FUNCTIONS
# ============================================================================

# Function to process notification hook
process_notification_hook() {
  local input="$1"
  local script_dir="$2"

  # Initialize environment
  init_hook_environment "$script_dir"

  # Extract enriched data
  local enriched_data=$(extract_enriched_data_with_fallback "$input" "--format=basic --limit=1 --reverse --include-multiline")

  # Extract standard fields
  extract_standard_fields "$enriched_data"

  # Format user inputs
  local formatted_inputs=$(format_user_inputs "$USER_INPUTS" "$DEFAULT_USER_INPUT")

  # Create and send notification message
  local notification_message=$(create_notification_message "$PROJECT_NAME" "$SESSION_ID" "$TIMESTAMP" "$MESSAGE" "$formatted_inputs")
  send_telegram_message "$notification_message" "notification"
}

# Function to process stop hook
process_stop_hook() {
  local input="$1"
  local script_dir="$2"

  # Initialize environment
  init_hook_environment "$script_dir"

  # Extract enriched data
  local enriched_data=$(extract_enriched_data_with_fallback "$input" "--format=basic --limit=1 --include-multiline")

  # Extract standard fields
  extract_standard_fields "$enriched_data"

  # Format user inputs
  local formatted_inputs=$(format_user_inputs "$USER_INPUTS" "$DEFAULT_USER_INPUT")

  # Send stop message with truncation handling
  send_stop_message_with_truncation "$PROJECT_NAME" "$SESSION_ID" "$TIMESTAMP" "$formatted_inputs"
}

# Function to initialize hook environment
init_hook_environment() {
  local script_dir="$1"

  # Validate script directory
  if ! validate_path "$script_dir" "directory"; then
    exit 1
  fi

  # Load configuration and validate
  if ! load_config; then
    log_error "Failed to load configuration"
    exit 1
  fi

  # Set up global variables with validation
  TELEGRAM_BOT_CLI="$(get_telegram_bot_cli)" || exit 1
  PROJECT_DIR="$(get_project_dir)" || exit 1
  EXTRACT_ENRICHED_DATA_SCRIPT="$script_dir/utils/extract-enriched-data.sh"

  # Validate critical paths
  if ! validate_path "$TELEGRAM_BOT_CLI" "file"; then
    exit 1
  fi

  if ! validate_path "$PROJECT_DIR" "directory"; then
    exit 1
  fi

  if ! validate_path "$EXTRACT_ENRICHED_DATA_SCRIPT" "file"; then
    exit 1
  fi

  # Add timestamp
  TIMESTAMP=$(get_timestamp)
}
