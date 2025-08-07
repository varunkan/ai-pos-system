#!/usr/bin/env python3
"""
Simple web server for Flutter web app with CORS support
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

PORT = 8080

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

def main():
    # Change to the web build directory
    web_dir = Path(__file__).parent / 'build' / 'web'
    if not web_dir.exists():
        print(f"❌ Web build directory not found: {web_dir}")
        print("Please run 'flutter build web' first")
        sys.exit(1)
    
    os.chdir(web_dir)
    
    print("🌐 AI POS System Web Server")
    print("📍 Serving from:", web_dir.absolute())
    print("🔗 Local URL: http://localhost:8080")
    print("🌍 Network URL: http://0.0.0.0:8080")
    print("📱 Access from any device on your network")
    print("⏹️  Press Ctrl+C to stop server")
    print("-" * 50)
    
    try:
        with socketserver.TCPServer(("", PORT), CORSHTTPRequestHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"❌ Port {PORT} is already in use")
            print("Please stop any existing server or use a different port")
        else:
            print(f"❌ Server error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 