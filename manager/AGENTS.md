# Guidelines: PDE Manager

Rust binary crate bootstrapping/installing PDE and its tools via `manifest.toml`, and
self-upgrading.

## File Hierarchy

- `src/main.rs`: Entry point; self-upgrade & component install flows, config symlinking.
- `src/arguments.rs`: CLI argument parsing, builds `Context`, loads/validates `InstallState`.
- `src/component.rs`: Manifest parsing, component installers - build_source / python_venv /
  release_asset / run_script, install state tracking.
- `src/utils.rs`: Shared helpers; logging, git clone, symlinks, `$HOME` resolution.

## Notes

- DO NOT build in release mode to validate changes. Build in debug mode.
  Build command: `$ ./pde-manager --upgrade-debug`
