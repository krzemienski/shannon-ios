# Claude Code iOS User Manual

## Welcome to Claude Code

Claude Code is your AI-powered development assistant on iOS, bringing the intelligence of Claude AI directly to your iPhone or iPad. This manual will guide you through all features and capabilities of the app.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Main Features](#main-features)
3. [Chat Interface](#chat-interface)
4. [Project Management](#project-management)
5. [SSH Terminal](#ssh-terminal)
6. [Settings & Customization](#settings--customization)
7. [Tools & Extensions](#tools--extensions)
8. [Monitoring & Analytics](#monitoring--analytics)
9. [Tips & Tricks](#tips--tricks)
10. [Troubleshooting](#troubleshooting)
11. [FAQ](#frequently-asked-questions)

## Getting Started

### First Launch

When you first open Claude Code, you'll be guided through a simple setup process:

1. **Welcome Screen**
   - Tap "Get Started" to begin setup
   - Review app capabilities

2. **API Configuration**
   - Enter your Claude API key
   - Choose default model (Opus, Sonnet, or Haiku)
   - Test connection

3. **Security Setup**
   - Enable Face ID/Touch ID for API key protection
   - Set up app passcode (optional)

4. **Personalization**
   - Choose theme preferences
   - Set default text size
   - Configure notification preferences

### Main Interface Overview

The app uses a tab-based navigation with five main sections:

```
┌─────────────────────────────────────┐
│         Claude Code                 │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │      Main Content Area      │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  [Chat] [Projects] [Tools]         │
│  [Monitor] [Settings]              │
└─────────────────────────────────────┘
```

## Main Features

### 1. AI Chat

The heart of Claude Code - intelligent conversations with Claude AI.

**Key Capabilities:**
- Multiple AI models (Opus, Sonnet, Haiku)
- Code generation and explanation
- Debugging assistance
- Architecture recommendations
- Best practices guidance

**How to Use:**
1. Tap the Chat tab
2. Type your message or code question
3. Tap Send or press Return
4. View streaming response in real-time

### 2. Project Organization

Keep your conversations organized by project context.

**Features:**
- Create unlimited projects
- Separate conversation history per project
- Project-specific settings
- Environment variables
- Quick project switching

### 3. SSH Terminal

Built-in terminal for remote development.

**Capabilities:**
- SSH connections to remote servers
- Multiple simultaneous sessions
- Command history
- File transfer support
- Port forwarding

### 4. Code Tools

Integrated development tools.

**Available Tools:**
- Syntax highlighting (100+ languages)
- Code formatting
- Diff viewer
- JSON/XML validators
- Regular expression tester
- Base64 encoder/decoder

### 5. Performance Monitoring

Track app and system performance.

**Metrics:**
- API response times
- Token usage
- Memory consumption
- Network statistics
- SSH session monitoring

## Chat Interface

### Starting a Conversation

1. **New Chat**
   - Tap the "+" button
   - Select project context (optional)
   - Choose AI model
   - Start typing

2. **Message Types**
   - Text messages
   - Code blocks (automatic detection)
   - Images (for visual questions)
   - Files (drag and drop support)

### Message Formatting

**Markdown Support:**
```markdown
# Headers
**Bold text**
*Italic text*
`inline code`
```code blocks```
- Lists
1. Numbered lists
> Quotes
```

### Code Blocks

**Automatic Language Detection:**
- Swift, Python, JavaScript, etc.
- Syntax highlighting
- Copy button for easy sharing
- Line numbers (optional)

**Example:**
```swift
func greet(name: String) -> String {
    return "Hello, \(name)!"
}
```

### Conversation Features

**Actions per Message:**
- Copy text or code
- Share via iOS Share Sheet
- Edit and resend
- Delete message
- Pin important messages

**Conversation Management:**
- Export conversation (PDF, Markdown, JSON)
- Clear history
- Search within conversation
- Jump to date

## Project Management

### Creating a Project

1. Navigate to Projects tab
2. Tap "New Project"
3. Enter project details:
   - Name (required)
   - Description
   - Default model
   - Environment variables

### Project Settings

**Configuration Options:**
- **Model Selection**: Choose default AI model
- **Temperature**: Control response creativity (0.0 - 1.0)
- **Max Tokens**: Set response length limit
- **System Prompt**: Custom instructions for AI
- **API Endpoint**: Override default API URL

### Environment Variables

Set project-specific variables:

```bash
API_KEY=your_api_key
DATABASE_URL=postgresql://...
DEBUG_MODE=true
```

Access in conversations:
- Reference with `$VARIABLE_NAME`
- Automatic substitution in code blocks

### Project Templates

**Available Templates:**
- iOS App Development
- Web Development
- Python Scripts
- Data Science
- DevOps
- Custom Template

## SSH Terminal

### Adding SSH Connection

1. Go to Terminal section
2. Tap "Add Connection"
3. Enter connection details:
   ```
   Host: example.com
   Port: 22
   Username: user
   Authentication: Password/Key
   ```

### Authentication Methods

**Password Authentication:**
- Enter password when prompted
- Option to save in Keychain

**SSH Key Authentication:**
1. Import existing key or generate new
2. Add public key to server
3. Connect using private key

### Terminal Features

**Session Management:**
- Multiple tabs
- Split view (iPad)
- Session persistence
- Background execution

**Customization:**
- Font size adjustment
- Color schemes
- Cursor styles
- Keyboard shortcuts

### File Transfer

**Upload Files:**
1. Tap upload button
2. Select file from Files app
3. Choose destination path

**Download Files:**
1. Long-press on file in terminal
2. Select "Download"
3. Choose save location

## Settings & Customization

### Appearance

**Theme Options:**
- Cyberpunk (Default)
- Dark Mode
- Light Mode
- High Contrast
- Custom Theme

**Customizable Elements:**
- Primary accent color
- Background style
- Font family and size
- Animation speed
- Neon glow intensity

### API Configuration

**Settings:**
```yaml
Base URL: http://localhost:8000
API Version: v1
Timeout: 30 seconds
Retry Attempts: 3
Cache Duration: 1 hour
```

### Security Settings

**Options:**
- Biometric authentication
- Auto-lock timeout
- Secure clipboard
- Screenshot blocking
- Jailbreak detection

### Data Management

**Features:**
- Export all data
- Import backup
- Clear cache
- Reset to defaults
- Storage usage

## Tools & Extensions

### MCP Tools

**Available Tools:**
- Code analyzer
- Documentation generator
- Test creator
- Dependency checker
- Performance profiler

**Using Tools:**
1. Select tool from Tools tab
2. Configure parameters
3. Run tool
4. View results

### Custom Tools

**Adding Custom Tool:**
```json
{
  "name": "my_tool",
  "description": "Custom tool description",
  "parameters": {
    "input": "string",
    "options": "object"
  }
}
```

## Monitoring & Analytics

### Dashboard Overview

**Real-time Metrics:**
- Active sessions
- API calls/minute
- Token usage
- Error rate
- Response time

### Performance Tracking

**Charts Available:**
- Response time trend
- Token usage over time
- Error frequency
- Model performance comparison

### SSH Monitoring

**Session Metrics:**
- Connection status
- Bandwidth usage
- Command history
- Session duration
- Active processes

## Tips & Tricks

### Productivity Tips

1. **Quick Actions**
   - Swipe left on message for options
   - Long-press for context menu
   - Shake to undo

2. **Keyboard Shortcuts** (iPad)
   - `Cmd + N`: New chat
   - `Cmd + K`: Clear conversation
   - `Cmd + /`: Show shortcuts
   - `Cmd + ,`: Settings

3. **Gestures**
   - Two-finger swipe: Navigate back
   - Pinch: Zoom code blocks
   - Three-finger tap: Show toolbar

### Best Practices

**For Better Responses:**
- Be specific in your questions
- Provide context and examples
- Use project settings for consistency
- Break complex tasks into steps

**For Performance:**
- Clear old conversations regularly
- Use appropriate model for task
- Enable response caching
- Limit max tokens when possible

### Hidden Features

1. **Triple-tap status bar**: Developer menu
2. **Long-press tab bar**: Quick switch
3. **Swipe down with two fingers**: Global search
4. **Shake device**: Report bug

## Troubleshooting

### Common Issues

#### Connection Problems

**Issue**: "Cannot connect to API"

**Solutions:**
1. Check internet connection
2. Verify API key is correct
3. Ensure API server is running
4. Check firewall settings
5. Try different network

#### Slow Performance

**Issue**: App feels sluggish

**Solutions:**
1. Clear app cache
2. Reduce max tokens
3. Close unused sessions
4. Restart app
5. Free up device storage

#### SSH Connection Failed

**Issue**: Cannot connect to server

**Solutions:**
1. Verify host and port
2. Check credentials
3. Ensure server allows SSH
4. Try different authentication method
5. Check network restrictions

### Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| API_KEY_INVALID | Invalid API key | Check key in Settings |
| RATE_LIMIT_EXCEEDED | Too many requests | Wait before retrying |
| NETWORK_ERROR | Connection failed | Check internet |
| SESSION_EXPIRED | Session timeout | Reconnect |
| INSUFFICIENT_TOKENS | Token limit reached | Upgrade plan |

### Getting Help

**Support Options:**
1. In-app help (Settings > Help)
2. Email: support@claudecode.app
3. Documentation: docs.claudecode.app
4. Community forum: forum.claudecode.app

## Frequently Asked Questions

### General

**Q: Which Claude model should I use?**
A: 
- Haiku: Fast, efficient for simple tasks
- Sonnet: Balanced performance and capability
- Opus: Most capable, best for complex tasks

**Q: Can I use Claude Code offline?**
A: Messages are queued offline and sent when connection returns. SSH and API features require internet.

**Q: How secure is my API key?**
A: API keys are stored in iOS Keychain with biometric protection and are never transmitted except to the API server.

### Features

**Q: Can I export my conversations?**
A: Yes, export as PDF, Markdown, or JSON from the conversation menu.

**Q: How many projects can I create?**
A: Unlimited projects with no restrictions.

**Q: Can I customize the AI's behavior?**
A: Yes, use system prompts in project settings to customize responses.

### Technical

**Q: What languages are supported for syntax highlighting?**
A: Over 100 languages including Swift, Python, JavaScript, Go, Rust, and more.

**Q: Can I connect to multiple SSH servers?**
A: Yes, save unlimited SSH connections and switch between them.

**Q: Is iPad supported?**
A: Yes, with optimized layout and keyboard shortcuts.

### Billing

**Q: Is Claude Code free?**
A: The app is free to download. You need your own Claude API key.

**Q: How is API usage billed?**
A: Through your Anthropic account based on token usage.

**Q: Can I track my usage?**
A: Yes, view detailed usage statistics in the Monitor tab.

---

## Keyboard Shortcuts (iPad)

| Shortcut | Action |
|----------|--------|
| `Cmd + N` | New conversation |
| `Cmd + W` | Close current tab |
| `Cmd + T` | New terminal session |
| `Cmd + K` | Clear conversation |
| `Cmd + F` | Search |
| `Cmd + ,` | Settings |
| `Cmd + 1-5` | Switch tabs |
| `Cmd + Shift + [` | Previous tab |
| `Cmd + Shift + ]` | Next tab |
| `Cmd + Return` | Send message |

---

## Contact & Support

**Need Help?**
- Email: support@claudecode.app
- Twitter: @ClaudeCodeApp
- GitHub: github.com/claudecode/ios

**Report Issues:**
- Use in-app feedback (Settings > Feedback)
- GitHub Issues for bugs
- Feature requests welcome!

---

Thank you for using Claude Code! We're constantly improving the app based on your feedback.