########################################## SETUP UTILITIES #########################################
# Helper functions and utilities for PDE setup

# Handle SIGINT - exit with code 130 = 128 + 2 (SIGINT)
interrupt_handler() { log -e "[SIGINT] User aborted the script!"; exit 130; }

# Handle SIGEXIT - clean up and propagate exit code
exit_handler() { code=$?; tput cnorm; rm -rf "$TMPDIR"; exit $code; }

# Log a message based on severity; only one severity must be specified
#
# Usage: log [-W] [-e|-i|-w] <message>
#    W: Calling function is a wrapper
#    e: Error (with newline) | i: Information | w: Warning
log() {
    local prefix= callingfunc="${FUNCNAME[1]:-main}" callingline="${BASH_LINENO[0]:-??}"

    # Skip a level in the function stack if called from a wrapper
    OPTIND=1; while getopts 'eiwW' level; do
        if [ "$level" = 'W' ]; then
            callingfunc="${FUNCNAME[2]:-main}"
            callingline="${BASH_LINENO[1]:-??}"
            break
        fi
    done

    # Parse severity and select prefix
    OPTIND=1; while getopts 'eiwW' level; do
        # Only one severity must be specified
        if [ "$level" != 'W' ] && [ -n "$prefix" ]; then
            log -eW 'Multiple severity levels specified!'
            return 1
        fi

        case "$level" in
            e) prefix="\n\e[31mERROR: $callingfunc():$callingline" ;;
            i) prefix='\e[36mINFO' ;;
            w) prefix='\e[33mWARN' ;;
            *) continue ;;
        esac
    done
    shift $((OPTIND - 1))

    echo -e "$prefix: $1\e[m"
}

# Execute a command and render last lines of output as a rolling log
#
# Usage: exec_ring_log <cmd> [<args> ...]
exec_ring_log() {
    local -r cmd="$@" BUFFERSIZE=15
    local buffer=()
    tput sc # save-cursor at current position

    # Execute and pipe output to render last BUFFERSIZE lines
    $cmd 2>&1 | while IFS= read -r line
    do
        buffer+=("$line")
        [ ${#buffer[@]} -gt $BUFFERSIZE ] && buffer=("${buffer[@]:1}")
        # BUG: breaks when cursor < BUFFERSIZE lines from screen bottom
        tput rc; tput ed # restore-cursor, erase-down
        echo && printf '\e[90m%s\e[m\r\n' "${buffer[@]}"
        sleep 0.1
    done || { log -eW "Log rendering failed! '$cmd'"; return 1; }
    [ ${PIPESTATUS[0]} -ne 0 ] && { log -eW "Command failed! '$cmd'"; return 1; }

    # Restore cursor to position before rolling logs
    tput rc; tput ed
}
