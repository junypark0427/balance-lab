#!/usr/bin/env python3
"""Build a Windows x64 game and an offline, portable serial companion from macOS/Windows."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DOWNLOADS = ROOT / "build" / "downloads"
TEMPLATES = ROOT / "build" / "templates"
OUTPUT = ROOT / "dist" / "BALANCE_LAB_Windows"
INPUTS = {
    "Godot_v4.7.2-stable_export_templates.tpz": (
        "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz",
        "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011",
    ),
    "python-3.13.17-embed-amd64.zip": (
        "https://www.python.org/ftp/python/3.13.17/python-3.13.17-embed-amd64.zip",
        "9e35319bffedab8b36ad44d8f377cb4f1733bcec257a0b6d04d94f01486ddb38",
    ),
    "pyserial-3.5-py2.py3-none-any.whl": (
        "https://files.pythonhosted.org/packages/07/bc/587a445451b253b285629263eb51c2d8e9bcea4fc97826266d186f96f558/pyserial-3.5-py2.py3-none-any.whl",
        "c4451db6ba391ca6ca299fb3ec7bae67a5c55dde170964c7a14ceefec02f2cf0",
    ),
    "pyserial-LICENSE.txt": (
        "https://raw.githubusercontent.com/pyserial/pyserial/v3.5/LICENSE.txt",
        "f91cb9813de6a5b142b8f7f2dede630b5134160aedaeaf55f4d6a7e2593ca3f3",
    ),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def prepare() -> None:
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    TEMPLATES.mkdir(parents=True, exist_ok=True)
    for name, (url, expected) in INPUTS.items():
        destination = DOWNLOADS / name
        if not destination.exists():
            print("Downloading", name, flush=True)
            pending = destination.with_suffix(destination.suffix + ".part")
            urllib.request.urlretrieve(url, pending)
            pending.replace(destination)
        if sha256(destination) != expected:
            raise ValueError("Checksum mismatch: " + str(destination))
    with zipfile.ZipFile(DOWNLOADS / "Godot_v4.7.2-stable_export_templates.tpz") as archive:
        if archive.read("templates/version.txt").strip() != b"4.7.2.stable":
            raise ValueError("Export template version must match Godot 4.7.2")
        for name in archive.namelist():
            if ("windows_" in name and "x86_64" in name) or name.endswith("icudt_godot.dat"):
                (TEMPLATES / Path(name).name).write_bytes(archive.read(name))
    print("Verified official export templates, Python runtime and pySerial.", flush=True)


def run_logged(command: list[str], name: str) -> None:
    logs = ROOT / "build" / "validation"
    logs.mkdir(parents=True, exist_ok=True)
    with (logs / name).open("w", encoding="utf-8") as log:
        completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    if completed.returncode:
        raise RuntimeError("Command failed; see " + str(logs / name))


def build(godot: str) -> None:
    version = subprocess.check_output([godot, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable"):
        raise ValueError("Use Godot 4.7.2 stable, not " + version)
    if OUTPUT.exists():
        # Do not erase a previous build, configs or logs without operator intent.
        raise FileExistsError("Move the previous output aside first: " + str(OUTPUT))
    OUTPUT.mkdir(parents=True)
    runtime = OUTPUT / "runtime"
    sensors = OUTPUT / "sensors"
    notices = OUTPUT / "licenses"
    for folder in (runtime, sensors, notices):
        folder.mkdir()
    with zipfile.ZipFile(DOWNLOADS / "python-3.13.17-embed-amd64.zip") as archive:
        archive.extractall(runtime)
    # Isolated embedded runtime: only bundled dependencies and standard library.
    (runtime / "python313._pth").write_text("python313.zip\n.\nLib/site-packages\n", encoding="ascii")
    with zipfile.ZipFile(DOWNLOADS / "pyserial-3.5-py2.py3-none-any.whl") as archive:
        for name in archive.namelist():
            if name.startswith("serial/"):
                destination = runtime / "Lib" / "site-packages" / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(name))
    shutil.copy2(DOWNLOADS / "pyserial-LICENSE.txt", notices / "pySerial.txt")
    shutil.copy2(runtime / "LICENSE.txt", notices / "Python.txt")
    shutil.copy2(ROOT / "hardware" / "bridge" / "bridge.py", sensors / "bridge.py")
    for name in ("launch.py", "controllers.default.json"):
        shutil.copy2(ROOT / "tools" / "windows" / name, sensors / name)
    for name in ("START_BALANCE_LAB.cmd", "START_OPENGL_FALLBACK.cmd"):
        text = (ROOT / "tools" / "windows" / name).read_text()
        (OUTPUT / name).write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("ascii"))
    shutil.copy2(ROOT / "docs" / "WINDOWS_RELEASE.md", OUTPUT / "사용방법.md")
    run_logged([godot, "--headless", "--path", str(ROOT), "--script",
                str(ROOT / "tools/windows/write_notices.gd"), "--", str(notices)], "export-licenses.log")
    run_logged([godot, "--headless", "--path", str(ROOT), "--export-release", "Windows Desktop",
                str(OUTPUT / "BALANCE_LAB.exe")], "export-windows.log")
    executable = OUTPUT / "BALANCE_LAB.exe"
    if executable.stat().st_size < (TEMPLATES / "windows_release_x86_64.exe").stat().st_size:
        raise ValueError("Incomplete exported executable")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = {
        "project": "BALANCE LAB", "godot": version, "source_commit": revision,
        "platform": "Windows 10/11 x86_64", "renderer": "Forward+ / Vulkan",
        "windows_native_execution_verified": False,
        "runtime": "CPython 3.13.17 embedded x64", "pyserial": "3.5",
        "sensor_profile": "P1 pitch/invert; P2 roll/invert; fresh C INIT required",
        "inputs": {name: {"url": url, "sha256": digest} for name, (url, digest) in INPUTS.items()},
        "files": {str(p.relative_to(OUTPUT)).replace("\\", "/"): sha256(p)
                  for p in sorted(OUTPUT.rglob("*")) if p.is_file()},
    }
    (OUTPUT / "BUILD_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Exported:", executable, flush=True)
    print("After exported-pack validation, archive this complete directory. Do not distribute only the EXE for sensor play.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot"))
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    prepare()
    if not args.prepare_only:
        if not args.godot:
            parser.error("Pass --godot /path/to/Godot executable")
        build(str(Path(args.godot).resolve()))


if __name__ == "__main__":
    main()
