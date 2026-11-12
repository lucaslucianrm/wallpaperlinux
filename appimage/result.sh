#!/usr/bin/env bash
# Present results in the caller's session, never in the privileged child.
run_with_result() (
    title=$1; success=$2; shift 2
    log=$(mktemp /tmp/rolimnet-result.XXXXXX)
    trap 'rm -f -- "$log"' EXIT
    if "$@" > "$log" 2>&1; then code=0; else code=$?; fi
    cat -- "$log" || true
    if ((code == 0)); then
        kind=info
        message=$success
        warnings=$(awk '/^AVISO:/' "$log")
        if [[ -n $warnings ]]; then message+=$'\n\n'"$warnings"; fi
    else
        kind=error
        message="A operação falhou ou foi cancelada (código $code)."$'\n\n'"$(tail -n 12 -- "$log")"
    fi
    printf '\n%s: %s\n' "$title" "$message"
    if [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} && ! -t 1 ]]; then
        if command -v zenity >/dev/null; then
            zenity "--$kind" --no-markup --title="$title" --text="$message" --width=560 >/dev/null 2>&1 || true
        elif command -v kdialog >/dev/null; then
            option=--msgbox; [[ $kind == info ]] || option=--error
            kdialog --title "$title" "$option" "$message" >/dev/null 2>&1 || true
        elif command -v xmessage >/dev/null && [[ -n ${DISPLAY:-} ]]; then
            xmessage -center -title "$title" "$message" >/dev/null 2>&1 || true
        elif command -v notify-send >/dev/null; then
            notify-send "$title" "$message" >/dev/null 2>&1 || true
        fi
    fi
    exit "$code"
)
