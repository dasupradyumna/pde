////////////////////////////////////// PDE MANAGER ENTRY-POINT /////////////////////////////////////

mod arguments;
mod component;
mod utils;

use crate::arguments::{Context, Mode};
use crate::component::{InstallState, Manifest};
use std::fs;
use std::path::Path;
use std::process::{self, Command};
use std::time::Instant;

fn main() {
    // Parse command-line arguments
    let mode = arguments::parse().unwrap_or_else(|e| {
        log!(error, "{e}");
        arguments::help();
        process::exit(1);
    });
    log!(debug, "{mode:#?}");

    // Run core logic based on execution mode
    let res = match mode {
        Mode::UpgradeSelf(release) => upgrade_self(release),
        Mode::ManageTools(ctx) => install_pde(&ctx),
    };

    // Handle error from upstream logic
    res.unwrap_or_else(|e| {
        log!(error, "{e}");
        process::exit(1);
    });
}

fn cleanup_temp_dir(temp_dir: &Path) {
    fs::remove_dir_all(temp_dir).unwrap_or_else(|e| {
        log!(error, "Clean-up failed for {:?}: {e}", temp_dir);
    });
    log!(debug, "Cleaned up temp directory");
}

fn upgrade_self(release: bool) -> utils::Result<()> {
    log!(info, "\n{}\nUpgrading pde-manager ...", "-".repeat(100));

    // Check if executed from current
    if !utils::in_pde_root() {
        return Err("Not executed from PDE root directory.".into());
    }
    let profile = if release { "release" } else { "dev" };
    let target_dir = if release { "release" } else { "debug" };

    // Build release binary
    log!(info, "- Building pde-manager in {target_dir} mode");
    Command::new("cargo")
        .args(&["build", "--profile", profile])
        .current_dir("manager")
        .status()
        .map_err(|e| format!("Build failed: {e}\nFix build errors and try again"))?;

    // Replace current executable with new binary
    let new_binary = format!("manager/target/{target_dir}/pde-manager");
    self_replace::self_replace(&new_binary)?;
    fs::remove_file(&new_binary)?;
    log!(info, "- Replaced current manager with newly built binary");

    Ok(())
}

fn install_pde(ctx: &Context) -> utils::Result<()> {
    let start = Instant::now();

    // Set up SIGINT handler to clean up temp directory
    let temp_dir = ctx.temp_dir.clone();
    ctrlc::set_handler(move || {
        cleanup_temp_dir(&temp_dir);
        process::exit(130);
    })
    .map_err(|e| format!("Error setting SIGINT handler: {e}"))?;
    log!(debug, "Setup SIGINT handler for Ctrl-C interrupts");

    // Clone PDE (main) to target location, if it does not exist
    log!(info, "\n{}\nEnsuring PDE project existence ...", "-".repeat(100));
    let cwd = std::env::current_dir()?;
    if utils::in_pde_root() && cwd != ctx.pde_dir {
        return Err(format!(
            "PDE already exists! Trying to clone PDE at 2 locations.\nExisting: {:?} Target: {:?}",
            cwd, ctx.pde_dir
        )
        .into());
    } else if !utils::in_pde_root() && !ctx.pde_dir.exists() {
        utils::clone_github("dasupradyumna/pde", &ctx.pde_branch, &ctx.pde_dir, false)?;
        log!(info, "- Cloned PDE to {:?}", ctx.pde_dir);

        // Move pde-manager binary to the newly cloned PDE directory
        fs::copy(std::env::current_exe()?, ctx.pde_dir.join("pde-manager"))?;
        self_replace::self_delete()?;
        log!(info, "- Moved current manager binary to PDE");
    } else {
        log!(info, "- PDE already exists at {:?}: Skipping clone", ctx.pde_dir);
    }
    // Ensure temp directory exists
    fs::create_dir_all(&ctx.temp_dir)?;
    log!(debug, "Ensured temp directory exists");

    // Load installation state
    let mut state = InstallState::load(&ctx.state_file)?;

    // Read install spec file (TOML) into vector of components
    let manifest: Manifest = {
        let content = fs::read_to_string(ctx.pde_dir.join("manifest.toml"))
            .map_err(|e| format!("Failed to read manifest: {e}"))?;
        toml::from_str(&content).map_err(|e| format!("Failed to parse manifest: {e}"))?
    };
    for mut component in manifest.list {
        log!(info, "\n{}\nInstalling component: {} ...", "-".repeat(100), component.meta.name);
        if state.should_skip(&component.meta) {
            log!(info, "- Component requirement already satisfied. Skipping");
            continue;
        }

        log!(debug, "{component:#?}");
        component.resolve_placeholders(&ctx).install(&ctx, &mut state)?;
        state.save(&ctx.state_file)?;
    }

    // Manage configs installation
    self::manage_configs(ctx)?;

    // Display elapsed time in human-readable format
    let elapsed = start.elapsed().as_secs_f64();
    let elapsed_i = elapsed as i64;
    let time_str = if elapsed_i >= 3600 {
        format!("{}h {}m {:.3}s", elapsed_i / 3600, (elapsed_i % 3600) / 60, elapsed % 60.)
    } else if elapsed_i >= 60 {
        format!("{}m {:.3}s", elapsed_i / 60, elapsed % 60.)
    } else {
        format!("{:.3}s", elapsed)
    };
    log!(info, "\n{}\nTotal time taken: {}", "-".repeat(100), time_str);

    // Clean up the temporary directory only in case of no exception
    cleanup_temp_dir(&ctx.temp_dir);

    Ok(())
}

