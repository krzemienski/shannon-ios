#!/bin/bash

# Icon Generator Script for Claude Code iOS
# Generates all required app icon sizes from master template
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ICONS_DIR="$PROJECT_ROOT/AppStoreAssets/Icons"
RESOURCES_DIR="$PROJECT_ROOT/Resources"

# Icon sizes for iOS App Store and Xcode
declare -A ICON_SIZES=(
    # iPhone
    ["20x20@2x"]="40"      # iPhone Settings
    ["20x20@3x"]="60"      # iPhone Settings
    ["29x29@2x"]="58"      # iPhone Settings/Spotlight
    ["29x29@3x"]="87"      # iPhone Settings/Spotlight  
    ["40x40@2x"]="80"      # iPhone Spotlight
    ["40x40@3x"]="120"     # iPhone Spotlight
    ["60x60@2x"]="120"     # iPhone App
    ["60x60@3x"]="180"     # iPhone App
    
    # iPad
    ["20x20@1x"]="20"      # iPad Settings
    ["20x20@2x"]="40"      # iPad Settings
    ["29x29@1x"]="29"      # iPad Settings/Spotlight
    ["29x29@2x"]="58"      # iPad Settings/Spotlight
    ["40x40@1x"]="40"      # iPad Spotlight
    ["40x40@2x"]="80"      # iPad Spotlight
    ["76x76@1x"]="76"      # iPad App
    ["76x76@2x"]="152"     # iPad App
    ["83.5x83.5@2x"]="167" # iPad Pro App
    
    # Universal
    ["1024x1024@1x"]="1024" # App Store
    
    # Apple Watch (if supported in future)
    ["24x24@2x"]="48"      # Watch Notification
    ["27.5x27.5@2x"]="55"  # Watch Notification
    ["29x29@2x"]="58"      # Watch Companion Settings
    ["29x29@3x"]="87"      # Watch Companion Settings
    ["40x40@2x"]="80"      # Watch Home Screen
    ["44x44@2x"]="88"      # Watch Home Screen
    ["50x50@2x"]="100"     # Watch Home Screen
    
    # Mac (if Mac Catalyst supported)
    ["16x16@1x"]="16"      # Mac Finder
    ["16x16@2x"]="32"      # Mac Finder
    ["32x32@1x"]="32"      # Mac Finder
    ["32x32@2x"]="64"      # Mac Finder
    ["128x128@1x"]="128"   # Mac Finder
    ["128x128@2x"]="256"   # Mac Finder
    ["256x256@1x"]="256"   # Mac Finder
    ["256x256@2x"]="512"   # Mac Finder
    ["512x512@1x"]="512"   # Mac Finder
    ["512x512@2x"]="1024"  # Mac Finder
)

