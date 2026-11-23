"""The release archives, in dist/releases/, and the card's tree in dist/.

    python tools/package.py

MiSTerRO-<version>-<CORE>.zip, one for each core, is made from the core's own verified package
(src/core-<family>/dist/<CORE>.zip, written by its tools/build.ps1 package): the bitstream (_Computer/) and the card's
files (games/<CORE>/) as they are there, the CRT emulation video preset (src/preset-crt/dist/: Filters/, Gamma/, Presets/)
and the documentation in docs/MiSTerRO/. It is extracted onto the MiSTer card.
The core's package also carries a source export and the build's reports, which a release does without; scans of
manuals and schematics are never shipped, and a package that still holds some loses them here.

MiSTerRO-<version>-assets.zip holds the firmware and media the cores are built with (tools/assets.py), for building
them from source. dist/releases/ holds the current version only; dist/ is the card
with everything on it.

Checked on the way: every file taken against the package's own SHA256SUMS, the bitstream against the SHA-256 in the
core's validation page where the page gives one, every bundle.json against the files beside it, every link of the
documentation, and each archive read back.
"""
from __future__ import annotations

import hashlib
import io
import json
import posixpath
import re
import shutil
import sys
import zipfile
from pathlib import Path

import assets

ROOT = Path(__file__).resolve().parents[1]
NAME = "MiSTerRO"
CORES = {  # family (src/core-<family>, docs/<family>): the core's name on the card
    "hc": "HC", "cip": "CIP", "tims": "TIMS", "cobra": "COBRA", "jet": "JET", "cubz": "CUBZ", "amic": "AMIC", "prae": "PRAE",
    "juniorxt": "JUNIORXT",
}
SCANS = (".pdf", "-docs.zip")
DOCS = "docs/" + NAME + "/"                              # the documentation's place on the card
NOT_SHIPPED = {"dev", "reference", "analysis"}           # folders of docs/ that stay in the repository
FAMILY_SCOPE = "One core with runtime model selection; the firmware, tapes and disks of each model are in its named subfolder."
# The lines of a README that show the pictures of assets/, which the archives do not hold.
PICTURE_LINE = re.compile(r"^(?:!\[[^\]]*\]\(assets/[^)]*\)|<p align=\"center\">.*\bassets/.*</p>)\r?\n\r?\n", re.M)


class PackageError(Exception):
    pass


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def documentation() -> dict[str, bytes]:
    """The tracked documentation at its repository paths under docs/MiSTerRO/, its links checked."""
    files: dict[str, bytes] = {}
    for name in ("README.md", "README.ro.md"):
        text = PICTURE_LINE.sub("", (ROOT / name).read_bytes().decode("utf-8"))
        if "assets/" in text:
            raise PackageError(f"{name} shows a picture of assets/ that is not on a line of its own")
        files[name] = text.encode("utf-8")
    for path in sorted((ROOT / "docs").rglob("*")):
        rel = path.relative_to(ROOT / "docs")
        if path.is_file() and rel.parts[0] not in NOT_SHIPPED and not NOT_SHIPPED & set(rel.parts) and rel.name != "DEVELOPMENT.md":
            files["docs/" + rel.as_posix()] = path.read_bytes()
    for name, data in files.items():
        if not name.endswith(".md"):
            continue
        for target in re.findall(r"\]\(([^)\s]+)\)", data.decode("utf-8")):
            if "://" in target or target.startswith(("#", "mailto:")):
                continue
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target.split("#", 1)[0]))
            if resolved not in files:
                raise PackageError(f"{name} links to {target}, which the archives do not hold")
    return {DOCS + name: data for name, data in files.items()}


