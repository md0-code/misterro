"""Upload dist/ to a MiSTer's /media/fat over SSH and verify the copies."""
import argparse
import hashlib
import os
import getpass
from pathlib import Path

import paramiko

ROOT = Path(__file__).resolve().parent.parent
REMOTE_ROOT = "/media/fat"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default=os.environ.get("MISTER_HOST"), required="MISTER_HOST" not in os.environ,
                    help="the MiSTer's address (or MISTER_HOST)")
    ap.add_argument("--user", default=os.environ.get("MISTER_USER", "root"))
    ap.add_argument("--password", default=os.environ.get("MISTER_PASSWORD"))
    a = ap.parse_args()

    files = sorted(p for p in (ROOT / "dist").rglob("*") if p.is_file())
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    password = a.password if a.password is not None else getpass.getpass("MiSTer SSH password: ")
    ssh.connect(a.host, username=a.user, password=password, timeout=10, look_for_keys=False, allow_agent=False)
    sftp = ssh.open_sftp()

    for local in files:
        rel = local.relative_to(ROOT / "dist").as_posix()
        remote = f"{REMOTE_ROOT}/{rel}"
        parts = remote.split("/")
        for i in range(3, len(parts)):
            d = "/".join(parts[:i])
            try:
                sftp.stat(d)
            except FileNotFoundError:
                sftp.mkdir(d)
        sftp.put(str(local), remote)
        _, out, _ = ssh.exec_command(f'md5sum "{remote}"')
        ok = out.read().decode().split()[0] == hashlib.md5(local.read_bytes()).hexdigest()
        print(f"{'OK  ' if ok else 'FAIL'} {remote}")
        if not ok:
            raise SystemExit(1)

    ssh.exec_command("sync")
    ssh.close()


if __name__ == "__main__":
    main()
