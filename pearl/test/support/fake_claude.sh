#!/bin/bash
# Fake claude CLI for integration testing.
# Outputs JSON stream lines matching the real CLI's --output-format stream-json.
# Format verified against claude-agent-sdk-python types.py and message_parser.py.
# Inspects --system-prompt to determine response type.

SYSTEM_PROMPT=""
PROMPT=""
FOUND_SEPARATOR=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --system-prompt)
      SYSTEM_PROMPT="$2"
      shift 2
      ;;
    --)
      FOUND_SEPARATOR=true
      shift
      ;;
    *)
      if [ "$FOUND_SEPARATOR" = true ]; then
        PROMPT="$1"
      fi
      shift
      ;;
  esac
done

# System init message (type: "system", subtype: "init")
echo '{"type":"system","subtype":"init"}'

# Determine response based on system prompt content
if echo "$SYSTEM_PROMPT" | grep -q "JSON generator"; then
  # Wiki structure generation request
  RESPONSE='{"pages":[{"id":"overview","title":"Overview","description":"Project overview"}]}'
  echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":$(echo "$RESPONSE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}],\"model\":\"claude-haiku-4-5-20251001\"},\"parent_tool_use_id\":null}"
elif echo "$SYSTEM_PROMPT" | grep -q "wiki page"; then
  # Wiki page generation request
  PAGE_CONTENT="# Test Page\n\nThis is generated test content for the wiki page."
  echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":$(echo "$PAGE_CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}],\"model\":\"claude-haiku-4-5-20251001\"},\"parent_tool_use_id\":null}"
else
  # Default chat response
  echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Hello from fake Claude!"}],"model":"claude-haiku-4-5-20251001"},"parent_tool_use_id":null}'
fi

# Result message with fields from SDK's ResultMessage dataclass
echo '{"type":"result","subtype":"success","is_error":false,"duration_ms":100,"duration_api_ms":80,"num_turns":1,"session_id":"test-session","total_cost_usd":0.001,"usage":{"input_tokens":10,"output_tokens":20}}'

exit 0
