"""Install the matching Godot template and attach the tracked native sources."""
from pathlib import Path
import os
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def prepare():
    build = ROOT / "android/build"
    (ROOT / "android/.gdignore").touch()
    template = Path(os.environ.get("APPDATA", "")) / "Godot/export_templates/4.7.2.stable/android_source.zip"
    if not (build / "gradlew.bat").exists():
        if not template.is_file():
            raise RuntimeError("Install the Godot 4.7.2 Android export template first.")
        with zipfile.ZipFile(template) as archive:
            archive.extractall(build)
    config = build / "config.gradle"
    text = config.read_text(encoding="utf-8").replace("ndkVersion         : '29.0.14206865'", "ndkVersion         : '28.2.13676358'")
    config.write_text(text, encoding="utf-8")
    gradle = build / "build.gradle"
    text = gradle.read_text(encoding="utf-8")
    attach = "apply from: '../kitty/services.gradle'"
    if attach not in text:
        gradle.write_text(text + "\n" + attach + "\n", encoding="utf-8")
    sdk = os.environ.get("ANDROID_HOME", "C:/AndroidSdk").replace("\\", "/")
    (build / "local.properties").write_text("sdk.dir=" + sdk + "\n", encoding="utf-8")
    (ROOT / "android/.build_version").write_text("4.7.2.stable", encoding="utf-8")
    # Remove stale Godot importer sidecars from older templates that lacked
    # the .gdignore boundary; Android's resource merger rejects these files.
    for metadata in (build / "res").rglob("*.import"):
        metadata.unlink()
    activity = build / "src/main/java/com/godot/game/GodotApp.java"
    text = activity.read_text(encoding="utf-8")
    if "protected void onNewIntent" not in text:
        text = text.replace("\t@Override\n\tpublic void onCreate(Bundle savedInstanceState)", "\t@Override\n\tprotected void onNewIntent(android.content.Intent intent) { super.onNewIntent(intent); setIntent(intent); }\n\n\t@Override\n\tpublic void onCreate(Bundle savedInstanceState)")
        activity.write_text(text, encoding="utf-8")

if __name__ == "__main__":
    prepare()
    print("Android template and KittyServices sources are ready.")
