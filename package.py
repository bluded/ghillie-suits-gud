#!/usr/bin/env python3

import argparse
import shutil
import sys
import zipfile
from pathlib import Path

MOD_NAME = "[BLUD] - Ghillie Suits Gud"
VERSION = "1.0.0"  # bump this for each release; the release tag must match (v1.0.0)
SAFE_NAME = "BLUD-Ghillie-Suits-Gud"
INCLUDE = ["gamedata", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md"]  # everything that ships
DEFAULT_MODS_DIR = "G:/GAMMA/mods" if sys.platform == "win32" else None

ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"


def collect_files():
    """(source path, path inside the zip) for every shipped file, sorted."""
    files = []
    for item in INCLUDE:
        src = ROOT / item
        if not src.exists():
            sys.exit(f"error: missing {item} in {ROOT}")
        if src.is_file():
            files.append((src, src.name))
        else:
            for f in sorted(src.rglob("*")):
                if f.is_file():
                    files.append((f, f.relative_to(ROOT).as_posix()))
    return files


def build_zip(files, zip_name):
    DIST.mkdir(exist_ok=True)
    zip_path = DIST / zip_name
    zip_path.unlink(missing_ok=True)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for src, arc in files:
            zf.write(src, arc)
    return zip_path


def deploy(files, mods_dir, version):
    mods = Path(mods_dir)
    if not mods.is_dir():
        sys.exit(f"error: mods folder not found: {mods}")
    target = mods / MOD_NAME
    target.mkdir(exist_ok=True)

    # Mirror gamedata so files removed from the repo disappear from the install.
    shutil.rmtree(target / "gamedata", ignore_errors=True)
    for src, arc in files:
        dst = target / arc
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # MO2 keeps its own meta.ini. Write one if it's missing, otherwise only
    # update its version= line so MO2 shows the right version.
    meta = target / "meta.ini"
    if not meta.exists():
        meta.write_text(
            "[General]\nmodid=0\n"
            f"version={version}\ninstallationFile=\n"
            f"comments=Built by package.py from {ROOT}\n",
            encoding="utf-8",
        )
    else:
        lines = meta.read_text(encoding="utf-8").splitlines()
        lines = [f"version={version}" if l.startswith("version=") else l for l in lines]
        meta.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return target


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument(
        "--version",
        help=f"add the version to the zip name; must match VERSION ({VERSION}). "
        "A leading 'v' is dropped, so a tag like v1.0.0 works",
    )
    p.add_argument(
        "--safe-name", action="store_true", help="use a name without spaces or brackets"
    )
    p.add_argument(
        "--deploy", action="store_true", help="also sync into the MO2 mods folder"
    )
    p.add_argument(
        "--mods-dir",
        default=DEFAULT_MODS_DIR,
        help=f"MO2 mods folder (default: {DEFAULT_MODS_DIR})",
    )
    args = p.parse_args()

    if args.version and args.version.lstrip("vV") != VERSION:
        sys.exit(
            f"error: --version {args.version} doesn't match VERSION = {VERSION} in package.py. "
            "Bump VERSION first, or tag the release to match it."
        )
    version = VERSION
    base = SAFE_NAME if args.safe_name else MOD_NAME
    sep = "-" if args.safe_name else " "
    zip_name = f"{base}{sep}v{version}.zip" if args.version else f"{base}.zip"

    files = collect_files()
    zip_path = build_zip(files, zip_name)
    print(
        f"Packaged {len(files)} files -> {zip_path} ({zip_path.stat().st_size / 1024:.1f} KB)"
    )

    if args.deploy:
        if not args.mods_dir:
            sys.exit("error: --deploy needs --mods-dir on this platform")
        target = deploy(files, args.mods_dir, version)
        print(f"Deployed -> {target}")
        print(f"Make sure '+{MOD_NAME}' is enabled in your MO2 profile.")


if __name__ == "__main__":
    main()
