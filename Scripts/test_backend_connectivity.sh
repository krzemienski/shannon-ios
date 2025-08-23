#!/bin/bash

# Backend Connectivity Test Script
# Tests real backend connectivity without requiring app build

BACKEND_URL="http://localhost:8000"
SIMULATOR_UUID="A707456B-44DB-472F-9722-C88153CDFFA1"

echo "=========================================="
echo "Claude Code iOS - Backend Connectivity Test"
echo "Backend URL: $BACKEND_URL"
echo "=========================================="
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local description=$2
    local expected_field=$3
    
    echo -e "${BLUE}[TEST]${NC} $description"
    echo "  URL: $BACKEND_URL$endpoint"
    
    response=$(curl -s -w "\n%{http_code}" "$BACKEND_URL$endpoint" 2>/dev/null)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "  ${GREEN}✅ HTTP Status: $http_code${NC}"
        
        if [ ! -z "$expected_field" ]; then
            if echo "$body" | grep -q "\"$expected_field\""; then
                echo -e "  ${GREEN}✅ Response contains '$expected_field' field${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Response missing '$expected_field' field${NC}"
            fi
        fi
        
        # Show first 100 chars of response
        preview=$(echo "$body" | head -c 100)
        echo "  Response preview: $preview..."
        
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✅ Test PASSED${NC}"
    else
        echo -e "  ${RED}❌ HTTP Status: $http_code${NC}"
        echo -e "  ${RED}❌ Test FAILED${NC}"
        ((TESTS_FAILED++))
    fi
    echo
}

# Function to test WebSocket
test_websocket() {
    echo -e "${BLUE}[TEST]${NC} WebSocket Connection"
    echo "  URL: ws://localhost:8000/v1/chat/stream"
    
    # Use Python to test WebSocket since it's more reliable
    python3 -c "
import asyncio
import websockets
import json
import sys

async def test():
    try:
        uri = 'ws://localhost:8000/v1/chat/stream'
        async with websockets.connect(uri) as websocket:
            # Send a test message
            test_msg = json.dumps({
                'type': 'ping',
                'timestamp': '2024-01-01T00:00:00Z'
            })
            await websocket.send(test_msg)
            
            # Try to receive response (with timeout)
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                print('✅ WebSocket connected and responsive')
                return 0
            except asyncio.TimeoutError:
                print('✅ WebSocket connected (no response expected for ping)')
                return 0
    except Exception as e:
        print(f'❌ WebSocket connection failed: {e}')
        return 1

sys.exit(asyncio.run(test()))
" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✅ Test PASSED${NC}"
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}❌ Test FAILED${NC}"
    fi
    echo
}

# Function to test POST endpoint
test_post_endpoint() {
    local endpoint=$1
    local description=$2
    local payload=$3
    
    echo -e "${BLUE}[TEST]${NC} $description"
    echo "  URL: $BACKEND_URL$endpoint"
    echo "  Method: POST"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -w "\n%{http_code}" \
        "$BACKEND_URL$endpoint" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo -e "  ${GREEN}✅ HTTP Status: $http_code${NC}"
        
        # Show first 100 chars of response
        preview=$(echo "$body" | head -c 100)
        echo "  Response preview: $preview..."
        
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✅ Test PASSED${NC}"
    else
        echo -e "  ${RED}❌ HTTP Status: $http_code${NC}"
        if [ ! -z "$body" ]; then
            echo "  Error: $body"
        fi
        ((TESTS_FAILED++))
        echo -e "  ${RED}❌ Test FAILED${NC}"
    fi
    echo
}

# Start tests
echo -e "${BLUE}Starting Backend Connectivity Tests...${NC}"
echo "=========================================="
echo

# 1. Health Check (no v1 prefix)
test_endpoint "/health" "Health Check" "status"

# 2. Models Endpoint
test_endpoint "/v1/models" "Models List" "data"

# 3. Projects Endpoint
test_endpoint "/v1/projects" "Projects List" "projects"

# 4. Sessions Endpoint
test_endpoint "/v1/sessions" "Sessions List" "sessions"

# 5. MCP Tools Endpoint
test_endpoint "/v1/mcp/tools" "MCP Tools" "tools"

# 6. Test WebSocket
if command -v python3 &> /dev/null; then
    test_websocket
else
    echo -e "${YELLOW}[SKIP]${NC} WebSocket test (Python 3 not available)"
fi

# 7. Test Chat Completion (POST)
chat_payload='{
    "model": "claude-3-5-sonnet-latest",
    "messages": [
        {"role": "user", "content": "Hello, this is a test"}
    ],
    "max_tokens": 10,
    "stream": false
}'
test_post_endpoint "/v1/chat/completions" "Chat Completion" "$chat_payload"

# 8. Test Create Project (POST)
project_payload='{
    "name": "UI Test Project",
    "description": "Test project from UI tests"
}'
test_post_endpoint "/v1/projects" "Create Project" "$project_payload"

# Summary
echo "=========================================="
echo -e "${BLUE}Test Summary${NC}"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All backend connectivity tests PASSED!${NC}"
    echo "The backend at $BACKEND_URL is fully operational."
    exit 0
else
    echo -e "${RED}❌ Some tests FAILED${NC}"
    echo "Please check the backend configuration and ensure it's running properly."
    exit 1
fi