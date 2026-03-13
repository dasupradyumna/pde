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
            // TODO: this does not happen on SIGINT
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
        utils::clone_github("dasupradyumna/pde", "main", &ctx.pde_dir, false)?;

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
        // TODO: copy config - target dir??
    }

    // TODO: Display total time taken by the script

    Ok(())
}
