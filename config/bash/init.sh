################################### BASH ENVIRONMENT ENTRY-POINT ###################################

# Sentinel for PDE bash environment
if [ -n "$PDE_BASH_ENV_LOADED" ]; then return; fi
PDE_BASH_ENV_LOADED=true

# Disable flow control - frees up <C-S> & <C-Q>
stty -ixon

# Builtin options
set +o braceexpand
set +o histexpand
shopt -s checkhash checkjobs dirspell hostcomplete huponexit progcomp_alias shift_verbose

# Source all custom bash modules in current script directory
for module in "$(dirname -- "${BASH_SOURCE[0]}")"/*.sh; do source "$module"; done

unset -v module
