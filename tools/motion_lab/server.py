"""Loopback-only HTTP interface. Production hosting requires a separate hardened gateway."""

from __future__ import annotations

import argparse
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
from urllib.parse import urlsplit

from .service import LabError, MAX_BODY, MotionService, strict_json


def make_server(service, token, port=8765, origins=()):
    if not isinstance(token, str) or not 24 <= len(token) <= 256 or not token.isascii() or not token.isprintable():
        raise LabError("Bridge token must contain 24..256 printable ASCII characters")
    allowed_origins = set(origins)
    for origin in allowed_origins:
        parsed = urlsplit(origin)
        if parsed.scheme not in ("http", "https") or not parsed.hostname or "*" in origin or parsed.path or parsed.query or parsed.fragment or parsed.username:
            raise LabError("Origins must be exact http(s)://host[:port] values; no wildcards")

    class Handler(BaseHTTPRequestHandler):
        server_version = "ssok-motion-lab/1"
        timeout = 5

        def log_message(self, format, *args):
            pass

        def _origin(self):
            origin = self.headers.get("Origin")
            return origin is None or origin in allowed_origins

        def _host(self):
            actual_port = self.server.server_address[1]
            return self.headers.get("Host") in {f"127.0.0.1:{actual_port}", f"localhost:{actual_port}"}

        def _reply(self, code, payload):
            encoded = json.dumps(payload, allow_nan=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Connection", "close")
            origin = self.headers.get("Origin")
            if origin in allowed_origins:
                self.send_header("Access-Control-Allow-Origin", origin)
                self.send_header("Vary", "Origin")
                self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
                self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.end_headers()
            try:
                self.wfile.write(encoded)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def _authorize(self):
            if not self._host() or not self._origin():
                self._reply(403, {"error": "Host or browser origin is not allowed"})
                return False
            if not hmac.compare_digest(self.headers.get("Authorization", "").encode(), ("Bearer " + token).encode()):
                self._reply(401, {"error": "Enter the local bridge token, not an OpenAI API key"})
                return False
            return True

        def do_OPTIONS(self):
            if not self._host() or not self._origin():
                self._reply(403, {"error": "Origin denied"})
                return
            self._reply(200, {})

        def do_GET(self):
            if not self._authorize():
                return
            try:
                if self.path == "/v1/status":
                    self._reply(200, service.describe())
                elif self.path.startswith("/v1/search/") and self.path.count("/") == 3:
                    self._reply(200, service.get(self.path.rsplit("/", 1)[-1]))
                elif self.path.startswith("/v1/pickup/") and self.path.count("/") == 3:
                    self._reply(200, service.pickup.get(self.path.rsplit("/", 1)[-1]))
                else:
                    self._reply(404, {"error": "Unknown endpoint"})
            except LabError as exc:
                self._reply(400, {"error": str(exc)})

        def do_POST(self):
            if not self._authorize():
                return
            if self.headers.get_content_type() != "application/json":
                self._reply(415, {"error": "Use application/json"})
                return
            try:
                if self.headers.get("Transfer-Encoding") or len(self.headers.get_all("Content-Length", [])) != 1:
                    raise LabError("Exactly one Content-Length is required")
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= MAX_BODY:
                    self._reply(413, {"error": "Request must be 1..65536 bytes"})
                    return
                self.connection.settimeout(5)
                body = self.rfile.read(size)
                if len(body) != size:
                    raise LabError("Incomplete request body")
                payload = strict_json(body)
                if self.path == "/v1/search":
                    self._reply(202, service.start(payload))
                elif self.path == "/v1/pickup/propose":
                    self._reply(202, service.pickup.start(payload))
                elif self.path.startswith("/v1/pickup/") and self.path.endswith("/cancel") and self.path.count("/") == 4:
                    if payload != {}:
                        raise LabError("Cancel body must be an empty object")
                    self._reply(200, service.pickup.cancel(self.path.split("/")[3]))
                elif self.path.startswith("/v1/search/") and self.path.endswith("/cancel") and self.path.count("/") == 4:
                    if payload != {}:
                        raise LabError("Cancel body must be an empty object")
                    self._reply(200, service.cancel(self.path.split("/")[3]))
                else:
                    self._reply(404, {"error": "Unknown endpoint"})
            except (LabError, ValueError, TimeoutError) as exc:
                self._reply(400, {"error": str(exc) if isinstance(exc, LabError) else "Invalid request"})

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="Enable paid OpenAI requests (still requires per-search consent)")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--max-calls", type=int, default=8)
    parser.add_argument("--origin", action="append", default=[], help="Explicit browser Origin allowed, e.g. http://localhost:8060")
    args = parser.parse_args()
    service = MotionService(Path(__file__).resolve().parents[2], provider="openai" if args.live else "mock",
                            max_calls=args.max_calls, godot=args.godot)
    token = os.environ.get("SSOK_BRIDGE_TOKEN") or secrets.token_urlsafe(32)
    server = make_server(service, token, args.port, args.origin)
    print(f"ssok motion lab: http://127.0.0.1:{server.server_address[1]} ({service.provider})", flush=True)
    print(f"Local bridge token (paste only into ssok): {token}", flush=True)
    print("OpenAI keys stay in this process. Ctrl+C stops the bridge. No remote/public binding.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        service.close()


if __name__ == "__main__":
    main()
