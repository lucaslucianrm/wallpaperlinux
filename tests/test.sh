#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
export XDG_CONFIG_HOME="$test_root/config with spaces"
export XDG_DATA_HOME="$test_root/data with spaces \$d %n quotes'"
export XDG_STATE_HOME="$test_root/state with spaces"
export XDG_RUNTIME_DIR="$test_root/runtime"
mkdir -m 700 "$XDG_RUNTIME_DIR"
export XDG_CURRENT_DESKTOP=X-Cinnamon DISPLAY=:0
export TOOL_LOG="$test_root/tool.log" IMAGE_FIXTURE="$test_root/image.png"
mkdir -p "$test_root/bin"
export PATH="$test_root/bin:$PATH"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uK0AAAAASUVORK5CYII=' | base64 -d > "$IMAGE_FIXTURE"
cat > "$test_root/bin/fake-tool" <<'TOOL'
#!/usr/bin/env bash
set -euo pipefail
tool="${0##*/}"
printf '%s ' "$tool" >> "$TOOL_LOG"
printf '<%s> ' "$@" >> "$TOOL_LOG"
printf '\n' >> "$TOOL_LOG"
case "$tool" in
  python|python3) echo 'Python must not be required' >&2; exit 99 ;;
  curl)
    output=''
    while (($#)); do
      if [[ $1 == --output ]]; then output=$2; shift; fi
      shift
    done
    cp -- "$IMAGE_FIXTURE" "$output"
    [[ ${FAIL_DOWNLOAD:-0} == 0 ]] || exit 22
    ;;
  sudo|pkexec)
    [[ ${FAIL_AUTH:-0} == 0 ]] || exit 126
    ;;
  gsettings)
    if [[ $1 == list-keys ]]; then
      printf '%s\n' picture-uri picture-uri-dark picture-filename picture-options
    elif [[ ${FAIL_APPLY:-0} == 1 ]]; then exit 1; fi
    ;;
  xfconf-query)
    if [[ " $* " == *' -l '* ]]; then
      printf '%s\n' /backdrop/screen0/monitorDP-1/workspace0/last-image /backdrop/screen0/monitorHDMI-1/workspace0/last-image
    fi
    ;;
  systemctl)
    [[ ${FAIL_SYSTEMD:-0} == 0 ]] || exit 1
    if [[ " $* " == *' list-timers '* ]]; then echo rolimnet-wallpaper.timer; fi
    ;;
esac
TOOL
chmod +x "$test_root/bin/fake-tool"
for tool in curl gsettings systemctl qdbus6 qdbus qdbus-qt5 xfconf-query pcmanfm pcmanfm-qt python python3 sudo pkexec kwriteconfig5 kwriteconfig6; do
  ln -s fake-tool "$test_root/bin/$tool"
