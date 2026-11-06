#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$root"
tool=${APPIMAGETOOL:-appimagetool}
command -v "$tool" >/dev/null || { echo 'Defina APPIMAGETOOL com o caminho do appimagetool oficial.' >&2; exit 1; }
arch=${ARCH:-$(uname -m)}
case "$arch" in x86_64|aarch64) ;; *) echo "Arquitetura não suportada: $arch" >&2; exit 1 ;; esac
stage=$(mktemp -d "$root/.appimage-build.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
appdir="$stage/Rolimnet.AppDir"
install -d -m 0755 "$appdir/usr/bin"
install -m 0755 "$root/install.sh" "$appdir/usr/bin/rolimnet-wallpaper"
install -m 0755 "$root/appimage/AppRun" "$appdir/AppRun"
install -m 0644 "$root/appimage/result.sh" "$appdir/result.sh"
install -m 0644 "$root/appimage/rolimnet-wallpaper.desktop" "$appdir/rolimnet-wallpaper.desktop"
install -m 0644 "$root/appimage/rolimnet-wallpaper.png" "$appdir/rolimnet-wallpaper.png"
ln -s rolimnet-wallpaper.png "$appdir/.DirIcon"
APPIMAGE_EXTRACT_AND_RUN=1 ARCH="$arch" "$tool" --no-appstream "$appdir" "$stage/output.AppImage"
mode=0755
chmod "$mode" "$stage/output.AppImage"
output="$root/Rolimnet-Wallpaper-$arch.AppImage"
mv -f -- "$stage/output.AppImage" "$output"
printf '%s\n' "$output"
