import logging
import os
import time
from ipaddress import AddressValueError, ip_address
from pathlib import Path
from typing import Final
from urllib.parse import quote

from flask import Flask, Response, abort, request
from redis import Redis
from redis.exceptions import RedisError, WatchError

APP_DIRECTORY: Final = Path(__file__).resolve().parent
DOWNLOAD_ROOT: Final = Path(os.environ.get("DOWNLOAD_ROOT", "/srv/downloads")).resolve()
POLICY_FILE: Final = Path(os.environ.get("POLICY_FILE", str(APP_DIRECTORY / "allow-ip-limits.example")))
REDIS_URL: Final = os.environ.get("REDIS_URL", "redis://127.0.0.1:6379/0")
DEFAULT_DOWNLOAD_LIMIT: Final = int(os.environ.get("DEFAULT_DOWNLOAD_LIMIT", "10"))
RESET_INTERVAL_SECONDS: Final = 14400  # Four hours.
STATE_TTL_SECONDS: Final = RESET_INTERVAL_SECONDS * 2

app = Flask(__name__)
redis_client = Redis.from_url(REDIS_URL, decode_responses=True)


def load_client_limits(path: Path) -> dict[str, int]:
    """Load exact-IP overrides from a simple, controlled policy file."""
    limits: dict[str, int] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        app.logger.warning("Policy file could not be read; using the default limit")
        return limits

    for line in lines:
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        client, separator, value = entry.partition("=")
        if not separator:
            app.logger.warning("Ignoring malformed policy entry")
            continue
        try:
            normalized_client = str(ip_address(client.strip()))
            limit = int(value.strip())
        except (AddressValueError, ValueError):
            app.logger.warning("Ignoring invalid policy entry")
            continue
        if limit < -1:
            app.logger.warning("Ignoring unsupported policy limit")
            continue
        limits[normalized_client] = limit
    return limits


def client_ip() -> str:
    """Trust X-Real-IP only because Gunicorn is loopback-only behind Nginx."""
    supplied = request.headers.get("X-Real-IP") or request.remote_addr or ""
    try:
        return str(ip_address(supplied))
    except AddressValueError:
        abort(404)


def resolve_requested_file(filename: str) -> tuple[Path, str] | None:
    """Reject absolute, traversal, hidden, and out-of-root file requests."""
    relative = Path(filename)
    if not filename or relative.is_absolute() or any(part in {"", ".", ".."} or part.startswith(".") for part in relative.parts):
        return None
    candidate = (DOWNLOAD_ROOT / relative).resolve()
    try:
        candidate.relative_to(DOWNLOAD_ROOT)
    except ValueError:
        return None
    if not candidate.is_file():
        return None
    return candidate, relative.as_posix()


def consume_download(client: str, relative_path: str, file_path: Path, limit: int) -> bool:
    """Atomically record one allowed download, or return False when the limit is reached."""
    state_key = f"filedelivery:{client}:{relative_path}"
    now = time.time()
    modification_time = file_path.stat().st_mtime

    try:
        with redis_client.pipeline() as pipeline:
            while True:
                try:
                    pipeline.watch(state_key)
                    state = pipeline.hgetall(state_key)
                    count = int(state.get("count", "0"))
                    last_reset = float(state.get("last_reset", "0"))
                    reset_required = (
                        last_reset == 0
                        or now - last_reset >= RESET_INTERVAL_SECONDS
                        or modification_time > last_reset
                    )
                    if reset_required:
                        count = 0
                        last_reset = now
                    if count >= limit:
                        pipeline.unwatch()
                        return False

                    pipeline.multi()
                    pipeline.hset(
                        state_key,
                        mapping={"count": str(count + 1), "last_reset": str(last_reset)},
                    )
                    pipeline.expire(state_key, STATE_TTL_SECONDS)
                    pipeline.execute()
                    return True
                except WatchError:
                    continue
    except (OSError, RedisError):
        app.logger.error("Redis policy state is unavailable")
        abort(503)


@app.get("/download/<path:filename>")
def download(filename: str) -> Response:
    resolved = resolve_requested_file(filename)
    if resolved is None:
        abort(404)
    file_path, relative_path = resolved

    limit = load_client_limits(POLICY_FILE).get(client_ip(), DEFAULT_DOWNLOAD_LIMIT)
    if limit == 0:
        abort(404)
    if limit != -1 and not consume_download(client_ip(), relative_path, file_path, limit):
        abort(429)

    response = Response(status=200)
    response.headers["X-Accel-Redirect"] = "/protected-internal/" + quote(relative_path, safe="/")
    return response


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    app.run(host="127.0.0.1", port=5000)
