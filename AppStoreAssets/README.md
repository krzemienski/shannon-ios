# Claude Code iOS - App Store Assets

Complete automated asset generation system for Claude Code iOS App Store submission.

## 🚀 Quick Start

Generate all assets with one command:

```bash
# Generate all production-ready assets
./Scripts/generate-all-assets.sh all --production

# Quick generation (essential assets only)
./Scripts/generate-all-assets.sh all --quick

# Generate for specific device and language
./Scripts/generate-all-assets.sh all --device iphone_67 --language en --mode dark
```

## 📁 Generated Assets Structure

```
AppStoreAssets/
├── Icons/                          # App icons in all sizes
│   ├── iOS/                       # iOS specific sizes
│   ├── AppStore/                  # 1024x1024 App Store icon
│   ├── Xcode/                     # Xcode asset catalog
│   │   └── AppIcon.appiconset/    # Ready for Xcode
│   └── Variations/                # Alternative designs
├── Screenshots/                    # App Store screenshots
│   ├── iphone_67/                 # iPhone 15 Pro Max
│   ├── iphone_61/                 # iPhone 15 Pro
│   ├── ipad_129/                  # iPad Pro 12.9"
│   └── ipad_11/                   # iPad Pro 11"
├── Previews/                      # App preview videos
│   └── [device]/[language]/       # 15-30 second videos
├── Marketing/                     # Marketing materials
│   ├── FeatureGraphics/          # Feature highlights
│   ├── Banners/                  # Promotional banners
│   ├── SocialMedia/              # Social templates
│   └── PressKit/                 # Press materials
├── Listing/                      # App Store listing content
│   ├── app_store_metadata.json   # Complete metadata
│   ├── app_description.txt       # Store descriptions
│   ├── keywords.txt              # SEO keywords
│   └── whats_new/                # Version release notes
└── Export/                       # App Store Connect ready
    ├── Screenshots/              # Organized by device
    ├── App_Previews/             # Video files
    ├── App_Icon/                 # Icon files
    └── submission_checklist.md   # Submission guide
```

## 🛠 Available Scripts

### Master Script
- **`generate-all-assets.sh`** - Orchestrates all asset generation

### Individual Generators
- **`icon-generator.sh`** - App icons and variations
- **`screenshot-automation.sh`** - Automated screenshots
- **`app-store-assets.sh`** - Complete asset pipeline
- **`app-preview-script.md`** - Video recording guide

## 📱 Supported Devices

