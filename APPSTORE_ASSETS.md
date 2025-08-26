# App Store Assets - Quick Start Guide

## 🎯 One-Command Asset Generation

### Generate Everything (Production Ready)
```bash
./Scripts/generate-all-assets.sh all --production
```

### Quick Essential Assets
```bash
./Scripts/generate-all-assets.sh all --quick
```

## 📱 What Gets Generated

1. **App Icons** (all iOS sizes + App Store 1024x1024)
2. **Screenshots** (iPhone 15 Pro Max, iPhone 15 Pro, iPad Pro 12.9", iPad Pro 11")
3. **App Preview Videos** (15-30 seconds, multiple languages)
4. **Marketing Materials** (feature graphics, social media, press kit)
5. **App Store Listing** (descriptions, keywords, metadata)
6. **Export Package** (App Store Connect ready files)

## 📂 Output Location

All assets are generated in: `AppStoreAssets/`
- Ready-to-upload files in: `AppStoreAssets/Export/`
- Submission checklist: `AppStoreAssets/Export/submission_checklist.md`

## 🚀 Quick Commands

```bash
# Check what's already generated
./Scripts/generate-all-assets.sh status

# Generate specific assets
./Scripts/generate-all-assets.sh icons          # Icons only
./Scripts/generate-all-assets.sh screenshots   # Screenshots only
./Scripts/generate-all-assets.sh previews      # Videos only

# Export for App Store Connect
./Scripts/generate-all-assets.sh export

# Validate everything
./Scripts/generate-all-assets.sh validate

# Clean and start over
./Scripts/generate-all-assets.sh clean
```

## ⚙️ Requirements

- **Xcode** with command line tools
- **iPhone 15 Pro Max Simulator** (UUID: A707456B-44DB-472F-9722-C88153CDFFA1)
- **Optional**: ImageMagick, FFmpeg for enhanced features

## 🔧 Installation

```bash
# Make scripts executable (done automatically)
chmod +x Scripts/*.sh

# Install optional tools for better results
brew install imagemagick ffmpeg librsvg
```

## 📋 App Store Connect Upload

1. Run: `./Scripts/generate-all-assets.sh all --production`
2. Upload from `AppStoreAssets/Export/` directory:
   - Screenshots from `Screenshots/`
   - App preview videos from `App_Previews/`
   - App icon from `App_Icon/`
3. Copy listing content from `Listing/app_store_metadata.json`
4. Follow `submission_checklist.md`

## 🆘 Troubleshooting

**App won't build?**
```bash
./Scripts/simulator_automation.sh build
```

**Simulator issues?**
```bash
xcrun simctl boot A707456B-44DB-472F-9722-C88153CDFFA1
```

**Check what's wrong:**
```bash
./Scripts/generate-all-assets.sh --dry-run    # See what would be generated
./Scripts/generate-all-assets.sh validate    # Check existing assets
```

## 📖 Full Documentation

Detailed documentation: `AppStoreAssets/README.md`

---

**Ready to ship!** 🚀 Your App Store assets will be generated automatically with professional quality and Apple compliance.