done
passed=0
ok() { passed=$((passed + 1)); printf 'ok %d - %s\n' "$passed" "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_exists() { [[ -f $1 ]] || fail "arquivo ausente: $1"; }
assert_absent() { [[ ! -e $1 ]] || fail "arquivo inesperado: $1"; }

cmp "$project_dir/install.sh" "$project_dir/rolimnet-wallpaper" || fail 'executável desatualizado: copie install.sh para rolimnet-wallpaper'
"$project_dir/rolimnet-wallpaper" --help > "$test_root/help"
assert_absent "$XDG_CONFIG_HOME/rolimnet-wallpaper/session.env"
ok 'help sem efeitos colaterais'

if FAIL_SYSTEMD=1 bash "$project_dir/install.sh" install > "$test_root/failure" 2>&1; then fail 'systemd ausente foi aceito'; fi
assert_absent "$XDG_DATA_HOME/rolimnet-wallpaper/rolimnet-wallpaper.sh"
ok 'recusa systemd indisponível antes de instalar'

if FAIL_AUTH=1 bash "$project_dir/install.sh" install > "$test_root/auth-failure" 2>&1; then fail 'instalou sem autenticação'; fi
assert_absent "$XDG_DATA_HOME/rolimnet-wallpaper/rolimnet-wallpaper.sh"
assert_absent "$XDG_CONFIG_HOME/rolimnet-wallpaper/session.env"
ok 'senha cancelada não instala arquivos nem tarefas'

"$project_dir/rolimnet-wallpaper" install > "$test_root/install"
[[ $(< "$test_root/install") == *'Instalação concluída com sucesso'* ]] || fail 'instalação sem confirmação final'
[[ $(< "$TOOL_LOG") == *'pkexec <--disable-internal-agent>'* ]] || fail 'instalação gráfica sem autenticação nativa'
ok 'instalação autentica sem executar o agente como root'
installed="$XDG_DATA_HOME/rolimnet-wallpaper/rolimnet-wallpaper.sh"
state="$XDG_STATE_HOME/rolimnet-wallpaper"
assert_exists "$installed"
assert_exists "$state/image"
image="$(cat "$state/image")"
cmp "$image" "$IMAGE_FIXTURE"
[[ $(< "$TOOL_LOG") != *lock-enabled* && $(< "$TOOL_LOG") != *idle-activation* ]] || fail 'alterou autenticação ou bloqueio automático'
ok 'instalação em arquivo único, sem Python ou alterações de autenticação'

bash "$project_dir/install.sh" install > "$test_root/reinstall"
assert_exists "$XDG_CONFIG_HOME/systemd/user/rolimnet-wallpaper.timer"
[[ $(< "$XDG_CONFIG_HOME/systemd/user/rolimnet-wallpaper.timer") == *'OnCalendar=*-*-* *:00:00 UTC'* ]] || fail 'timer não está agendado a cada hora'
ok 'reinstalação usa a mesma tarefa'

if FAIL_APPLY=1 bash "$project_dir/install.sh" install > "$test_root/install-apply-failure" 2>&1; then fail 'instalação ignorou falha ao aplicar'; fi
[[ $(< "$test_root/install-apply-failure") != *'Instalação concluída com sucesso'* ]] || fail 'confirmou sucesso após falha'
ok 'instalação falha sem confirmação de sucesso quando o desktop recusa imagem'

if command -v script >/dev/null; then
  export INSTALL_SOURCE="$project_dir/install.sh"
  script -q -e -c 'bash "$INSTALL_SOURCE" install' /dev/null < /dev/null > "$test_root/terminal-install"
  [[ $(< "$TOOL_LOG") == *'sudo <-k> <-p>'* ]] || fail 'terminal não solicitou autenticação sudo'
  if FAIL_AUTH=1 script -q -e -c 'bash "$INSTALL_SOURCE" install' /dev/null < /dev/null > "$test_root/terminal-cancel"; then fail 'terminal ignorou senha cancelada'; fi
  ok 'terminal autentica via sudo e propaga cancelamento'
fi

old_stamp=$(( $(date +%s) - 300 ))
printf '%s\n' "$old_stamp" > "$state/last-success"
printf '<html>invalid</html>' > "$IMAGE_FIXTURE"
if bash "$installed" update > "$test_root/invalid" 2>&1; then fail 'aceitou HTML'; fi
[[ $(cat "$state/image") == "$image" && $(cat "$state/last-success") == "$old_stamp" ]] || fail 'alterou estado na falha'
assert_exists "$image"
ok 'resposta HTML mantém imagem e estado anteriores'

head -c20 -- "$image" > "$IMAGE_FIXTURE"
if bash "$installed" update > "$test_root/truncated" 2>&1; then fail 'aceitou PNG truncado'; fi
[[ $(cat "$state/last-success") == "$old_stamp" ]] || fail 'alterou estado após truncamento'
ok 'PNG truncado é rejeitado'

cp "$image" "$IMAGE_FIXTURE"
: > "$TOOL_LOG"
if FAIL_DOWNLOAD=1 bash "$installed" update > "$test_root/offline" 2>&1; then fail 'aceitou falha de rede'; fi
cmp "$image" "$IMAGE_FIXTURE"
[[ $(< "$TOOL_LOG") != *pkexec* && $(< "$TOOL_LOG") != *sudo* ]] || fail 'atualização automática solicitou senha'
ok 'download incompleto preserva imagem anterior sem pedir senha'

if FAIL_APPLY=1 bash "$installed" update > "$test_root/apply" 2>&1; then fail 'aceitou falha de aplicação'; fi
[[ $(cat "$state/last-success") == "$old_stamp" ]] || fail 'registrou sucesso após falha'
ok 'falha do desktop não registra sucesso'

: > "$TOOL_LOG"
XDG_CURRENT_DESKTOP=GNOME bash "$installed" session > "$test_root/session"
[[ $(< "$TOOL_LOG") != *curl* && $(< "$TOOL_LOG") == *picture-uri-dark* && $(< "$TOOL_LOG") == *org.gnome.desktop.screensaver* ]] || fail 'login não aplicou variantes claro/escuro e bloqueio'
ok 'novo login reaplica cache sem download'

: > "$TOOL_LOG"
printf '%s\n' "$(( $(date +%s) - 3600 ))" > "$state/last-success"
bash "$installed" session > "$test_root/session-expired"
[[ $(< "$TOOL_LOG") == *curl* ]] || fail 'login reutilizou cache com uma hora ou mais'
ok 'novo login baixa novamente quando o cache completa uma hora'

printf '%s\n' "$(( $(date +%s) - 7200 ))" > "$state/last-success"
: > "$TOOL_LOG"
if FAIL_DOWNLOAD=1 XDG_CURRENT_DESKTOP=MATE bash "$installed" session > "$test_root/offline-login" 2>&1; then fail 'falha de rede ocultada'; fi
[[ $(< "$TOOL_LOG") == *org.mate.background* ]] || fail 'login offline não reaplicou cache antigo'
[[ $(cat "$state/image") == "$image" ]] || fail 'login offline alterou imagem salva'
ok 'login offline reaplica cache antigo e informa falha de atualização'

for desktop in MATE KDE XFCE LXDE LXQt; do
  : > "$TOOL_LOG"
  XDG_CURRENT_DESKTOP="$desktop" bash "$installed" session > "$test_root/session"
  case "$desktop" in
    MATE) [[ $(< "$TOOL_LOG") == *org.mate.background* ]] || fail 'MATE' ;;
    KDE) [[ $(< "$TOOL_LOG") == *evaluateScript* && $(< "$TOOL_LOG") == *kscreenlockerrc* && $(< "$TOOL_LOG") == *WallpaperPlugin* ]] || fail 'KDE desktop/bloqueio' ;;
    XFCE) [[ $(< "$TOOL_LOG") == *monitorDP-1* && $(< "$TOOL_LOG") == *monitorHDMI-1* ]] || fail 'Xfce' ;;
    LXDE) [[ $(< "$TOOL_LOG") == *pcmanfm* && $(< "$TOOL_LOG") == *--profile=LXDE* ]] || fail 'LXDE' ;;
    LXQt) [[ $(< "$TOOL_LOG") == *pcmanfm-qt* && $(< "$TOOL_LOG") == *--profile=lxqt* ]] || fail 'LXQt' ;;
  esac
  [[ $(< "$TOOL_LOG") != *lock-enabled* && $(< "$TOOL_LOG") != *idle-activation* ]] || fail 'alterou autenticação ou bloqueio automático'
  ok "aplica wallpaper e verifica integração em $desktop"
