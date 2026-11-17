#!/usr/bin/env python3
"""Local, read-only Codex usage bridge for the Plasma widget."""

from __future__ import annotations

import argparse
import json
import os
import re
import select
import shutil
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from urllib.parse import unquote


FIVE_HOURS = 300
WEEK = 10080
DEFAULT_PATHS = (
    "~/.local/bin/codex",
    "~/.npm-global/bin/codex",
    "/usr/local/bin/codex",
    "/usr/bin/codex",
    "/usr/lib/chatgpt/resources/codex",
)
CLIENT_INFO = {"name": "kde_codex_usage_widget", "title": "Codex usage widget", "version": "0.1.0"}


def runtime_socket() -> Path:
    base = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/codex-usage-{os.getuid()}")
    directory = base / "codex-usage-widget"
    try:
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    except OSError:
        directory = Path(f"/tmp/codex-usage-{os.getuid()}")
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.stat().st_uid != os.getuid() or directory.stat().st_mode & 0o077:
        raise RuntimeError("Unsafe runtime directory permissions")
    return directory / "bridge.sock"


def validate_binary(path: str) -> bool:
    candidate = Path(path).expanduser()
    if not candidate.is_file() or not os.access(candidate, os.X_OK):
        return False
    try:
        result = subprocess.run(
            [str(candidate), "--version"], capture_output=True, text=True, timeout=5, check=False
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0 and re.search(r"(?m)^codex-cli\s+\S+", result.stdout) is not None


def resolve_binary(custom_path: str, validator=validate_binary) -> str | None:
    if custom_path:
        return str(Path(custom_path).expanduser()) if validator(custom_path) else None
    candidates = [shutil.which("codex"), *(str(Path(p).expanduser()) for p in DEFAULT_PATHS)]
    for candidate in candidates:
        if candidate and validator(candidate):
            return candidate
    return None


def classify_windows(result: dict) -> dict:
    limits = (result.get("rateLimitsByLimitId") or {}).get("codex") or result.get("rateLimits") or {}
    windows = {"five_hour": None, "weekly": None}
    for item in (limits.get("primary"), limits.get("secondary")):
        if not isinstance(item, dict):
            continue
        duration = item.get("windowDurationMins")
        key = "five_hour" if duration == FIVE_HOURS else "weekly" if duration == WEEK else None
        if key:
            used = max(0, min(100, int(item.get("usedPercent", 0))))
            windows[key] = {"remaining": 100 - used, "used": used, "resets_at": item.get("resetsAt")}
    return windows


class CodexSession:
    def __init__(self, binary: str):
        self.binary = binary
        self.process = subprocess.Popen(
            [binary, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            bufsize=0, start_new_session=True,
        )
        self.buffer = b""
        self.next_id = 1
        response = self.request("initialize", {"clientInfo": CLIENT_INFO}, timeout=10)
        if "error" in response:
            self.close()
            raise RuntimeError(str(response["error"].get("message", "Codex initialization failed")))
        self.send({"method": "initialized", "params": {}})

    def send(self, message: dict) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write((json.dumps(message) + "\n").encode())
        self.process.stdin.flush()

    def request(self, method: str, params: dict | None = None, timeout: float = 10) -> dict:
        request_id = self.next_id
        self.next_id += 1
        message = {"id": request_id, "method": method}
        if params is not None:
            message["params"] = params
        self.send(message)
        deadline = time.monotonic() + timeout
        assert self.process.stdout is not None
        fd = self.process.stdout.fileno()
        while time.monotonic() < deadline:
            if b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                try:
                    response = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if response.get("id") == request_id:
                    return response
                continue
            remaining = deadline - time.monotonic()
            if not select.select([fd], [], [], max(0, remaining))[0]:
                break
            chunk = os.read(fd, 65536)
            if not chunk:
                raise RuntimeError("Codex app server exited")
            self.buffer += chunk
        raise TimeoutError("Codex usage request timed out")

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()


class Bridge:
    def __init__(self):
        self.lock = threading.Lock()
        self.session: CodexSession | None = None
        self.cache: dict[str, tuple[float, dict]] = {}
        self.validation_cache: dict[str, tuple[tuple[int, int, int, int], bool]] = {}
        self.last_access = time.monotonic()

    def cached_validation(self, path: str) -> bool:
        candidate = Path(path).expanduser()
        try:
            stat = candidate.stat()
            signature = (stat.st_dev, stat.st_ino, stat.st_mtime_ns, stat.st_size)
        except OSError:
            return False
        cached = self.validation_cache.get(str(candidate))
        if cached and cached[0] == signature:
            return cached[1]
        valid = validate_binary(str(candidate))
        self.validation_cache[str(candidate)] = (signature, valid)
        return valid

    def handle(self, request: dict) -> dict:
        with self.lock:
            self.last_access = time.monotonic()
            path = request.get("path", "")
            if request.get("command") == "validate":
                return {"valid": not path or validate_binary(path)}
            binary = resolve_binary(path, self.cached_validation)
            if not binary:
                return {"status": "missing", "five_hour": None, "weekly": None}
            interval = max(1, int(request.get("interval_ms", 60000))) / 1000
            cached = self.cache.get(binary)
            if cached and time.monotonic() - cached[0] < interval:
                return cached[1]
            try:
                if self.session is None or self.session.binary != binary or self.session.process.poll() is not None:
                    if self.session is not None:
                        self.session.close()
                    self.session = CodexSession(binary)
                response = self.session.request("account/rateLimits/read", {"excludeResetCreditDetails": True})
                if "error" in response:
                    message = str(response["error"].get("message", ""))
                    if "authentication required" in message.lower():
                        return {"status": "auth", "five_hour": None, "weekly": None}
                    raise RuntimeError(message or "Codex usage query failed")
                windows = classify_windows(response.get("result") or {})
                value = {"status": "ok", "updated_at": int(time.time()), **windows}
                self.cache[binary] = (time.monotonic(), value)
                return value
            except (OSError, RuntimeError, TimeoutError, ValueError, BrokenPipeError) as exc:
                if self.session is not None:
                    self.session.close()
                    self.session = None
                return {"status": "error", "message": str(exc), "five_hour": None, "weekly": None}


def serve() -> None:
    address = runtime_socket()
    owns_socket = False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            try:
                server.bind(str(address))
            except OSError:
                return  # Another bridge won the startup race.
            owns_socket = True
            os.chmod(address, 0o600)
            server.listen(8)
            server.settimeout(10)
            bridge = Bridge()
            while time.monotonic() - bridge.last_access < 600:
                try:
                    connection, _ = server.accept()
                except socket.timeout:
                    continue
                with connection:
                    connection.settimeout(30)
                    try:
                        request = json.loads(connection.recv(65536).decode())
                        answer = bridge.handle(request)
                    except (OSError, ValueError, TypeError) as exc:
                        answer = {"status": "error", "message": str(exc)}
                    try:
                        connection.sendall((json.dumps(answer) + "\n").encode())
                    except OSError:
                        pass
            if bridge.session is not None:
                bridge.session.close()
    finally:
        if owns_socket:
            try:
                address.unlink()
            except FileNotFoundError:
                pass


def client_request(request: dict) -> dict:
    address = runtime_socket()
    for attempt in range(30):
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                connection.settimeout(30)
                connection.connect(str(address))
                connection.sendall(json.dumps(request).encode())
                return json.loads(connection.recv(65536).decode())
        except (ConnectionRefusedError, FileNotFoundError):
            if attempt == 0:
                if address.exists():
                    address.unlink()
                subprocess.Popen(
                    [sys.executable, str(Path(__file__).resolve()), "serve"],
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
            time.sleep(0.1)
        except OSError as exc:
            return {"status": "error", "message": str(exc)}
    return {"status": "error", "message": "Could not start the usage helper"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("fetch", "validate", "serve"))
    parser.add_argument("--path-uri", default="")
    parser.add_argument("--interval-ms", type=int, default=60000)
    args = parser.parse_args()
    if args.command == "serve":
        serve()
    elif args.command == "validate":
        path = unquote(args.path_uri)
        print(json.dumps({"valid": not path or validate_binary(path)}))
    else:
        try:
            answer = client_request({
                "command": args.command,
                "path": unquote(args.path_uri),
                "interval_ms": args.interval_ms,
            })
        except (OSError, RuntimeError) as exc:
            answer = {"status": "error", "message": str(exc)}
        print(json.dumps(answer))


if __name__ == "__main__":
    main()
