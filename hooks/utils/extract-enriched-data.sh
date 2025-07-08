#!/usr/bin/env bash

# Unified Data Extraction Script for Claude Code (Refactored Version)
# This script combines the functionality of extract-project-name.sh and extract-user-inputs.sh
# into a single, more efficient and maintainable solution.
#
# Usage: echo '{"session_id": "abc123", "transcript_path": "/path/to/file"}' | ./extract-enriched-data-refactored.sh [OPTIONS]
#
# Options:
#   --format=basic|detailed|json (default: basic)
#   --limit=N (default: 10, 0 for all)
#   --reverse (show newest first)
#   --include-multiline (preserve multiline inputs as single entries)

# ============================================================================
# CONFIGURATION AND GLOBALS
# ============================================================================

# Default settings
format="basic"
limit=10
reverse=false
include_multiline=false

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
CONFIG_PATH="$(dirname "$SCRIPT_DIR")/config.sh"
if [ -f "$CONFIG_PATH" ]; then
  source "$CONFIG_PATH"
else
  echo "Error: config.sh not found at $CONFIG_PATH" >&2
  exit 1
fi

# Claude Projects directory
claude_projects_dir="$CLAUDE_PROJECTS_DIR"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function to validate JSON input
validate_json() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "Error: Empty input" >&2
    return 1
  fi

  if ! echo "$input" | jq . >/dev/null 2>&1; then
    echo "Error: Invalid JSON input" >&2
    return 1
  fi

  return 0
}

# Function to log warnings to stderr
log_warning() {
  echo "Warning: $1" >&2
}

# Function to log errors to stderr
log_error() {
  echo "Error: $1" >&2
}

# ============================================================================
# SESSION FILE RESOLUTION
# ============================================================================

# Cache directory for resolved session files (bash 3.2 compatible)
CACHE_DIR="${TMPDIR:-/tmp}/.claude_hook_cache"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Function to escape special characters for grep
escape_for_grep() {
  local string="$1"
  # Escape special regex characters: . * [ ] ^ $ \ + ? { } | ( )
  echo "$string" | sed 's/[.*[^$\\+?{}|()\\]/\\&/g'
}

# Function to extract project directory from transcript_path
extract_project_dir() {
  local transcript_path="$1"

  # Check if transcript_path is valid
  if [ -z "$transcript_path" ] || [ "$transcript_path" = "null" ]; then
    return 1
  fi

  # Get the parent directory (project directory)
  local project_dir=$(dirname "$transcript_path")

  # Validate that the project directory exists and is within claude_projects_dir
  if [ -d "$project_dir" ] && echo "$project_dir" | grep -q "^$claude_projects_dir/"; then
    echo "$project_dir"
    return 0
  fi

  return 1
}

# Function to find session file by session_id
find_session_file_by_id() {
  local session_id="$1"
  local search_dir="${2:-$claude_projects_dir}"

  # Check cache first (bash 3.2 compatible)
  local cache_key=$(echo "$session_id" | sed 's/[^a-zA-Z0-9_-]/_/g')
  local cache_file="$CACHE_DIR/session_${cache_key}.cache"

  if [ -f "$cache_file" ]; then
    local cached_file=$(cat "$cache_file" 2>/dev/null)
    if [ -n "$cached_file" ] && [ -f "$cached_file" ]; then
      echo "$cached_file"
      return 0
    fi
  fi

  # Check if session_id is valid and search directory exists
  if [ -z "$session_id" ] || [ "$session_id" = "null" ] || [ ! -d "$search_dir" ]; then
    if [ -n "$DEBUG" ]; then
      echo "[DEBUG] Invalid session_id or search_dir not found: session_id='$session_id', dir='$search_dir'" >&2
    fi
    return 1
  fi

  if [ -n "$DEBUG" ]; then
    echo "[DEBUG] Searching for session_id: '$session_id'" >&2
    echo "[DEBUG] In directory: '$search_dir'" >&2
  fi

  # Stage 1: Try filename-based search first (most efficient)
  local session_file=$(find "$search_dir" -name "${session_id}.jsonl" 2>/dev/null | head -1)

  if [ -n "$session_file" ] && [ -f "$session_file" ]; then
    if [ -n "$DEBUG" ]; then
      echo "[DEBUG] Found session file by filename: '$session_file'" >&2
    fi
    echo "$session_file"
    return 0
  fi

  # Stage 2: Fallback to content-based search (handles session reuse cases)
  # Escape special characters in session_id for grep
  local escaped_session_id=$(escape_for_grep "$session_id")

  # Use more flexible regex pattern that allows for spaces around colons
  local search_pattern="\"sessionId\"[[:space:]]*:[[:space:]]*\"$escaped_session_id\""

  if [ -n "$DEBUG" ]; then
    echo "[DEBUG] Using search pattern: '$search_pattern'" >&2
  fi

  # Use ripgrep if available for better performance
  if command -v rg &>/dev/null; then
    local matching_file=$(rg -l "$search_pattern" "$search_dir" --glob "*.jsonl" 2>/dev/null | head -1)
  else
    local matching_file=$(find "$search_dir" -name "*.jsonl" -exec grep -l "$search_pattern" {} \; 2>/dev/null | head -1)
  fi

  if [ -n "$matching_file" ] && [ -f "$matching_file" ]; then
    if [ -n "$DEBUG" ]; then
      echo "[DEBUG] Found session file by content search: '$matching_file'" >&2
    fi
    # Cache the result (bash 3.2 compatible)
    echo "$matching_file" >"$cache_file" 2>/dev/null || true
    echo "$matching_file"
    return 0
  fi

  if [ -n "$DEBUG" ]; then
    echo "[DEBUG] Session file not found. Searched in: '$search_dir'" >&2
    echo "[DEBUG] Pattern used: '$search_pattern'" >&2
  fi

  return 1
}

