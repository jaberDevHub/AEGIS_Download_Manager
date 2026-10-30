"""Cross-platform local IPC server used by Aegis browser integration."""

import ctypes
import http.server
import json
import os
import socket
import stat
import sys
import threading
import time

from PyQt6.QtCore import QThread, pyqtSignal

if sys.platform == "win32":
    from ctypes import wintypes
else:
    wintypes = None

from ipc_transport import (
    GENERIC_WRITE,
    INVALID_HANDLE_VALUE,
    OPEN_EXISTING,
    PIPE_ACCESS_DUPLEX,
    PIPE_NAME,
    PIPE_TYPE_BYTE,
    PIPE_WAIT,
    kernel32,
    send_ipc_message,
    unix_socket_path,
)

MAX_MESSAGE_BYTES = 10 * 1024 * 1024
DEFAULT_HTTP_PORTS = (28795, 28796, 28797)


def auto_register_native_host():
    """Silently registers the native messaging host in the Windows Registry if possible."""
    if sys.platform != "win32":
        return
    try:
        import winreg

        base_dir = os.path.dirname(os.path.abspath(__file__))
        manifest_path = os.path.join(base_dir, "browser_extension", "com.aegis.downloadmanager.json")
        if not os.path.isfile(manifest_path):
            return

        host_exe = os.path.join(base_dir, "browser_extension", "aegis_host.exe")
        host_bat = os.path.join(base_dir, "browser_extension", "aegis_host.bat")
        target_path = host_exe if os.path.isfile(host_exe) else host_bat

        if os.path.isfile(target_path):
            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest_data = json.load(f)
                if manifest_data.get("path") != target_path:
                    manifest_data["path"] = target_path
                    with open(manifest_path, "w", encoding="utf-8") as f:
                        json.dump(manifest_data, f, indent=2)
            except Exception:
                pass

        subkeys = [
            r"Software\Google\Chrome\NativeMessagingHosts\com.aegis.downloadmanager",
            r"Software\Microsoft\Edge\NativeMessagingHosts\com.aegis.downloadmanager",
            r"Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.aegis.downloadmanager",
        ]
        for subkey in subkeys:
            try:
                with winreg.CreateKey(winreg.HKEY_CURRENT_USER, subkey) as k:
                    winreg.SetValue(k, "", winreg.REG_SZ, manifest_path)
            except Exception:
                pass
    except Exception:
        pass


class AegisHttpBridgeHandler(http.server.BaseHTTPRequestHandler):
    """Direct HTTP bridge for browser extensions (zero native host setup required)."""

    server_instance = None

    def _set_cors_headers(self, content_type="application/json"):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
        self.send_header("Access-Control-Max-Age", "86400")
        if content_type:
            self.send_header("Content-Type", content_type)

    def do_OPTIONS(self):
        self.send_response(200)
        self._set_cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        clean_path = self.path.split("?")[0]
        if clean_path in ("/ping", "/status", "/"):
            data = json.dumps({
                "status": "ok",
                "app": "Aegis Download Manager",
                "version": "1.2.0",
                "message": "Aegis is online and ready",
            }).encode("utf-8")
            self.send_response(200)
            self._set_cors_headers()
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(404)
            self._set_cors_headers()
            self.end_headers()

    def do_POST(self):
        clean_path = self.path.split("?")[0]
        if clean_path in ("/download", "/add", "/task", "/"):
            try:
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length) if length > 0 else b"{}"
                payload = json.loads(body.decode("utf-8"))
                if not isinstance(payload, dict):
                    raise ValueError("Payload must be a JSON object")

                if AegisHttpBridgeHandler.server_instance:
                    AegisHttpBridgeHandler.server_instance.message_received.emit(payload)

                resp = json.dumps({"status": "ok", "message": "Task accepted by Aegis"}).encode("utf-8")
                self.send_response(200)
                self._set_cors_headers()
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
                return
            except Exception as e:
                resp = json.dumps({"status": "error", "message": str(e)}).encode("utf-8")
                self.send_response(400)
                self._set_cors_headers()
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
                return

        self.send_response(404)
        self._set_cors_headers()
        self.end_headers()

    def log_message(self, format, *args):
        # Silence standard terminal logs
        pass


