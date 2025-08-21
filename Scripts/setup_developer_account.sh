#!/bin/bash

# Xcode Developer Account Setup Helper
# This script guides through configuring Xcode developer account

echo "==========================================
Xcode Developer Account Configuration
==========================================

Current Status:
"

# Check for existing identities
echo "📱 Code Signing Identities:"
security find-identity -v -p codesigning 2>/dev/null || echo "   No identities found"

echo "
📋 Provisioning Profiles:"
ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | wc -l | xargs echo "   Found" | sed 's/$/profiles/'

echo "
==========================================
Setup Instructions:
==========================================

1. Open Xcode Preferences:
   - Xcode menu → Settings (⌘,)
   - Click 'Accounts' tab

2. Add Apple ID:
   - Click '+' button
   - Select 'Apple ID'
   - Enter your Apple ID credentials
   - Sign in with 2FA if required

3. Manage Certificates:
   - Select your account
   - Click 'Manage Certificates'
   - Click '+' → 'Apple Development'
   - Xcode will create and download certificates

4. Configure Project:
   - Open project in Xcode
   - Select project in navigator
   - Go to 'Signing & Capabilities' tab
   - Enable 'Automatically manage signing'
   - Select your team from dropdown

5. For Device Testing (Optional):
   - Register devices in Apple Developer Portal
   - Or use automatic registration when connecting device

==========================================
Verification Commands:
==========================================

# Check identities:
security find-identity -v -p codesigning

# List provisioning profiles:
ls ~/Library/MobileDevice/Provisioning\\ Profiles/

# View profile details:
security cms -D -i ~/Library/MobileDevice/Provisioning\\ Profiles/*.mobileprovision

==========================================
Note: Free Apple ID allows:
- Development on simulators
- Testing on your own devices (up to 3)
- 7-day app provisioning

Paid Developer Account ($99/year) provides:
- App Store distribution
- TestFlight beta testing
- Unlimited device registration
- 1-year provisioning profiles
==========================================
"

# Check if Xcode is configured
if security find-identity -v -p codesigning | grep -q "Apple Development"; then
    echo "✅ Apple Development identity found - Basic setup complete!"
else
    echo "⚠️ No Apple Development identity found - Please configure in Xcode"
fi