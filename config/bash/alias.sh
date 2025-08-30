####################################### ALIASES AND FUNCTIONS ######################################

# Check and synchronize all installed packages, while removing unused ones
alias apt-sync='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'

# Directory stack manipulation
alias dls='dirs -v'
alias dcd='pushd 1>/dev/null'
alias drm='popd 1>/dev/null'
alias dcn='pushd +1 1>/dev/null'
alias dcp='pushd -0 1>/dev/null'

# Short-hand aliases
# alias e='nvim' # TODO: when installed
alias g='lazygit'
alias v='venv'

# List permissions of file system object
alias lmod='stat --printf "    object: %n (%F)\n    perms: (%a) %A\n"'

# Create and enter a directory
mkcd() { mkdir -p "$1" && cd "$1" || return 1; }

# Delete an directory recursively
alias rmd='rm -rf'

# Copy STDIN into clipboard
# alias xcp='xclip -selection clipboard' # TODO: when installed

# Set WezTerm tab title
# alias wt='wezterm cli set-tab-title' # TODO: when installed

########################## VIRTUAL ENVIRONMENT MANAGER #########################

# Virtual environments directory
__VENVS_DIR="$HOME/.venvs"

venv() {
    local -r cmd="$1" name="$2"
    local -r HELP='Usage: venv COMMAND [NAME]\nCOMMAND: new|list|del|run'
    mkdir -p "$__VENVS_DIR"

    # Check if command has been specified
    if [ -z "$cmd" ]; then
        __render red; echo -e "[ERROR] Command not specified!\n\n$HELP"; return 1
    fi

    if [ "$cmd" == 'list' ]; then         ### LIST : list all virtual environments
        local env_list="$(cd "$__VENVS_DIR" && compgen -d -- "${COMP_WORDS[2]}")"

        # Return raw environment list for bash completion
        if [ -n "$COMP_CWORD" ]; then printf "$env_list"; return 0; fi

        # Format and print environment list otherwise
        if [ -z "$env_list" ]; then
            __render yellow; echo 'No virtual environments found!'
        else
            echo "Virtual environments:"
            printf -- "  - %s\n" $env_list
        fi
        return 0
    fi

    # Check if environment name has been specified
    if [ -z "$name" ]; then
        __render red; echo -e "[ERROR] Virtual environment name not specified!\n\n$HELP"; return 1
    fi

    # Get environment directory path
    local -r venv_dir="$__VENVS_DIR/$name"

    if [ "$cmd" == 'new' ]; then        ### NEW : create a new virtual environment
        if [ -d "$venv_dir" ]; then
            __render red; echo "[ERROR] Virtual environment '$name' already exists!"; return 1
        fi
        python -m venv "$venv_dir" && echo "Created virtual environment: '$name'"

    elif [ "$cmd" == 'del' ]; then       ### DEL : remove a virtual environment
        if [ ! -d "$venv_dir" ]; then
            __render red; echo "[ERROR] Virtual environment '$name' does not exist!"; return 1
        fi
        __user_continue "Delete virtual environment '$name'?" || return 0
        [ "$VIRTUAL_ENV" == "$venv_dir" ] && deactivate
        rm -r "$venv_dir" || return 1

    elif [ "$cmd" == 'run' ]; then      ### RUN : activate a virtual environment
        if [ ! -d "$venv_dir" ]; then
            __render yellow; echo "[WARN] Virtual environment '$name' does not exist!"; __render
            __user_continue "Create it?" || return 0
            venv new "$name" || return 1
        fi
        source "$venv_dir/bin/activate"
    fi
}
__venv_complete() {
    local -r cmd="${COMP_WORDS[1]}"
    COMPREPLY=()
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=($(compgen -W 'new list del run' -- "$cmd"))
    elif [ $COMP_CWORD -eq 2 ] && [ "$cmd" != 'list' ] && [ "$cmd" != 'new' ]; then
        COMPREPLY=($(venv list))
    fi
}
complete -F __venv_complete venv v
