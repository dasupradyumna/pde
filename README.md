# Personal Development Environment

This repository contains the installation script, configurations and dot files for all the software
tools that form my personal development environment. This environment comprises mainly of command
line utilities and terminal-based tools, trying to emulate the Unix philosophy.

## Components

- Installation Script
- Version Lock File
- Custom Bash Environment
- Git Workflow Tools - Git, LazyGit & Delta

## Installation

The setup script for Ubuntu needs to be run _only_ from the root of this repository. There may be
unexpected behavior if this precondition is violated. Note that this script requires **root** access
or **sudo** permissions to install common system dependencies, irrespective of scope.

This script ensures all system dependencies are installed, downloads all PDE tools and installs
their configurations to `~/.config` (system config directory not supported yet). Tool versions are
locked using `version.lock` file for reproducible release builds.

```bash
./setup_ubuntu.sh -h            # Displays help message
./setup_ubuntu.sh               # Installs PDE at local scope
./setup_ubuntu.sh -s            # Installs PDE at system scope
./setup_ubuntu.sh -U [-s]       # Uninstalls PDE at specified scope
```
