"""CI gameplay evidence driver (Linux/X11).

Moves the real mouse over the game window via xdotool while Godot runs
with --write-movie, so the recorded AVI contains true rendered gameplay.
Window is assumed at (0,0) without decorations (Xvfb, no WM): canvas
coordinates equal screen coordinates.

Usage: python3 tools/mouse_timeline.py [duration_seconds]
"""
import math
import subprocess
import sys
import time

DURATION = float(sys.argv[1]) if len(sys.argv) > 1 else 26.0


def field_point(t: float):
    """Canvas coords: field sweeps + UI hovers (clamping proof)."""
    if t < 8.0:
        return (240 + 560 * math.sin(2 * math.pi * t / 7.0),
                300 + 220 * math.sin(4 * math.pi * t / 7.0 + math.pi / 3))
    if t < 10.0:  # над правой панелью — магнит обязан остаться в поле
        return (1100.0, 350.0)
    if t < 16.0:
        u = t - 10.0
        return (490 + 420 * math.sin(2 * math.pi * u / 6.0 + 1.2),
                380 + 240 * math.sin(4 * math.pi * u / 6.0 + 0.4))
    if t < 18.0:  # над верхним HUD
        return (400.0, 20.0)
    u = t - 18.0
    return (200 + 680 * (0.5 + 0.5 * math.sin(2 * math.pi * u / 2.0)),
            200 + 420 * (0.5 + 0.5 * math.sin(2 * math.pi * u / 1.3 + 2.0)))


def main() -> None:
    t0 = time.time()
    while True:
        t = time.time() - t0
        if t >= DURATION:
            break
        x, y = field_point(t)
        subprocess.run(["xdotool", "mousemove", str(int(x)), str(int(y))],
                       check=False)
        time.sleep(0.01)
    print("mouse timeline done: %.1fs" % DURATION)


if __name__ == "__main__":
    main()