done

if XDG_CURRENT_DESKTOP=sway bash "$installed" session > "$test_root/unsupported" 2>&1; then fail 'ambiente desconhecido foi aceito'; fi
ok 'desktop não suportado recebe erro explícito'

: > "$TOOL_LOG"
(
  flock -x 9
  bash "$installed" update > "$test_root/lock"
) 9> "$state/update.lock"
[[ $(< "$TOOL_LOG") != *curl* ]] || fail 'ignorou lock'
ok 'chamadas simultâneas não duplicam downloads'

# O timer pode iniciar uma atualização durante a instalação.
: > "$TOOL_LOG"
(
  flock -x 9
  bash "$project_dir/install.sh" install > "$test_root/install-lock" 2>&1 &
  installer_pid=$!
  sleep 0.3
  kill -0 "$installer_pid" 2>/dev/null || fail 'instalação anunciou sucesso sem esperar aplicação'
  flock -u 9
  wait "$installer_pid"
) 9> "$state/update.lock"
[[ $(< "$TOOL_LOG") == *curl* ]] || fail 'instalação não aplicou primeira imagem após esperar lock'
ok 'instalação aguarda atualização concorrente antes de confirmar sucesso'

if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$XDG_CONFIG_HOME/autostart/rolimnet-wallpaper.desktop"
  ok 'autostart passa na validação Desktop Entry'
fi
if command -v systemd-analyze >/dev/null; then
  systemd-analyze --user verify "$XDG_CONFIG_HOME/systemd/user/rolimnet-wallpaper.service" "$XDG_CONFIG_HOME/systemd/user/rolimnet-wallpaper.timer" > "$test_root/units" 2>&1 || { cat "$test_root/units"; fail 'units inválidas'; }
  ok 'units passam no verificador systemd'
fi

bash "$installed" status > "$test_root/status"
[[ $(< "$test_root/status") == *rolimnet-wallpaper.timer* ]] || fail 'status não mostra timer'
ok 'status exibe tarefa'

bash "$installed" uninstall > "$test_root/uninstall"
assert_absent "$installed"
assert_absent "$XDG_CONFIG_HOME/systemd/user/rolimnet-wallpaper.timer"
assert_absent "$XDG_CONFIG_HOME/autostart/rolimnet-wallpaper.desktop"
assert_exists "$image"
ok 'desinstalação remove tarefa e mantém imagem aplicada'
printf '\n%d verificações passaram. Nenhum desktop ou timer real foi alterado.\n' "$passed"