### iPhone
- **iPhone 15 Pro Max (6.7")** - 1290x2796
- **iPhone 15 Pro (6.1")** - 1179x2556

### iPad  
- **iPad Pro 12.9" (6th gen)** - 2048x2732
- **iPad Pro 11" (4th gen)** - 1668x2388

## 🌍 Localization Support

Supported languages:
- English (en) - Primary
- Spanish (es)
- French (fr)
- German (de)
- Japanese (ja)
- Chinese Simplified (zh-Hans)
- Chinese Traditional (zh-Hant)
- Korean (ko)
- Portuguese Brazil (pt-BR)
- Russian (ru)
- Italian (it)
- Arabic (ar)

## 🎨 Asset Types

### App Icons
- **All iOS Sizes**: 20x20 to 1024x1024
- **Retina Support**: @1x, @2x, @3x variants
- **Xcode Ready**: AppIcon.appiconset bundle
- **App Store**: 1024x1024 marketing icon

### Screenshots
- **10 Scenarios**: Welcome, interface, editor, AI, terminal, etc.
- **Dark/Light Mode**: Both appearance variants
- **High Quality**: Device-specific resolutions
- **Localized**: Multi-language support

### App Preview Videos
- **Duration**: 15-30 seconds
- **Quality**: HD, App Store optimized
- **Content**: Feature demonstrations
- **Subtitles**: Optional text overlays

### Marketing Materials
- **Feature Graphics**: Highlight key features
- **Social Media**: Templates for all platforms
- **Press Kit**: Professional media package
- **Banners**: Various promotional sizes

## ⚙️ Requirements

### System Requirements
- **macOS**: 10.15+ recommended
- **Xcode**: 15.2+ with command line tools
- **iOS Simulator**: iPhone 15 Pro Max configured

### Optional Tools (Enhanced Features)
```bash
# Install via Homebrew
brew install imagemagick    # Image processing
brew install ffmpeg        # Video processing
brew install librsvg       # SVG conversion
```

### Project Requirements
- Claude Code iOS project built and runnable
- Simulator UUID: `A707456B-44DB-472F-9722-C88153CDFFA1`
- Valid provisioning profile

## 🚀 Usage Examples

### Complete Asset Generation
```bash
# Production-ready assets with validation
./Scripts/generate-all-assets.sh all --production

# Quick essential assets only
./Scripts/generate-all-assets.sh all --quick

# Specific language and appearance
./Scripts/generate-all-assets.sh all --language es --mode dark
```

### Individual Asset Types
```bash
# Icons only
./Scripts/generate-all-assets.sh icons

# Screenshots for specific device
./Scripts/generate-all-assets.sh screenshots --device iphone_67

# App preview videos
./Scripts/generate-all-assets.sh previews --language en --mode dark

# Marketing materials
./Scripts/generate-all-assets.sh marketing
```

### Asset Management
```bash
# Check generation status
./Scripts/generate-all-assets.sh status

# Validate existing assets
./Scripts/generate-all-assets.sh validate

# Export for App Store Connect
./Scripts/generate-all-assets.sh export

# Clean all generated assets
./Scripts/generate-all-assets.sh clean
```

## 📋 App Store Submission Checklist

### Before Running Scripts
- [ ] App builds successfully
- [ ] Simulator configured and working
- [ ] All required tools installed
- [ ] Project metadata updated

### Asset Generation
- [ ] Run `./Scripts/generate-all-assets.sh all --production`
- [ ] Validate assets with `--validate` flag
- [ ] Check export directory contents
- [ ] Verify screenshot quality and content

### App Store Connect Upload
- [ ] Upload screenshots from `Export/Screenshots/`
- [ ] Upload app preview videos from `Export/App_Previews/`
- [ ] Use 1024x1024 icon from `Export/App_Icon/`
- [ ] Copy listing content from `Listing/`

### Review Preparation
- [ ] Test app thoroughly on devices
- [ ] Prepare demo account if needed
- [ ] Review content guidelines compliance
- [ ] Set up support and marketing URLs

## 🔧 Customization

### Modifying Icons
1. Edit `AppStoreAssets/Icons/icon_master.svg`
2. Run `./Scripts/icon-generator.sh all`
3. Copy to Resources: `./Scripts/icon-generator.sh copy`

### Screenshot Scenarios
Modify scenarios in `screenshot-automation.sh`:
```bash
declare -A SCREENSHOT_SCENARIOS=(
    ["01_welcome"]="Welcome and onboarding screen"
    ["02_main_interface"]="Main interface with navigation"
    # Add more scenarios...
)
```

### App Store Metadata
Edit `Listing/app_store_metadata.json` for:
- App descriptions in all languages
- Keywords and categories
- Pricing and availability
- Technical requirements

## 🐛 Troubleshooting

### Common Issues

**Simulator Not Found**
```bash
# Check available simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot A707456B-44DB-472F-9722-C88153CDFFA1
```

**App Won't Launch**
```bash
# Build and install manually
./Scripts/simulator_automation.sh build
./Scripts/simulator_automation.sh launch
```

**Missing Dependencies**
```bash
# Install all optional tools
brew install imagemagick ffmpeg librsvg pngcrush
```

**Permission Issues**
```bash
# Make all scripts executable
chmod +x Scripts/*.sh
```

### Debug Mode
Add debug flags to any script:
```bash
./Scripts/generate-all-assets.sh all --dry-run    # Show what would be generated
./Scripts/generate-all-assets.sh status          # Check current state
./Scripts/generate-all-assets.sh validate        # Verify assets
```

## 📈 Asset Optimization

### Performance
- **Parallel Generation**: Multiple assets generated simultaneously
- **Caching**: Reuse common elements across assets
- **Compression**: Optimal file sizes for App Store
- **Validation**: Automatic quality checks

### Quality Assurance
- **Automated Validation**: Check dimensions, file sizes, formats
- **Visual Consistency**: Unified branding across all assets
- **App Store Compliance**: Follow Apple guidelines
- **Device Optimization**: Pixel-perfect for each device

## 🔄 Continuous Integration

### GitHub Actions Integration
```yaml
# .github/workflows/assets.yml
name: Generate App Store Assets
on:
  push:
    branches: [main]
jobs:
  generate:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - run: ./Scripts/generate-all-assets.sh all --production
      - uses: actions/upload-artifact@v3
        with:
          name: app-store-assets
          path: AppStoreAssets/Export/
```

### Pre-commit Hooks
```bash
# .git/hooks/pre-commit
#!/bin/bash
./Scripts/generate-all-assets.sh validate || exit 1
```

## 🎯 Best Practices

### Asset Quality
1. **High Resolution**: Use vector sources when possible
2. **Consistent Branding**: Maintain visual identity
3. **Accessibility**: Consider all user abilities
4. **Localization**: Test all languages and cultures

### Workflow Efficiency
1. **Batch Generation**: Generate all assets together
2. **Version Control**: Track asset changes
3. **Automation**: Minimize manual steps
4. **Validation**: Always verify before submission

### App Store Optimization
1. **Keywords**: Research and optimize
2. **Screenshots**: Show key features first
3. **Descriptions**: Clear, compelling copy
4. **Previews**: Demonstrate core value

## 📞 Support

### Resources
- **Apple Guidelines**: [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Human Interface Guidelines**: [iOS Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- **App Store Connect**: [Developer Documentation](https://developer.apple.com/app-store-connect/)

### Getting Help
1. Check troubleshooting section above
2. Validate assets with built-in tools
3. Review Apple's submission guidelines
4. Test thoroughly before submission

---

**Ready to submit to the App Store?** Run the production asset generation and follow the submission checklist! 🚀