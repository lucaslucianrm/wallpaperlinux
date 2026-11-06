#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d '/tmp/wallpaper appimage.XXXXXX')
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/usr/bin"
cp "$root/appimage/AppRun" "$stage/AppRun"
printf 'printf "<%%s>\\n" "$@"\nexit 37\n' > "$stage/usr/bin/rolimnet-wallpaper"
code=0
bash "$stage/AppRun" status 'argumento com espaços' > "$stage/output" || code=$?
[[ $code == 37 ]]
[[ $(cat "$stage/output") == $'<status>\n<argumento com espaços>' ]]
echo 'ok - AppRun wallpaper preserva argumentos e código de saída sem sudo'
