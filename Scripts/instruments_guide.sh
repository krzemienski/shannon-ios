#!/bin/bash

# Instruments Performance Profiling Guide
# Helper for using Instruments with ClaudeCode iOS

echo "==========================================
Instruments Performance Profiling Guide
==========================================

Instruments Location:
/Applications/Xcode.app/Contents/Applications/Instruments.app

To launch Instruments:
$ open /Applications/Xcode.app/Contents/Applications/Instruments.app

Or from Xcode:
Product menu → Profile (⌘I)

==========================================
Key Instruments for iOS Development:
==========================================

1. Time Profiler
   - CPU usage analysis
   - Method execution time
   - Call tree inspection

2. Allocations
   - Memory allocation tracking
   - Heap growth analysis
   - Reference cycles detection

3. Leaks
   - Memory leak detection
   - Abandoned memory identification
   - Retain cycle analysis

4. Network
   - Network request monitoring
   - Data transfer analysis
   - Connection debugging

5. Core Animation
   - Frame rate analysis
   - Rendering performance
   - UI responsiveness

6. Energy Log
   - Battery usage profiling
   - Power consumption analysis
   - Energy impact assessment

==========================================
Quick Profiling Workflow:
==========================================

1. Build for Profiling:
   xcodebuild -scheme ClaudeCode -configuration Release

2. Launch with Instruments:
   - Open Instruments
   - Choose template (e.g., Time Profiler)
   - Select ClaudeCode as target
   - Click Record button

3. Analyze Results:
   - Inspect call tree
   - Identify hotspots
   - Export data for documentation

==========================================
Common Performance Issues to Check:
==========================================

• Main thread blocking
• Excessive memory allocations
• Retain cycles and leaks
• Slow network requests
• UI rendering bottlenecks
• Excessive CPU usage
• Battery drain causes

==========================================
"

# Check if we can open Instruments
if [ -d "/Applications/Xcode.app/Contents/Applications/Instruments.app" ]; then
    echo "✅ Instruments is available"
    echo ""
    read -p "Would you like to open Instruments now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open /Applications/Xcode.app/Contents/Applications/Instruments.app
        echo "📊 Opening Instruments..."
    fi
else
    echo "⚠️ Instruments not found. Please ensure Xcode is properly installed."
fi