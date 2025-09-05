# Claude Code API Backend Integration

## Overview
The Claude Code API backend has been successfully integrated into the Shannon iOS project. The backend provides an OpenAI-compatible API gateway for Claude Code with enhanced project management capabilities.

## Directory Structure
```
claude-code-api/
├── claude_code_api/
│   ├── api/                  # API endpoint implementations
│   │   ├── chat.py           # Chat completions endpoint
│   │   ├── models.py         # Model management endpoints
│   │   ├── projects.py       # Project management endpoints
│   │   └── sessions.py       # Session management endpoints
│   ├── core/                 # Core functionality
│   │   ├── auth.py           # Authentication middleware
│   │   ├── config.py         # Configuration settings
│   │   ├── database.py       # Database management
│   │   ├── session_manager.py # Session lifecycle management
│   │   └── claude_manager.py # Claude Code integration
│   ├── models/               # Data models
│   │   ├── claude.py         # Claude-specific models
│   │   └── openai.py         # OpenAI-compatible models
│   ├── utils/                # Utility functions
│   │   ├── parser.py         # Response parsing
│   │   └── streaming.py      # SSE streaming support
│   └── main.py               # FastAPI application entry point
├── tests/                    # Test suite
├── assets/                   # Static assets
├── pyproject.toml           # Python package configuration
└── setup.py                 # Package setup script
```

## Available API Endpoints

### Health & Status
- `GET /` - API information and available endpoints
- `GET /health` - Health check with Claude version info

### Chat Operations (OpenAI-compatible)
- `POST /v1/chat/completions` - Create chat completion (streaming supported)
- `GET /v1/chat/completions/{session_id}/status` - Check completion status
- `POST /v1/chat/completions/debug` - Debug chat endpoint
- `DELETE /v1/chat/completions/{session_id}` - Cancel active completion

### Model Management
- `GET /v1/models` - List available models
- `GET /v1/models/{model_id}` - Get specific model details
- `GET /v1/models/capabilities` - Get model capabilities

### Project Management
- `GET /v1/projects` - List all projects (paginated)
- `POST /v1/projects` - Create new project
- `GET /v1/projects/{project_id}` - Get project details
- `DELETE /v1/projects/{project_id}` - Delete project

### Session Management
- `GET /v1/sessions` - List active sessions (paginated)
- `POST /v1/sessions` - Create new session
- `GET /v1/sessions/{session_id}` - Get session details
- `DELETE /v1/sessions/{session_id}` - End session
- `GET /v1/sessions/stats` - Get session statistics

## Backend Requirements

### Python Dependencies (from pyproject.toml)
- Python >=3.10
- FastAPI >=0.104.0
- Uvicorn with standard extras >=0.24.0
- Pydantic >=2.5.0
- HTTPx >=0.25.0
- Structlog >=23.2.0
- SQLAlchemy >=2.0.23
- Alembic >=1.13.0
- PassLib with bcrypt >=1.7.4
- Python-JOSE with cryptography >=3.3.0
- OpenAI SDK >=1.0.0
- Additional utilities for async operations, file handling, and configuration

### Key Features
1. **OpenAI Compatibility**: Drop-in replacement for OpenAI API
2. **Streaming Support**: Real-time SSE streaming for chat completions
3. **Session Management**: Persistent session handling with cleanup
4. **Project Management**: Create and manage Claude Code projects
5. **Authentication**: JWT-based auth with bcrypt password hashing
6. **Database**: SQLAlchemy with async SQLite support
7. **Structured Logging**: Using structlog for comprehensive logging
8. **CORS Support**: Configurable CORS for cross-origin requests

## Setup Instructions

### 1. Install Python Dependencies
```bash
cd /Users/nick/Documents/shannon-ios/claude-code-api
pip install -e .  # Install in development mode
# or
pip install -r requirements.txt  # If requirements.txt exists
```

### 2. Configure Environment Variables
Create a `.env` file in the claude-code-api directory:
```env
# API Configuration
API_HOST=0.0.0.0
API_PORT=8000

# Security
SECRET_KEY=your-secret-key-here
API_KEY=your-api-key-here

# Database
DATABASE_URL=sqlite+aiosqlite:///./claude_code.db

# Claude Code Configuration
CLAUDE_CODE_PATH=/usr/local/bin/claude
```

### 3. Initialize Database
```bash
cd claude-code-api
python -c "from claude_code_api.core.database import create_tables; import asyncio; asyncio.run(create_tables())"
```

### 4. Run the Backend
```bash
# Development mode with auto-reload
uvicorn claude_code_api.main:app --reload --host 0.0.0.0 --port 8000

# or using the package entry point
python -m claude_code_api.main
```

## Integration with iOS App

### API Base URL
The iOS app should connect to: `http://localhost:8000/v1`

### Authentication Headers
```swift
let headers = [
    "Authorization": "Bearer \(apiKey)",
    "Content-Type": "application/json"
]
```

### Example: Chat Completion Request
```swift
let request = [
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
        ["role": "user", "content": "Hello, Claude!"]
    ],
    "stream": true
]
```

### SSE Streaming Support
The backend supports Server-Sent Events for real-time streaming of responses. The iOS app's existing SSE implementation should work seamlessly with these endpoints.

## Testing the Backend

### Quick Test with cURL
```bash
# Health check
curl http://localhost:8000/health

# List models
curl http://localhost:8000/v1/models \
  -H "Authorization: Bearer your-api-key"

# Create chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Integration Status
✅ Repository cloned successfully
✅ .git directory removed
✅ Backend structure documented
✅ API endpoints identified
✅ Dependencies documented
✅ Setup instructions provided
✅ Integration guide for iOS app created

## Next Steps
1. Install Python dependencies
2. Configure environment variables
3. Run the backend server
4. Update iOS app API client to point to local backend
5. Test end-to-end integration

## Notes
- The backend provides a bridge between the iOS app and Claude Code CLI
- All OpenAI-compatible endpoints are available at `/v1/*`
- The backend handles session management and project persistence
- Streaming is fully supported through Server-Sent Events (SSE)