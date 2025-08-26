# App Preview Video Script for Claude Code iOS

## Video Specifications
- **Duration**: 15-30 seconds
- **Format**: MOV (H.264, AAC audio)
- **Frame Rate**: 30 fps
- **Quality**: High (suitable for App Store)

## Device-Specific Requirements

### iPhone 15 Pro Max (6.7")
- **Resolution**: 1290x2796 (Portrait)
- **Aspect Ratio**: 9:19.5
- **Max File Size**: 500MB

### iPhone 15 Pro (6.1")
- **Resolution**: 1179x2556 (Portrait)
- **Aspect Ratio**: 9:19.5
- **Max File Size**: 500MB

### iPad Pro 12.9" (6th gen)
- **Resolution**: 2048x2732 (Portrait)
- **Aspect Ratio**: 3:4
- **Max File Size**: 500MB

### iPad Pro 11" (4th gen)
- **Resolution**: 1668x2388 (Portrait)
- **Aspect Ratio**: 139:199
- **Max File Size**: 500MB

## Script Variations

### Version 1: Quick Feature Demo (30 seconds)
Perfect for showcasing core functionality across all devices.

#### Timeline:
```
0:00-0:03  App Launch & Welcome Screen
0:03-0:08  AI Code Assistant Demo
0:08-0:15  SSH Terminal Connection
0:15-0:22  Code Editor Features
0:22-0:27  File Management
0:27-0:30  App Icon & Closing
```

#### Detailed Actions:

**0:00-0:03: Launch & Welcome**
- Show app icon tap
- Splash screen with Claude Code branding
- Quick transition to main interface

**0:03-0:08: AI Code Assistant**
- Open code editor with sample file
- Type partial code (e.g., "function calculateT...")
- Show AI autocomplete popup
- Accept suggestion with animation
- Show Claude AI badge/indicator

**0:08-0:15: SSH Terminal**
- Tap terminal tab/button
- Show connection dialog with server details (blur sensitive info)
- Connect animation
- Terminal prompt appears
- Execute simple command (ls, pwd, or ps)
- Show colored output

**0:15-0:22: Code Editor Features**
- Return to editor
- Show syntax highlighting (multiple languages)
- Demonstrate code folding
- Quick search/replace
- Line numbers and minimap (if available)

**0:22-0:27: File Management**
- Open file browser/explorer
- Navigate through project folders
- Create new file gesture
- Show file operations (copy, rename)

**0:27-0:30: Closing**
- Zoom out to show full interface
- Brief app icon display
- Fade to "Claude Code" text

### Version 2: Professional Developer Workflow (30 seconds)
Focus on professional development scenarios.

#### Timeline:
```
0:00-0:05  Remote Server Connection
0:05-0:12  Live Code Editing & Git
0:12-0:20  AI-Assisted Debugging
0:20-0:25  Mobile-First Features
0:25-0:30  Productivity Showcase
```

#### Detailed Actions:

**0:00-0:05: Remote Connection**
- Show SSH connection setup
- Server connection with loading indicator
- Terminal session established
- Quick server info display (hostname, uptime)

**0:05-0:12: Code & Git**
- Open existing project file
- Make code changes with proper syntax highlighting
- Show git status indicator
- Quick commit with message
- Push animation/indicator

**0:12-0:20: AI Debugging**
- Introduce deliberate code error
- Show error highlighting
- Invoke Claude AI help
- Display AI suggestion bubble
- Apply fix with animation

**0:20-0:25: Mobile Features**
- Demonstrate touch gestures (pinch to zoom, swipe)
- Show landscape/portrait rotation
- Quick multitasking (if iPad)
- External keyboard connection indicator

**0:25-0:30: Productivity**
- Fast-switch between multiple files
- Split view (iPad) or tabs
- App icon with notification badge
- "Available on App Store" text

### Version 3: Learning & Education Focus (25 seconds)
Targeted at students and learning developers.

#### Timeline:
```
0:00-0:04  Tutorial/Learning Mode
0:04-0:10  Interactive Code Examples
0:10-0:17  AI Learning Assistant
0:17-0:22  Progress Tracking
0:22-0:25  Community Features
```

