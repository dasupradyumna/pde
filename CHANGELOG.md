# CHANGE LOG

## 2026.1

_Installer rust-rewrite, custom theming, and UI improvements._

### Added

- **Setup**
  - Rewrite logic into a rust binary crate `manager`
    - Self-upgrade support and fresh PDE cloning
    - TOML manifest loading with `Component`, `Installer`, and `Group` types
    - Tool config installation; bash environment variables extracted to a separate sourced file
    - Interrupt handling via `ctrlc` crate and structured logging via `log!()` macro
    - Skip component when requirement is already satisfied via local installation state tracking
    - Human-readable elapsed time display
  - Docker installation script
- **Neovim**
  - `aurorux` colorscheme and  `gitsigns.nvim` for buffer-level git status
  - Statuscolumn, tabline, and winbar configuration
  - `nvim-dap` plugin for debugging using debug adapter protocol
  - Filetype plugin files for `help`, `markdown`, `rust`, and `vim`
  - Keymap to rename current buffer file
  - Vimscript autoload wrapper for Lua notify module
- **WezTerm**
  - Support for transparent background along with images
  - All windows open in a maximized state
- **GDB**: Configure a colored pretty prompt

### Changed

- **Neovim**
  - Session manager refactored to use Vimscript autoload wrapper for notify module
  - Command-mode and mode-cancel keymaps updated; cursorline disabled in quickfix windows

### Fixed

- **Neovim**: Correct library paths for Lua LS
- **AI**: Restored Anthropic authentication in OpenCode via plugin workaround

## 2026.0

_Support for LSP and treesitter in neovim, along with CLI tool launcher._

### Added

- **Neovim**
  - LSP configuration for Rust (rust-analyzer) and C++ (clangd).
  - Plugin management via `lazy.nvim`; integrated `blink.cmp` for auto-completion.
  - Treesitter enabled for available filetypes, including folding support.
  - Scratch file toggle with edge swapping and auto-write support.
  - Tool launcher utility with last-used tool toggle and temporary tabline.
  - Cursorline enabled only in focused window; additional convenience keymaps.
- **AI**
  - Aider and OpenCode installation logic with bash completion.
  - OpenCode configuration with custom agents and keymaps.
- **GDB**
  - Configuration and watcher module.

### Fixed

- **Neovim**
  - Prevented leakage of `g:TabpageNames` during session load.
- **Setup**
  - Fixed WezTerm bash completion generation bug.

## 2025.3.0

_Improvements to setup logic, and include Neovim and Aider._

### Added

- **Neovim**
  - Initial config with keymaps, aliases, and whitespace trimming
  - Session manager with automatic load/save, empty-session cleanup, and error handling
  - Tabpage manager supporting create, rename, move, and persistence via sessions
  - Notification manager as a Lua module
- **AI**
  - Aider configuration with helper bash function for managing chat history
- **Setup**
  - Neovim installation logic, including runtime dependencies and system requirements
  - Git-crypt installation logic with version locking

### Changed

- **Bash**
  - Improved readline behavior
- **Setup**
  - Tracking for non–version-locked tools; lock file renamed to `lock.version`
- **Misc**
  - Added Vimaan MDH helper
  - Refreshed git-crypt encryption and collaborators

### Fixed

- **Setup**
  - Prevented runaway rolling logs near the screen bottom

## 2025.2.0

_Integrate WezTerm and configure its workflow._

### Added

- **WezTerm** [#5](https://github.com/dasupradyumna/pde/issues/5)
  - Add custom color scheme and fonts with extended Unicode support
  - Implement status bar with domain, workspace, battery and multiplexer latency indicators
  - Define custom keybindings for copy, search, tab and pane actions
  - Support for custom domains and workspaces, along with convenience helper actions
- **Setup**
  - Implement installation logic for WezTerm with improved GitHub asset download logic
  - Add headless installation mode with configurable binary and config folders
  - Install bash completion and context menu item Nautilus extension for WezTerm

### Fixed

- **Bash**
  - Disabled `failglob` to ensure completion works correctly
  - Unset helper variables in `init.sh` to avoid leaks

## 2025.1.1

_Update GitHub workflows for pull requests and issue labels._

## 2025.1.0

_Ready to use Bash environment along with Git workflow._

### Added

- **Git workflow** [#3](https://github.com/dasupradyumna/pde/issues/3)
  - Add **Git** configuration files and post-checkout hook for automatic email setup
  - Add **Lazygit** configuration with theme, keybindings, interactive behavior
  - Add **Delta** configuration integrated with LazyGit as pager for diffs
- **Bash environment** [#4](https://github.com/dasupradyumna/pde/issues/4)
  - Customize shell behavior with `set`/`shopt` and readline editing via `inputrc`
  - Customize prompt strings (PS1-4)
  - Add aliases for directory stacks and Python **venv** management
  - Ensure terminal supports 256 true-color rendering
- **Installation** [#2](https://github.com/dasupradyumna/pde/issues/2)
  - Add installation logic for all tools and their configurations  
    Ensures all system dependencies are already installed
  - Add bash environment entry point to `.bashrc`
  - Add uninstallation logic via `-U` flag  
    Removes configs and tools (except Git and common dependencies)
  - Support version lock file
  - Support for system and local scopes via `-s` flag

## 2025.0.0

_Starting Point. No features, just a bare bones repository._
