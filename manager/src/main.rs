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
        Mode::UpgradeSelf => upgrade_self(),
        Mode::ManageTools(ctx) => install_pde(ctx),
    };
    res.unwrap_or_else(|e| {
        utils::print_err(e);
        process::exit(1);
    });
}

fn upgrade_self() -> Result<(), Box<dyn std::error::Error>> {
    // Check if executed from current
    if !utils::in_pde_root() {
        return Err("Not executed from PDE root directory.".into());
    }

    // Build release binary
    Command::new("cargo")
        .args(&["build-manager"])
        .current_dir("manager")
        .status()
        .map_err(|e| format!("Build failed: {e}\nFix build errors and try again"))?;

    // Replace current executable with new binary
    let new_binary = "manager/target/release/pde-manager";
    self_replace::self_replace(&new_binary)?;
    fs::remove_file(&new_binary)?;

    Ok(())
}

fn install_pde(ctx: Context) -> Result<(), Box<dyn std::error::Error>> {
    // Check if git is installed and available
    if !utils::has_command("git") {
        return Err("'git' command not found!".into());
    }

    // Clone PDE (main) to target location, if it does not exist
    let pde_path = ctx.clone_dir.join("pde");
    let cwd = std::env::current_dir()?;
    if utils::in_pde_root() && cwd != pde_path {
        return Err(format!(
            "PDE already exists! Trying to clone PDE at 2 locations.\nExisting: {:?} Target: {:?}",
            cwd, pde_path
        )
        .into());
    } else if !utils::in_pde_root() && !pde_path.exists() {
        println!("Cloning PDE ...");

        // TODO: move to SSH-based cloning, useful for dev work
        Command::new("git")
            .args(&[
                "clone",
                "https://github.com/dasupradyumna/pde",
                &pde_path.to_string_lossy(),
            ])
            .status()
            .map_err(|e| format!("Failed to clone PDE: {e}"))?;

        // Move pde-manager binary to the newly cloned PDE directory
        fs::copy(std::env::current_exe()?, pde_path.join("pde-manager"))?;
        self_replace::self_delete()?;

        println!("Clone complete!");
    } else {
        println!("PDE already exists at {:?}, skipping clone", pde_path);
    }

    // Read install spec file (TOML) into vector of components
    let toml_content = fs::read_to_string(pde_path.join("manifest.toml"))
        .map_err(|e| format!("Failed to read manifest: {e}"))?;
    let manifest: Manifest =
        toml::from_str(&toml_content).map_err(|e| format!("Failed to parse manifest: {e}"))?;
    dbg!(&manifest);

    for component in manifest.list {
        // TODO: if component / group is disabled or already installed, then skip
        component.install(&ctx);
        // TODO: copy config - target dir??
    }

    // TODO: Display total time taken by the script

    Ok(())
}
