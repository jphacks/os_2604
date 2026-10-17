#!/bin/sh
# Native asset hooks preserve PATH but may filter DEVELOPER_DIR.
# Keep SDK selection local to this command without changing xcode-select.
set -eu
xcode_developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [ ! -d "$xcode_developer_dir" ]; then
  echo 'Set DEVELOPER_DIR to the installed Xcode Contents/Developer directory.' >&2
  exit 1
fi
shim_dir=$(mktemp -d "${TMPDIR:-/tmp}/os2604-xcode.XXXXXX")
trap 'rm -rf "$shim_dir"' EXIT HUP INT TERM
ln -s "$xcode_developer_dir" "$shim_dir/Developer"
cat > "$shim_dir/xcrun" <<'SHIM'
#!/bin/sh
DEVELOPER_DIR="$(dirname "$0")/Developer"
export DEVELOPER_DIR
exec /usr/bin/xcrun "$@"
SHIM
chmod +x "$shim_dir/xcrun"
DEVELOPER_DIR="$xcode_developer_dir" PATH="$shim_dir:$PATH" flutter "$@"
