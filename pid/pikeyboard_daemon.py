#!/usr/bin/env python3
"""
piKeyboard daemon for Raspberry Pi 5.

Runs a WebSocket server on :8765/ws, advertises itself via Bonjour
(_pikeyboard._tcp), and injects keyboard + mouse events into Linux
via /dev/uinput.

Run in fake mode on macOS for protocol testing:
    PIKEYBOARD_FAKE=1 ./pikeyboard_daemon.py
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import socket
import sys
from typing import Any

LOG = logging.getLogger("pikeyboard")

PORT = int(os.environ.get("PIKEYBOARD_PORT", "8765"))
FAKE = os.environ.get("PIKEYBOARD_FAKE") == "1" or sys.platform == "darwin"

# ---------------------------------------------------------------------------
# Input injection
# ---------------------------------------------------------------------------

class Injector:
    """Injects keyboard + mouse events. Uses uinput on Linux, logs in fake mode."""

    def __init__(self, fake: bool = False) -> None:
        self.fake = fake
        self.kbd = None
        self.mouse = None
        if not fake:
            self._init_uinput()

    def _init_uinput(self) -> None:
        try:
            import uinput  # type: ignore
        except ImportError:
            LOG.error("python-uinput not installed. apt: sudo apt install python3-uinput")
            sys.exit(2)

        # Build full key list dynamically — every KEY_* uinput exposes.
        keys = [getattr(uinput, k) for k in dir(uinput) if k.startswith("KEY_")]
        self.kbd = uinput.Device(keys, name="piKeyboard")
        self.mouse = uinput.Device(
            [
                uinput.REL_X, uinput.REL_Y, uinput.REL_WHEEL, uinput.REL_HWHEEL,
                uinput.BTN_LEFT, uinput.BTN_RIGHT, uinput.BTN_MIDDLE,
            ],
            name="piKeyboard-mouse",
        )

    # ----- key -----
    def key(self, code: str, down: bool, modifiers: list[str]) -> None:
        if self.fake:
            LOG.info("[fake] key %s down=%s mods=%s", code, down, modifiers)
            return
        import uinput  # type: ignore
        # Press modifiers on key-down, release on key-up
        mod_map = {
            "shift": uinput.KEY_LEFTSHIFT,
            "ctrl":  uinput.KEY_LEFTCTRL,
            "alt":   uinput.KEY_LEFTALT,
            "meta":  uinput.KEY_LEFTMETA,
        }
        key = getattr(uinput, code, None)
        if key is None:
            LOG.warning("unknown key code %s", code)
            return
        if down:
            for m in modifiers:
                if m in mod_map: self.kbd.emit(mod_map[m], 1, syn=False)
            self.kbd.emit(key, 1)
        else:
            self.kbd.emit(key, 0, syn=False)
            for m in modifiers:
                if m in mod_map: self.kbd.emit(mod_map[m], 0, syn=False)
            self.kbd.syn()

    # ----- text -----
    def text(self, s: str) -> None:
        if self.fake:
            LOG.info("[fake] text %r", s)
            return
        import uinput  # type: ignore
        # Map each char to KEY_* + shift if needed.
        for ch in s:
            self._type_char(ch)

    def _type_char(self, ch: str) -> None:
        import uinput  # type: ignore
        shift = False
        key = None

        if ch.isalpha():
            shift = ch.isupper()
            key = getattr(uinput, f"KEY_{ch.upper()}", None)
        elif ch.isdigit():
            key = getattr(uinput, f"KEY_{ch}", None)
        else:
            mapping = {
                " ": ("KEY_SPACE", False), "\n": ("KEY_ENTER", False),
                "\t": ("KEY_TAB", False),
                "-": ("KEY_MINUS", False), "_": ("KEY_MINUS", True),
                "=": ("KEY_EQUAL", False), "+": ("KEY_EQUAL", True),
                "[": ("KEY_LEFTBRACE", False), "{": ("KEY_LEFTBRACE", True),
                "]": ("KEY_RIGHTBRACE", False), "}": ("KEY_RIGHTBRACE", True),
                ";": ("KEY_SEMICOLON", False), ":": ("KEY_SEMICOLON", True),
                "'": ("KEY_APOSTROPHE", False), '"': ("KEY_APOSTROPHE", True),
                ",": ("KEY_COMMA", False), "<": ("KEY_COMMA", True),
                ".": ("KEY_DOT", False), ">": ("KEY_DOT", True),
                "/": ("KEY_SLASH", False), "?": ("KEY_SLASH", True),
                "\\": ("KEY_BACKSLASH", False), "|": ("KEY_BACKSLASH", True),
                "`": ("KEY_GRAVE", False), "~": ("KEY_GRAVE", True),
                "!": ("KEY_1", True), "@": ("KEY_2", True), "#": ("KEY_3", True),
                "$": ("KEY_4", True), "%": ("KEY_5", True), "^": ("KEY_6", True),
                "&": ("KEY_7", True), "*": ("KEY_8", True), "(": ("KEY_9", True),
                ")": ("KEY_0", True),
            }
            if ch in mapping:
                name, shift = mapping[ch]
                key = getattr(uinput, name, None)

        if key is None:
            return
        if shift:
            self.kbd.emit(uinput.KEY_LEFTSHIFT, 1, syn=False)
        self.kbd.emit(key, 1, syn=False)
        self.kbd.emit(key, 0, syn=False)
        if shift:
            self.kbd.emit(uinput.KEY_LEFTSHIFT, 0, syn=False)
        self.kbd.syn()

    # ----- mouse -----
    def mouse_move(self, dx: float, dy: float) -> None:
        if self.fake:
            if abs(dx) + abs(dy) > 4:
                LOG.info("[fake] move dx=%.0f dy=%.0f", dx, dy)
            return
        import uinput  # type: ignore
        self.mouse.emit(uinput.REL_X, int(dx), syn=False)
        self.mouse.emit(uinput.REL_Y, int(dy))

    def mouse_button(self, button: str, down: bool) -> None:
        if self.fake:
            LOG.info("[fake] button %s down=%s", button, down)
            return
        import uinput  # type: ignore
        m = {"left": uinput.BTN_LEFT, "right": uinput.BTN_RIGHT, "middle": uinput.BTN_MIDDLE}
        b = m.get(button)
        if b is None:
            return
        self.mouse.emit(b, 1 if down else 0)

    def scroll(self, dx: float, dy: float) -> None:
        if self.fake:
            LOG.info("[fake] scroll dx=%.1f dy=%.1f", dx, dy)
            return
        import uinput  # type: ignore
        if dy:
            self.mouse.emit(uinput.REL_WHEEL, int(dy), syn=False)
        if dx:
            self.mouse.emit(uinput.REL_HWHEEL, int(dx))


# ---------------------------------------------------------------------------
# WebSocket server
# ---------------------------------------------------------------------------

async def handle(websocket, injector: Injector) -> None:
    peer = websocket.remote_address
    LOG.info("client connected: %s", peer)
    try:
        async for raw in websocket:
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            t = msg.get("t")
            p = msg.get("p") or {}
            if t == "hello":
                LOG.info("hello from %s v%s", p.get("client"), p.get("version"))
            elif t == "ping":
                await websocket.send(json.dumps({"t": "pong"}))
            elif t == "key":
                injector.key(p.get("code", ""), bool(p.get("down")), p.get("modifiers") or [])
            elif t == "text":
                injector.text(p.get("s", ""))
            elif t == "mouse":
                dx = float(p.get("dx") or 0); dy = float(p.get("dy") or 0)
                button = p.get("button"); down = p.get("down")
                if button is None:
                    injector.mouse_move(dx, dy)
                else:
                    injector.mouse_button(button, bool(down))
            elif t == "scroll":
                injector.scroll(float(p.get("dx") or 0), float(p.get("dy") or 0))
    except Exception as e:
        LOG.warning("client error: %s", e)
    finally:
        LOG.info("client disconnected: %s", peer)


# ---------------------------------------------------------------------------
# Bonjour (async — required for zeroconf 0.130+ when called inside an asyncio loop)
# ---------------------------------------------------------------------------

async def advertise_bonjour(port: int) -> Any:
    try:
        from zeroconf.asyncio import AsyncServiceInfo, AsyncZeroconf  # type: ignore
    except ImportError:
        LOG.warning("zeroconf not installed; skipping advertisement (pip install zeroconf)")
        return None

    hostname = socket.gethostname()
    # Pick the first non-loopback IPv4 we can find. gethostbyname() may return 127.0.1.1.
    addr = None
    try:
        for info_tuple in socket.getaddrinfo(hostname, None, socket.AF_INET):
            ip = info_tuple[4][0]
            if not ip.startswith("127."):
                addr = ip
                break
    except socket.gaierror:
        pass
    if addr is None:
        # Fallback: open a UDP socket to a public IP and read our own outbound IP.
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("1.1.1.1", 80))
            addr = s.getsockname()[0]
        finally:
            s.close()

    info = AsyncServiceInfo(
        "_pikeyboard._tcp.local.",
        f"{hostname}._pikeyboard._tcp.local.",
        addresses=[socket.inet_aton(addr)],
        port=port,
        properties={"version": "0.2.1"},
        server=f"{hostname}.local.",
    )
    azc = AsyncZeroconf()
    await azc.async_register_service(info)
    LOG.info("advertised %s on %s:%d", info.name, addr, port)
    return azc


# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

async def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    LOG.info("piKeyboard daemon starting (fake=%s, port=%d)", FAKE, PORT)

    try:
        import websockets  # type: ignore
    except ImportError:
        LOG.error("websockets not installed. pip install websockets")
        sys.exit(2)

    injector = Injector(fake=FAKE)
    bonjour = await advertise_bonjour(PORT)

    async def handler(ws):
        await handle(ws, injector)

    async with websockets.serve(handler, "0.0.0.0", PORT):
        LOG.info("listening on ws://0.0.0.0:%d/ws", PORT)
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
