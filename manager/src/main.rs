mod arguments;
mod component;
mod utils;

use crate::arguments::{Context, Mode};
use crate::component::Manifest;
use std::fs;
use std::process::{self, Command};

fn main() {
    // Parse command-line arguments
    let args = arguments::parse().unwrap_or_else(|e| {
        utils::print_err(e);
        arguments::help();
        process::exit(1);
    });
    dbg!(&args);

    let res = match args {
        Mode::UpgradeSelf(release) => upgrade_self(release),
        Mode::ManageTools(ctx) => {
            let res = install_pde(&ctx);
            // Clean up temp directory before exiting
            fs::remove_dir_all(&ctx.temp_dir).unwrap_or_else(|e| {
                utils::print_err(format!("Clean-up failed for {:?}: {e}", ctx.temp_dir));
            });
            res
        }
    };
    res.unwrap_or_else(|e| {
        utils::print_err(e);
        process::exit(1);
    });
}

fn upgrade_self(release: bool) -> utils::Result<()> {
    // Check if executed from current
    if !utils::in_pde_root() {
        return Err("Not executed from PDE root directory.".into());
    }

    // Build release binary
    let profile = if release { "release" } else { "dev" };
    Command::new("cargo")
        .args(&["build", "--profile", profile])
        .current_dir("manager")
        .status()
        .map_err(|e| format!("Build failed: {e}\nFix build errors and try again"))?;

    // Replace current executable with new binary
    let target_dir = if release { "release" } else { "debug" };
    let new_binary = format!("manager/target/{target_dir}/pde-manager");
    self_replace::self_replace(&new_binary)?;
    fs::remove_file(&new_binary)?;

    Ok(())
}

fn install_pde(ctx: &Context) -> utils::Result<()> {
    // Clone PDE (main) to target location, if it does not exist
    let cwd = std::env::current_dir()?;
    if utils::in_pde_root() && cwd != ctx.pde_dir {
        return Err(format!(
            "PDE already exists! Trying to clone PDE at 2 locations.\nExisting: {:?} Target: {:?}",
            cwd, ctx.pde_dir
        )
        .into());
    } else if !utils::in_pde_root() && !ctx.pde_dir.exists() {
        println!("Cloning PDE ...");
        utils::clone_github("dasupradyumna/pde", &ctx.pde_branch, &ctx.pde_dir, false)?;

        // Move pde-manager binary to the newly cloned PDE directory
        fs::copy(std::env::current_exe()?, ctx.pde_dir.join("pde-manager"))?;
        self_replace::self_delete()?;

        println!("Clone complete!");
    } else {
        println!("PDE already exists at {:?}, skipping clone", ctx.pde_dir);
    }
    // Ensure temp directory exists
    fs::create_dir_all(&ctx.temp_dir)?;

    // Read install spec file (TOML) into vector of components
    let manifest: Manifest = {
        let toml_content = fs::read_to_string(ctx.pde_dir.join("manifest.toml"))
            .map_err(|e| format!("Failed to read manifest: {e}"))?;
        toml::from_str(&toml_content).map_err(|e| format!("Failed to parse manifest: {e}"))?
    };
    dbg!(&manifest);

    for mut component in manifest.list {
        // TODO: if component / group is disabled or already installed, then skip
        component.resolve_placeholders(&ctx).install(&ctx)?;
    }
    self::manage_configs(ctx)?;

    // TODO: Display total time taken by the script

    Ok(())
}

fn manage_configs(ctx: &Context) -> utils::Result<()> {
    // Ensure destination directory exists
    let dst_dir = utils::home().join(".config"); // TODO: handle windows path also here
    fs::create_dir_all(&dst_dir)?;

    for config in fs::read_dir(ctx.pde_dir.join("config"))? {
        let config = config?;
        let config_name = config.file_name();

        if config_name != "bash" {
            // All other tools just need their config folders symlink to standard config path
            let src_config = config.path();
            let dst_config = dst_dir.join(&config_name);

            // Remove existing symlink
            if dst_config.exists() {
                if !dst_config.is_symlink() {
                    return Err(
                        format!("Existing config for {config_name:?} is not symlink!").into(),
                    );
                }
                fs::remove_file(&dst_config)?;
            }
            utils::create_symlink(&src_config, &dst_config)?;
            continue;
        }

        // Manage PDE environment on login
        let profile_path = {
            let bash_profile = utils::home().join(".bash_profile");
            let profile = utils::home().join(".profile");
            if bash_profile.exists() {
                bash_profile
            } else {
                profile
            }
        };
        let entrypoint = format!(
            "\n# >>> PDE-ENVIRONMENT >>>\nsource {}/config/bash/env\n# <<< PDE-ENVIRONMENT <<<",
            ctx.pde_dir.display()
        );
        let content = fs::read_to_string(&profile_path).unwrap_or_default();
        if !content.contains(">>> PDE-ENTRYPOINT >>>") {
            fs::write(&profile_path, format!("{}{}", content, entrypoint))?;
            println!("Added PDE bash entry point to {:?}", profile_path);
        }

        // Manage bash entry point
        let bashrc = utils::home().join(".bashrc");
        let entrypoint = format!(
            "\n# >>> PDE-ENTRYPOINT >>>\nsource {}/config/bash/init.sh\n# <<< PDE-ENTRYPOINT <<<",
            ctx.pde_dir.display()
        );
        let content = fs::read_to_string(&bashrc).unwrap_or_default();
        if !content.contains(">>> PDE-ENTRYPOINT >>>") {
            fs::write(&bashrc, format!("{}{}", content, entrypoint))?;
            println!("Added PDE bash entry point to {:?}", bashrc);
        }
    }

    Ok(())
}
