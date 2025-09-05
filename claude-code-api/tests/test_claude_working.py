#!/usr/bin/env python3
"""
Test that demonstrates Claude CLI is working and create a proper test
"""

import subprocess
import json
import time

def test_claude_directly():
    """Test Claude CLI directly to prove it works"""
    print("🧪 Testing Claude CLI directly...")
    
    cmd = [
        "/usr/local/share/nvm/versions/node/v23.11.1/bin/claude",
        "-p", "Say hello and return",
        "--model", "claude-3-5-haiku-20241022", 
        "--output-format", "stream-json",
        "--verbose",
        "--dangerously-skip-permissions"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        print(f"✅ Exit code: {result.returncode}")
        if result.stdout:
            lines = result.stdout.strip().split('\n')
            print(f"✅ Got {len(lines)} lines of output")
            for i, line in enumerate(lines[:3]):  # Show first 3 lines
                try:
                    data = json.loads(line)
                    print(f"   Line {i+1}: {data.get('type', 'unknown')} - {line[:100]}...")
                except:
                    print(f"   Line {i+1}: {line[:100]}...")
        
        if result.stderr:
            print(f"⚠️  stderr: {result.stderr[:200]}")
            
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("❌ Command timed out")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_api_with_real_claude():
    """Test if our API is working now"""
    import requests
    
    print("\n🌐 Testing API with real Claude...")
    
    try:
        # Test health first
        health = requests.get("http://localhost:8000/health", timeout=5)
        print(f"Health check: {health.status_code}")
        
        # Test chat completion
        payload = {
            "model": "claude-3-5-haiku-20241022",
            "messages": [{"role": "user", "content": "Hi"}],
            "stream": False
        }
        
        print("Making chat completion request...")
        response = requests.post(
            "http://localhost:8000/v1/chat/completions",
            json=payload,
            timeout=30
        )
        
        print(f"✅ Chat completion status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            if 'choices' in data:
                content = data['choices'][0]['message']['content']
                print(f"✅ Response: {content[:100]}...")
                return True
        else:
            print(f"❌ Error response: {response.text[:200]}")
            
    except requests.exceptions.Timeout:
        print("❌ API request timed out")
    except Exception as e:
        print(f"❌ API test error: {e}")
    
    return False

if __name__ == "__main__":
    print("🚀 Testing Claude Code Integration")
    print("=" * 50)
    
    # Test 1: Direct Claude CLI
    claude_works = test_claude_directly()
    
    # Test 2: API with Claude  
    api_works = test_api_with_real_claude()
    
    print("\n" + "=" * 50)
    print(f"📊 Results:")
    print(f"   Claude CLI: {'✅ WORKS' if claude_works else '❌ FAILS'}")
    print(f"   API:        {'✅ WORKS' if api_works else '❌ FAILS'}")
    
    if claude_works and not api_works:
        print("\n💡 Claude CLI works but API fails - this means the issue is in our Python async handling!")
    elif claude_works and api_works:
        print("\n🎉 Everything works! API is ready!")
    else:
        print("\n❌ Claude CLI itself has issues")