# Function to resolve session file path
resolve_session_file() {
  local session_id="$1"
  local transcript_path="$2"

  # Stage 1: Try transcript_path first (highest priority)
  if [ -n "$transcript_path" ] && [ "$transcript_path" != "null" ] && [ -f "$transcript_path" ]; then
    echo "$transcript_path"
    return 0
  fi

  # Stage 2: Try session_id search (both filename and content-based)
  if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
    local search_dir="$claude_projects_dir"

    # Optimization: Try to extract project directory from transcript_path for narrowed search
    local project_dir=$(extract_project_dir "$transcript_path")
    if [ $? -eq 0 ] && [ -n "$project_dir" ]; then
      search_dir="$project_dir"
      if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Using optimized search in project directory: '$search_dir'" >&2
      fi
    else
      if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Using full search in claude_projects_dir: '$search_dir'" >&2
      fi
    fi

    local resolved_file=$(find_session_file_by_id "$session_id" "$search_dir")
    if [ $? -eq 0 ] && [ -n "$resolved_file" ]; then
      echo "$resolved_file"
      return 0
    fi
  fi

  return 1
}

# ============================================================================
# PROJECT NAME EXTRACTION
# ============================================================================

# Function to extract project name from input
extract_project_name() {
  local input="$1"
  local project_name="unknown"

  # Extract session_id and transcript_path using jq
  local session_id=$(echo "$input" | jq -r '.session_id // empty')
  local transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

  # Resolve the session file
  local resolved_file=$(resolve_session_file "$session_id" "$transcript_path")

  if [ $? -eq 0 ] && [ -n "$resolved_file" ] && [ -f "$resolved_file" ]; then
    # Extract cwd from the resolved file
    local cwd_path=$(jq -r 'select(.cwd) | .cwd' "$resolved_file" 2>/dev/null | head -1)

    # If we found a cwd path, extract the project name from it
    if [ -n "$cwd_path" ] && [ "$cwd_path" != "null" ]; then
      project_name=$(basename "$cwd_path")
    fi
  fi

  # Return the input JSON with added project_name field
  echo "$input" | jq --arg project_name "$project_name" '. + {project_name: $project_name}'
}

# ============================================================================
# USER INPUTS EXTRACTION
# ============================================================================

# Function to check if content is a tool use result
is_tool_use_result() {
  local line="$1"
  # Check if message.content is an array containing tool_use_id
  echo "$line" | jq -e '.message.content | type == "array" and length > 0 and (.[0] | has("tool_use_id"))' >/dev/null 2>&1
}

