#!/bin/bash

# Test Monitoring System for Claude Code iOS
# This script demonstrates the monitoring capabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Claude Code iOS Monitoring Test ===${NC}\n"

# Check if simulator is running
SIMULATOR_UUID="A707456B-44DB-472F-9722-C88153CDFFA1"
echo -e "${YELLOW}Checking simulator status...${NC}"

if xcrun simctl list | grep -q "$SIMULATOR_UUID.*Booted"; then
    echo -e "${GREEN}✓ Simulator is running${NC}"
else
    echo -e "${YELLOW}Starting simulator...${NC}"
    xcrun simctl boot $SIMULATOR_UUID || true
    sleep 5
fi

# Build the app with monitoring enabled
echo -e "\n${YELLOW}Building app with monitoring...${NC}"
xcodebuild -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
    -configuration Debug \
    build

echo -e "${GREEN}✓ Build complete${NC}"

# Install and launch the app
echo -e "\n${YELLOW}Installing and launching app...${NC}"
APP_BUNDLE_ID="com.claudecode.ios"

# Find the app path
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClaudeCode.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}✗ Could not find built app${NC}"
    exit 1
fi

xcrun simctl install $SIMULATOR_UUID "$APP_PATH"
echo -e "${GREEN}✓ App installed${NC}"

# Start log streaming in background
LOG_FILE="logs/monitoring_test_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

echo -e "\n${YELLOW}Starting log capture to $LOG_FILE${NC}"
xcrun simctl spawn $SIMULATOR_UUID log stream \
    --predicate 'subsystem CONTAINS "com.claudecode"' \
    --level debug \
    --style syslog > "$LOG_FILE" 2>&1 &
LOG_PID=$!

# Launch the app
xcrun simctl launch $SIMULATOR_UUID $APP_BUNDLE_ID
echo -e "${GREEN}✓ App launched${NC}"

# Monitor for specific events
echo -e "\n${BLUE}Monitoring for events (press Ctrl+C to stop)...${NC}"
echo -e "${YELLOW}Try these actions in the app:${NC}"
echo "  • Tap 'Test Backend' to test API connection"
echo "  • Tap 'Test Chat API' to test chat endpoint"
echo "  • Tap 'Simulate Error' to trigger error tracking"
echo "  • Tap 'Track Custom Event' to send analytics"
echo "  • Switch between dashboard tabs to see real-time metrics"
echo ""

# Function to check for monitoring events in logs
check_monitoring() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${BLUE}Recent monitoring events:${NC}"
        
        # Check for performance metrics
        if grep -q "performance.metric" "$LOG_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓ Performance metrics detected${NC}"
            tail -n 5 "$LOG_FILE" | grep "performance.metric" || true
        fi
        
        # Check for errors
        if grep -q "error.tracked" "$LOG_FILE" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Errors tracked:${NC}"
            tail -n 5 "$LOG_FILE" | grep "error.tracked" || true
        fi
        
        # Check for analytics events
        if grep -q "analytics.event" "$LOG_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓ Analytics events:${NC}"
            tail -n 5 "$LOG_FILE" | grep "analytics.event" || true
        fi
        
        # Check for network monitoring
        if grep -q "network.request" "$LOG_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓ Network requests monitored:${NC}"
            tail -n 5 "$LOG_FILE" | grep "network.request" || true
        fi
    fi
}

# Trap cleanup
cleanup() {
    echo -e "\n${YELLOW}Stopping log capture...${NC}"
    kill $LOG_PID 2>/dev/null || true
    
    echo -e "\n${BLUE}=== Monitoring Summary ===${NC}"
    if [ -f "$LOG_FILE" ]; then
        echo "Log file: $LOG_FILE"
        echo "Total events: $(grep -c "com.claudecode" "$LOG_FILE" 2>/dev/null || echo "0")"
        echo "Errors tracked: $(grep -c "error.tracked" "$LOG_FILE" 2>/dev/null || echo "0")"
        echo "Performance metrics: $(grep -c "performance.metric" "$LOG_FILE" 2>/dev/null || echo "0")"
        echo "Analytics events: $(grep -c "analytics.event" "$LOG_FILE" 2>/dev/null || echo "0")"
    fi
    
    echo -e "\n${GREEN}✓ Monitoring test complete${NC}"
    exit 0
}

trap cleanup INT TERM

# Monitor for 60 seconds or until interrupted
for i in {1..60}; do
    sleep 1
    if [ $((i % 10)) -eq 0 ]; then
        check_monitoring
    fi
done

cleanup