# Print functions
print_header() {
    echo -e "\n${PURPLE}======================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}======================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# Check dependencies
check_dependencies() {
    print_step "Checking dependencies..."
    
    if ! command -v convert &> /dev/null; then
        print_error "ImageMagick not found. Install with: brew install imagemagick"
    fi
    
    if ! command -v rsvg-convert &> /dev/null; then
        print_warning "rsvg-convert not found. SVG conversion may not work optimally."
        print_warning "Install with: brew install librsvg"
    fi
    
    print_success "Dependencies checked"
}

# Create master SVG template
create_master_template() {
    local template_path="$ICONS_DIR/icon_master.svg"
    
    mkdir -p "$ICONS_DIR"
    
    print_step "Creating master icon template..."
    
    cat > "$template_path" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Background Gradient -->
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#764ba2;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#667eea;stop-opacity:1" />
    </linearGradient>
    
    <!-- Icon Elements Gradient -->
    <linearGradient id="iconGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ffffff;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#f8fafc;stop-opacity:0.95" />
    </linearGradient>
    
    <!-- Shadow Filter -->
    <filter id="dropShadow" x="-50%" y="-50%" width="200%" height="200%">
      <feDropShadow dx="0" dy="4" stdDeviation="8" flood-color="#000000" flood-opacity="0.25"/>
    </filter>
    
    <!-- Glow Filter -->
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
      <feMerge> 
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  
  <!-- Background with rounded corners -->
  <rect width="1024" height="1024" rx="180" ry="180" fill="url(#bgGradient)" filter="url(#dropShadow)"/>
  
  <!-- Main Icon Content -->
  <g transform="translate(128, 128)" filter="url(#glow)">
    
    <!-- Terminal Window Frame -->
    <rect x="50" y="100" width="668" height="468" rx="24" ry="24" 
          fill="rgba(0,0,0,0.8)" stroke="url(#iconGradient)" stroke-width="3"/>
    
    <!-- Terminal Header -->
    <rect x="50" y="100" width="668" height="60" rx="24" ry="24" 
          fill="rgba(0,0,0,0.9)"/>
    <rect x="50" y="136" width="668" height="24" fill="rgba(0,0,0,0.9)"/>
    
    <!-- Window Controls -->
    <circle cx="90" cy="130" r="8" fill="#ff5f57"/>
    <circle cx="118" cy="130" r="8" fill="#ffbd2e"/>
    <circle cx="146" cy="130" r="8" fill="#28ca42"/>
    
    <!-- Terminal Content Area -->
    <rect x="74" y="180" width="620" height="364" fill="rgba(0,0,0,0.95)" rx="8"/>
    
    <!-- Code Brackets (Left) -->
    <path d="M150 220 L110 320 L150 420" 
          stroke="url(#iconGradient)" stroke-width="16" fill="none" 
          stroke-linecap="round" stroke-linejoin="round" opacity="0.9"/>
    
    <!-- Code Brackets (Right) -->
    <path d="M618 220 L658 320 L618 420" 
          stroke="url(#iconGradient)" stroke-width="16" fill="none" 
          stroke-linecap="round" stroke-linejoin="round" opacity="0.9"/>
    
    <!-- Terminal Cursor -->
    <rect x="380" y="300" width="20" height="40" fill="url(#iconGradient)" rx="3">
      <animate attributeName="opacity" values="1;0;1" dur="1.5s" repeatCount="indefinite"/>
    </rect>
    
    <!-- Code Lines -->
    <line x1="200" y1="240" x2="350" y2="240" 
          stroke="url(#iconGradient)" stroke-width="8" 
          stroke-linecap="round" opacity="0.7"/>
    <line x1="200" y1="270" x2="450" y2="270" 
          stroke="url(#iconGradient)" stroke-width="8" 
          stroke-linecap="round" opacity="0.6"/>
    <line x1="200" y1="340" x2="420" y2="340" 
          stroke="url(#iconGradient)" stroke-width="8" 
          stroke-linecap="round" opacity="0.7"/>
    <line x1="200" y1="370" x2="380" y2="370" 
          stroke="url(#iconGradient)" stroke-width="8" 
          stroke-linecap="round" opacity="0.5"/>
    <line x1="200" y1="400" x2="500" y2="400" 
          stroke="url(#iconGradient)" stroke-width="8" 
          stroke-linecap="round" opacity="0.6"/>
    
    <!-- AI Accent/Badge -->
    <circle cx="600" cy="180" r="28" fill="#4ade80" opacity="0.9"/>
    <text x="600" y="190" font-family="Arial, sans-serif" font-size="24" 
          font-weight="bold" fill="white" text-anchor="middle">AI</text>
    
  </g>
  
  <!-- Subtle Highlight -->
  <ellipse cx="300" cy="200" rx="200" ry="50" 
           fill="url(#iconGradient)" opacity="0.1"/>
  
</svg>
EOF
    
    print_success "Master template created: $template_path"
}

# Generate PNG from SVG template
generate_png_from_svg() {
    local svg_path="$1"
    local output_path="$2"
    local size="$3"
    
    if command -v rsvg-convert &> /dev/null; then
        # Use rsvg-convert for better SVG rendering
        rsvg-convert -w "$size" -h "$size" -f png -o "$output_path" "$svg_path"
    else
        # Fallback to ImageMagick
        convert -background transparent -size "${size}x${size}" "$svg_path" "$output_path"
    fi
    
    # Optimize PNG
    if command -v pngcrush &> /dev/null; then
        pngcrush -q "$output_path" "${output_path}.tmp" && mv "${output_path}.tmp" "$output_path"
    fi
}

# Generate all icon sizes
generate_all_icons() {
    local master_svg="$ICONS_DIR/icon_master.svg"
    
    print_header "Generating All Icon Sizes"
    
    # Create master template if it doesn't exist
    if [ ! -f "$master_svg" ]; then
        create_master_template
    fi
    
    # Create output directories
    mkdir -p "$ICONS_DIR/iOS"
    mkdir -p "$ICONS_DIR/AppStore"
    mkdir -p "$ICONS_DIR/Xcode"
    
    # Generate each required size
    for size_name in "${!ICON_SIZES[@]}"; do
        local pixel_size="${ICON_SIZES[$size_name]}"
        local output_path="$ICONS_DIR/iOS/icon_${size_name//@/_}.png"
        
        print_step "Generating ${size_name} (${pixel_size}x${pixel_size})"
        
        generate_png_from_svg "$master_svg" "$output_path" "$pixel_size"
        
        if [ -f "$output_path" ]; then
            print_success "Generated: icon_${size_name//@/_}.png"
        else
            print_warning "Failed to generate: $size_name"
        fi
    done
    
    # Generate special versions
    generate_app_store_icon "$master_svg"
    generate_xcode_assets "$master_svg"
    
    print_success "All icons generated successfully"
}

# Generate App Store specific icon
generate_app_store_icon() {
    local master_svg="$1"
    local app_store_path="$ICONS_DIR/AppStore/icon_1024x1024.png"
    
    print_step "Generating App Store icon (1024x1024)"
    
    generate_png_from_svg "$master_svg" "$app_store_path" "1024"
    
    # Additional optimization for App Store
    if command -v convert &> /dev/null; then
        # Ensure proper color profile and quality
        convert "$app_store_path" \
            -colorspace sRGB \
            -quality 95 \
            -strip \
            "$app_store_path"
    fi
    
    print_success "App Store icon generated"
}

# Generate Xcode asset catalog structure
generate_xcode_assets() {
    local master_svg="$1"
    local assets_dir="$ICONS_DIR/Xcode/AppIcon.appiconset"
    
    print_step "Generating Xcode asset catalog"
    
    mkdir -p "$assets_dir"
    
    # Create Contents.json for AppIcon.appiconset
    cat > "$assets_dir/Contents.json" << 'EOF'
{
  "images": [
    {
      "filename": "icon_20x20@2x.png",
      "idiom": "iphone",
      "scale": "2x",
      "size": "20x20"
    },
    {
      "filename": "icon_20x20@3x.png",
      "idiom": "iphone",
      "scale": "3x",
      "size": "20x20"
    },
    {
      "filename": "icon_29x29@2x.png",
      "idiom": "iphone",
      "scale": "2x",
      "size": "29x29"
    },
    {
      "filename": "icon_29x29@3x.png",
      "idiom": "iphone",
      "scale": "3x",
      "size": "29x29"
    },
    {
      "filename": "icon_40x40@2x.png",
      "idiom": "iphone",
      "scale": "2x",
      "size": "40x40"
    },
    {
      "filename": "icon_40x40@3x.png",
      "idiom": "iphone",
      "scale": "3x",
      "size": "40x40"
    },
    {
      "filename": "icon_60x60@2x.png",
      "idiom": "iphone",
      "scale": "2x",
      "size": "60x60"
    },
    {
      "filename": "icon_60x60@3x.png",
      "idiom": "iphone",
      "scale": "3x",
      "size": "60x60"
    },
    {
      "filename": "icon_20x20@1x.png",
      "idiom": "ipad",
      "scale": "1x",
      "size": "20x20"
    },
    {
      "filename": "icon_20x20@2x.png",
      "idiom": "ipad",
      "scale": "2x",
      "size": "20x20"
    },
    {
      "filename": "icon_29x29@1x.png",
      "idiom": "ipad",
      "scale": "1x",
      "size": "29x29"
    },
    {
      "filename": "icon_29x29@2x.png",
      "idiom": "ipad",
      "scale": "2x",
      "size": "29x29"
    },
    {
      "filename": "icon_40x40@1x.png",
      "idiom": "ipad",
      "scale": "1x",
      "size": "40x40"
    },
    {
      "filename": "icon_40x40@2x.png",
      "idiom": "ipad",
      "scale": "2x",
      "size": "40x40"
    },
    {
      "filename": "icon_76x76@1x.png",
      "idiom": "ipad",
      "scale": "1x",
      "size": "76x76"
    },
    {
      "filename": "icon_76x76@2x.png",
      "idiom": "ipad",
      "scale": "2x",
      "size": "76x76"
    },
    {
      "filename": "icon_83.5x83.5@2x.png",
      "idiom": "ipad",
      "scale": "2x",
      "size": "83.5x83.5"
    },
    {
      "filename": "icon_1024x1024@1x.png",
      "idiom": "ios-marketing",
      "scale": "1x",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
EOF

    # Generate icons for Xcode asset catalog
    local xcode_sizes=("20" "40" "60" "58" "87" "80" "120" "180" "29" "76" "152" "167" "1024")
    local xcode_names=("20x20@1x" "20x20@2x" "20x20@3x" "29x29@2x" "29x29@3x" "40x40@2x" "60x60@2x" "60x60@3x" "29x29@1x" "40x40@1x" "40x40@2x" "76x76@1x" "76x76@2x" "83.5x83.5@2x" "1024x1024@1x")
    
    for i in "${!xcode_sizes[@]}"; do
        local size="${xcode_sizes[$i]}"
        local name="${xcode_names[$i]}"
        local output_path="$assets_dir/icon_${name}.png"
        
        generate_png_from_svg "$master_svg" "$output_path" "$size"
    done
    
    print_success "Xcode asset catalog generated"
}

# Create alternative icon variations
create_icon_variations() {
    print_step "Creating icon variations..."
    
    local variations_dir="$ICONS_DIR/Variations"
    mkdir -p "$variations_dir"
    
    # Light mode variation
    create_light_mode_icon "$variations_dir"
    
    # Minimalist variation
    create_minimalist_icon "$variations_dir"
    
    # Monochrome variation
    create_monochrome_icon "$variations_dir"
    
    print_success "Icon variations created"
}

# Create light mode icon variation
create_light_mode_icon() {
    local output_dir="$1"
    local template_path="$output_dir/icon_light_mode.svg"
    
    cat > "$template_path" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGradientLight" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#f8fafc;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#e2e8f0;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#cbd5e1;stop-opacity:1" />
    </linearGradient>
    
    <linearGradient id="iconGradientDark" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1e293b;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#334155;stop-opacity:0.95" />
    </linearGradient>
  </defs>
  
  <!-- Background -->
  <rect width="1024" height="1024" rx="180" ry="180" fill="url(#bgGradientLight)"/>
  
  <!-- Icon content with dark elements on light background -->
  <g transform="translate(128, 128)">
    <!-- Terminal frame -->
    <rect x="50" y="100" width="668" height="468" rx="24" ry="24" 
          fill="url(#iconGradientDark)" stroke="#64748b" stroke-width="3"/>
    
    <!-- Code elements -->
    <path d="M150 220 L110 320 L150 420" 
          stroke="#3b82f6" stroke-width="16" fill="none" 
          stroke-linecap="round"/>
    <path d="M618 220 L658 320 L618 420" 
          stroke="#3b82f6" stroke-width="16" fill="none" 
          stroke-linecap="round"/>
          
    <!-- AI badge -->
    <circle cx="600" cy="180" r="28" fill="#10b981"/>
    <text x="600" y="190" font-family="Arial" font-size="24" 
          font-weight="bold" fill="white" text-anchor="middle">AI</text>
  </g>
</svg>
EOF

    # Generate PNG versions
    generate_png_from_svg "$template_path" "$output_dir/icon_light_1024.png" "1024"
    
    print_step "Light mode variation created"
}

# Create minimalist icon variation
create_minimalist_icon() {
    local output_dir="$1"
    local template_path="$output_dir/icon_minimalist.svg"
    
    cat > "$template_path" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgMinimal" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- Background -->
  <rect width="1024" height="1024" rx="180" ry="180" fill="url(#bgMinimal)"/>
  
  <!-- Minimal design -->
  <g transform="translate(312, 312)">
    <!-- Simple brackets -->
    <path d="M50 100 L20 200 L50 300" stroke="white" stroke-width="24" 
          fill="none" stroke-linecap="round"/>
    <path d="M350 100 L380 200 L350 300" stroke="white" stroke-width="24" 
          fill="none" stroke-linecap="round"/>
    
    <!-- Central element -->
    <circle cx="200" cy="200" r="20" fill="white"/>
  </g>
</svg>
EOF

    generate_png_from_svg "$template_path" "$output_dir/icon_minimalist_1024.png" "1024"
    
    print_step "Minimalist variation created"
}

# Create monochrome icon variation
create_monochrome_icon() {
    local output_dir="$1"
    
    # Convert main icon to monochrome using ImageMagick
    if [ -f "$ICONS_DIR/AppStore/icon_1024x1024.png" ] && command -v convert &> /dev/null; then
        convert "$ICONS_DIR/AppStore/icon_1024x1024.png" \
            -colorspace Gray \
            "$output_dir/icon_monochrome_1024.png"
        
        print_step "Monochrome variation created"
    fi
}

# Validate generated icons
validate_icons() {
    print_header "Validating Generated Icons"
    
    local validation_passed=true
    
    # Check critical icon sizes
    local critical_sizes=("60" "120" "180" "1024")
    
    for size in "${critical_sizes[@]}"; do
        local found_icon=""
        
        # Look for icon with this size
        find "$ICONS_DIR" -name "*${size}*.png" -type f | head -1 | while read icon_path; do
            if [ -n "$icon_path" ]; then
                # Verify actual dimensions
                if command -v identify &> /dev/null; then
                    local actual_size=$(identify -format "%w" "$icon_path")
                    if [ "$actual_size" = "$size" ]; then
                        print_success "✓ ${size}x${size} icon verified"
                    else
                        print_warning "✗ ${size}x${size} icon has wrong dimensions: ${actual_size}x${actual_size}"
                        validation_passed=false
                    fi
                else
                    print_success "✓ ${size}x${size} icon exists"
                fi
            else
                print_warning "✗ Missing ${size}x${size} icon"
                validation_passed=false
            fi
        done
    done
    
    # Check App Store icon specifically
    local app_store_icon="$ICONS_DIR/AppStore/icon_1024x1024.png"
    if [ -f "$app_store_icon" ]; then
        local file_size=$(stat -f%z "$app_store_icon" 2>/dev/null || stat -c%s "$app_store_icon" 2>/dev/null)
        if [ "$file_size" -gt 1000000 ]; then  # 1MB
            print_warning "App Store icon is very large: $(($file_size / 1024))KB"
        else
            print_success "App Store icon size is acceptable"
        fi
    else
        print_warning "App Store icon not found"
        validation_passed=false
    fi
    
    if [ "$validation_passed" = true ]; then
        print_success "Icon validation completed successfully"
    else
        print_warning "Some icons may need attention"
    fi
}

# Copy icons to Resources directory
copy_to_resources() {
    print_step "Copying icons to Resources directory..."
    
    if [ ! -d "$RESOURCES_DIR" ]; then
        mkdir -p "$RESOURCES_DIR"
    fi
    
    # Copy Xcode asset catalog
    if [ -d "$ICONS_DIR/Xcode/AppIcon.appiconset" ]; then
        cp -r "$ICONS_DIR/Xcode/AppIcon.appiconset" "$RESOURCES_DIR/"
        print_success "AppIcon.appiconset copied to Resources"
    fi
    
    # Copy App Store icon
    if [ -f "$ICONS_DIR/AppStore/icon_1024x1024.png" ]; then
        cp "$ICONS_DIR/AppStore/icon_1024x1024.png" "$RESOURCES_DIR/AppStoreIcon.png"
        print_success "App Store icon copied to Resources"
    fi
}

# Generate icon usage documentation
generate_documentation() {
    print_step "Generating icon documentation..."
    
    cat > "$ICONS_DIR/README.md" << 'EOF'
# Claude Code iOS App Icons

This directory contains all generated app icons for Claude Code iOS in various sizes and formats.

## Directory Structure

```
Icons/
├── iOS/                    # All iOS icon sizes
├── AppStore/              # App Store specific icons
├── Xcode/                 # Xcode asset catalog
│   └── AppIcon.appiconset/
├── Variations/            # Alternative icon designs
└── icon_master.svg        # Master SVG template
```

## Icon Sizes

### iPhone
- 20x20 @2x, @3x (Settings)
- 29x29 @2x, @3x (Settings/Spotlight)  
- 40x40 @2x, @3x (Spotlight)
- 60x60 @2x, @3x (App icon)

### iPad  
- 20x20 @1x, @2x (Settings)
- 29x29 @1x, @2x (Settings/Spotlight)
- 40x40 @1x, @2x (Spotlight)
- 76x76 @1x, @2x (App icon)
- 83.5x83.5 @2x (iPad Pro)

### App Store
- 1024x1024 @1x (App Store listing)

## Usage

### Xcode Integration
1. Copy `AppIcon.appiconset` to your project's `Resources` directory
2. Reference in Xcode asset catalog
3. Ensure `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in build settings

### App Store Connect
Use the 1024x1024 PNG from the AppStore directory for App Store listings.

## Design Guidelines

The Claude Code icon features:
- Modern gradient background (#667eea to #764ba2)
- Terminal/code editor representation
- AI accent badge in green
- Professional developer tools aesthetic
- Optimized for iOS icon guidelines

## Customization

To modify the icon design:
1. Edit `icon_master.svg`
2. Run `./Scripts/icon-generator.sh all` to regenerate all sizes
3. Validate with `./Scripts/icon-generator.sh validate`

## Quality Assurance

All icons are:
- Generated from vector source for scalability
- Optimized for file size
- Validated for correct dimensions
- Designed for high-DPI displays
- Following Apple's Human Interface Guidelines
EOF
    
    print_success "Documentation generated"
}

# Main function
main() {
    local command="${1:-all}"
    
    case $command in
        "all")
            check_dependencies
            create_master_template
            generate_all_icons
            create_icon_variations
            validate_icons
            copy_to_resources
            generate_documentation
            ;;
        "template")
            create_master_template
            ;;
        "generate")
            check_dependencies
            generate_all_icons
            ;;
        "variations")
            create_icon_variations
            ;;
        "validate")
            validate_icons
            ;;
        "copy")
            copy_to_resources
            ;;
        "docs")
            generate_documentation
            ;;
        "clean")
            rm -rf "$ICONS_DIR"
            print_success "Icons directory cleaned"
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  all         - Generate all icons and assets (default)"
            echo "  template    - Create master SVG template only"
            echo "  generate    - Generate PNG icons from template"
            echo "  variations  - Create icon variations"
            echo "  validate    - Validate generated icons"
            echo "  copy        - Copy icons to Resources directory"
            echo "  docs        - Generate documentation"
            echo "  clean       - Remove all generated icons"
            echo ""
            exit 1
            ;;
    esac
    
    print_header "Icon Generation Complete!"
    echo -e "${GREEN}Icons available in: $ICONS_DIR${NC}"
    echo -e "${BLUE}Xcode assets: $ICONS_DIR/Xcode/AppIcon.appiconset${NC}"
    echo -e "${PURPLE}App Store icon: $ICONS_DIR/AppStore/icon_1024x1024.png${NC}"
}

# Run main function
main "$@"