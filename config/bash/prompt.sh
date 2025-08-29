######################################## BASH COMMAND PROMPT #######################################

# Terminal ANSI color codes
declare -rA __colors=(
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
__render() { printf '\1\e[%sm\2' "${__colors["$1"]}"; }

# Save exit status of last command
export PROMPT_COMMAND='__prompt_last_exit=$?'

# Disable python virtual environments from changing the prompt
VIRTUAL_ENV_DISABLE_PROMPT=true
if command -v conda &>/dev/null; then conda config --set changeps1 false &>/dev/null; fi

############################### PROMPT COMPONENTS ##############################

# Component for background jobs with a count (if greater than 1)
__prompt_job_list() {
    local -r n_jobs="$(jobs | wc -l)"
    if [ $n_jobs -eq 0 ]; then return; fi
    printf "$(__render yellow)● $([ $n_jobs -gt 1 ] && printf "$n_jobs " || echo -n)"
}

# Component for current user and host (displayed only on non-local systems)
__prompt_user_host() {
    local host_icon
    if [ -n "$(who -m )" ]; then # SSH server
        host_icon=" "
    elif [ -f "/.dockerenv" ]; then # Docker container
        host_icon=" "
    else
        return
    fi
    __render brightgreen
    printf "$(whoami) $host_icon $(hostname) "
}

# Component for current working directory
__prompt_cwd() { __render brightblue; printf "${PWD/#$HOME/\~} "; }

# Component for directory stack size
__prompt_dir_stack() {
    local -r n_dirs="$(dirs -v | wc -l)"
    [ $n_dirs -gt 1 ] &&  printf "$(__render magenta) $n_dirs ";
}

# Component for describing current git HEAD
__prompt_git_head() {
    git rev-parse --is-inside-work-tree &>/dev/null || return
    __render brightred

    # Handle HEAD as branch
    local -r branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
    [ -n "$branch" ] && { printf "    󰃻  $(__render brightcyan)$branch "; return; }

    # Handle HEAD as tag
    local -r tag="$(git describe --tags --exact-match 2>/dev/null)"
    [ -n "$tag" ] && { printf "      $(__render brightcyan)$tag "; return; }

    # Handle HEAD as neither
    local ref="$(git describe --contains 2>/dev/null)" # tag~N
    [ -z "$ref" ] && { ref="$(git describe --contains --all 2>/dev/null)"; } # branch~N
    [ -z "$ref" ] && { ref="[$(git describe --contains --always)]"; } # commit SHA
    printf "    󱥸  $(__render brightcyan)$ref "
}

# Component for Python virtual environment - venv and conda
__prompt_python_env() {
    # NOTE: assumes both venv and conda environments can be active simultaneously
    __render brightmagenta
    [ -n "$VIRTUAL_ENV" ] && printf "$(basename "$VIRTUAL_ENV") "
    [ -n "$CONDA_DEFAULT_ENV" ] && printf "$(basename "$CONDA_DEFAULT_ENV") "
}

# Final prompt terminator, indicating success or failure of last command
__prompt_terminator() {
    # FIX: neovim terminal start with SHLVL at 2 ; correct this using bash_env file
    if [ $__prompt_last_exit -eq 0 ]; then __render none; else __render brightred; fi
    printf "%$((SHLVL+1))s" + | sed -e 's| ||g' -e 's|+|  |g'
    __render none
}

################################ PROMPT STRINGS ################################

export PS1='
$(__prompt_job_list)$(__prompt_user_host)$(__prompt_cwd)$(__prompt_dir_stack)$(__prompt_git_head)
$(__prompt_python_env)$(__prompt_terminator)'

export PS2='  $(__render brightblack)$(__render none)  '

export PS3='$(__render cyan)SELECT$(__render none) '

export PS4='$(__render green)[TRACE]$(__render none) '
