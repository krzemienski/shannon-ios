#!/bin/bash

# Test chat completion endpoint
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-haiku-20241022",
    "messages": [
      {"role": "user", "content": "Say hello in 5 words"}
    ],
    "stream": false
  }' | python3 -m json.tool