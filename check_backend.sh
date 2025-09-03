#!/bin/bash

# Quick backend connectivity check
BACKEND_URL="http://192.168.0.155:8000"

echo "====================================="
echo "Backend Connectivity Check"
echo "====================================="
echo ""

# 1. Check if port is open
echo "1. Checking port 8000..."
nc -zv 192.168.0.155 8000 2>&1

echo ""
echo "2. Testing health endpoint..."
curl -v "$BACKEND_URL/health" 2>&1 | grep -E "(HTTP|Connected|Failed|refused)"

echo ""
echo "3. Testing v1 endpoints..."
endpoints=("/v1/models" "/v1/projects" "/v1/tools")
for endpoint in "${endpoints[@]}"; do
    echo -n "   $endpoint: "
    curl -s -o /dev/null -w "%{http_code}\n" "$BACKEND_URL$endpoint" 2>&1
done

echo ""
echo "4. Checking network interfaces..."
ifconfig | grep -E "inet.*192.168" | head -3

echo ""
echo "====================================="
echo "If backend is not running, start it with:"
echo "cd <backend-dir> && python -m uvicorn main:app --host 0.0.0.0 --port 8000"
echo "====================================="