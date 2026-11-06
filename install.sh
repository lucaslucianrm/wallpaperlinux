#!/usr/bin/env bash
# Instalador e agente Rolimnet em um único arquivo. Não requer Python.
set -Eeuo pipefail
umask 077
((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) || {
    echo 'ERRO: requer Bash 4.3 ou mais recente.' >&2
    exit 1
}

IMAGE_URL='https://core.rolimnet.com/api/wallpaper/image'
MAX_BYTES=26214400
UNIT=rolimnet-wallpaper
SESSION_KEYS=(DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR)

die() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
help_text() {
    cat <<'HELP'
Rolimnet Wallpaper — arquivo único, sem sudo e sem Python.

Uso: ./rolimnet-wallpaper [install|update|status|session|uninstall]
Alternativa: bash install.sh [install|update|status|session|uninstall]
Sem argumento: install. Execute dentro da sessão gráfica do usuário.

install    Aplica a imagem agora e agenda atualização a cada 1 hora.
update     Baixa e aplica agora.
status     Exibe imagem atual e próxima execução.
session    Registra a sessão gráfica atual e reaplica/atualiza a imagem.
uninstall  Remove tarefa e programa; mantém as imagens em uso.

Aplica somente o wallpaper. Não cria políticas de bloqueio nem altera
configurações de bloqueadores de tela ou autenticação.
HELP
}

init_paths() {
    config_root=${XDG_CONFIG_HOME:-$HOME/.config}
    data_root=${XDG_DATA_HOME:-$HOME/.local/share}
    state_root=${XDG_STATE_HOME:-$HOME/.local/state}
    local value
    for value in "$config_root" "$data_root" "$state_root"; do
        [[ $value == /* && $value != *[[:cntrl:]]* ]] || die 'Diretórios XDG precisam ser absolutos e sem caracteres de controle.'
    done
    CONFIG="$config_root/$UNIT"; DATA="$data_root/$UNIT"; STATE="$state_root/$UNIT"
    UNITS="$config_root/systemd/user"; AUTOSTART="$config_root/autostart/$UNIT.desktop"
    INSTALLED="$DATA/$UNIT.sh"
}

need() { command -v "$1" >/dev/null 2>&1 || die "Dependência ausente: $1"; }
graphical_session() { [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || die 'Execute dentro da sessão gráfica, sem sudo ou SSH.'; }

detect_desktop() {
    local value=${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-}}
    case "${value,,}" in
        *cinnamon*) echo cinnamon ;;
        *gnome*|*unity*) echo gnome ;;
        *kde*|*plasma*) echo kde ;;
        *mate*) echo mate ;;
        *xfce*) echo xfce ;;
        *lxqt*) echo lxqt ;;
        *lxde*) echo lxde ;;
        *) die "Ambiente não suportado: ${value:-não identificado}." ;;
    esac
}

find_qdbus() {
    local tool
    for tool in qdbus6 qdbus qdbus-qt5; do
        if command -v "$tool" >/dev/null 2>&1; then printf '%s\n' "$tool"; return; fi
    done
    die 'Plasma requer qdbus6, qdbus ou qdbus-qt5.'
}

check_desktop_tools() {
    case "$1" in
        gnome|cinnamon|mate) need gsettings ;;
        kde) find_qdbus >/dev/null ;;
        xfce) need xfconf-query ;;
        lxqt) need pcmanfm-qt ;;
        lxde) need pcmanfm ;;
        *) die "Ambiente não suportado: $1" ;;
    esac
}

write_text() {
    local destination=$1 stage_file
    mkdir -p -- "$(dirname -- "$destination")"
    stage_file=$(mktemp "$destination.XXXXXX")
    printf '%s\n' "$2" > "$stage_file"
    mv -f -- "$stage_file" "$destination"
}

save_session() {
    local key stage_file
    mkdir -p -- "$CONFIG"
    stage_file=$(mktemp "$CONFIG/.session.XXXXXX")
    for key in "${SESSION_KEYS[@]}"; do
        if [[ -v $key ]]; then printf '%s\0%s\0' "$key" "${!key}"; fi
    done > "$stage_file"
    mv -f -- "$stage_file" "$CONFIG/session.env"
    write_text "$CONFIG/desktop" "$desktop"
}

load_session() {
    [[ -f $CONFIG/desktop && -f $CONFIG/session.env ]] || die 'Não instalado. Execute install primeiro.'
    local key value
    desktop=$(< "$CONFIG/desktop")
    for key in "${SESSION_KEYS[@]}"; do unset "$key"; done
    # Dados NUL separados, sem source/eval da configuração.
    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
        case "$key" in
            DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|DBUS_SESSION_BUS_ADDRESS|XDG_CURRENT_DESKTOP|XDG_SESSION_DESKTOP|XDG_SESSION_TYPE|XDG_RUNTIME_DIR)
                export "$key=$value" ;;
        esac
    done < "$CONFIG/session.env"
}

file_uri() {
    local LC_ALL=C value=$1 uri=file:// char hex i
    for ((i=0; i<${#value}; i++)); do
        char=${value:i:1}
        case "$char" in
            [a-zA-Z0-9/._~-]) uri+=$char ;;
            *) printf -v hex '%02X' "'$char"; uri+="%$hex" ;;
        esac
    done
    printf '%s\n' "$uri"
}

set_gsetting() {
    local schema=$1 key=$2 value=$3 optional=${4:-no} keys
    if ! keys=$(gsettings list-keys "$schema"); then
        [[ $optional == yes ]] && return 0
        die "Schema indisponível: $schema"
    fi
    if [[ $'\n'$keys$'\n' != *$'\n'"$key"$'\n'* ]]; then
        [[ $optional == yes ]] && return 0
        die "Chave indisponível: $schema $key"
    fi
    value=${value//\\/\\\\}; value=${value//\'/\\\'}
    gsettings set "$schema" "$key" "'$value'"
}

apply_wallpaper() {
    local image=$1 uri schema qdbus properties prop found=0
    uri=$(file_uri "$image")
    case "$desktop" in
        gnome|cinnamon)
            schema="org.$desktop.desktop.background"
            set_gsetting "$schema" picture-uri "$uri"
            set_gsetting "$schema" picture-uri-dark "$uri" yes ;;
        mate) set_gsetting org.mate.background picture-filename "$image" ;;
        kde)
            qdbus=$(find_qdbus)
            "$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
                "var ds = desktops(); for (var i = 0; i < ds.length; i++) { ds[i].wallpaperPlugin = 'org.kde.image'; ds[i].currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General']; ds[i].writeConfig('Image', '$uri'); }" ;;
        xfce)
            properties=$(xfconf-query -c xfce4-desktop -l)
            while IFS= read -r prop; do
                case "$prop" in
                    /backdrop/*/last-image|/backdrop/*/image-path)
                        xfconf-query -c xfce4-desktop -p "$prop" -s "$image"
                        found=1 ;;
                esac
            done <<< "$properties"
            [[ $found == 1 ]] || die 'Xfce sem monitores configurados. Abra as configurações do desktop e tente novamente.' ;;
        lxqt) pcmanfm-qt --profile=lxqt --set-wallpaper="$image" ;;
        lxde) pcmanfm --profile=LXDE --set-wallpaper="$image" ;;
        *) die "Ambiente não suportado: $desktop" ;;
    esac
}

image_extension() {
    local file=$1 size header ending
    size=$(wc -c < "$file")
    ((size > 20 && size <= MAX_BYTES)) || die 'Imagem vazia, truncada ou maior que 25 MiB.'
    header=$(od -An -tx1 -N12 -- "$file" | tr -d ' \n')
    case "$header" in
        89504e470d0a1a0a*)
            ending=$(tail -c12 -- "$file" | od -An -tx1 | tr -d ' \n')
            [[ $ending == 0000000049454e44ae426082 ]] || die 'PNG truncado; imagem anterior preservada.'
            echo png ;;
        ffd8ff*)
            ending=$(tail -c2 -- "$file" | od -An -tx1 | tr -d ' \n')
            [[ $ending == ffd9 ]] || die 'JPEG truncado; imagem anterior preservada.'
            echo jpg ;;
        52494646????????57454250)
            local b0 b1 b2 b3
            read -r b0 b1 b2 b3 < <(od -An -tu1 -j4 -N4 -- "$file")
            ((b0 + 256*b1 + 65536*b2 + 16777216*b3 + 8 == size)) || die 'WebP truncado; imagem anterior preservada.'
            echo webp ;;
        *) die 'Resposta inválida: esperado PNG, JPEG ou WebP; imagem anterior preservada.' ;;
    esac
}

update_wallpaper() (
    local mode=${1:-update} temporary='' image previous='' hash extension now stamp=0
    mkdir -p -- "$STATE" "$DATA"
    exec 9> "$STATE/update.lock"
    if [[ $mode == session ]]; then
        flock -w 240 9 || die 'Outra atualização está demorando. Tente session novamente.'
        graphical_session
        desktop=$(detect_desktop)
        check_desktop_tools "$desktop"
        [[ -f $CONFIG/desktop ]] || die 'Não instalado. Execute install primeiro.'
        save_session
    elif ! flock -n 9; then
        echo 'Uma atualização já está em execução; chamada ignorada.'
        exit 0
    fi
    load_session
    trap '[[ -z ${temporary:-} ]] || rm -f -- "$temporary"' EXIT
    now=$(date +%s)
    if [[ -f $STATE/image ]]; then previous=$(< "$STATE/image"); fi
    if [[ $mode == session && -f $STATE/last-success ]]; then
        stamp=$(< "$STATE/last-success")
        if [[ $stamp =~ ^[0-9]{1,12}$ && -f $previous ]] && ((now >= 10#$stamp && now - 10#$stamp < 3600)); then
            apply_wallpaper "$previous"
            echo 'Imagem armazenada reaplicada à sessão atual.'
            exit 0
        fi
    fi
    temporary=$(mktemp "$DATA/.download.XXXXXX")
    curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 60 --max-filesize "$MAX_BYTES" \
        --retry 2 --retry-delay 3 --output "$temporary" "$IMAGE_URL"
    extension=$(image_extension "$temporary")
    read -r hash _ < <(sha256sum < "$temporary")
    [[ $hash =~ ^[a-f0-9]{64}$ ]] || die 'Falha ao calcular SHA-256 da imagem.'
    image="$DATA/wallpaper-$hash.$extension"
    mv -f -- "$temporary" "$image"
    temporary=''
    apply_wallpaper "$image"
    write_text "$STATE/image" "$image"
    write_text "$STATE/last-success" "$(date +%s)"
    local old
    for old in "$DATA"/wallpaper-*; do
        if [[ -f $old && $old != "$image" && $old != "$previous" ]]; then rm -f -- "$old"; fi
    done
    printf 'Wallpaper aplicado: %s\n' "$image"
)

unit_quote() {
    local value=$1 mode=${2:-exec}
    value=${value//\\/\\\\}; value=${value//\"/\\\"}; value=${value//%/%%}
    if [[ $mode == exec ]]; then value=${value//\$/\$\$}; fi
    printf '"%s"' "$value"
}

desktop_quote() {
    local value=$1
    value=${value//\\/\\\\}; value=${value//\"/\\\"}; value=${value//\`/\\\`}; value=${value//\$/\\\$}
    value=${value//\\/\\\\}; value=${value//%/%%}
    printf '"%s"' "$value"
}

install_wallpaper() {
    ((EUID != 0)) || die 'Execute como usuário da sessão gráfica, sem sudo.'
    graphical_session
    local tool source_path stage_file bash_path
    for tool in curl systemctl flock sha256sum od; do need "$tool"; done
    desktop=$(detect_desktop)
    check_desktop_tools "$desktop"
    systemctl --user show-environment >/dev/null || die 'systemd de usuário indisponível. Nenhum arquivo foi instalado.'
    mkdir -p -- "$DATA" "$UNITS" "$(dirname -- "$AUTOSTART")"
    source_path=$(readlink -f -- "${BASH_SOURCE[0]}")
    if [[ $source_path != "$INSTALLED" ]]; then
        stage_file=$(mktemp "$DATA/.script.XXXXXX")
        cp -- "$source_path" "$stage_file"; chmod 700 "$stage_file"
        mv -f -- "$stage_file" "$INSTALLED"
    fi
    save_session
    bash_path=$(command -v bash)
    write_text "$UNITS/$UNIT.service" "[Unit]
Description=Atualizar wallpaper Rolimnet

[Service]
Type=oneshot
Environment=$(unit_quote "XDG_CONFIG_HOME=$config_root" env)
Environment=$(unit_quote "XDG_DATA_HOME=$data_root" env)
Environment=$(unit_quote "XDG_STATE_HOME=$state_root" env)
ExecStart=$(unit_quote "$bash_path") $(unit_quote "$INSTALLED") update
TimeoutStartSec=240
UMask=0077"
    write_text "$UNITS/$UNIT.timer" "[Unit]
Description=Wallpaper Rolimnet a cada 1 hora

[Timer]
OnCalendar=*-*-* *:00:00 UTC
Persistent=true
AccuracySec=1min
Unit=$UNIT.service

[Install]
WantedBy=timers.target"
    write_text "$AUTOSTART" "[Desktop Entry]
Type=Application
Name=Rolimnet Wallpaper
Comment=Atualizar o wallpaper da sessão
Exec=$(desktop_quote "$bash_path") $(desktop_quote "$INSTALLED") session
Terminal=false
X-GNOME-Autostart-enabled=true"
    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT.timer"
    printf 'Instalado para %s. Timer ativo a cada hora cheia. Aplicando a primeira imagem...\n' "$desktop"
    echo 'Se esta primeira atualização falhar, a tarefa permanece instalada; consulte status e tente update.'
    update_wallpaper
}

status_wallpaper() {
    if [[ ! -f $CONFIG/desktop ]]; then echo 'Não instalado para este usuário.'; return; fi
    printf 'Ambiente: %s\nURL: %s\n' "$(cat "$CONFIG/desktop")" "$IMAGE_URL"
    if [[ -f $STATE/image ]]; then printf 'Imagem: %s\n' "$(cat "$STATE/image")"; fi
    if [[ -f $STATE/last-success ]]; then
        printf 'Último download/aplicação: %s\n' "$(date -d "@$(cat "$STATE/last-success")" --iso-8601=seconds)"
    else echo 'Nenhuma atualização concluída com sucesso.'; fi
    systemctl --user list-timers --all "$UNIT.timer"
}

uninstall_wallpaper() {
    systemctl --user disable --now "$UNIT.timer" || true
    systemctl --user stop "$UNIT.service" || true
    mkdir -p -- "$STATE"
    (
        flock -w 240 9 || die 'Outra atualização está em execução. Aguarde e tente novamente.'
        rm -f -- "$AUTOSTART" "$UNITS/$UNIT.timer" "$UNITS/$UNIT.service" \
            "$CONFIG/session.env" "$CONFIG/desktop" "$STATE/image" "$STATE/last-success" "$INSTALLED"
    ) 9> "$STATE/update.lock"
    systemctl --user daemon-reload
    systemctl --user reset-failed "$UNIT.service" 2>/dev/null || true
    printf 'Tarefa e programa removidos. Imagens mantidas em %s para preservar o wallpaper.\n' "$DATA"
}

command=${1:-install}
[[ $# -le 1 ]] || die 'Use apenas um comando. Consulte --help.'
case "$command" in -h|--help|help) help_text; exit 0 ;; esac
[[ $(uname -s) == Linux ]] || die 'Este script requer Linux.'
init_paths
case "$command" in
    install) install_wallpaper ;;
    update) update_wallpaper ;;
    session) update_wallpaper session ;;
    status) status_wallpaper ;;
    uninstall) uninstall_wallpaper ;;
    *) help_text >&2; die "Comando desconhecido: $command" ;;
esac
