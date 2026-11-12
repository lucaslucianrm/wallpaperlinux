#!/usr/bin/env bash
set -Eeuo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
for operation in system-install system-update system-uninstall; do
    if bash "$project/install.sh" "$operation" > "$stage/unprivileged" 2>&1; then
        echo "FAIL: operação global sem autorização: $operation"; exit 1
    fi
    [[ $(cat "$stage/unprivileged") == *'requer autorização administrativa'* ]]
done
echo 'ok - operações globais rejeitam execução sem privilégio'
source "$project/install.sh"
init_system_paths
SYSTEM_ETC="$stage/etc"
SYSTEM_SHARE="$stage/share"
SYSTEM_STATE="$stage/state"
SYSTEM_LIB="$stage/lib"
SYSTEM_UNITS="$SYSTEM_ETC/systemd/system"
SYSTEM_IMAGE="$SYSTEM_SHARE/backgrounds/rolimnet-wallpaper/wallpaper"
SYSTEM_SCRIPT="$SYSTEM_LIB/agent.sh"
mkdir -p "$SYSTEM_UNITS" "$SYSTEM_ETC/lightdm" "$SYSTEM_STATE" "$(dirname -- "$SYSTEM_IMAGE")" "$stage/bin"
export IMAGE_FIXTURE="$stage/fixture.png" TOOL_LOG="$stage/tools.log"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uK0AAAAASUVORK5CYII=' | base64 -d > "$IMAGE_FIXTURE"
cat > "$stage/bin/curl" <<'TOOL'
#!/usr/bin/env bash
while (($#)); do
  if [[ $1 == --output ]]; then output=$2; shift; fi
  shift
done
cp -- "$IMAGE_FIXTURE" "$output"
exit "${FAIL_DOWNLOAD:-0}"
TOOL
cat > "$stage/bin/systemctl" <<'TOOL'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TOOL_LOG"
TOOL
chmod +x "$stage/bin/"*
export PATH="$stage/bin:$PATH"
require_root() { :; }

ln -s /usr/lib/systemd/system/lightdm.service "$SYSTEM_UNITS/display-manager.service"
printf '[Seat:*]\ngreeter-session=slick-greeter\n' > "$SYSTEM_ETC/lightdm/lightdm.conf"
[[ $(detect_login) == slick ]] || { echo 'FAIL: Slick não detectado'; exit 1; }
printf '# preserve\n[Greeter]\nshow-clock=false\nbackground=/original.png\n' > "$SYSTEM_ETC/lightdm/slick-greeter.conf"
cp "$SYSTEM_ETC/lightdm/slick-greeter.conf" "$stage/original"
configure_login slick
[[ $(ini_get Greeter background "$SYSTEM_ETC/lightdm/slick-greeter.conf") == "$SYSTEM_IMAGE" ]]
[[ $(ini_get Greeter draw-user-backgrounds "$SYSTEM_ETC/lightdm/slick-greeter.conf") == false ]]
[[ $(ini_get Greeter show-clock "$SYSTEM_ETC/lightdm/slick-greeter.conf") == false ]]
configure_login slick
restore_login
cmp "$stage/original" "$SYSTEM_ETC/lightdm/slick-greeter.conf"
echo 'ok - Slick preserva opções, reinstala e restaura backup original'

printf '[Seat:*]\ngreeter-session=lightdm-gtk-greeter\n' > "$SYSTEM_ETC/lightdm/lightdm.conf"
[[ $(detect_login) == gtk ]]
configure_login gtk
[[ $(ini_get greeter user-background "$SYSTEM_ETC/lightdm/lightdm-gtk-greeter.conf") == false ]]
restore_login
[[ ! -e $SYSTEM_ETC/lightdm/lightdm-gtk-greeter.conf ]]
echo 'ok - GTK configura imagem pública e remove configuração criada ao desinstalar'
printf '[greeter]\nbackground=/old.png\n[monitor: HDMI-1]\nbackground=/monitor-old.png\nuser-background=true\n' > "$SYSTEM_ETC/lightdm/lightdm-gtk-greeter.conf"
configure_login gtk
[[ $(ini_get 'monitor: HDMI-1' background "$SYSTEM_ETC/lightdm/lightdm-gtk-greeter.conf") == "$SYSTEM_IMAGE" ]]
[[ $(ini_get 'monitor: HDMI-1' user-background "$SYSTEM_ETC/lightdm/lightdm-gtk-greeter.conf") == false ]]
restore_login
echo 'ok - GTK configura overrides existentes por monitor'

configure_login slick
printf '\n# edited by admin\n' >> "$SYSTEM_ETC/lightdm/slick-greeter.conf"
if (configure_login slick); then echo 'FAIL: reinstalação ignorou edição do administrador'; exit 1; fi
restore_login > "$stage/restore-warning"
[[ $(cat "$stage/restore-warning") == *AVISO* ]]
[[ $(cat "$SYSTEM_ETC/lightdm/slick-greeter.conf") == *'edited by admin'* ]]
echo 'ok - restauração preserva alterações posteriores do administrador'

rm -f "$SYSTEM_STATE/"config-* "$SYSTEM_STATE/adapter"
rm "$SYSTEM_UNITS/display-manager.service"
ln -s /usr/lib/systemd/system/sddm.service "$SYSTEM_UNITS/display-manager.service"
mkdir -p "$SYSTEM_SHARE/sddm/themes/breeze"
printf '[Theme]\nCurrent=breeze\n' > "$SYSTEM_ETC/sddm.conf"
printf '[General]\nbackground=default.png\n' > "$SYSTEM_SHARE/sddm/themes/breeze/theme.conf"
[[ $(detect_login) == sddm ]]
configure_login sddm
[[ $(ini_get General background "$SYSTEM_SHARE/sddm/themes/breeze/theme.conf.user") == "$SYSTEM_IMAGE" ]]
restore_login
[[ ! -e $SYSTEM_SHARE/sddm/themes/breeze/theme.conf.user ]]
printf '[Theme]\nCurrent=custom\n' > "$SYSTEM_ETC/sddm.conf"
[[ $(detect_login) == unsupported ]]
echo 'ok - SDDM Breeze usa override; tema desconhecido não recebe suporte falso'

rm "$SYSTEM_UNITS/display-manager.service"
ln -s /usr/lib/systemd/system/gdm.service "$SYSTEM_UNITS/display-manager.service"
[[ $(detect_login) == unsupported ]]
echo 'ok - GDM não recebe suporte falso'

system_update
cmp "$IMAGE_FIXTURE" "$SYSTEM_IMAGE"
[[ $(stat -c %a "$SYSTEM_IMAGE") == 644 ]]
cp "$SYSTEM_IMAGE" "$stage/previous"
if (FAIL_DOWNLOAD=22 system_update); then echo 'FAIL: download com erro aceito'; exit 1; fi
cmp "$stage/previous" "$SYSTEM_IMAGE"
printf '<html>not an image</html>' > "$IMAGE_FIXTURE"
if (system_update); then echo 'FAIL: HTML aceito'; exit 1; fi
cmp "$stage/previous" "$SYSTEM_IMAGE"
echo 'ok - atualização global atômica, pública e preservada offline/HTML'

cp "$stage/previous" "$IMAGE_FIXTURE"
rm "$SYSTEM_UNITS/display-manager.service"
ln -s /usr/lib/systemd/system/lightdm.service "$SYSTEM_UNITS/display-manager.service"
printf '[Seat:*]\ngreeter-session=slick-greeter\n' > "$SYSTEM_ETC/lightdm/lightdm.conf"
cp "$SYSTEM_ETC/lightdm/slick-greeter.conf" "$stage/before-install"
system_install
[[ -x $SYSTEM_SCRIPT ]]
[[ $(stat -c %a "$SYSTEM_STATE") == 700 ]]
[[ $(stat -c %a "$SYSTEM_UNITS/$UNIT-login.service") == 644 ]]
[[ $(cat "$TOOL_LOG") == *"enable --now $UNIT-login.timer"* ]]
if command -v systemd-analyze >/dev/null; then
    systemd-analyze verify "$SYSTEM_UNITS/$UNIT-login.service" "$SYSTEM_UNITS/$UNIT-login.timer"
fi
(
    unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
    system_update
    if FAIL_DOWNLOAD=22 system_update; then exit 1; fi
    cmp "$stage/previous" "$SYSTEM_IMAGE"
)
system_install
system_uninstall
cmp "$stage/before-install" "$SYSTEM_ETC/lightdm/slick-greeter.conf"
[[ ! -e $SYSTEM_SCRIPT && ! -e $SYSTEM_UNITS/$UNIT-login.timer ]]
[[ -f $SYSTEM_IMAGE ]]
echo 'ok - ciclo global instala, agenda, atualiza sem sessão e restaura ao remover'
