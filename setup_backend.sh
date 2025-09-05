#!/bin/bash

# Claude Code API Backend Setup Script
# This script sets up the Python backend for iOS integration

echo "================================================"
echo "Claude Code API Backend Setup for iOS"
echo "================================================"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.10+"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "✅ Python version: $PYTHON_VERSION"

# Check if Claude Code CLI is installed
if ! command -v claude &> /dev/null; then
    echo "⚠️  Claude Code CLI not found. Please install it first."
    echo "   Visit: https://claude.ai/code"
else
    echo "✅ Claude Code CLI found at: $(which claude)"
fi

# Navigate to backend directory
cd claude-code-api || { echo "❌ Backend directory not found"; exit 1; }

echo ""
echo "📦 Installing Python dependencies..."
echo "================================================"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -e .

echo ""
echo "🔧 Setting up environment variables..."
echo "================================================"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
# Claude Code API Configuration
ANTHROPIC_API_KEY=your_api_key_here
CLAUDE_BINARY_PATH=/usr/local/bin/claude
PROJECT_ROOT=./projects
DATABASE_URL=sqlite:///claude_code.db
REQUIRE_AUTH=false
ALLOWED_ORIGINS=["http://localhost:3000", "http://localhost:8080", "capacitor://localhost", "ionic://localhost"]
DEFAULT_MODEL=claude-3-5-haiku-20241022
LOG_LEVEL=INFO
EOF
    echo "✅ Created .env file - Please update with your API key"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "🧪 Running backend tests..."
echo "================================================"

# Run basic tests
make test-health 2>/dev/null || python -m pytest tests/test_health.py -v
make test-models 2>/dev/null || python -m pytest tests/test_models.py -v

echo ""
echo "🚀 Starting backend server..."
echo "================================================"
echo "Starting server on http://localhost:8000"
echo "API Documentation: http://localhost:8000/docs"
echo "Health Check: http://localhost:8000/health"
echo ""
echo "Press Ctrl+C to stop the server"
echo "================================================"

# Start the server
python -m claude_code_api.main

# Alternatively, use make command if available
# make start-dev