## Production Guidelines

### Visual Style
- **Clean UI**: Minimize distracting elements
- **Smooth Animations**: 60fps where possible
- **Consistent Branding**: Claude Code colors and fonts
- **Professional Look**: Avoid amateur recording artifacts

### Audio Considerations
- **No Narration**: Visual-only demonstration
- **Subtle Sound Effects**: UI interaction sounds (optional)
- **Background Music**: Light, tech-focused (if used)

### Text Overlays (Optional)
- **Minimal Text**: Let actions speak
- **Key Features**: Brief callouts for major features
- **Localization**: Consider text-free approach for global appeal

## Recording Setup

### Simulator Configuration
```bash
# Set up simulator environment
export SIMULATOR_UUID="A707456B-44DB-472F-9722-C88153CDFFA1"

# Configure appearance
xcrun simctl ui $SIMULATOR_UUID appearance dark  # or light

# Set device orientation
xcrun simctl ui $SIMULATOR_UUID orientation portrait
```

### Demo Data Preparation
- **Sample Code Files**: Pre-written examples in popular languages
- **Fake Server Credentials**: Safe, demo-only SSH connections
- **Git Repository**: Sample project with commit history
- **AI Responses**: Pre-cached or scripted AI interactions

### Recording Commands
```bash
# Start recording
xcrun simctl io $SIMULATOR_UUID recordVideo --type=mov output_video.mov

# Perform demo actions...

# Stop recording (kill process or use duration limit)
# Process will stop automatically after specified duration
```

## Post-Production Checklist

### Technical Requirements
- [ ] Correct resolution for target device
- [ ] Frame rate: 30 fps minimum
- [ ] Audio: AAC encoding (if included)
- [ ] Video: H.264 encoding
- [ ] File size under 500MB
- [ ] Duration 15-30 seconds

### Content Review
- [ ] No personal/sensitive information visible
- [ ] All UI elements properly displayed
- [ ] Smooth transitions and animations
- [ ] Consistent branding throughout
- [ ] Professional appearance

### App Store Compliance
- [ ] No promotional text in video
- [ ] Accurate representation of app functionality
- [ ] No comparison with competitors
- [ ] Appropriate for all audiences
- [ ] Follows App Store Review Guidelines

## Device-Specific Considerations

### iPhone Previews
- **Portrait Only**: Focus on single-hand usage
- **Touch Interactions**: Emphasize thumb-friendly design
- **Quick Actions**: Show efficiency for on-the-go use

### iPad Previews
- **Landscape Options**: Show multitasking capabilities
- **Larger Screen**: Demonstrate split-view and pro features
- **External Input**: Apple Pencil or keyboard if applicable

## Localization Notes

### Text-Free Approach
- Design demos to be universally understood
- Use visual cues instead of text overlays
- Rely on UI elements rather than explanatory text

### Multiple Language Versions
- If creating localized versions, ensure UI text is translated
- Consider cultural differences in workflow demonstration
- Adapt demo scenarios to local development practices

## Template Scenarios by Programming Language

### Web Development
- HTML/CSS editing with live preview
- JavaScript debugging with console output
- React component development

### Mobile Development
- Swift/Kotlin syntax highlighting
- iOS/Android project structure
- Build and deployment simulation

### Data Science
- Python notebook-style editing
- Data visualization previews
- AI-assisted code generation

### DevOps
- Docker commands in terminal
- CI/CD pipeline interaction
- Server monitoring and logs

## Accessibility Considerations

- **High Contrast**: Ensure good visibility
- **Clear Actions**: Make interactions obvious
- **Readable Text**: Appropriate font sizes
- **Smooth Motion**: Avoid jarring transitions that might cause issues

## Brand Consistency

### Visual Elements
- Claude Code logo placement
- Consistent color scheme (#667eea to #764ba2 gradient)
- Professional typography
- Clean, modern interface design

### Messaging
- Professional development focus
- AI-powered assistance emphasis
- Mobile productivity benefits
- Accessibility and inclusion

This script provides comprehensive guidance for creating compelling App Store preview videos that showcase Claude Code's key features while meeting Apple's technical and content requirements.