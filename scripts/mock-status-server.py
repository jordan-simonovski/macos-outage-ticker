#!/usr/bin/env python3
"""Mock Statuspage server for local ticker testing.

Answers GET /<site>/api/v2/status.json with the Statuspage v2 payload shape.
Each site cycles: up for --up seconds, down for --down seconds, computed from
wall-clock time (stateless). The site name hashes to a phase offset so
different sites go down at different times.

Keep --down comfortably above one full scroll pass, which takes
(screenWidth + textWidth) / scrollPointsPerSecond seconds — roughly 15s at the
mock config's 200 pt/s on a 1728pt display. Cycling faster than that replaces
the message before anyone can read it.

Usage:
    python3 scripts/mock-status-server.py [--port 8787] [--up 45] [--down 30]
    python3 scripts/mock-status-server.py --self-test
"""
import argparse
import json
import time
import zlib
from http.server import BaseHTTPRequestHandler, HTTPServer


def indicator(site: str, now: int, up: int, down: int) -> str:
    period = up + down
    offset = zlib.crc32(site.encode()) % period
    return "major" if (now + offset) % period >= up else "none"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not self.path.endswith("/api/v2/status.json"):
            self.send_error(404)
            return
        site = self.path.strip("/").split("/")[0]
        ind = indicator(site, int(time.time()), self.server.up, self.server.down)
        desc = "Mock Major Outage" if ind == "major" else "All Systems Operational"
        body = json.dumps({"status": {"indicator": ind, "description": desc}}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        site = self.path.strip("/").split("/")[0]
        ind = indicator(site, int(time.time()), self.server.up, self.server.down)
        print(f"{time.strftime('%H:%M:%S')} {site}: {ind}")


def self_test(up: int = 45, down: int = 30) -> None:
    # Over one full period every site spends exactly `up` seconds up and
    # `down` seconds down, regardless of its phase offset, and the cycle repeats.
    for site in ("mockhub", "mockhouse"):
        states = [indicator(site, t, up, down) for t in range(up + down)]
        assert states.count("none") == up, states
        assert states.count("major") == down, states
        assert indicator(site, 0, up, down) == indicator(site, up + down, up, down)
    print("self-test OK")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--up", type=int, default=45)
    parser.add_argument("--down", type=int, default=30)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        server = HTTPServer(("127.0.0.1", args.port), Handler)
        server.up, server.down = args.up, args.down
        print(f"mock statuspage on http://127.0.0.1:{args.port} "
              f"(up {args.up}s / down {args.down}s per site)")
        server.serve_forever()
