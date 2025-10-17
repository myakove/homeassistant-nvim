# Python Scripts

This directory contains Python helper scripts used by the plugin.

## websocket_client.py

WebSocket client for bidirectional communication with Home Assistant.

### Usage

```bash
# Using uv (recommended - auto-installs websockets)
uv run --with websockets python3 websocket_client.py <ws_url> <token>

# Or with websockets installed
python3 websocket_client.py <ws_url> <token>
```

### Arguments

- `ws_url`: WebSocket URL (e.g., `ws://192.168.1.10:8123/api/websocket`)
- `token`: Home Assistant long-lived access token

### Protocol

**Input (stdin):** JSON messages to send to Home Assistant
```json
{"type": "get_states", "id": 1}
```

**Output (stdout):** JSON messages received from Home Assistant
```json
{"type": "result", "id": 1, "success": true, "result": [...]}
```

### Testing

You can test the script manually:

```bash
# Start the client
uv run --with websockets python3 websocket_client.py \
  ws://homeassistant.local:8123/api/websocket \
  your_token_here

# It will connect and print messages
# Type JSON commands on stdin:
{"type": "get_states", "id": 1}
```

### Development

The script uses:
- `websockets` library for WebSocket protocol
- `asyncio` for async I/O
- `json` for message serialization
- stdin/stdout for communication with Neovim

### Error Handling

Errors are returned as JSON:
```json
{"type": "error", "message": "Connection failed"}
```

The script exits with code 1 on fatal errors.
