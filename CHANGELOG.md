# CHANGE LOG

## 2025.1.1

_Updated GitHub workflows for pull requests and issue labels_

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
