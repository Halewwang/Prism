#!/bin/zsh
set -euo pipefail

if (( $# != 2 )); then
  print -u2 "usage: $0 <Prism.app> <output.dmg>"
  exit 64
fi
app="${1:A}"
dmg="${2:A}"
script_dir="${0:A:h}"
repo_root="${script_dir:h:h}"
vendor="$repo_root/node_modules/dmg-builder/vendor"
[[ -d "$app" && "${app:t}" == Prism.app && ! -e "$dmg" ]]
[[ -f "$vendor/dmgbuild/core.py" ]] || {
  print -u2 "Install the locked packaging dependencies first: npm ci --ignore-scripts"
  exit 69
}
temporary="$(mktemp -d "${TMPDIR:-/tmp}/prism-installer.XXXXXX")"
temporary="${temporary:A}"
mount="$temporary/mount"
mounted=false
cleanup() {
  if [[ "$mounted" == true ]] && ! hdiutil detach "$mount" -quiet; then
    print -u2 "Installer volume remains mounted at: $mount"
    return
  fi
  rm -rf "$temporary"
}
trap cleanup EXIT
mkdir -p "$temporary/staging/.background" "$mount" "${dmg:h}"
ditto "$app" "$temporary/staging/Prism.app"
ln -s /Applications "$temporary/staging/Applications"
cp "$script_dir/../Resources/Installer/install-background.png" "$temporary/staging/.background/install.png"
hdiutil create -volname Prism -fs HFS+ -srcfolder "$temporary/staging" -format UDRW "$temporary/readwrite.dmg" >/dev/null
# A failed attach can still leave a mounted volume that cleanup must not delete.
mounted=true
hdiutil attach "$temporary/readwrite.dmg" -readwrite -nobrowse -mountpoint "$mount" >/dev/null
# Generate aliases on the final volume so they never point into the build checkout.
env -u backgroundColor PYTHONDONTWRITEBYTECODE=1 PYTHONIOENCODING=utf8 \
  volumePath="$mount" windowX=200 windowY=200 windowWidth=640 windowHeight=400 \
  iconSize=112 iconTextSize=13 backgroundFile="$mount/.background/install.png" \
  iconLocations="'Prism.app': (175, 160), 'Applications': (465, 160)" \
  python3 -B "$vendor/dmgbuild/core.py"
python3 -B "$script_dir/verify-dmg-layout.py" "$mount"
hdiutil detach "$mount" -quiet
mounted=false
hdiutil convert "$temporary/readwrite.dmg" -format UDZO -o "$dmg" >/dev/null
hdiutil verify "$dmg" >/dev/null
