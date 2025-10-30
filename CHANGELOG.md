# CHANGE LOG

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