def receipt(family: str, data: bytes, kept: set[str], folder: str) -> bytes:
    """A bundle.json without the scans it listed, described as the repository describes the model now."""
    bundle = json.loads(data)
    files = bundle.get("files")
    if isinstance(files, dict):
        bundle["files"] = {n: v for n, v in files.items() if folder + n in kept}
    if isinstance(bundle.get("sources"), dict):
        bundle["sources"] = {n: v for n, v in bundle["sources"].items() if not n.endswith(SCANS)}
    for key in ("manual", "schematic"):
        bundle.pop(key, None)
    models = ROOT / "docs" / family / "bundles.json"
    if "model" in bundle and models.is_file():
        bundle["scope"] = json.loads(models.read_text(encoding="utf-8"))[bundle["model"]]["scope"]
    elif "family" in bundle:
        bundle["scope"] = FAMILY_SCOPE
    return (json.dumps(bundle, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def core_files(family: str, core: str) -> dict[str, bytes]:
    """The card's files of one core, from its verified package."""
    package = ROOT / "src" / f"core-{family}" / "dist" / f"{core}.zip"
    if not package.is_file():
        raise PackageError(f"{package.relative_to(ROOT)} is missing: build the core's package first")
    with zipfile.ZipFile(package) as z:
        sums = {n: h for h, n in (line.split("  ", 1) for line in z.read("SHA256SUMS").decode("utf-8").splitlines())}
        names = [n for n in z.namelist() if n.startswith(("_Computer/", "games/")) and not n.endswith("/") and not n.endswith(SCANS)]
        files = {n: z.read(n) for n in names}
    for name, data in files.items():
        if sums.get(name) != sha(data):
            raise PackageError(f"{package.name}: {name} is not the file of its SHA256SUMS")
    bitstreams = [n for n in files if n.endswith(".rbf")]
    if len(bitstreams) != 1 or not any(n.startswith(f"games/{core}/") for n in files):
        raise PackageError(f"{package.name}: one bitstream and the files of games/{core}/ expected")
    validation = (ROOT / "docs" / family / "validation.md").read_text(encoding="utf-8")
    stated = re.search(r"(?:RBF|Bitstream|\.rbf) SHA-256:\s*`([0-9a-f]{64})`", validation)
    digest = sha(files[bitstreams[0]])
    if stated and stated.group(1) != digest:
        raise PackageError(f"{package.name}: the bitstream is not the one of docs/{family}/validation.md")
    kept = set(files)
    for name in [n for n in files if n.endswith("/bundle.json")]:
        folder = name[:-len("bundle.json")]
        files[name] = receipt(family, files[name], kept, folder)
        listed = json.loads(files[name]).get("files", {})
        for member, entry in listed.items():
            if isinstance(entry, dict) and "sha256" in entry and sha(files[folder + member]) != entry["sha256"]:
                raise PackageError(f"{package.name}: {folder}{member} is not the file of its bundle.json")
    print(f"{core:9} {len(files):3} files, bitstream {digest[:16]}" + (" (as validated)" if stated else ""))
    return files


def preset_files() -> dict[str, bytes]:
    source = ROOT / "src" / "preset-crt" / "dist"
    files = {p.relative_to(source).as_posix(): p.read_bytes() for p in sorted(source.rglob("*")) if p.is_file()}
    if not any(n.startswith("Presets/") for n in files):
        raise PackageError("src/preset-crt/dist/ holds no preset")
    return files


def write(archive: Path, files: dict[str, bytes]) -> None:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(files):
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            z.writestr(entry, files[name])
    archive.write_bytes(buffer.getvalue())
    with zipfile.ZipFile(archive) as z:
        if z.testzip() or {n: sha(z.read(n)) for n in z.namelist()} != {n: sha(d) for n, d in files.items()}:
            raise PackageError(f"{archive.name} does not read back as written")


def main() -> int:
    version = (ROOT / "src" / "VERSION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise PackageError("src/VERSION must hold MAJOR.MINOR.PATCH")
    if f"## {version} (" not in (ROOT / "docs" / "CHANGELOG.md").read_text(encoding="utf-8"):
        raise PackageError(f"docs/CHANGELOG.md has no entry for {version}")
    docs = documentation()
    preset = preset_files()
    card: dict[str, bytes] = {**docs, **preset}
    archives: dict[str, dict[str, bytes]] = {}
    for family, core in CORES.items():
        files = core_files(family, core)
        archives[core] = {**files, **preset, **docs}
        card.update(files)

    dist = ROOT / "dist"
    releases = dist / "releases"
    if dist.exists():
        shutil.rmtree(dist)
    releases.mkdir(parents=True)
    for label, files in archives.items():
        write(releases / f"{NAME}-{version}-{label}.zip", files)
    assets.pack(releases / f"{NAME}-{version}-assets.zip")
    for name, data in card.items():
        target = dist / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for archive in sorted(releases.iterdir()):
        print(f"{archive.stat().st_size:10} {archive.name}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except PackageError as error:
        print(f"package: {error}", file=sys.stderr)
        sys.exit(1)
