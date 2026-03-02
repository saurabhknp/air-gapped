#!/usr/bin/env python3
"""
Minimal proxy between Codex and llama-server. Normalizes the request "tools"
array so every tool has type "function", which fixes the 400 error:
  'type' of tool must be 'function'
Codex may send tools with other types (e.g. code_interpreter); llama-server
only accepts type "function". We filter and normalize, then forward.
Uses stdlib only (no extra deps). Set BACKEND_URL and LISTEN_PORT in env.
"""

import json
import os
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler


BACKEND = os.environ.get("CODEX_PROXY_BACKEND", "http://127.0.0.1:28080").rstrip("/")
LISTEN_PORT = int(os.environ.get("CODEX_PROXY_PORT", "28081"))


def normalize_tools(tools: list) -> list:
    """Keep only tools that can be sent as type 'function'; ensure type is set."""
    out = []
    for t in tools:
        if not isinstance(t, dict):
            continue
        # Already correct
        if t.get("type") == "function":
            out.append(t)
            continue
        # Has "function" key but missing or wrong type (e.g. Codex schema)
        if "function" in t:
            t = dict(t)
            t["type"] = "function"
            out.append(t)
            continue
        # Other types (code_interpreter, etc.) are dropped
    return out


def _apply_tools_inplace(obj: dict, depth: int = 0) -> None:
    """Find every 'tools' key in obj and replace with normalized list (max depth 10)."""
    if depth > 10:
        return
    for key, val in list(obj.items()):
        if key == "tools" and isinstance(val, list):
            normalized = normalize_tools(val)
            if not normalized:
                obj.pop("tools", None)
            else:
                obj["tools"] = normalized
        elif isinstance(val, dict):
            _apply_tools_inplace(val, depth + 1)
        elif isinstance(val, list):
            for item in val:
                if isinstance(item, dict):
                    _apply_tools_inplace(item, depth + 1)


def parse_and_rewrite_body(body: bytes, path: str) -> bytes:
    """If path is chat/completions or responses (Codex) and body has tools, normalize tools."""
    if "chat/completions" not in path and "responses" not in path:
        return body
    try:
        data = json.loads(body.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return body
    if not isinstance(data, dict):
        return body
    _apply_tools_inplace(data)
    return json.dumps(data, ensure_ascii=False).encode("utf-8")


class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._forward(body=None)

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length else b""
        if body and ("/chat/completions" in self.path or "/responses" in self.path):
            body = parse_and_rewrite_body(body, self.path)
        self._forward(body=body)

    def do_OPTIONS(self):
        self._forward(body=None)

    def _forward(self, body=None):
        url = BACKEND + self.path
        req_headers = {k: v for k, v in self.headers.items() if k.lower() not in ("host", "connection")}
        if body is not None:
            req_headers["Content-Length"] = str(len(body))
        try:
            req = urllib.request.Request(url, data=body, headers=req_headers, method=self.command)
            with urllib.request.urlopen(req, timeout=300) as resp:
                self.send_response(resp.status)
                # Forward headers but drop transfer-encoding/connection; we stream with chunked
                for k, v in resp.headers.items():
                    kl = k.lower()
                    if kl in ("transfer-encoding", "connection", "content-length"):
                        continue
                    if kl == "content-length":
                        # We stream; backend may send chunked, so don't forward content-length
                        continue
                    self.send_header(k, v)
                # Stream body in chunks so client gets data as backend produces it
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                chunk_size = 8192
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    self.wfile.write(("%x\r\n" % len(chunk)).encode())
                    self.wfile.write(chunk)
                    self.wfile.write(b"\r\n")
                    try:
                        self.wfile.flush()
                    except (BrokenPipeError, ConnectionResetError):
                        break
                self.wfile.write(b"0\r\n\r\n")
                try:
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError):
                    pass
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in ("transfer-encoding", "connection"):
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(e.read())
        except urllib.error.URLError as e:
            self.send_response(502)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Bad Gateway: {e.reason}\n".encode())
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Proxy error: {e}\n".encode())

    def log_message(self, format, *args):
        pass  # quiet by default


def main():
    server = HTTPServer(("127.0.0.1", LISTEN_PORT), ProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
