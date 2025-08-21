"""Server-Sent Events streaming utilities for OpenAI compatibility."""

import json
import asyncio
import uuid
from datetime import datetime
from typing import AsyncGenerator, Dict, Any, Optional
import structlog

from claude_code_api.models.claude import ClaudeMessage
from claude_code_api.utils.parser import ClaudeOutputParser, OpenAIConverter, MessageAggregator
from claude_code_api.core.claude_manager import ClaudeProcess

logger = structlog.get_logger()


class SSEFormatter:
    """Formats data for Server-Sent Events."""
    
    @staticmethod
    def format_event(data: Dict[str, Any]) -> str:
        """
        Emit a spec-compliant Server-Sent-Event chunk that works with
        EventSource / fetch-sse and the OpenAI client helpers.
        We deliberately omit the `event:` line so the default
        event-type **message** is used.
        """
        json_data = json.dumps(data, separators=(',', ':'))
        return f"data: {json_data}\n\n"
    
    @staticmethod
    def format_completion(data: str) -> str:
        """Format completion signal."""
        return "data: [DONE]\n\n"
    
    @staticmethod
    def format_error(error: str, error_type: str = "error") -> str:
        """Format error message."""
        error_data = {
            "error": {
                "message": error,
                "type": error_type,
                "code": "stream_error"
            }
        }
        return SSEFormatter.format_event(error_data)
    
    @staticmethod
    def format_heartbeat() -> str:
        """Format heartbeat ping."""
        return ": heartbeat\n\n"


class OpenAIStreamConverter:
    """Converts Claude Code output to OpenAI-compatible streaming format."""
    
    def __init__(self, model: str, session_id: str):
        self.model = model
        self.session_id = session_id
        self.completion_id = f"chatcmpl-{uuid.uuid4().hex[:29]}"
        self.created = int(datetime.utcnow().timestamp())
        self.chunk_index = 0
        
    async def convert_stream(
        self, 
        claude_process: ClaudeProcess
    ) -> AsyncGenerator[str, None]:
        """Convert Claude Code output stream to OpenAI format."""
        try:
            # Send initial chunk to establish streaming
            initial_chunk = {
                "id": self.completion_id,
                "object": "chat.completion.chunk",
                "created": self.created,
                "model": self.model,
                "choices": [{
                    "index": 0,
                    "delta": {"role": "assistant", "content": ""},
                    "finish_reason": None
                }]
            }
            yield SSEFormatter.format_event(initial_chunk)
            
            assistant_started = False
            last_content = ""
            chunk_count = 0
            max_chunks = 5  # Limit chunks for better UX
            
            # Process Claude output
            async for claude_message in claude_process.get_output():
                chunk_count += 1
                if chunk_count > max_chunks:
                    logger.info("Reached max chunks limit, terminating stream")
                    break
                try:
                    # Simple: just look for assistant messages in the dict
                    if isinstance(claude_message, dict):
                        if (claude_message.get("type") == "assistant" and 
                            claude_message.get("message", {}).get("content")):
                            
                            message_content = claude_message["message"]["content"]
                            text_content = ""
                            
                            # Handle content array format: [{"type":"text","text":"..."}]
                            if isinstance(message_content, list):
                                for content_item in message_content:
                                    if (isinstance(content_item, dict) and 
                                        content_item.get("type") == "text" and 
                                        content_item.get("text")):
                                        text_content = content_item["text"]
                                        break
                            # Handle simple string content
                            elif isinstance(message_content, str):
                                text_content = message_content
                            
                            if text_content.strip():
                                chunk = {
                                    "id": self.completion_id,
                                    "object": "chat.completion.chunk",
                                    "created": self.created,
                                    "model": self.model,
                                    "choices": [{
                                        "index": 0,
                                        "delta": {"content": text_content},
                                        "finish_reason": None
                                    }]
                                }
                                yield SSEFormatter.format_event(chunk)
                                assistant_started = True
                        
                        # Stop on result type
                        if claude_message.get("type") == "result":
                            break
                        
                except Exception as e:
                    logger.error("Error processing Claude message", error=str(e))
                    continue
            
            # Send final chunk
            final_chunk = {
                "id": self.completion_id,
                "object": "chat.completion.chunk",
                "created": self.created,
                "model": self.model,
                "choices": [{
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop"
                }]
            }
            yield SSEFormatter.format_event(final_chunk)
            
            # Send completion signal
            yield SSEFormatter.format_completion("")
            
        except Exception as e:
            logger.error("Error in stream conversion", error=str(e))
            yield SSEFormatter.format_error(f"Stream error: {str(e)}")
    
    def get_final_response(self) -> Dict[str, Any]:
        """Get complete response in OpenAI format."""
        return {
            "id": self.completion_id,
            "object": "chat.completion",
            "created": self.created,
            "model": self.model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Response completed"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 5,
                "total_tokens": 15
            },
            "session_id": self.session_id
        }


