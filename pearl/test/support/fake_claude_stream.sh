#!/bin/bash
# Fake claude CLI that outputs multiple assistant messages for streaming tests.
# Format verified against claude-agent-sdk-python types.py and message_parser.py.
# Stderr suppressed: broken pipe is expected when the stream consumer halts early.

echo '{"type":"system","subtype":"init"}' 2>/dev/null

# Multiple assistant messages to simulate streaming chunks
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"chunk1"}],"model":"claude-haiku-4-5-20251001"},"parent_tool_use_id":null}' 2>/dev/null
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"chunk2"}],"model":"claude-haiku-4-5-20251001"},"parent_tool_use_id":null}' 2>/dev/null
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"chunk3"}],"model":"claude-haiku-4-5-20251001"},"parent_tool_use_id":null}' 2>/dev/null

echo '{"type":"result","subtype":"success","is_error":false,"duration_ms":300,"duration_api_ms":250,"num_turns":1,"session_id":"test-session","total_cost_usd":0.003,"usage":{"input_tokens":10,"output_tokens":30}}' 2>/dev/null

exit 0
