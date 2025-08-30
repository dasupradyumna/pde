################################### BASH ENVIRONMENT ENTRY-POINT ###################################

# Sentinel for PDE bash environment
if [ -n "$PDE_BASH_ENV_LOADED" ]; then return; fi
PDE_BASH_ENV_LOADED=true

# Disable flow control - frees up <C-S> & <C-Q>
stty -ixon

# Builtin options
set +o braceexpand
set +o histexpand
shopt -s checkhash checkjobs dirspell failglob hostcomplete huponexit progcomp_alias shift_verbose

# Source all custom bash modules
for module in "$(dirname -- "${BASH_SOURCE[0]}")"/*.sh; do source "$module"; done

# Set environment variables
# FIGNORE, LS_COLORS

# Ensures terminal supports 256 colors + truecolor
[ "$TERM" != "xterm-256color" ] && export TERM=xterm-256color
[ "$COLORTERM" != "truecolor" ] && export COLORTERM=truecolor

# Ensures all readline programs use custom inputrc
export INPUTRC="$(dirname -- "${BASH_SOURCE[0]}")/inputrc"