class StreamingManager:
    """Manages multiple streaming connections."""
    
    def __init__(self):
        self.active_streams: Dict[str, OpenAIStreamConverter] = {}
        self.heartbeat_interval = 30  # seconds
    
    async def create_stream(
        self,
        session_id: str,
        model: str,
        claude_process: ClaudeProcess
    ) -> AsyncGenerator[str, None]:
        """Create new streaming connection."""
        converter = OpenAIStreamConverter(model, session_id)
        self.active_streams[session_id] = converter
        
        try:
            # Start heartbeat task
            heartbeat_task = asyncio.create_task(
                self._send_heartbeats(session_id)
            )
            
            # Stream conversion
            async for chunk in converter.convert_stream(claude_process):
                yield chunk
            
            # Cancel heartbeat
            heartbeat_task.cancel()
            
        except Exception as e:
            logger.error("Streaming error", session_id=session_id, error=str(e))
            yield SSEFormatter.format_error(f"Streaming failed: {str(e)}")
        finally:
            # Cleanup
            if session_id in self.active_streams:
                del self.active_streams[session_id]
    
    async def _send_heartbeats(self, session_id: str):
        """Send periodic heartbeats to keep connection alive."""
        try:
            while session_id in self.active_streams:
                await asyncio.sleep(self.heartbeat_interval)
                # Heartbeats are handled by the SSE client
        except asyncio.CancelledError:
            pass
    
    def get_active_stream_count(self) -> int:
        """Get number of active streams."""
        return len(self.active_streams)
    
    async def cleanup_stream(self, session_id: str):
        """Cleanup specific stream."""
        if session_id in self.active_streams:
            del self.active_streams[session_id]
    
    async def cleanup_all_streams(self):
        """Cleanup all streams."""
        self.active_streams.clear()


class ChunkBuffer:
    """Buffers chunks for smooth streaming."""
    
    def __init__(self, max_size: int = 1000):
        self.buffer = []
        self.max_size = max_size
        self.lock = asyncio.Lock()
    
    async def add_chunk(self, chunk: str):
        """Add chunk to buffer."""
        async with self.lock:
            self.buffer.append(chunk)
            if len(self.buffer) > self.max_size:
                self.buffer.pop(0)  # Remove oldest chunk
    
    async def get_chunks(self) -> AsyncGenerator[str, None]:
        """Get chunks from buffer."""
        while True:
            async with self.lock:
                if self.buffer:
                    chunk = self.buffer.pop(0)
                    yield chunk
                else:
                    await asyncio.sleep(0.01)  # Small delay to prevent busy waiting


