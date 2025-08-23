#!/usr/bin/env python3
"""
Minimal test script to check backend connectivity
"""
import requests
import sys

def test_backend():
    backend_url = "http://localhost:8000"
    
    print(f"Testing backend at {backend_url}...")
    
    try:
        # Test health endpoint
        response = requests.get(f"{backend_url}/health", timeout=5)
        print(f"Health check: {response.status_code}")
        if response.status_code == 200:
            print("✅ Backend is healthy")
            print(f"Response: {response.json()}")
        else:
            print(f"❌ Backend returned status {response.status_code}")
            return False
            
        # Test API info endpoint
        response = requests.get(f"{backend_url}/api/v1/", timeout=5)
        print(f"\nAPI info check: {response.status_code}")
        if response.status_code == 200:
            print("✅ API is accessible")
            print(f"Response: {response.json()}")
        else:
            print(f"❌ API returned status {response.status_code}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to backend - is it running?")
        print("Start the backend with: cd backend && python -m uvicorn main:app --reload")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_backend()
    sys.exit(0 if success else 1)