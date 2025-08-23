#!/bin/bash

# Test Backend API Endpoints
echo "=== Testing Claude Code Backend API Integration ==="
echo ""

BASE_URL="http://localhost:8000/v1"

# Test health endpoint
echo "1. Testing Health Endpoint..."
curl -s "$BASE_URL/../health" | python3 -m json.tool
echo ""

# Test models endpoint
echo "2. Testing Models Endpoint..."
curl -s "$BASE_URL/models" | python3 -m json.tool
echo ""

# Test creating a session
echo "3. Testing Create Session..."
SESSION_RESPONSE=$(curl -s -X POST "$BASE_URL/sessions/create" \
  -H "Content-Type: application/json" \
  -d '{}')
echo "$SESSION_RESPONSE" | python3 -m json.tool
SESSION_ID=$(echo "$SESSION_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null)
echo ""

# Test listing sessions
echo "4. Testing List Sessions..."
curl -s "$BASE_URL/sessions" | python3 -m json.tool
echo ""

# Test creating a project
echo "5. Testing Create Project..."
PROJECT_RESPONSE=$(curl -s -X POST "$BASE_URL/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Project",
    "description": "Test project from API",
    "path": "/tmp/test-project"
  }')
echo "$PROJECT_RESPONSE" | python3 -m json.tool
PROJECT_ID=$(echo "$PROJECT_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null)
echo ""

# Test listing projects
echo "6. Testing List Projects..."
curl -s "$BASE_URL/projects" | python3 -m json.tool
echo ""

# Test getting session info (if session was created)
if [ ! -z "$SESSION_ID" ]; then
    echo "7. Testing Get Session Info..."
    curl -s "$BASE_URL/sessions/$SESSION_ID" | python3 -m json.tool
    echo ""
fi

# Test MCP servers endpoint
echo "8. Testing MCP Servers..."
curl -s "$BASE_URL/mcp/servers" | python3 -m json.tool 2>/dev/null || echo "MCP servers endpoint not available"
echo ""

# Cleanup - delete test session if created
if [ ! -z "$SESSION_ID" ]; then
    echo "9. Cleaning up - Deleting test session..."
    curl -s -X DELETE "$BASE_URL/sessions/$SESSION_ID" | python3 -m json.tool 2>/dev/null || echo "Session deleted"
    echo ""
fi

# Cleanup - delete test project if created
if [ ! -z "$PROJECT_ID" ]; then
    echo "10. Cleaning up - Deleting test project..."
    curl -s -X DELETE "$BASE_URL/projects/$PROJECT_ID" | python3 -m json.tool 2>/dev/null || echo "Project deleted"
    echo ""
fi

echo "=== Backend API Testing Complete ==="#