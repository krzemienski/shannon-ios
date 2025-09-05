#!/bin/bash

# Claude Code API Backend Setup Script
# This script sets up the Claude Code API backend for the Shannon iOS project

echo "==================================="
echo "Claude Code API Backend Setup"
echo "==================================="

# Check Python version
echo "Checking Python version..."
python3 --version

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
else
    echo "Virtual environment already exists"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat > .env << EOF
# Claude Code API Configuration
API_HOST=0.0.0.0
API_PORT=8000

# Security (change these in production!)
SECRET_KEY=dev-secret-key-change-in-production
API_KEY=dev-api-key-change-in-production

# Database
DATABASE_URL=sqlite+aiosqlite:///./claude_code.db

# Claude Code Path
CLAUDE_CODE_PATH=/usr/local/bin/claude

# CORS Origins (comma-separated)
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,capacitor://localhost,http://localhost

# Logging
LOG_LEVEL=INFO
EOF
    echo ".env file created with default values"
    echo "⚠️  Please update the SECRET_KEY and API_KEY in .env for security"
else
    echo ".env file already exists"
fi

# Initialize database
echo "Initializing database..."
python3 -c "
import asyncio
import sys
import os
sys.path.insert(0, os.getcwd())
from claude_code_api.core.database import create_tables

async def init_db():
    await create_tables()
    print('Database initialized successfully')

asyncio.run(init_db())
" 2>/dev/null || echo "Note: Database initialization will happen on first run"

echo ""
echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo ""
echo "To run the backend:"
echo "  1. Activate the virtual environment: source venv/bin/activate"
echo "  2. Run the server: uvicorn claude_code_api.main:app --reload"
echo ""
echo "The API will be available at: http://localhost:8000"
echo "API Documentation: http://localhost:8000/docs"
echo ""
echo "For iOS integration, use base URL: http://localhost:8000/v1"