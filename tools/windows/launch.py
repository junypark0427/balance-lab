"""Portable Windows operator launcher; no game physics or sensor mapping changes."""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import subprocess
import sys
import time


def config_path() -> Path:
    # Never write into the installed/unzipped application directory.
    base = os.environ.get("LOCALAPPDATA")
    if not base:
        base = str(Path.home() / "AppData" / "Local")
    return Path(base) / "BALANCE_LAB" / "controllers.json"


def seed_config(target: Path, source: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive create preserves settings if two processes start at once.
    try:
        with target.open("x", encoding="utf-8") as destination:
            destination.write(source.read_text(encoding="utf-8"))
    except FileExistsError:
        pass


def stop_child(child: subprocess.Popen | None) -> None:
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=3)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keyboard", action="store_true")
    parser.add_argument("--opengl", action="store_true", help="Alternative for older graphics drivers")
    args = parser.parse_args()
    if os.name != "nt":
        print("This launcher is for Windows 10/11 x64. Use Godot on macOS.")
        return 1

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.CreateMutexW.restype = wintypes.HANDLE
    kernel.ReleaseMutex.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    mutex = kernel.CreateMutexW(None, True, "Local\\BALANCE_LAB_Portable_Launcher")
    if not mutex:
        raise ctypes.WinError(ctypes.get_last_error())
    if ctypes.get_last_error() == 183:  # ERROR_ALREADY_EXISTS
        kernel.CloseHandle(mutex)
        print("BALANCE LAB launcher is already running. Check the game window.")
        return 1

    root = Path(__file__).resolve().parent.parent
    target = config_path()
    logs = target.parent / "logs"
    bridge = game = None
    try:
        logs.mkdir(parents=True, exist_ok=True)
        executable = root / "BALANCE_LAB.exe"
        if not executable.is_file():
            raise FileNotFoundError("Extract the entire ZIP before running START_BALANCE_LAB.cmd")
        seed_config(target, root / "sensors" / "controllers.default.json")
        print("BALANCE LAB | Windows x64")
        print("C: INIT current pose | F8: SENSOR/KEYBOARD | F4: sensor panel | F3: debug overlay")
        print("Settings:", target)
        print("Logs:", logs)
        with (logs / "bridge.log").open("w", encoding="utf-8") as bridge_log, (logs / "game.log").open("w", encoding="utf-8") as game_log:
            if not args.keyboard:
                bridge = subprocess.Popen(
                    [sys.executable, "-u", str(root / "sensors" / "bridge.py"),
                     "--config", str(target), "--no-console"],
                    cwd=root, stdout=bridge_log, stderr=subprocess.STDOUT,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
                time.sleep(0.6)
                if bridge.poll() is not None:
                    print("Sensor bridge could not start. Keyboard is available; see bridge.log.")
                else:
                    print("Sensor bridge started. Hold neutral, press C, then select SENSOR with F8.")
            command = [str(executable)]
            if args.opengl:
                command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]
            game = subprocess.Popen(command, cwd=root, stdout=game_log, stderr=subprocess.STDOUT)
            print("Keep this window open. Closing the game also stops this launcher's sensor bridge.")
            code = game.wait()
            if code:
                print("Game exited with code", code, "- see game.log.")
            return code
    finally:
        # Only our own children are stopped; unrelated Python/serial processes are untouched.
        stop_child(game)
        stop_child(bridge)
        kernel.ReleaseMutex(mutex)
        kernel.CloseHandle(mutex)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print("Could not launch BALANCE LAB:", exc, file=sys.stderr)
        raise SystemExit(1)
