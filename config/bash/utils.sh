######################################### COMMON UTILITIES #########################################

# Terminal ANSI color codes
declare -rA __render_styles=(
    # formatting
    [none]='0'              [bold]='1'              [normal]='22'
    # normal colors
    [black]='30'            [red]='31'
    [green]='32'            [yellow]='33'
    [blue]='34'             [magenta]='35'
    [cyan]='36'             [white]='37'
    # bright colors
    [brightblack]='90'      [brightred]='91'
    [brightgreen]='92'      [brightyellow]='93'
    [brightblue]='94'       [brightmagenta]='95'
    [brightcyan]='96'       [brightwhite]='97'
)

# Prints an escape sequence matching the given style to the terminal
__render() { printf '\1\e[%sm\2' "${__render_styles["${1:-none}"]}"; }

# Prompt user to continue via yes|no input
__user_continue() {
    local prompt="$1 (y/n) " invalid='Invalid choice!'
    local msg="$prompt"
    tput sc
    while true; do
        read -p "$msg" choice
        case "$choice" in
            [yY]) return 0 ;;
            [nN]) return 1 ;;
            *) [ ${#msg} -eq ${#prompt} ] && msg="$invalid $prompt"; tput rc; tput el ;;
        esac
    done
}