# Function to check if this is a system/meta message
is_system_message() {
  local line="$1"
  local content="$2"

  # Check if this is an assistant message
  local msg_type=$(echo "$line" | jq -r '.type // empty')
  if [ "$msg_type" = "assistant" ]; then
    return 0
  fi

  # Check if message role is assistant
  local msg_role=$(echo "$line" | jq -r '.message.role // empty')
  if [ "$msg_role" = "assistant" ]; then
    return 0
  fi

  # Check if isMeta is true
  if echo "$line" | jq -e '.isMeta == true' >/dev/null 2>&1; then
    return 0
  fi

  # Check for command-related tags
  if echo "$content" | grep -q '<command-name>' || echo "$content" | grep -q '<local-command-stdout>' || echo "$content" | grep -q '<command-message>' || echo "$content" | grep -q '<command-args>'; then
    return 0
  fi

  # Check if content starts with "Caveat:"
  case "$content" in
    "Caveat:"*) return 0 ;;
  esac

  # Check for system reminder tags
  if echo "$content" | grep -q '<system-reminder>'; then
    return 0
  fi

  # Check if content contains tool use (additional safety check)
  if echo "$content" | jq -e 'type == "array" and length > 0 and (.[0] | has("tool_use_id"))' >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# Function to extract user inputs from source file
