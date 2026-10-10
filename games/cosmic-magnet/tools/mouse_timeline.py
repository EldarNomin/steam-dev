"""CI gameplay evidence driver (Linux/X11) for CM-002.

Moves the real mouse over the game window via xdotool while Godot runs
with --write-movie, so the recorded AVI contains true rendered gameplay.
Window is assumed at (0,0) without decorations (Xvfb, no WM): canvas
coordinates equal screen coordinates.

The 200s timeline sweeps the field and periodically clicks the fixed UI
positions of LAUNCH and the first upgrade button. Clicks are state-safe:
LAUNCH is hidden in SALVAGE and the shop is disabled outside DOCK, so
 stray clicks are no-ops; this drives a full economy loop on camera:
collect -> auto/manual return -> buy strength -> relaunch.

Usage: python3 tools/mouse_timeline.py [duration_seconds]
"""
import math
import subprocess
import sys
import time

DURATION = float(sys.argv[1]) if len(sys.argv) > 1 else 200.0

# Фиксированные центры кнопок (canvas coords; дети панелей — относительные
# офсеты + позиция панели).
BTN_LAUNCH = (1130, 680)      # SidePanel(980,60) + (16..284, 596..644)
BTN_STRENGTH = (1130, 138)    # SidePanel + (16..284, 56..100)
BTN_NEW_GAME = (640, 347)     # MenuPanel(470,110) + (30..310, 214..260)
BTN_CONFIRM_YES = (640, 369)  # ConfirmPanel(460,250) + (32..328, 100..146)


def field_point(t: float):
    """Canvas coords inside the play field."""
    period = 11.0
    return (460 + 430 * math.sin(2 * math.pi * t / period),
            300 + 200 * math.sin(4 * math.pi * t / period + math.pi / 3))


def click(x: float, y: float) -> None:
    subprocess.run(["xdotool", "mousemove", str(int(x)), str(int(y))], check=False)
    subprocess.run(["xdotool", "click", "1"], check=False)


def main() -> None:
    t0 = time.time()
    started = False
    next_strength_click = 6.0
    next_launch_click = 2.0
    while True:
        t = time.time() - t0
        if t >= DURATION:
            break
        if not started:
            # Меню: NEW GAME; на машине с прежним сейвом появится подтверждение.
            click(*BTN_NEW_GAME)
            time.sleep(0.4)
            click(*BTN_CONFIRM_YES)
            started = True
            continue
        if t >= next_launch_click:
            click(*BTN_LAUNCH)
            next_launch_click += 9.0
            continue
        if t >= next_strength_click:
            click(*BTN_STRENGTH)
            next_strength_click += 4.0
            continue
        x, y = field_point(t)
        x = max(0, min(1399, int(x)))
        y = max(0, min(799, int(y)))
        subprocess.run(["xdotool", "mousemove", str(x), str(y)], check=False)
        time.sleep(0.01)
    print("mouse timeline done: %.1fs" % DURATION)


if __name__ == "__main__":
    main()
