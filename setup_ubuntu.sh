#!/bin/bash
########################################### UBUNTU SETUP ###########################################
# Setup all programs required for the PDE in Ubuntu and install their configs appropriately

############################### GLOBAL VARIABLES ###############################

# UBUNTU_ver="$(source /etc/os-release && echo $ver_ID)"
TMPDIR="$PWD/tmp"

############################### UTILITY FUNCTIONS ##############################

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

############################ INSTALLATION FUNCTIONS ############################

install_deps() {
    apt-get update
    apt-get install -y bash-completion build-essential curl software-properties-common
}

install_git() {
    echo && log -i 'Installing Git from PPA ...'

    exec_ring_log add-apt-repository -y ppa:git-core/ppa
    log -i 'Added git PPA repository to APT sources'

    local version="$(apt-cache policy git | grep Candidate | awk '{print $2}')"
    exec_ring_log apt-get install -y "git=$version"
    log -i "Installed $(git --version)"
}

install_lazygit() {
    echo && log -i 'Installing LazyGit ...'
    cd "$TMPDIR"
    local -r ver='0.54.2'
    local -r pkg="lazygit_${ver}_Linux_x86_64"
    curl -Lo pkg.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/$pkg.tar.gz"
    tar xf pkg.tar.gz lazygit
    install lazygit -D -t /usr/local/bin # ~/.local/bin if user
    cd ..
}

install_delta() {
    echo && log -i 'Installing Delta ...'
    cd "$TMPDIR"
    local -r ver='0.18.2'
    local -r pkg="delta-${ver}-x86_64-unknown-linux-gnu"
    curl -Lo pkg.tar.gz "https://github.com/dandavison/delta/releases/download/${ver}/$pkg.tar.gz"
    tar xf pkg.tar.gz "$pkg/delta"
    install "$pkg/delta" -D -t /usr/local/bin # ~/.local/bin if user
    cd ..
}

############################## PIPELINE FUNCTIONS ##############################

# Handle SIGINT - exit with code 130 = 128 + 2 (SIGINT)
interrupt_handler() { log -e "[SIGINT] User aborted the script!"; exit 130; }

# Handle SIGEXIT - clean up and propagate exit code
exit_handler() { code=$?; tput cnorm; rm -rf "$TMPDIR"; exit $code; }

main() {
    set -e
    trap interrupt_handler INT
    trap exit_handler EXIT
    tput civis
    mkdir -p "$TMPDIR"

    # Common Dependencies
    echo && log -i 'Installing common dependencies ...'
    exec_ring_log install_deps
    log -i 'Completed'

    # Git & Tools
    install_git
    install_lazygit
    install_delta
}

main $@