extract_user_inputs_from_file() {
  local source_file="$1"
  local file_type="$2"
  local temp_results=()
  local count=0

  # Read the source file line by line and filter user inputs
  while IFS= read -r line; do
    # Skip empty lines and malformed JSON
    if [ -z "$line" ] || ! echo "$line" | jq . >/dev/null 2>&1; then
      continue
    fi

    local content=""

    # Handle different file formats
    if [ "$file_type" = "projects" ]; then
      # Claude Projects format processing
      # Check if this is a user input line
      if ! echo "$line" | jq -e '.type == "user" and .message.role == "user"' >/dev/null 2>&1; then
        continue
      fi

      # Extract content based on type (string or array)
      local content_type=$(echo "$line" | jq -r '.message.content | type')

      if [ "$content_type" = "string" ]; then
        # Simple string format - extract directly
        content=$(echo "$line" | jq -r '.message.content // empty')
      elif [ "$content_type" = "array" ]; then
        # Array format - check if it's a tool use result or text content
        # First check if it contains tool_use_id (tool result)
        if echo "$line" | jq -e '.message.content[0] | has("tool_use_id")' >/dev/null 2>&1; then
          continue
        fi

        # Check if it's text content format [{"type": "text", "text": "..."}]
        if echo "$line" | jq -e '.message.content[0].type == "text"' >/dev/null 2>&1; then
          # Extract all text content and join them
          content=$(echo "$line" | jq -r '.message.content[] | select(.type == "text") | .text' | tr '\n' ' ')
        else
          # Unknown array format, skip
          continue
        fi
      else
        # Neither string nor array, skip
        continue
      fi

      # Skip if content is empty or null
      if [ -z "$content" ] || [ "$content" = "null" ]; then
        continue
      fi

      # Additional safety checks for non-user content patterns
      if echo "$content" | grep -qi "^\[.*\]" ||
        echo "$content" | grep -qi "^ERROR:" ||
        echo "$content" | grep -qi "^WARNING:" ||
        echo "$content" | grep -qi "^INFO:" ||
        echo "$content" | grep -qi "^DEBUG:" ||
        echo "$content" | grep -qi "^SYSTEM:" ||
        echo "$content" | grep -qi "Tool execution" ||
        echo "$content" | grep -qi "Assistant response" ||
        echo "$content" | grep -q "<command-name>" ||
        echo "$content" | grep -q "<command-message>" ||
        echo "$content" | grep -q "<command-args>" ||
        echo "$content" | grep -q "<local-command-stdout>" ||
        echo "$content" | grep -q "<system-reminder>" ||
        case "$content" in "Caveat:"*) true ;; *) false ;; esac then
        continue
      fi
    else
      # Traditional transcript format processing
      # Check if this is a user message (explicitly exclude assistant messages)
      local type=$(echo "$line" | jq -r '.type // empty')
      if [ "$type" != "user" ] || [ "$type" = "assistant" ]; then
        continue
      fi

      # Check if message exists and has role "user"
      local role=$(echo "$line" | jq -r '.message.role // empty')
      if [ "$role" != "user" ]; then
        continue
      fi

      # Extract content based on type (string or array) - same logic as Claude Projects
      local content_type=$(echo "$line" | jq -r '.message.content | type')

      if [ "$content_type" = "string" ]; then
        # Simple string format - extract directly
        content=$(echo "$line" | jq -r '.message.content // empty')
      elif [ "$content_type" = "array" ]; then
        # Array format - check if it's a tool use result or text content
        # Check if this is a tool use result (content is array with tool_use_id)
        if is_tool_use_result "$line"; then
          continue
        fi

        # Check if it's text content format [{"type": "text", "text": "..."}]
        if echo "$line" | jq -e '.message.content[0].type == "text"' >/dev/null 2>&1; then
          # Extract all text content and join them
          content=$(echo "$line" | jq -r '.message.content[] | select(.type == "text") | .text' | tr '\n' ' ')
        else
          # Unknown array format, skip
          continue
        fi
      else
        # Neither string nor array, skip
        continue
      fi

      if [ -z "$content" ] || [ "$content" = "null" ]; then
        continue
      fi

      # Check if this is a system/meta message
      if is_system_message "$line" "$content"; then
        continue
      fi
    fi

    count=$((count + 1))

    # This is a real user input, extract relevant fields
    # Truncate content to configured length
    if [ ${#content} -gt $USER_INPUT_TRUNCATE_LENGTH ]; then
      content="${content:0:$USER_INPUT_TRUNCATE_LENGTH}..."
    fi

    case $format in
      basic)
        if [ "$include_multiline" = true ]; then
          # Wrap in code blocks for better Telegram formatting
          local formatted_content=$(printf '```\n%s\n```' "$content")
          temp_results+=("$formatted_content")
        else
          # For single line content, still use code blocks for consistency
          local formatted_content=$(printf '```\n%s\n```' "$content")
          temp_results+=("$formatted_content")
        fi
        ;;
      detailed)
        local timestamp=$(echo "$line" | jq -r '.timestamp // empty')
        local cwd=$(echo "$line" | jq -r '.cwd // empty')
        local uuid=$(echo "$line" | jq -r '.uuid // empty')
        if [ "$include_multiline" = true ]; then
          # Wrap content in code blocks for better formatting
          local formatted_content=$(printf '```\n%s\n```' "$content")
          local result=$(printf "[$timestamp] %s\n  CWD: %s\n  UUID: %s\n" "$formatted_content" "$cwd" "$uuid")
        else
          local formatted_content=$(printf '```\n%s\n```' "$content")
          local result=$(printf "[$timestamp] %s\n  CWD: %s\n  UUID: %s\n" "$formatted_content" "$cwd" "$uuid")
        fi
        temp_results+=("$result")
        ;;
      json)
        # For JSON format, we need to update the content field with truncated content
        local result=$(echo "$line" | jq --arg truncated_content "$content" '{
                            timestamp: .timestamp,
                            content: $truncated_content,
                            cwd: .cwd,
                            uuid: .uuid,
                            sessionId: .sessionId,
                            isMeta: .isMeta
                        }')
        temp_results+=("$result")
        ;;
    esac
  done <"$source_file"

  # Apply reverse and limit
  local start_idx=0
  local end_idx=${#temp_results[@]}

  if [ "$reverse" = true ]; then
    if [ "$limit" -gt 0 ] && [ "$limit" -lt "$end_idx" ]; then
      start_idx=$((end_idx - limit))
    fi
    for ((i = end_idx - 1; i >= start_idx; i--)); do
      if [ "$format" = "detailed" ]; then
        echo "${temp_results[i]}"
        echo
      else
        echo "${temp_results[i]}"
      fi
    done
  else
    if [ "$limit" -gt 0 ] && [ "$limit" -lt "$end_idx" ]; then
      end_idx=$limit
    fi
    for ((i = 0; i < end_idx; i++)); do
      if [ "$format" = "detailed" ]; then
        echo "${temp_results[i]}"
        echo
      else
        echo "${temp_results[i]}"
      fi
    done
  fi
}

