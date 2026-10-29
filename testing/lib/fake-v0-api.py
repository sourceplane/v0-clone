#!/usr/bin/env python3
"""A stand-in for the v0 Platform API — just the calls the v0 clone's two
Workers make that need no generation: list chats (the key check), the
trusted preview hosts, a chat's preview, and the preview app itself.

  fake-v0-api.py <port-file> --key <api-key> [--chat <id>]

Only `Authorization: Bearer <api-key>` is answered; anything else is v0's
401. The preview URL it hands out is its own origin (v0's previews are origins;
the proxy maps paths onto them), where every path outside /v2/ answers only
the short-lived token it issued (x-v0-preview-token), so a page served
through the proxy proves the proxy fetched the preview with the key.
Every request is logged to stderr as `METHOD /path`.
"""
import json, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

port_file = sys.argv[1]
key = sys.argv[sys.argv.index("--key") + 1]
chat = sys.argv[sys.argv.index("--chat") + 1] if "--chat" in sys.argv else "chat_e2e"
TOKEN = "preview-token-e2e"
state = {"hosts": ["old.example"]}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("content-type", ctype)
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self, method):
        path = urlparse(self.path).path
        sys.stderr.write(f"{method} {path}\n"); sys.stderr.flush()
        if not path.startswith("/v2/"):
            if self.headers.get("x-v0-preview-token") != TOKEN:
                return self.send(401, b"no preview token", "text/plain")
            return self.send(200, b'<!doctype html><html><body><h1 id="design-mode-test">Hello from the preview</h1></body></html>', "text/html")
        if self.headers.get("authorization") != f"Bearer {key}":
            return self.send(401, {"message": "Invalid API key."})
        length = int(self.headers.get("content-length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}") if length else {}
        if path == "/v2/chats" and method == "GET":
            return self.send(200, {"chats": [], "cursor": None})
        if path == "/v2/settings/preview-hosts":
            if method == "GET":
                return self.send(200, {"hosts": state["hosts"]})
            if method in ("PUT", "POST"):
                state["hosts"] = list(body.get("hosts") or [])
                sys.stderr.write("HOSTS " + ",".join(state["hosts"]) + "\n"); sys.stderr.flush()
                return self.send(200, {"hosts": state["hosts"]})
        if path == f"/v2/chats/{chat}/preview" and method == "GET":
            host = self.headers.get("host")
            return self.send(200, {"url": f"http://{host}/", "token": TOKEN, "expiresAt": "2099-01-01T00:00:00.000Z"})
        return self.send(404, {"message": f"stand-in v0 API: no {method} {path}"})

    def do_GET(self): self.handle_any("GET")
    def do_PUT(self): self.handle_any("PUT")
    def do_POST(self): self.handle_any("POST")

srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(port_file, "w").write(str(srv.server_address[1]))
srv.serve_forever()
