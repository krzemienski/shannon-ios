#!/bin/bash

# Shannon iOS App Backend Monitoring Script
# Purpose: Monitor connectivity between iOS app and Claude-powered backend

BACKEND_IP="192.168.0.155"
BACKEND_PORT="8000"
BACKEND_URL="http://$BACKEND_IP:$BACKEND_PORT"
LOG_DIR="logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MONITOR_LOG="$LOG_DIR/monitor_$TIMESTAMP.log"
NETWORK_LOG="$LOG_DIR/network_$TIMESTAMP.log"
APP_LOG="$LOG_DIR/app_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "$LOG_DIR"

# Log function
log() {
    local level=$1
    shift
    local message="$@"
    echo -e "${level}[$(date '+%H:%M:%S')]${NC} $message" | tee -a "$MONITOR_LOG"
}

# Check backend health
check_backend() {
    log $BLUE "Checking backend connectivity..."
    
    # Test health endpoint
    response=$(curl -s -w "\n%{http_code}" "$BACKEND_URL/health" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        log $GREEN "✅ Backend is healthy!"
        log $GREEN "Response: $body"
        return 0
    else
        log $RED "❌ Backend not responding (HTTP $http_code)"
        log $YELLOW "Attempting to check if port is open..."
        nc -zv $BACKEND_IP $BACKEND_PORT 2>&1 | tee -a "$MONITOR_LOG"
        return 1
    fi
}

# Test API endpoints
test_endpoints() {
    log $BLUE "Testing API endpoints..."
    
    endpoints=(
        "/health"
        "/v1/models"
        "/v1/projects"
        "/v1/tools"
        "/v1/sessions"
    )
    
    for endpoint in "${endpoints[@]}"; do
        log $BLUE "Testing $BACKEND_URL$endpoint"
        response=$(curl -s -o /dev/null -w "%{http_code} - %{time_total}s" "$BACKEND_URL$endpoint" 2>&1)
        
        if [[ "$response" =~ ^2[0-9][0-9] ]]; then
            log $GREEN "  ✅ $endpoint: $response"
        else
            log $RED "  ❌ $endpoint: $response"
        fi
    done
}

# Monitor network traffic
monitor_network() {
    log $BLUE "Starting network monitoring on port $BACKEND_PORT..."
    
    # Check if tcpdump is available
    if command -v tcpdump &> /dev/null; then
        log $YELLOW "Starting tcpdump (may require sudo)..."
        sudo tcpdump -i any -n "host $BACKEND_IP and port $BACKEND_PORT" -w "$NETWORK_LOG.pcap" &
        TCPDUMP_PID=$!
        log $GREEN "Network capture started (PID: $TCPDUMP_PID)"
    else
        log $YELLOW "tcpdump not available, using netstat for monitoring"
    fi
}

# Monitor simulator logs
monitor_simulator() {
    log $BLUE "Starting simulator log monitoring..."
    
    # Get simulator UUID
    SIMULATOR_UUID="50523130-57AA-48B0-ABD0-4D59CE455F14"
    
    # Start log stream
    xcrun simctl spawn $SIMULATOR_UUID log stream \
        --predicate 'process == "ClaudeCode" OR process == "ClaudeCodeSwift" OR subsystem contains "com.claudecode"' \
        --level debug \
        --style compact > "$APP_LOG" 2>&1 &
    
    SIMLOG_PID=$!
    log $GREEN "Simulator logging started (PID: $SIMLOG_PID)"
}

# Real-time connection monitor
realtime_monitor() {
    log $BLUE "Starting real-time connection monitoring..."
    
    while true; do
        # Check active connections
        connections=$(netstat -an | grep "$BACKEND_IP:$BACKEND_PORT" | grep -E "(ESTABLISHED|SYN_SENT|TIME_WAIT)" | wc -l)
        
        if [ "$connections" -gt 0 ]; then
            log $GREEN "📡 Active connections to backend: $connections"
            netstat -an | grep "$BACKEND_IP:$BACKEND_PORT" | grep -E "(ESTABLISHED|SYN_SENT|TIME_WAIT)" | tee -a "$MONITOR_LOG"
        fi
        
        # Check for WebSocket connections
        ws_connections=$(netstat -an | grep "$BACKEND_IP:$BACKEND_PORT" | grep "ESTABLISHED" | wc -l)
        if [ "$ws_connections" -gt 0 ]; then
            log $GREEN "🔌 WebSocket connections: $ws_connections"
        fi
        
        sleep 2
    done
}

# Main monitoring function
main() {
    log $GREEN "==================================="
    log $GREEN "Shannon iOS Backend Monitor"
    log $GREEN "==================================="
    log $BLUE "Backend: $BACKEND_URL"
    log $BLUE "Logs: $LOG_DIR"
    echo ""
    
    # Step 1: Check backend
    if ! check_backend; then
        log $RED "⚠️  WARNING: Backend is not running!"
        log $YELLOW "The app will not be able to connect to the backend."
        log $YELLOW ""
        log $YELLOW "To start the backend:"
        log $YELLOW "1. Navigate to the backend directory"
        log $YELLOW "2. Run: python -m uvicorn main:app --host 0.0.0.0 --port 8000"
        log $YELLOW ""
        log $YELLOW "Continuing with monitoring setup anyway..."
    fi
    
    # Step 2: Test endpoints
    test_endpoints
    
    # Step 3: Start network monitoring
    monitor_network
    
    # Step 4: Start simulator monitoring
    monitor_simulator
    
    # Step 5: Launch the app
    log $GREEN ""
    log $GREEN "==================================="
    log $GREEN "Ready to launch the iOS app"
    log $GREEN "==================================="
    log $BLUE "Building and launching app..."
    
    # Build and launch
    cd /Users/nick/Documents/shannon-ios
    tuist generate && tuist build --open &
    BUILD_PID=$!
    
    log $GREEN "App build started (PID: $BUILD_PID)"
    
    # Step 6: Start real-time monitoring
    log $GREEN ""
    log $GREEN "==================================="
    log $GREEN "Real-time Monitoring Active"
    log $GREEN "==================================="
    log $YELLOW "Press Ctrl+C to stop monitoring"
    
    # Trap cleanup
    trap cleanup EXIT
    
    # Start real-time monitoring
    realtime_monitor
}

# Cleanup function
cleanup() {
    log $YELLOW "Stopping monitors..."
    
    if [ ! -z "$TCPDUMP_PID" ]; then
        sudo kill $TCPDUMP_PID 2>/dev/null
        log $YELLOW "Stopped network capture"
    fi
    
    if [ ! -z "$SIMLOG_PID" ]; then
        kill $SIMLOG_PID 2>/dev/null
        log $YELLOW "Stopped simulator logging"
    fi
    
    log $GREEN "Monitoring complete. Logs saved to:"
    log $GREEN "  - Monitor: $MONITOR_LOG"
    log $GREEN "  - App: $APP_LOG"
    log $GREEN "  - Network: $NETWORK_LOG.pcap (if available)"
}

# Run main function
main