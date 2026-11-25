#!/bin/sh
# Installs aSup and every add-on of the signed catalog into one folder (Linux x86_64):
#   <dir>/asup, <dir>/extensions/<id>/ (read beside the binary, no profile entry needed),
#   and a link ~/.local/bin/asup. Rerun it to update.
#   curl -fsSL https://raw.githubusercontent.com/gagni/asup-releases/main/install.sh | sh
#   sh install.sh [--dir DIR] [--no-addons]
# Needs: curl or wget, tar with zstd, unzip, sha256sum, python3.
set -eu
repo=https://raw.githubusercontent.com/gagni/asup-releases/main
dir=${ASUP_INSTALL_DIR:-$HOME/.local/opt/asup}
addons=1
while [ $# -gt 0 ]; do
    case $1 in
        --dir) dir=$2; shift ;;
        --no-addons) addons=0 ;;
        *) echo "usage: install.sh [--dir DIR] [--no-addons]" >&2; exit 2 ;;
    esac
    shift
done
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo "aSup ships for Linux x86_64 only" >&2; exit 1; }
for tool in tar unzip sha256sum python3 zstd; do
    command -v $tool >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done
fetch() {
    if command -v curl >/dev/null; then curl -fsSL --retry 3 -o "$2" "$1"; else wget -q -O "$2" "$1"; fi
}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fetch "$repo/catalog.json" "$work/catalog.json"
# One line per asset of this OS: kind id version url sha256.
python3 -I - "$work/catalog.json" > "$work/assets" <<'PY'
import json, sys
for c in json.load(open(sys.argv[1]))['components']:
    for a in c['assets']:
        if a['os'] == 'linux' and a['arch'] in ('x86_64', 'any'):
            print(c['kind'], c['id'], a.get('version') or c['version'], a['url'], a['sha256'])
PY
get() { # url sha256 -> verified file path
    file=$work/$(basename "$1")
    fetch "$1" "$file" >&2
    [ "$(sha256sum "$file" | cut -d' ' -f1)" = "$2" ] || { echo "checksum mismatch: $1" >&2; exit 1; }
    echo "$file"
}
mkdir -p "$dir/extensions"
while read -r kind id version url sha; do
    if [ "$kind" = app ]; then
        echo "aSup $version"
        archive=$(get "$url" "$sha")
        tar --zstd -xf "$archive" -C "$work"
        install -m 755 "$work"/asup-light-*-linux-x86_64/asup "$dir/asup.new"
        mv -f "$dir/asup.new" "$dir/asup"
    elif [ $addons = 1 ]; then
        echo "add-on $id $version"
        pack=$(get "$url" "$sha")
        rm -rf "$dir/extensions/$id.new"
        unzip -q "$pack" -d "$dir/extensions/$id.new"
        rm -rf "$dir/extensions/$id"
        mv "$dir/extensions/$id.new" "$dir/extensions/$id"
        rm -f "$pack"
    fi
done < "$work/assets"
mkdir -p "$HOME/.local/bin"
ln -sf "$dir/asup" "$HOME/.local/bin/asup"
"$dir/asup" --version
echo "Installed in $dir (command: ~/.local/bin/asup)"
