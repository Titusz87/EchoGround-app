# Sends Python logs (and optionally print() output) to Better Stack over plain HTTPS.
# WHY this instead of the logtail-python package: the same HTTP call worked with curl
# (HTTP 202), but the package's handler delivered nothing from the deployed app.
# This version uses httpx, so there is nothing extra to install.

import datetime
import logging
import os
import queue
import sys
import threading
import httpx


class BetterStackHandler(logging.Handler):
    def __init__(self, token: str, host: str):
        super().__init__()
        self.url = host if host.startswith("http") else f"https://{host}"
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        self._queue = queue.Queue(maxsize=5000)
        # background thread, so logging never slows down or blocks your requests
        threading.Thread(target=self._worker, daemon=True).start()

    def push(self, level: str, logger_name: str, message: str):
        body = {
            "dt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "level": level,
            "logger": logger_name,
            "message": message,
        }
        try:
            self._queue.put_nowait(body)
        except queue.Full:
            pass  # drop the line rather than block the app

    def emit(self, record):
        try:
            self.push(record.levelname, record.name, self.format(record))
        except Exception:
            pass

    def _worker(self):
        with httpx.Client(timeout=10) as client:
            while True:
                body = self._queue.get()
                try:
                    response = client.post(self.url, json=body, headers=self.headers)
                    if response.status_code >= 300:
                        # sys.__stdout__ bypasses the print() capture below (no loops)
                        sys.__stdout__.write(
                            f"Better Stack rejected a log line: HTTP {response.status_code}\n"
                        )
                except Exception as e:
                    sys.__stdout__.write(f"Better Stack send failed: {e}\n")


class _PrintCapture:
    """Forwards every print(...) line to Better Stack and still writes it to the console."""

    def __init__(self, stream, handler: BetterStackHandler):
        self._stream = stream
        self._handler = handler
        self._partial = ""

    def write(self, text):
        self._stream.write(text)
        self._partial += text
        while "\n" in self._partial:
            line, self._partial = self._partial.split("\n", 1)
            if line.strip():
                self._handler.push("INFO", "print", line)
        return len(text)

    def flush(self):
        self._stream.flush()

    def __getattr__(self, name):
        return getattr(self._stream, name)


def setup_betterstack(capture_print: bool = True):
    """Call once at import time in main.py, above app = FastAPI(...)."""
    token = os.getenv("BETTERSTACK_SOURCE_TOKEN")
    host = os.getenv("BETTERSTACK_INGESTING_HOST")
    if not token or not host:
        print("Better Stack NOT configured: missing env vars")
        return

    handler = BetterStackHandler(token, host)
    handler.setFormatter(logging.Formatter("%(message)s"))
    # uvicorn loggers don't pass messages to the root logger, so attach to them directly
    for name in ("", "uvicorn", "uvicorn.access"):
        logging.getLogger(name).addHandler(handler)
    logging.getLogger().setLevel(logging.INFO)

    # httpx logs every request at INFO. Without this, sending a log would create
    # another log line, which would be sent, and so on forever.
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)

    if capture_print and not isinstance(sys.stdout, _PrintCapture):
        sys.stdout = _PrintCapture(sys.stdout, handler)

    print("Better Stack handler enabled")