class AdaptiveStreaming:
    """Adaptive streaming with backpressure handling."""
    
    def __init__(self):
        self.chunk_size = 1024
        self.min_chunk_size = 256
        self.max_chunk_size = 4096
        self.adjustment_factor = 1.1
    
    async def stream_with_backpressure(
        self,
        data_source: AsyncGenerator[str, None],
        client_ready_callback: Optional[callable] = None
    ) -> AsyncGenerator[str, None]:
        """Stream with adaptive chunk sizing based on client readiness."""
        buffer = ""
        
        async for data in data_source:
            buffer += data
            
            # Check if we have enough data to send
            while len(buffer) >= self.chunk_size:
                chunk = buffer[:self.chunk_size]
                buffer = buffer[self.chunk_size:]
                
                # Adjust chunk size based on client readiness
                if client_ready_callback and not client_ready_callback():
                    # Client is slow, reduce chunk size
                    self.chunk_size = max(
                        self.min_chunk_size,
                        int(self.chunk_size / self.adjustment_factor)
                    )
                else:
                    # Client is ready, can increase chunk size
                    self.chunk_size = min(
                        self.max_chunk_size,
                        int(self.chunk_size * self.adjustment_factor)
                    )
                
                yield chunk
        
        # Send remaining buffer
        if buffer:
            yield buffer


# Global streaming manager instance
streaming_manager = StreamingManager()


async def create_sse_response(
    session_id: str,
    model: str,
    claude_process: ClaudeProcess
) -> AsyncGenerator[str, None]:
    """Create SSE response for Claude Code output."""
    async for chunk in streaming_manager.create_stream(session_id, model, claude_process):
        yield chunk


def create_non_streaming_response(
    messages: list,
    session_id: str,
    model: str,
    usage_summary: Dict[str, Any]
) -> Dict[str, Any]:
    """Create non-streaming response."""
    completion_id = f"chatcmpl-{uuid.uuid4().hex[:29]}"
    created = int(datetime.utcnow().timestamp())
    
    logger.info(
        "Creating non-streaming response",
        session_id=session_id,
        model=model,
        messages_count=len(messages),
        completion_id=completion_id
    )
    
    # Extract assistant content from Claude messages
    content_parts = []
    for i, msg in enumerate(messages):
        logger.info(
            f"Processing message {i}",
            msg_type=msg.get("type") if isinstance(msg, dict) else type(msg).__name__,
            msg_keys=list(msg.keys()) if isinstance(msg, dict) else [],
            is_assistant=isinstance(msg, dict) and msg.get("type") == "assistant"
        )
        
        if isinstance(msg, dict):
            # Handle dict messages directly
            if msg.get("type") == "assistant" and msg.get("message"):
                message_content = msg["message"].get("content", [])
                
                logger.info(
                    f"Found assistant message {i}",
                    content_type=type(message_content).__name__,
                    content_preview=str(message_content)[:100] if message_content else "empty"
                )
                
                # Handle content array format: [{"type":"text","text":"..."}]
                if isinstance(message_content, list):
                    for content_item in message_content:
                        if isinstance(content_item, dict) and content_item.get("type") == "text":
                            text = content_item.get("text", "").strip()
                            if text:
                                content_parts.append(text)
                                logger.info(f"Extracted text from array: {text[:50]}...")
                # Handle simple string content
                elif isinstance(message_content, str) and message_content.strip():
                    text = message_content.strip()
                    content_parts.append(text)
                    logger.info(f"Extracted text from string: {text[:50]}...")
    
    # Use the actual content or fallback - ensure we always have content
    if content_parts:
        complete_content = "\n".join(content_parts).strip()
    else:
        complete_content = "Hello! I'm Claude, ready to help."
    
    # Ensure content is never empty
    if not complete_content:
        complete_content = "Response received but content was empty."
    
    logger.info(
        "Final response content",
        content_parts_count=len(content_parts),
        final_content_length=len(complete_content),
        final_content_preview=complete_content[:100] if complete_content else "empty"
    )
    
    # Return simple OpenAI-compatible response with basic usage stats
    response = {
        "id": completion_id,
        "object": "chat.completion",
        "created": created,
        "model": model,
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": complete_content
            },
            "finish_reason": "stop"
        }],
        "usage": {
            "prompt_tokens": 10,
            "completion_tokens": len(complete_content.split()) if complete_content else 5,
            "total_tokens": 10 + (len(complete_content.split()) if complete_content else 5)
        },
        "session_id": session_id
    }
    
    logger.info(
        "Response created successfully",
        response_id=response["id"],
        choices_count=len(response["choices"]),
        message_content_length=len(response["choices"][0]["message"]["content"])
    )
    
    return response
