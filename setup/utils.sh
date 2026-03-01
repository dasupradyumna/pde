########################################## SETUP UTILITIES #########################################

# Get installed and latest versions of a package
#
# Usage: apt_pkg_versions <package_name>
apt_pkg_versions() {
    apt-cache policy "$1" | awk '/Installed:/ {i=$2} /Candidate:/ {c=$2} END {print i, c}'
}

# Download a file from a GitHub release
#
# Usage: curl_file_github <namespace> <version> <remote_file> <local_path>
curl_file_github() {
    local -r ns="$1" ver="$2" src="$3" dst="$4"
    exec_ring_log curl -L "https://github.com/$ns/releases/download/$ver/$src" -o "$dst"
}

# Execute a command and render last lines of output as a rolling log
#
# Usage: exec_ring_log <cmd> [<args> ...]
exec_ring_log() {
    local -r cmd="$@" BUFFERSIZE=15
    local lines=() n_rows_per_line=() total_rows=1

    rm -f "$FIFO_FILE"
    mkfifo "$FIFO_FILE"
    $cmd &>"$FIFO_FILE" &
    cmd_pid=$!

    # Execute and pipe output to render last BUFFERSIZE lines
    printf '\e[90m\n' # Color:bright-black
    while IFS= read -r line; do
        printf "\e[${total_rows}A" # Cursor-up N rows

        # Strip ANSI color sequences and handles TAB/CR characters
        line="$(sed -e 's/\x1b\[[0-9;]*m//g' -e $'s/\t/        /g' -E -e $'s/\r+$//' <<< "$line")"
        line=" >> ${line##*$'\r'}"
        lines+=("$line")
        n_rows_per_line+=($(((${#line} + $COLUMNS - 1) / $COLUMNS)))
        total_rows=$((total_rows + ${n_rows_per_line[-1]}))

        # Rotate logs when buffer is full
        if [ ${#lines[@]} -gt $BUFFERSIZE ]; then
            total_rows=$((total_rows - ${n_rows_per_line[0]}))
            n_rows_per_line=("${n_rows_per_line[@]:1}")
            lines=("${lines[@]:1}")
        fi

        printf '\e[J\n' # Erase-down
        printf '%s\r\n' "${lines[@]}"
    done < "$FIFO_FILE" || { log -eW "Log rendering failed! '$cmd'"; return 1; }

    wait "$cmd_pid" || { log -eW "Command failed! '$cmd'"; return 1; }
    printf "\e[${total_rows}A\e[J\e[m" # Cursor-up N rows + Erase-down + Color:white
}

# Check if a command is available
#
# Usage: has_cmd <command>
has_cmd() {
    command -v "$1" &>/dev/null
    return $?
}

# Check if a package is already up-to-date
#
# Usage: is_latest_installed <package_name> <installed_version> <latest_version>
is_latest_installed() {
    local -r pkg="$1" installed="$2" latest="$3"
    if [ "$installed" = "$latest" ]; then
        log -i "Latest '$pkg': $installed"
        return 0
    elif [ "$installed" = '(none)' ]; then
        log -w "Install '$pkg': $latest"
        return 1
    else
        log -w "Update '$pkg': $installed >> $latest"
        return 1
    fi
}

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
