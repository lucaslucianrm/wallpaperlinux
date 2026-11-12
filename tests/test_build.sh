#!/usr/bin/env bash
set -Eeuo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d '/tmp/wallpaper build.XXXXXX')
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/project" "$stage/bin"
cp "$project/build_appimage.sh" "$project/install.sh" "$stage/project/"
cp -r "$project/appimage" "$stage/project/"
export REAL_INSTALL
REAL_INSTALL=$(command -v install)
# Os diretórios intermediários podem respeitar a umask do empacotador.
cat > "$stage/bin/install" <<'TOOL'
#!/usr/bin/env bash
original_args=("$@")
if [[ $1 == -d ]]; then
    shift
    while (($#)); do
        case "$1" in
            -m) shift 2 ;;
            *) mkdir -p -- "$(dirname -- "$1")"; shift ;;
        esac
    done
fi
exec "$REAL_INSTALL" "${original_args[@]}"
TOOL
cat > "$stage/bin/appimagetool" <<'TOOL'
#!/usr/bin/env bash
set -euo pipefail
appdir=$2
for path in "$appdir" "$appdir/usr" "$appdir/usr/bin"; do
    [[ $(stat -c %a "$path") == 755 ]] || { echo "FAIL: diretório privado no pacote: $path" >&2; exit 1; }
done
printf 'fixture package\n' > "$3"
TOOL
chmod +x "$stage/bin/"*
PATH="$stage/bin:$PATH" APPIMAGETOOL="$stage/bin/appimagetool" bash "$stage/project/build_appimage.sh"
[[ -x $stage/project/Rolimnet-Wallpaper-$(uname -m).AppImage ]]
echo 'ok - empacotador define permissões de todos os diretórios com umask privada'
