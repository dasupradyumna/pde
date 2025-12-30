# Personal Development Environment

A streamlined development environment setup for Ubuntu systems, featuring essential CLI tools and
custom configurations. Built with the *Unix philosophy* in mind, focusing on terminal-based tools for
maximum efficiency and productivity.

## Components

- **Automated Setup**: One-command installation with version locking
- **Git Tools**: LazyGit (0.54.2) + Delta (0.18.2) for enhanced git workflow
- **Custom Bash**: Aliases, prompts, and utilities for productivity
- **WezTerm**: Terminal multiplexer with custom theme and keybindings
- **Neovim**: TUI Editor with support for LSP, treesitter and extensibility

## Installation

The setup script for Ubuntu needs to be run _only_ from the root of this repository. There may be
unexpected behavior if this precondition is violated. Note that this script requires **root** access
or **sudo** permissions to install common system dependencies, irrespective of scope.

This script ensures all system dependencies are installed, downloads all PDE tools and installs
their configurations to `~/.config` (system config directory not supported yet). Tool versions are
locked using `version.lock` file for reproducible release builds.

### Usage

```bash
# Install locally
./setup_ubuntu.sh

# Install system-wide
./setup_ubuntu.sh -s

# Install headless
./setup_ubuntu.sh -H

# Uninstall
./setup_ubuntu.sh -U
```

## Project Structure

```
├── config/          # Tool configurations
│   ├── aider/       # AI coding agent
│   ├── bash/        # Custom bash environment
│   ├── delta/       # Delta diff enhancer
│   ├── git/         # Git version control
│   ├── lazygit/     # LazyGit git helper
│   ├── nvim/        # Neovim editor
│   └── wezterm/     # WezTerm multiplexer
├── setup/           # Modular installation modules
├── setup_ubuntu.sh  # Main installation script
└── lock.version     # Tool version specifications
```
