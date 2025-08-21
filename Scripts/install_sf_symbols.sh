#!/bin/bash

# SF Symbols Installation Helper
# This script guides the user through installing SF Symbols

echo "==========================================
SF Symbols Installation Guide
==========================================

SF Symbols is a free app from Apple that provides thousands of configurable symbols.

To install SF Symbols:

1. Visit: https://developer.apple.com/sf-symbols/
2. Click 'Download SF Symbols 6' (or latest version)
3. Open the downloaded .dmg file
4. Drag SF Symbols.app to Applications folder
5. Launch SF Symbols from Applications

Features:
- Browse over 6,000 symbols
- Search by name or category
- Copy symbol names for use in code
- Export symbols in various formats
- Preview symbols with different rendering modes

Usage in SwiftUI:
    Image(systemName: \"star.fill\")
    Label(\"Favorites\", systemImage: \"heart.fill\")

Would you like to open the download page now? (y/n)"

read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    open "https://developer.apple.com/sf-symbols/"
    echo "✅ Opening SF Symbols download page..."
    echo "📝 After installation, you can verify by running:"
    echo "   ls /Applications/ | grep 'SF Symbols'"
else
    echo "ℹ️ You can download SF Symbols later from:"
    echo "   https://developer.apple.com/sf-symbols/"
fi

echo "
==========================================
Note: SF Symbols requires macOS 12 or later
=========================================="