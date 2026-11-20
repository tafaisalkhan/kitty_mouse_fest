"""Block private inputs and ad identifiers before they enter Git."""
import re
import subprocess
import sys
from pathlib import Path

def git(*args):
    return subprocess.check_output(["git", *args])

def main():
    staged = "--staged" in sys.argv
    names = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").decode().split("\0") if staged else git("ls-files", "-z").decode().split("\0")
    bad = []
    for name in filter(None, names):
        base = Path(name).name.lower()
        private = base in {"admob_secrets.json", "release_signing.json", "export_presets.cfg", "key.properties", "signing.properties", ".env"} or base.startswith(".env.") or base.endswith((".jks", ".keystore")) or "keystore" in base and base.endswith(".properties") or name.startswith(".private/")
        if private:
            bad.append(name + ": private file")
            continue
        raw = git("show", ":" + name) if staged else Path(name).read_bytes()
        if re.search(rb"ca-app-pub-\d{16}[~/]\d{10}", raw):
            bad.append(name + ": embedded ad identifier")
        if b"BEGIN PRIVATE KEY" in raw or b"BEGIN RSA PRIVATE KEY" in raw:
            bad.append(name + ": private key")
    if bad:
        print("Commit blocked:\n" + "\n".join(bad))
        return 1
    print("Secret scan passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
