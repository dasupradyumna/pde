# Agent Guidelines for PDE

## General
- Variable and function names must be snake-case, and constant names must be upper-snake-case.

## Manager
- Crate folder: `./manager`
- DO NOT build in release mode to validate changes. Build in debug mode.
  Build command: `$ ./pde-manager --upgrade-debug`

## Neovim
- Config folder: `./config/nvim`
- Find all help documentation under `$HOME/.pde/share/nvim/runtime/doc` folder
- For vimscript, skip `l:` prefix in local variable names.
