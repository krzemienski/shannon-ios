#!/bin/bash

# Launch Shannon iOS App with Monitoring
SIMULATOR_UUID="50523130-57AA-48B0-ABD0-4D59CE455F14"
APP_BUNDLE="/Users/nick/Library/Developer/Xcode/DerivedData/ClaudeCodeSwift-cetgrvakzdvpodcquxkubsixrawj/Index.noindex/Build/Products/Debug-iphonesimulator/ClaudeCode.app"
BUNDLE_ID="com.claudecode.ios"
BACKEND_URL="http://192.168.0.155:8000"
LOG_FILE="logs/launch_monitor_$(date +%Y%m%d_%H%M%S).log"

mkdir -p logs

echo "==========================================" | tee -a "$LOG_FILE"
echo "Shannon iOS App Launch Monitor" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "Simulator: $SIMULATOR_UUID" | tee -a "$LOG_FILE"
echo "App Bundle: $APP_BUNDLE" | tee -a "$LOG_FILE"
echo "Backend: $BACKEND_URL" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# 1. Check backend status
echo "1. Backend Status Check..." | tee -a "$LOG_FILE"
if curl -s --connect-timeout 2 "$BACKEND_URL/health" > /dev/null 2>&1; then
    echo "   ✅ Backend is running" | tee -a "$LOG_FILE"
else
    echo "   ❌ Backend is NOT running (Connection will fail)" | tee -a "$LOG_FILE"
fi

# 2. Boot simulator
echo "2. Booting simulator..." | tee -a "$LOG_FILE"
xcrun simctl boot $SIMULATOR_UUID 2>/dev/null || echo "   Simulator already booted" | tee -a "$LOG_FILE"

# 3. Start monitoring network
echo "3. Starting network monitor..." | tee -a "$LOG_FILE"
netstat -an | grep "192.168.0.155:8000" > logs/network_baseline.log
echo "   Network baseline captured" | tee -a "$LOG_FILE"

# 4. Install app
echo "4. Installing app..." | tee -a "$LOG_FILE"
xcrun simctl install $SIMULATOR_UUID "$APP_BUNDLE" 2>&1 | tee -a "$LOG_FILE"

# 5. Start log stream
echo "5. Starting log stream..." | tee -a "$LOG_FILE"
xcrun simctl spawn $SIMULATOR_UUID log stream \
    --predicate 'process == "ClaudeCode" OR eventMessage contains "192.168" OR eventMessage contains "API" OR eventMessage contains "network" OR eventMessage contains "connection"' \
    --level debug \
    --style compact > logs/app_stream_$(date +%Y%m%d_%H%M%S).log 2>&1 &
LOG_PID=$!
echo "   Log stream PID: $LOG_PID" | tee -a "$LOG_FILE"

# 6. Launch app
echo "6. Launching app..." | tee -a "$LOG_FILE"
xcrun simctl launch --console-pty $SIMULATOR_UUID $BUNDLE_ID 2>&1 | tee -a "$LOG_FILE" &
LAUNCH_PID=$!

# 7. Monitor connections for 30 seconds
echo "7. Monitoring connections..." | tee -a "$LOG_FILE"
for i in {1..15}; do
    sleep 2
    connections=$(netstat -an | grep "192.168.0.155:8000" | grep -E "(ESTABLISHED|SYN_SENT)" | wc -l)
    if [ "$connections" -gt 0 ]; then
        echo "   [$(date +%H:%M:%S)] 🔌 Active connections: $connections" | tee -a "$LOG_FILE"
        netstat -an | grep "192.168.0.155:8000" | tee -a "$LOG_FILE"
    else
        echo "   [$(date +%H:%M:%S)] No backend connections detected" | tee -a "$LOG_FILE"
    fi
    
    # Check for any network errors in console
    if [ -f logs/app_stream_*.log ]; then
        errors=$(tail -100 logs/app_stream_*.log 2>/dev/null | grep -i "error\|failed\|refused" | wc -l)
        if [ "$errors" -gt 0 ]; then
            echo "   [$(date +%H:%M:%S)] ⚠️  Network errors detected: $errors" | tee -a "$LOG_FILE"
        fi
    fi
done

# 8. Final status
echo "" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "Launch Complete - Summary" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Check if app is running
if xcrun simctl get_app_container $SIMULATOR_UUID $BUNDLE_ID 2>/dev/null; then
    echo "✅ App is installed and accessible" | tee -a "$LOG_FILE"
else
    echo "❌ App installation issue detected" | tee -a "$LOG_FILE"
fi

# Check for crashes
crashes=$(find ~/Library/Logs/DiagnosticReports -name "ClaudeCode*.ips" -mmin -5 2>/dev/null | wc -l)
if [ "$crashes" -gt 0 ]; then
    echo "⚠️  Crash reports found: $crashes" | tee -a "$LOG_FILE"
else
    echo "✅ No crashes detected" | tee -a "$LOG_FILE"
fi

# Network summary
total_connections=$(netstat -an | grep "192.168.0.155:8000" | wc -l)
echo "📊 Total connection attempts: $total_connections" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Logs saved to:" | tee -a "$LOG_FILE"
echo "  - Main log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "  - App stream: logs/app_stream_*.log" | tee -a "$LOG_FILE"
echo "  - Network baseline: logs/network_baseline.log" | tee -a "$LOG_FILE"

# Cleanup
kill $LOG_PID 2>/dev/null

echo "" | tee -a "$LOG_FILE"
echo "Monitor complete at $(date)" | tee -a "$LOG_FILE"