# Main function to extract user inputs
extract_user_inputs() {
  local input="$1"

  # Extract both transcript_path and session_id from input
  local transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
  local session_id=$(echo "$input" | jq -r '.session_id // empty')
  local project_path=$(echo "$input" | jq -r '.project_path // empty')

  # Determine the source file to process
  local source_file=""
  local file_type=""

  if [ -n "$transcript_path" ] && [ "$transcript_path" != "null" ]; then
    # Try to resolve the actual session file first
    local resolved_file=$(resolve_session_file "$session_id" "$transcript_path")

    if [ $? -eq 0 ] && [ -n "$resolved_file" ] && [ -f "$resolved_file" ]; then
      # Use the resolved file
      source_file="$resolved_file"
      # Determine file type based on path
      if echo "$resolved_file" | grep -q "/.claude/projects/"; then
        file_type="projects"
      else
        file_type="transcript"
      fi
    else
      # Fallback to direct transcript path
      source_file="$transcript_path"
      file_type="transcript"

      if [ ! -f "$source_file" ]; then
        log_error "Transcript file not found: $source_file"
        return 1
      fi

      if [ ! -r "$source_file" ]; then
        log_error "Cannot read transcript file: $source_file"
        return 1
      fi
    fi
  elif [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
    # Claude Projects mode
    file_type="projects"

    # Use helper function to find the Claude Projects JSONL file
    source_file=$(resolve_session_file "$session_id" "$transcript_path")

    if [ $? -ne 0 ] || [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
      # If no source file found, return empty user_inputs
      echo ""
      return 0
    fi
  else
    # Try to use helper function to resolve the source file
    if [ -n "$transcript_path" ] && [ "$transcript_path" != "null" ]; then
      local resolved_file=$(resolve_session_file "" "$transcript_path")
      if [ $? -eq 0 ] && [ -n "$resolved_file" ] && [ -f "$resolved_file" ]; then
        source_file="$resolved_file"
        # Determine file type based on path
        if echo "$resolved_file" | grep -q "/.claude/projects/"; then
          file_type="projects"
        else
          file_type="transcript"
        fi
      else
        source_file="$transcript_path"
        file_type="transcript"
      fi

      if [ ! -f "$source_file" ]; then
        log_error "Source file not found: $source_file"
        return 1
      fi

      if [ ! -r "$source_file" ]; then
        log_error "Cannot read source file: $source_file"
        return 1
      fi
    else
      log_error "No transcript_path or session_id found in input"
      return 1
    fi
  fi

  # Extract user inputs from the source file
  extract_user_inputs_from_file "$source_file" "$file_type"
}

# ============================================================================
# MAIN PROCESSING LOGIC
# ============================================================================

# Function to enrich data with project name and user inputs
enrich_data() {
  local input="$1"

  # Validate input JSON
  if ! validate_json "$input"; then
    return 1
  fi

  # Step 1: Extract project name and enrich data
  local enriched_data=$(extract_project_name "$input")

  # Check if project name extraction was successful
  if [ $? -ne 0 ] || [ -z "$enriched_data" ]; then
    # Fallback: use original input if extract_project_name fails
    log_warning "Failed to extract project name, using original input"
    enriched_data="$input"
  fi

  # Validate enriched data is still valid JSON
  if ! validate_json "$enriched_data"; then
    log_warning "Project name extraction produced invalid JSON, using original input"
    enriched_data="$input"
  fi

  # Step 2: Extract user inputs and further enrich data
  local user_inputs=$(extract_user_inputs "$enriched_data")

  # Check if user inputs extraction was successful
  if [ $? -ne 0 ]; then
    # Fallback: use empty user inputs if extraction fails
    log_warning "Failed to extract user inputs, using empty user inputs"
    user_inputs=""
  fi

  # Output the final enriched JSON
  if [ "$format" = "json" ]; then
    # For JSON format, collect all JSON objects into an array
    if [ -n "$user_inputs" ]; then
      local user_inputs_json=$(echo "$user_inputs" | jq -s '.')
      echo "$enriched_data" | jq --argjson user_inputs "$user_inputs_json" '. + {user_inputs: $user_inputs}'
    else
      echo "$enriched_data" | jq '. + {user_inputs: []}'
    fi
  else
    # For basic and detailed formats, keep as string
    echo "$enriched_data" | jq --arg user_inputs "$user_inputs" '. + {user_inputs: $user_inputs}'
  fi
}

# ============================================================================
# COMMAND LINE ARGUMENT PARSING
# ============================================================================

# Parse command line arguments
while [ $# -gt 0 ]; do
  case $1 in
    --format=*)
      format="${1#*=}"
      shift
      ;;
    --limit=*)
      limit="${1#*=}"
      shift
      ;;
    --reverse)
      reverse=true
      shift
      ;;
    --include-multiline)
      include_multiline=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate format parameter
case $format in
  basic | detailed | json) ;;
  *)
    log_error "Invalid format. Use basic, detailed, or json"
    exit 1
    ;;
esac

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Read JSON input from stdin
input=$(cat)

# Process and enrich the data
enrich_data "$input"