fn manage_configs(ctx: &Context) -> utils::Result<()> {
    log!(info, "\n{}\nCopying tool configs ...", "-".repeat(100));

    // Ensure destination directory exists
    let dst_dir = utils::home().join(".config"); // TODO: handle windows path also here
    fs::create_dir_all(&dst_dir)?;
    log!(debug, "Ensured target config {dst_dir:?} exists");

    let src_dir = ctx.pde_dir.join("config");
    log!(info, "- Creating symlinks from {src_dir:?} to {dst_dir:?}");
    for config in fs::read_dir(src_dir)? {
        let config = config?;
        let config_name = config.file_name();
        if config_name == "bash" {
            continue; // Handle bash separately below
        }

        // All other tools just need their config folders symlink to standard config path
        let src_config = config.path();
        let dst_config = dst_dir.join(&config_name);

        // Remove existing symlink
        if dst_config.exists() {
            if !dst_config.is_symlink() {
                return Err(format!("Existing config for {config_name:?} is not symlink!").into());
            }
            fs::remove_file(&dst_config)?;
            log!(debug, "Removed existing config symlink");
        }
        utils::create_symlink(&src_config, &dst_config)?;
        log!(info, "  - Created symlink for {config_name:?}");
    }

    // Manage PDE environment on login
    let profile_path = {
        let bash_profile = utils::home().join(".bash_profile");
        let profile = utils::home().join(".profile");
        if bash_profile.exists() { bash_profile } else { profile }
    };
    log!(debug, "Profile path: {profile_path:?}");
    let entrypoint = format!(
        "\n# >>> PDE-ENVIRONMENT >>>\nsource {}/config/bash/env\n# <<< PDE-ENVIRONMENT <<<",
        ctx.pde_dir.display()
    );
    let content = fs::read_to_string(&profile_path).unwrap_or_default();
    if content.contains(">>> PDE-ENVIRONMENT >>>") {
        log!(info, "- PDE bash environment already in {profile_path:?}");
    } else {
        fs::write(&profile_path, format!("{}{}", content, entrypoint))?;
        log!(info, "- Added PDE bash environment to {profile_path:?}");
    }

    // Manage bash entry point
    let bashrc = utils::home().join(".bashrc");
    let entrypoint = format!(
        "\n# >>> PDE-ENTRYPOINT >>>\nsource {}/config/bash/init.sh\n# <<< PDE-ENTRYPOINT <<<",
        ctx.pde_dir.display()
    );
    let content = fs::read_to_string(&bashrc).unwrap_or_default();
    if content.contains(">>> PDE-ENTRYPOINT >>>") {
        log!(info, "- PDE bash entry point already in {profile_path:?}");
    } else {
        fs::write(&bashrc, format!("{}{}", content, entrypoint))?;
        log!(info, "- Added PDE bash entry point to {bashrc:?}");
    }

    Ok(())
}
