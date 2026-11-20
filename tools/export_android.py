"""Export a debug APK or production-only, release-signed AAB without logging secrets."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
import hashlib
from setup_android import ROOT, prepare

KEYS = ("ADMOB_APP_ID", "ADMOB_BANNER_ID", "ADMOB_INTERSTITIAL_ID", "ADMOB_REWARDED_ID")

def sync_public_export_options(local_text):
    # The tracked template owns version/artwork metadata. An open editor can
    # otherwise save stale public values into the private local preset.
    canonical = (ROOT / "export_presets.example.cfg").read_text(encoding="utf-8")
    fields = ("include_filter", "version/code", "version/name", "launcher_icons/main_192x192",
              "launcher_icons/adaptive_foreground_432x432", "launcher_icons/adaptive_monochrome_432x432")
    for field in fields:
        pattern = r"^" + re.escape(field) + r"=.*$"
        match = re.search(pattern, canonical, re.MULTILINE)
        if match:
            local_text = re.sub(pattern, lambda _: match.group(0), local_text, count=1, flags=re.MULTILINE)
    return local_text

def read_config(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}

def validate_trial_bundle():
    manifest_path = ROOT / "levels/trial/manifest.json"
    if not manifest_path.exists():
        return
    manifest = read_config(manifest_path)
    if not manifest.get("all_verified") or len(manifest.get("levels", [])) != 5 or not manifest.get("mechanics_files"):
        raise RuntimeError("Run TrialCampaignChecks before exporting: all five trial levels must pass.")
    for name, expected in manifest.get("mechanics_files", {}).items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Trial mechanics changed after verification: " + name)
    for entry in manifest["levels"]:
        path = ROOT / "levels/trial" / ("trial_%02d.json" % entry["number"])
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != entry.get("file_sha256"):
            raise RuntimeError("Trial JSON changed after verification: " + path.name)

def validate_endless_bundle():
    path = ROOT / "levels/endless/verification.json"
    if not path.exists():
        raise RuntimeError("Run EndlessBurrowsChecks before exporting.")
    proof = read_config(path)
    if not proof.get("fast_passed") or not proof.get("normal_passed") or not proof.get("hashes"):
        raise RuntimeError("Endless modules must pass both fixed-step and normal-speed checks.")
    for name, expected in proof["hashes"].items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Endless source or artwork changed after verification: " + name)


def validate_release():
    ads = read_config(Path(os.environ.get("KITTY_ADMOB_CONFIG", ROOT / "admob_secrets.json")))
    missing = []
    for key in KEYS:
        value = str(ads.get(key, ""))
        pattern = r"ca-app-pub-\d{16}~\d{10}" if key == "ADMOB_APP_ID" else r"ca-app-pub-\d{16}/\d{10}"
        if not re.fullmatch(pattern, value) or "3940256099942544" in value:
            missing.append(key)
    signing = read_config(Path(os.environ.get("KITTY_SIGNING_CONFIG", ROOT / "release_signing.json")))
    for key in ("keystore_path", "key_alias", "store_password", "key_password"):
        if not signing.get(key): missing.append("release_signing." + key)
    if signing.get("keystore_path") and not Path(signing["keystore_path"]).is_file(): missing.append("release keystore file")
    if missing:
        raise RuntimeError("Release export blocked. Configure: " + ", ".join(missing) + ". No test IDs or signing fallbacks will be used.")
    return ads, signing

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--engine", default=str(Path.home() / "Downloads/Godot_Engine/Godot_v4.7.2-stable_win64.exe"))
    args = parser.parse_args()
    private_values = []
    signing = None
    if args.release:
        ads, signing = validate_release()
        private_values = list(ads.values()) + [signing["store_password"], signing["key_password"]]
    validate_trial_bundle()
    validate_endless_bundle()
    prepare()
    path = ROOT / "export_presets.cfg"
    if not path.exists(): path.write_bytes((ROOT / "export_presets.example.cfg").read_bytes())
    original = sync_public_export_options(path.read_text(encoding="utf-8"))
    text = original
    if args.release:
        # The temporary local preset is ignored by Git and restored even on failure.
        release = original.split("[preset.1]")[0].replace("[preset.0]", "[preset.1]").replace("[preset.0.options]", "[preset.1.options]")
        release = release.replace('name="Android"', 'name="Android Release"').replace('export_path="build/kitty-rescue-debug.apk"', 'export_path="build/kitty-rescue-release.aab"')
        release += '\ngradle_build/export_format=1\n'
        for key, value in [("release",signing["keystore_path"]),("release_user",signing["key_alias"]),("release_password",signing["store_password"])]:
            release += "keystore/" + key + "=" + json.dumps(value.replace("\\", "/") if key=="release" else value) + "\n"
        text = original.split("[preset.1]")[0] + "\n" + release
    path.write_text(text, encoding="utf-8")
    env = os.environ.copy()
    env["KITTY_PRODUCTION"] = "1" if args.release else "0"
    env.setdefault("JAVA_HOME", "C:/Program Files/Eclipse Adoptium/jdk-21.0.12.8-hotspot")
    env.setdefault("ANDROID_HOME", "C:/AndroidSdk")
    output = "build/kitty-rescue-release.aab" if args.release else "build/kitty-rescue-debug.apk"
    started = time.time()
    command = [args.engine, "--headless", "--path", str(ROOT), "--export-release" if args.release else "--export-debug", "Android Release" if args.release else "Android", output, "--log-file", "build/android-export-private.log"]
    try:
        process = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        log = process.stdout
        log_path = ROOT / "build/android-export-private.log"
        if log_path.exists(): log += "\n" + log_path.read_text(encoding="utf-8", errors="replace")
        for value in filter(None, private_values): log = log.replace(value, "<redacted>")
        log = re.sub(r"ca-app-pub-\d{16}[~/]\d{10}", "<redacted-ad-id>", log)
        (ROOT / "build/android-export-redacted.log").write_text(log, encoding="utf-8")
        if process.returncode != 0 or "[ DONE ] export" not in log:
            raise RuntimeError("Android export failed. See build/android-export-redacted.log.")
        artifact = ROOT / output
        if not artifact.is_file() or artifact.stat().st_mtime < started:
            raise RuntimeError("Export did not produce a fresh Android artifact.")
        with zipfile.ZipFile(artifact) as archive:
            asset_prefix = "base/assets/" if args.release else "assets/"
            for metadata in ("cat-ball-white.frames.json", "mouse-ball.frames.json"):
                if asset_prefix + "assets/characters/" + metadata not in archive.namelist():
                    raise RuntimeError("Export is missing required character frame metadata: " + metadata)
            if (ROOT / "levels/trial/manifest.json").exists():
                for number in range(1, 6):
                    if asset_prefix + "levels/trial/trial_%02d.json" % number not in archive.namelist():
                        raise RuntimeError("Export is missing trial JSON %d." % number)
            for module in ("laser", "bee", "rock_switch", "portal", "water"):
                name = asset_prefix + "levels/endless/modules/" + module + ".json"
                if name not in archive.namelist():
                    raise RuntimeError("Missing endless module: " + module)
            for metadata in ("props-v2.frames.json", "mechanisms-v2.frames.json", "bomb-v2.frames.json"):
                if asset_prefix + "assets/obstacles/" + metadata not in archive.namelist():
                    raise RuntimeError("Missing prop texture metadata: " + metadata)
            units_name = "base/assets/kitty_ad_units.json" if args.release else "assets/kitty_ad_units.json"
            if units_name not in archive.namelist():
                raise RuntimeError("Export is missing its generated native ad-unit config.")
            units = json.loads(archive.read(units_name))
            if args.release:
                if any(units.get(key) != ads[key] for key in KEYS[1:]):
                    raise RuntimeError("Packaged production ad-unit config does not match private inputs.")
                if not any(name.startswith("META-INF/") and name.endswith((".RSA", ".DSA", ".EC")) for name in archive.namelist()):
                    raise RuntimeError("Release AAB is not signed.")
        print("Exported " + output)
    finally:
        path.write_text(original, encoding="utf-8")
    return 0

if __name__ == "__main__":
    try: raise SystemExit(main())
    except (RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
