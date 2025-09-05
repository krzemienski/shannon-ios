"""Claude Code specific models and utilities."""

from datetime import datetime
from typing import List, Optional, Dict, Any, Union, Literal
from pydantic import BaseModel, Field
from enum import Enum


class ClaudeModel(str, Enum):
    """Available Claude models - matching Claude Code CLI supported models."""
    OPUS_4 = "claude-opus-4-20250514"
    SONNET_4 = "claude-sonnet-4-20250514"
    SONNET_37 = "claude-3-7-sonnet-20250219"
    HAIKU_35 = "claude-3-5-haiku-20241022"


class ClaudeMessageType(str, Enum):
    """Claude message types from JSONL output."""
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    RESULT = "result"
    ERROR = "error"
    TOOL_USE = "tool_use"
    TOOL_RESULT = "tool_result"


class ClaudeToolType(str, Enum):
    """Claude Code built-in tools."""
    BASH = "bash"
    EDIT = "edit"
    READ = "read"
    WRITE = "write"
    LS = "ls"
    GREP = "grep"
    GLOB = "glob"
    TODO_WRITE = "todowrite"
    MULTI_EDIT = "multiedit"


class ClaudeMessage(BaseModel):
    """Claude message from JSONL output."""
    type: str = Field(..., description="Message type")
    subtype: Optional[str] = Field(None, description="Message subtype")
    message: Optional[Dict[str, Any]] = Field(None, description="Message content")
    session_id: Optional[str] = Field(None, description="Session ID")
    model: Optional[str] = Field(None, description="Model used")
    cwd: Optional[str] = Field(None, description="Current working directory")
    tools: Optional[List[str]] = Field(None, description="Available tools")
    result: Optional[str] = Field(None, description="Execution result")
    error: Optional[str] = Field(None, description="Error message")
    usage: Optional[Dict[str, Any]] = Field(None, description="Token usage")
    cost_usd: Optional[float] = Field(None, description="Cost in USD")
    duration_ms: Optional[int] = Field(None, description="Duration in milliseconds")
    num_turns: Optional[int] = Field(None, description="Number of turns")
    timestamp: Optional[str] = Field(None, description="Timestamp")


class ClaudeToolUse(BaseModel):
    """Claude tool use information."""
    id: str = Field(..., description="Tool use ID")
    name: str = Field(..., description="Tool name")
    input: Dict[str, Any] = Field(..., description="Tool input parameters")


class ClaudeToolResult(BaseModel):
    """Claude tool result information."""
    tool_use_id: str = Field(..., description="Tool use ID")
    content: Union[str, Dict[str, Any]] = Field(..., description="Tool result content")
    is_error: Optional[bool] = Field(False, description="Whether this is an error result")


class ClaudeSessionInfo(BaseModel):
    """Claude session information."""
    session_id: str = Field(..., description="Session ID")
    project_path: str = Field(..., description="Project path")
    model: str = Field(..., description="Model being used")
    started_at: datetime = Field(..., description="Session start time")
    is_running: bool = Field(..., description="Whether session is running")
    total_tokens: int = Field(0, description="Total tokens used")
    total_cost: float = Field(0.0, description="Total cost")
    message_count: int = Field(0, description="Number of messages")


class ClaudeProcessStatus(str, Enum):
    """Claude process status."""
    STARTING = "starting"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    STOPPED = "stopped"
    TIMEOUT = "timeout"


class ClaudeExecutionRequest(BaseModel):
    """Claude execution request."""
    prompt: str = Field(..., description="User prompt")
    project_path: str = Field(..., description="Project path")
    model: Optional[str] = Field(None, description="Model to use")
    system_prompt: Optional[str] = Field(None, description="System prompt")
    resume_session: Optional[str] = Field(None, description="Session ID to resume")
    stream: bool = Field(True, description="Whether to stream output")


class ClaudeExecutionResponse(BaseModel):
    """Claude execution response."""
    session_id: str = Field(..., description="Session ID")
    status: ClaudeProcessStatus = Field(..., description="Execution status")
    messages: List[ClaudeMessage] = Field(..., description="Messages from execution")
    total_tokens: int = Field(0, description="Total tokens used")
    total_cost: float = Field(0.0, description="Total cost")
    duration_ms: int = Field(0, description="Execution duration")


class ClaudeStreamingChunk(BaseModel):
    """Claude streaming chunk."""
    session_id: str = Field(..., description="Session ID")
    chunk_type: str = Field(..., description="Type of chunk")
    data: ClaudeMessage = Field(..., description="Chunk data")
    is_final: bool = Field(False, description="Whether this is the final chunk")


class ClaudeProjectConfig(BaseModel):
    """Claude project configuration."""
    project_id: str = Field(..., description="Project ID")
    name: str = Field(..., description="Project name")
    path: str = Field(..., description="Project path")
    default_model: str = Field(ClaudeModel.HAIKU_35, description="Default model")
    system_prompt: Optional[str] = Field(None, description="Default system prompt")
    tools_enabled: List[ClaudeToolType] = Field(default_factory=list, description="Enabled tools")
    max_tokens: Optional[int] = Field(None, description="Maximum tokens per request")
    temperature: Optional[float] = Field(None, description="Temperature setting")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation time")
    updated_at: datetime = Field(default_factory=datetime.utcnow, description="Last update time")