class AegisIpcServer(QThread):
    """Accept requests over local HTTP bridge, Windows named pipe, or POSIX domain socket."""

    message_received = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.running = True
        self._current_handle = None
        self._unix_server = None
        self._owns_unix_socket = False
        self._httpd = None
        self._http_thread = None
        self.http_port = 28795

    def run(self):
        auto_register_native_host()
        self._start_http_bridge()
        if sys.platform == "win32":
            self._run_windows()
        elif hasattr(socket, "AF_UNIX"):
            self._run_unix()

    def _start_http_bridge(self):
        AegisHttpBridgeHandler.server_instance = self
        for port in DEFAULT_HTTP_PORTS:
            try:
                self._httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), AegisHttpBridgeHandler)
                self.http_port = port
                self._http_thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)
                self._http_thread.start()
                break
            except OSError:
                continue

    def _stop_http_bridge(self):
        if self._httpd:
            try:
                self._httpd.shutdown()
                self._httpd.server_close()
            except Exception:
                pass
            self._httpd = None

    def _run_windows(self):
        while self.running:
            handle = kernel32.CreateNamedPipeW(
                PIPE_NAME,
                PIPE_ACCESS_DUPLEX,
                PIPE_TYPE_BYTE | PIPE_WAIT,
                255,
                65536,
                65536,
                1000,
                None,
            )
            if handle == INVALID_HANDLE_VALUE or handle == 0:
                time.sleep(0.5)
                continue

            self._current_handle = handle
            connected = kernel32.ConnectNamedPipe(handle, None)
            if connected or kernel32.GetLastError() == 535:
                buf = ctypes.create_string_buffer(65536)
                bytes_read = wintypes.DWORD(0)
                success = kernel32.ReadFile(handle, buf, 65535, ctypes.byref(bytes_read), None)
                if success and bytes_read.value > 0:
                    self._handle_message(
                        buf.raw[:bytes_read.value], lambda data: self._write_windows(handle, data)
                    )
                kernel32.FlushFileBuffers(handle)
                kernel32.DisconnectNamedPipe(handle)

            kernel32.CloseHandle(handle)
            self._current_handle = None

    @staticmethod
    def _write_windows(handle, data: bytes):
        written = wintypes.DWORD(0)
        kernel32.WriteFile(handle, data, len(data), ctypes.byref(written), None)

    def _run_unix(self):
        path = unix_socket_path()
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._unix_server = server
        try:
            if os.path.lexists(path):
                try:
                    existing = os.lstat(path)
                except FileNotFoundError:
                    existing = None
                if existing is not None and (
                    not stat.S_ISSOCK(existing.st_mode)
                    or (hasattr(os, "getuid") and existing.st_uid != os.getuid())
                ):
                    return
                probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                try:
                    probe.settimeout(0.25)
                    probe.connect(path)
                    return
                except OSError:
                    try:
                        current = os.lstat(path)
                        if existing and (current.st_dev, current.st_ino) == (existing.st_dev, existing.st_ino):
                            os.unlink(path)
                    except FileNotFoundError:
                        pass
                finally:
                    probe.close()

            server.bind(path)
            self._owns_unix_socket = True
            os.chmod(path, 0o600)
            server.listen(8)
            server.settimeout(0.5)
            while self.running:
                try:
                    client, _ = server.accept()
                except socket.timeout:
                    continue
                except OSError:
                    if self.running:
                        time.sleep(0.1)
                    continue
                with client:
                    self._handle_unix_client(client)
        except OSError:
            return
        finally:
            try:
                server.close()
            except OSError:
                pass
            self._unix_server = None
            if self._owns_unix_socket:
                try:
                    os.unlink(path)
                except FileNotFoundError:
                    pass
                self._owns_unix_socket = False

    def _handle_unix_client(self, client):
        client.settimeout(2.0)
        raw = bytearray()
        try:
            while len(raw) <= MAX_MESSAGE_BYTES:
                part = client.recv(min(65536, MAX_MESSAGE_BYTES + 1 - len(raw)))
                if not part:
                    break
                raw.extend(part)
            if len(raw) > MAX_MESSAGE_BYTES:
                client.sendall(json.dumps({
                    "status": "error", "message": "IPC message is too large"
                }).encode("utf-8"))
                return
            self._handle_message(bytes(raw), client.sendall)
        except (OSError, ValueError):
            pass

    def _handle_message(self, raw_data: bytes, send_reply):
        try:
            message = json.loads(raw_data.decode("utf-8"))
            if not isinstance(message, dict):
                raise ValueError("IPC payload must be a JSON object")
            self.message_received.emit(message)
            reply = {"status": "ok", "message": "Task received by Aegis"}
        except Exception as exc:
            reply = {"status": "error", "message": str(exc)}
        send_reply(json.dumps(reply).encode("utf-8"))

    def stop(self):
        self.running = False
        self._stop_http_bridge()
        if kernel32 and self._current_handle:
            try:
                client = kernel32.CreateFileW(
                    PIPE_NAME, GENERIC_WRITE, 0, None, OPEN_EXISTING, 0, None
                )
                if client != INVALID_HANDLE_VALUE and client != 0:
                    kernel32.CloseHandle(client)
            except Exception:
                pass
        if self._unix_server:
            try:
                self._unix_server.close()
            except OSError:
                pass
