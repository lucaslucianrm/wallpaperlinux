#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d '/tmp/wallpaper appimage.XXXXXX')
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/usr/bin"
cp "$root/appimage/AppRun" "$stage/AppRun"
cp "$root/appimage/result.sh" "$stage/result.sh"
unset DISPLAY WAYLAND_DISPLAY
printf 'printf "<%%s>\\n" "$@"\nexit 37\n' > "$stage/usr/bin/rolimnet-wallpaper"
code=0
bash "$stage/AppRun" status 'argumento com espaços' > "$stage/output" || code=$?
[[ $code == 37 ]]
[[ $(cat "$stage/output") == *$'<status>\n<argumento com espaços>'* ]]
[[ $(cat "$stage/output") == *'falhou'* && $(cat "$stage/output") == *'37'* ]]
echo 'ok - AppRun wallpaper preserva argumentos e código de saída sem sudo'

printf 'printf "imagem aplicada\\n"\n' > "$stage/usr/bin/rolimnet-wallpaper"
bash "$stage/AppRun" install > "$stage/success"
[[ $(cat "$stage/success") == *'sucesso'* && $(cat "$stage/success") == *'1 hora'* ]]
echo 'ok - sucesso informa aplicação do wallpaper e agenda de uma hora'
mkdir -p "$stage/bin"
cat > "$stage/bin/zenity" <<'TOOL'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NOTICE_LOG"
TOOL
chmod +x "$stage/bin/zenity"
sed "s|export PATH=/usr/sbin:/usr/bin:/sbin:/bin|export PATH=\"$stage/bin:/usr/bin:/bin\"|" "$root/appimage/AppRun" > "$stage/AppRun"
export DISPLAY=:fixture NOTICE_LOG="$stage/notice"
bash "$stage/AppRun" install > "$stage/success"
[[ $(cat "$NOTICE_LOG") == *'--info'* && $(cat "$NOTICE_LOG") == *'1 hora'* ]]
printf 'echo "falha simulada ao baixar imagem" >&2\nexit 22\n' > "$stage/usr/bin/rolimnet-wallpaper"
code=0
bash "$stage/AppRun" update > "$stage/failure" || code=$?
[[ $code == 22 ]]
[[ $(cat "$NOTICE_LOG") == *'--error'* && $(cat "$NOTICE_LOG") == *'falha simulada ao baixar imagem'* ]]
echo 'ok - avisos gráficos de sucesso/erro com motivo e código original'