class ClaudeFileInfo(BaseModel):
    """Claude file information."""
    path: str = Field(..., description="File path")
    name: str = Field(..., description="File name")
    size: int = Field(..., description="File size in bytes")
    modified_at: datetime = Field(..., description="Last modified time")
    is_directory: bool = Field(..., description="Whether this is a directory")
    extension: Optional[str] = Field(None, description="File extension")


class ClaudeWorkspaceInfo(BaseModel):
    """Claude workspace information."""
    path: str = Field(..., description="Workspace path")
    files: List[ClaudeFileInfo] = Field(..., description="Files in workspace")
    total_files: int = Field(..., description="Total number of files")
    total_size: int = Field(..., description="Total size in bytes")
    claude_md_files: List[str] = Field(..., description="CLAUDE.md files found")


class ClaudeVersionInfo(BaseModel):
    """Claude version information."""
    version: str = Field(..., description="Claude Code version")
    build: Optional[str] = Field(None, description="Build information")
    is_available: bool = Field(..., description="Whether Claude is available")
    path: str = Field(..., description="Path to Claude binary")


class ClaudeErrorInfo(BaseModel):
    """Claude error information."""
    error_type: str = Field(..., description="Type of error")
    message: str = Field(..., description="Error message")
    session_id: Optional[str] = Field(None, description="Session ID where error occurred")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Error timestamp")
    traceback: Optional[str] = Field(None, description="Error traceback")


class ClaudeMetrics(BaseModel):
    """Claude usage metrics."""
    total_sessions: int = Field(..., description="Total number of sessions")
    active_sessions: int = Field(..., description="Currently active sessions")
    total_tokens: int = Field(..., description="Total tokens processed")
    total_cost: float = Field(..., description="Total cost incurred")
    avg_session_duration_ms: float = Field(..., description="Average session duration")
    most_used_model: str = Field(..., description="Most frequently used model")
    tool_usage_stats: Dict[str, int] = Field(..., description="Tool usage statistics")
    error_rate: float = Field(..., description="Error rate percentage")


class ClaudeModelInfo(BaseModel):
    """Claude model information."""
    id: str = Field(..., description="Model ID")
    name: str = Field(..., description="Model display name")
    description: str = Field(..., description="Model description")
    max_tokens: int = Field(..., description="Maximum tokens supported")
    input_cost_per_1k: float = Field(..., description="Input cost per 1K tokens")
    output_cost_per_1k: float = Field(..., description="Output cost per 1K tokens")
    supports_streaming: bool = Field(True, description="Whether model supports streaming")
    supports_tools: bool = Field(True, description="Whether model supports tool use")


# Utility functions for model validation
def validate_claude_model(model: str) -> str:
    """Validate and normalize Claude model name."""
    # Direct Claude model names
    valid_models = [model.value for model in ClaudeModel]
    
    if model in valid_models:
        return model
    
    # Default to Haiku for testing
    return ClaudeModel.HAIKU_35


def get_default_model() -> str:
    """Get the default Claude model."""
    return ClaudeModel.HAIKU_35


def get_model_info(model_id: str) -> ClaudeModelInfo:
    """Get information about a Claude model."""
    model_info = {
        ClaudeModel.OPUS_4: ClaudeModelInfo(
            id=ClaudeModel.OPUS_4,
            name="Claude Opus 4",
            description="Most powerful Claude model for complex reasoning",
            max_tokens=500000,
            input_cost_per_1k=15.0,
            output_cost_per_1k=75.0,
            supports_streaming=True,
            supports_tools=True
        ),
        ClaudeModel.SONNET_4: ClaudeModelInfo(
            id=ClaudeModel.SONNET_4,
            name="Claude Sonnet 4",
            description="Latest Sonnet model with enhanced capabilities",
            max_tokens=500000,
            input_cost_per_1k=3.0,
            output_cost_per_1k=15.0,
            supports_streaming=True,
            supports_tools=True
        ),
        ClaudeModel.SONNET_37: ClaudeModelInfo(
            id=ClaudeModel.SONNET_37,
            name="Claude Sonnet 3.7",
            description="Advanced Sonnet model for complex tasks",
            max_tokens=200000,
            input_cost_per_1k=3.0,
            output_cost_per_1k=15.0,
            supports_streaming=True,
            supports_tools=True
        ),
        ClaudeModel.HAIKU_35: ClaudeModelInfo(
            id=ClaudeModel.HAIKU_35,
            name="Claude Haiku 3.5",
            description="Fast and cost-effective model for quick tasks",
            max_tokens=200000,
            input_cost_per_1k=0.25,
            output_cost_per_1k=1.25,
            supports_streaming=True,
            supports_tools=True
        )
    }
    
    return model_info.get(model_id, model_info[ClaudeModel.HAIKU_35])


def get_available_models() -> List[ClaudeModelInfo]:
    """Get list of all available Claude models."""
    return [get_model_info(model) for model in ClaudeModel]
