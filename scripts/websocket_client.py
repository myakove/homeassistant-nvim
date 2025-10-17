#!/usr/bin/env python3
"""
Home Assistant WebSocket Client
Bidirectional communication between Neovim and Home Assistant via WebSocket.

Usage:
    python websocket_client.py <websocket_url> <access_token>
    
Input (stdin):  JSON messages to send to Home Assistant
Output (stdout): JSON messages received from Home Assistant
"""

import asyncio
import websockets
import json
import sys


async def read_stdin(websocket):
    """Read JSON messages from stdin and forward to WebSocket."""
    loop = asyncio.get_event_loop()
    while True:
        try:
            line = await loop.run_in_executor(None, sys.stdin.readline)
            if not line:
                print(json.dumps({"type": "error", "message": "stdin closed"}), file=sys.stderr, flush=True)
                break
            
            line = line.strip()
            if not line:  # Empty line, skip
                continue
                
            msg = json.loads(line)
            await websocket.send(json.dumps(msg))
        except json.JSONDecodeError as e:
            print(json.dumps({"type": "error", "message": f"Invalid JSON: {e}"}), file=sys.stderr, flush=True)
            continue  # Don't break on JSON errors, keep processing
        except Exception as e:
            print(json.dumps({"type": "error", "message": f"read_stdin error: {e}"}), file=sys.stderr, flush=True)
            break


async def read_websocket(websocket):
    """Read messages from WebSocket and print to stdout as JSON."""
    async for message in websocket:
        try:
            data = json.loads(message)
            print(json.dumps(data), flush=True)
        except Exception as e:
            print(json.dumps({"type": "error", "message": str(e)}), flush=True)


async def connect(uri, token):
    """Connect to Home Assistant WebSocket API."""
    try:
        # Increase max message size to 10MB for large state responses
        async with websockets.connect(uri, max_size=10 * 1024 * 1024) as websocket:
            # Wait for auth_required
            msg = await websocket.recv()
            data = json.loads(msg)
            print(json.dumps(data), flush=True)
            
            if data.get("type") == "auth_required":
                # Send auth
                auth_msg = {"type": "auth", "access_token": token}
                await websocket.send(json.dumps(auth_msg))
                
                # Wait for auth response
                auth_response = await websocket.recv()
                print(json.dumps(json.loads(auth_response)), flush=True)
            
            # Run both readers concurrently
            await asyncio.gather(
                read_stdin(websocket),
                read_websocket(websocket)
            )
    except Exception as e:
        print(json.dumps({"type": "error", "message": str(e)}), flush=True)
        sys.exit(1)


def main():
    """Main entry point."""
    if len(sys.argv) != 3:
        print(json.dumps({
            "type": "error",
            "message": "Usage: websocket_client.py <websocket_url> <access_token>"
        }), flush=True)
        sys.exit(1)
    
    uri = sys.argv[1]
    token = sys.argv[2]
    
    asyncio.run(connect(uri, token))


if __name__ == "__main__":
    main()
