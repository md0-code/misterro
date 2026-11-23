"""The firmware and media the cores are built with, which the repository does not hold.

    python tools/assets.py check             every file of tools/assets.lock.json is in place, with its size and SHA-256
    python tools/assets.py unpack ARCHIVE    put the files of a release's assets archive in place
    python tools/assets.py pack ARCHIVE      make that archive from the files in place
    python tools/assets.py lock              write tools/assets.lock.json from the files in place

The files are the ROM images, tapes and disks of src/core-<family>/assets/ (everything there but the project's own
*.py and *.asm sources, which are committed) and the FreeDOS source archives that go with the JUNIOR-XT demo disk
(docs/juniorxt/reference/). MiSTerRO-<version>-assets.zip holds them at these paths.
"""
from __future__ import annotations

import hashlib
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "tools" / "assets.lock.json"
OWN = (".py", ".asm")                                   # committed sources among the assets
EXTRA = [f"docs/juniorxt/reference/{name}-source.zip" for name in ("kernel2036", "freecom082pl3", "chkdsk", "format")]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def present() -> list[str]:
    names = [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / "src").glob("core-*/assets/**/*"))
             if p.is_file() and p.suffix not in OWN and "__pycache__" not in p.parts]
    return sorted(names + [n for n in EXTRA if (ROOT / n).is_file()])


def read_lock() -> dict[str, dict]:
    return json.loads(LOCK.read_text(encoding="utf-8"))


def check() -> list[str]:
    """The files of the lock that are missing or different."""
    bad = []
    for name, entry in read_lock().items():
        path = ROOT / name
        if not path.is_file() or path.stat().st_size != entry["bytes"] or sha(path.read_bytes()) != entry["sha256"]:
            bad.append(name)
    return bad


def pack(archive: Path) -> None:
    bad = check()
    if bad:
        raise SystemExit("missing or changed: " + ", ".join(bad))
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in read_lock():
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            z.writestr(entry, (ROOT / name).read_bytes())


def unpack(archive: Path) -> None:
    lock = read_lock()
    with zipfile.ZipFile(archive) as z:
        names = set(z.namelist())
        for name, entry in lock.items():
            if name not in names:
                raise SystemExit(f"{archive.name} does not hold {name}")
            data = z.read(name)
            if len(data) != entry["bytes"] or sha(data) != entry["sha256"]:
                raise SystemExit(f"{name} in {archive.name} is not the file of tools/assets.lock.json")
            target = ROOT / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    print(f"{len(lock)} files in place")


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else ""
    if command == "check" and len(argv) == 2:
        bad = check()
        print("\n".join(f"missing or changed: {name}" for name in bad) or f"{len(read_lock())} files in place")
        return 1 if bad else 0
    if command == "lock" and len(argv) == 2:
        lock = {name: {"bytes": (ROOT / name).stat().st_size, "sha256": sha((ROOT / name).read_bytes())} for name in present()}
        LOCK.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"{len(lock)} files in tools/assets.lock.json")
        return 0
    if command in ("pack", "unpack") and len(argv) == 3:
        (pack if command == "pack" else unpack)(Path(argv[2]))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
