
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT/ThreeOneOSFive.xcodeproj/project.pbxproj"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/VexoExternal.xcarchive"
IPA="$BUILD_DIR/VexoExternal-unsigned.ipa"

echo "Preparing Vexo External project..."

if [ ! -f "$PROJECT" ]; then
  echo "ERROR: Xcode project file not found: $PROJECT" >&2
  exit 1
fi

# Repair the Xcode project file format marker.
python3 - "$PROJECT" <<'PYTHON'
from pathlib import Path
import sys

project = Path(sys.argv[1])
text = project.read_text(encoding="utf-8")

lines = text.splitlines()
if not lines:
    raise SystemExit("ERROR: project.pbxproj is empty")

# Xcode project files should use the standard OpenStep plist marker.
if lines[0].strip() != "// !$*UTF8*$!":
    lines[0] = "// !$*UTF8*$!"

text = "\n".join(lines) + "\n"

# Quote file paths containing spaces and parentheses.
bad_paths = [
    "ThreeOneOSFive/Patches/OGIOS File (6).3105",
    "ThreeOneOSFive/Patches/OGIOS File (7).3105",
    "ThreeOneOSFive/Patches/OGIOS File (9).3105",
    "ThreeOneOSFive/Patches/OGIOS File (10).3105",
]

for path in bad_paths:
    text = text.replace(
        "path = " + path + ";",
        'path = "' + path + '";'
    )

project.write_text(text, encoding="utf-8")
print("Project file format and patch paths checked.")
PYTHON

# Validate the project file before starting the build.
plutil -lint "$PROJECT"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

command -v xcodebuild >/dev/null || {
  echo "ERROR: xcodebuild is required on macOS." >&2
  exit 127
}

echo "Building unsigned Vexo External IPA..."

xcodebuild \
  -project "$ROOT/ThreeOneOSFive.xcodeproj" \
  -scheme OGIOS \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive

APP="$ARCHIVE/Products/Applications/OGIOS.app"

if [ ! -d "$APP" ]; then
  echo "ERROR: OGIOS.app was not created." >&2
  exit 1
fi

PATCH_DIR="$APP/Patches"
mkdir -p "$PATCH_DIR"

for package in "$APP"/*.3105; do
  [ -e "$package" ] || continue
  filename="$(basename "$package" .3105)"
  mv "$package" "$PATCH_DIR/$filename.OGIOS"
done

VIDEO="$ROOT/ThreeOneOSFive/Resources/Create external video.mov"

if [ -f "$VIDEO" ]; then
  cp "$VIDEO" "$APP/Create external video.mov"
else
  echo "WARNING: External video resource was not found."
fi

/usr/libexec/PlistBuddy \
  -c "Set :CFBundleDisplayName 'Vexo external'" \
  "$APP/Info.plist" || true

/usr/libexec/PlistBuddy \
  -c "Set :CFBundlePackageType APPL" \
  "$APP/Info.plist" || true

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

(
  cd "$BUILD_DIR"
  /usr/bin/zip -qry "$IPA" Payload
  rm -rf Payload
)

echo "SUCCESS: Unsigned IPA created at:"
echo "$IPA"
