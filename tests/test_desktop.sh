#!/usr/bin/env bash
# Exercita schemas GSettings e arquivos KConfig reais, sem alterar o desktop.
set -Eeuo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
export XDG_CONFIG_HOME="$stage/config" XDG_DATA_HOME="$stage/data" XDG_STATE_HOME="$stage/state"
export XDG_RUNTIME_DIR="$stage/runtime" GSETTINGS_BACKEND=keyfile
mkdir -m 700 "$XDG_RUNTIME_DIR"
source "$project/install.sh"
init_paths
uri=$(file_uri "$stage/imagem com espaços.png")
for desktop in gnome cinnamon; do
    if ! gsettings list-schemas | awk -v schema="org.$desktop.desktop.background" '$0 == schema { found=1 } END { exit !found }'; then
        [[ $desktop != gnome ]] || { echo 'FAIL: schema GNOME obrigatório ausente'; exit 1; }
        echo 'SKIP - schemas Cinnamon não instalados nesta distro'
        continue
    fi
    apply_wallpaper "$stage/imagem com espaços.png"
    [[ $(gsettings get "org.$desktop.desktop.background" picture-uri) == "'$uri'" ]]
    if [[ $desktop == gnome ]] && gsettings list-keys org.gnome.desktop.screensaver | awk '$0 == "picture-uri" { found=1 } END { exit !found }'; then
        [[ $(gsettings get org.gnome.desktop.screensaver picture-uri) == "'$uri'" ]]
    fi
    echo "ok - schemas reais: $desktop recebe caminho codificado sem mudar autenticação"
done
tool=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
if [[ -z $tool ]]; then
    [[ ${REQUIRE_KDE:-0} == 0 ]] || { echo 'FAIL: ferramenta KConfig ausente'; exit 1; }
    echo 'SKIP - ferramentas KDE não instaladas'
    exit 0
fi
mkdir -p "$config_root"
printf '[Daemon]\nAutolock=false\nLockOnResume=false\n' > "$config_root/kscreenlockerrc"
desktop=kde
apply_lockscreen "$stage/imagem com espaços.png"
reader=${tool/kwriteconfig/kreadconfig}
[[ $("$reader" --file "$config_root/kscreenlockerrc" --group Greeter --key WallpaperPlugin) == org.kde.image ]]
[[ $("$reader" --file "$config_root/kscreenlockerrc" --group Greeter --group Wallpaper --group org.kde.image --group General --key Image) == "$uri" ]]
[[ $("$reader" --file "$config_root/kscreenlockerrc" --group Daemon --key Autolock) == false ]]
[[ $("$reader" --file "$config_root/kscreenlockerrc" --group Daemon --key LockOnResume) == false ]]
echo 'ok - KConfig real: bloqueio KDE recebe imagem e mantém opções de segurança'
