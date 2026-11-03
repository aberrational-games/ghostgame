#!/usr/bin/env python3

import json
import os
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

BRANCH = "godot-file-locks"
REGISTRY = ".godot_locks/locks.json"
EXTENSIONS = {".tscn", ".gd", ".tres", ".res"}


def git(*args, cwd=None):
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip()


def find_root():
    for path in (Path.cwd(), *Path.cwd().parents):
        if (path / "project.godot").is_file():
            return path.resolve()
    raise RuntimeError("Run this command inside a Godot project.")


ROOT = find_root()
REMOTE = git("remote", "get-url", "origin", cwd=ROOT)


def get_user():
    result = subprocess.run(
        ["gh", "api", "user"],
        capture_output=True,
        text=True
    )
    if result.returncode:
        raise RuntimeError("Run 'gh auth login' first.")

    return json.loads(result.stdout)["login"]


USER = get_user()


def normalize(value):
    path = (ROOT / value).resolve()

    if not path.is_relative_to(ROOT):
        raise RuntimeError("Path must be inside the project.")

    if not path.is_file():
        raise RuntimeError(f"File not found: {value}")

    if path.suffix.lower() not in EXTENSIONS:
        raise RuntimeError("Unsupported file type.")

    return path, path.relative_to(ROOT).as_posix()


def set_readonly(path):
    mode = path.stat().st_mode
    path.chmod(mode & ~(stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH))


def set_writable(path):
    mode = path.stat().st_mode
    path.chmod(mode | stat.S_IWUSR)


def clone_registry(directory):
    git(
        "clone", "--quiet",
        "--branch", BRANCH,
        "--single-branch",
        REMOTE, str(directory)
    )


def update_registry(change):
    # Git's non-fast-forward rejection prevents two users
    # from successfully acquiring the same lock.
    for attempt in range(8):
        with tempfile.TemporaryDirectory() as temp:
            clone = Path(temp) / "registry"
            clone_registry(clone)

            registry = clone / REGISTRY
            locks = json.loads(registry.read_text())

            if not change(locks):
                return False

            registry.write_text(
                json.dumps(locks, indent=2) + "\n"
            )

            git("add", REGISTRY, cwd=clone)
            git(
                "commit", "-m",
                f"Update file locks ({USER})",
                cwd=clone
            )

            result = subprocess.run(
                ["git", "push", "origin", BRANCH],
                cwd=clone,
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                return True

        time.sleep(0.5 * (attempt + 1))

    raise RuntimeError("Could not update lock registry. Try again.")


def read_locks():
    with tempfile.TemporaryDirectory() as temp:
        clone = Path(temp) / "registry"
        clone_registry(clone)
        return json.loads((clone / REGISTRY).read_text())


def lock_file(value):
    path, relative = normalize(value)

    def change(locks):
        if relative in locks:
            print("Already locked by:", locks[relative]["owner"])
            return False

        locks[relative] = {"owner": USER}
        return True

    if update_registry(change):
        set_writable(path)
        print(f"Locked: {relative}")
        print(f"Owner: {USER}")


def unlock_file(value):
    path, relative = normalize(value)

    def change(locks):
        entry = locks.get(relative)

        if not entry:
            print("File is not locked.")
            return False

        if entry["owner"] != USER:
            print("You do not own this lock.")
            print("Owner:", entry["owner"])
            return False

        del locks[relative]
        return True

    if update_registry(change):
        set_writable(path)
        print(f"Unlocked: {relative}")


def list_locks():
    locks = read_locks()

    if not locks:
        print("No active locks.")
        return

    for path, entry in sorted(locks.items()):
        print(f"{path} — {entry['owner']}")


def status(value):
    _, relative = normalize(value)
    entry = read_locks().get(relative)

    if entry:
        print(f"LOCKED by {entry['owner']}")
    else:
        print("AVAILABLE")


def sync():
    locks = read_locks()

    # Restore write permission on supported project files.
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue

        if ".git" in path.parts or ".godot" in path.parts:
            continue

        if path.suffix.lower() in EXTENSIONS:
            set_writable(path)

    # Apply read-only permissions to files locked by others.
    for relative, entry in locks.items():
        path = (ROOT / relative).resolve()

        if not path.is_relative_to(ROOT):
            continue

        if path.is_file() and entry["owner"] != USER:
            set_readonly(path)

    print("Permissions synchronized.")


def main():
    if len(sys.argv) < 2:
        print("Commands: lock, unlock, list, status, sync")
        return

    command = sys.argv[1]

    if command == "lock" and len(sys.argv) == 3:
        lock_file(sys.argv[2])
    elif command == "unlock" and len(sys.argv) == 3:
        unlock_file(sys.argv[2])
    elif command == "list":
        list_locks()
    elif command == "status" and len(sys.argv) == 3:
        status(sys.argv[2])
    elif command == "sync":
        sync()
    else:
        print("Invalid command or arguments.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("ERROR:", error)
        sys.exit(1)
