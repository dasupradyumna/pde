mod component;
mod utils;

use std::fs;
use std::path::PathBuf;
use std::process::{self, Command};

fn main() {
    // Parse command-line arguments
    let args = parse_args().unwrap_or_else(|e| {
        utils::print_err(e);
        show_help();
        process::exit(1);
    });
    dbg!(&args);

    let res = if args.upgrade_self {
        upgrade_self()
    } else {
        manage_pde(args)
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

fn manage_pde(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    // Check if git is installed and available
    if !utils::has_command("git") {
        return Err("'git' command not found!".into());
    }

    // Clone PDE (main) to target location, if it does not exist
    let pde_path = args.clone_dir.join("pde");
    let cwd = std::env::current_dir()?;
    if utils::in_pde_root() && cwd != pde_path {
        return Err(format!(
            "PDE already exists! Trying to clone PDE at 2 locations.\nExisting: {:?} Target: {:?}",
            cwd, pde_path
        )
        .into());
    } else if !utils::in_pde_root() && !pde_path.exists() {
        println!("Cloning PDE ...");

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

    Ok(())
}

fn show_help() {
    println!("Usage: pde-manager [OPTIONS]\n");
    println!("  -h          Show this help message and exit");
    println!("  -c <PATH>   PDE clone directory (default: $HOME/projects)");
    println!("  -i <PATH>   Prefix to installation paths");
    println!("  --upgrade   Build and upgrade pde-manager");
    println!("              (Assumes CWD is PDE root; fails otherwise)");
}

#[derive(Debug)]
struct Args {
    clone_dir: PathBuf,
    install_prefix: PathBuf,
    upgrade_self: bool,
}

fn parse_args() -> Result<Args, Box<dyn std::error::Error>> {
    let mut arg_c = None;
    let mut arg_i = None;

    let mut parser = lexopt::Parser::from_env();
    while let Some(arg) = parser.next()? {
        match arg {
            // Show help
            lexopt::Arg::Short('h') => {
                show_help();
                process::exit(0);
            }
            // Clone directory path
            lexopt::Arg::Short('c') => arg_c = Some(PathBuf::from(parser.value()?)),
            // Installation prefix
            lexopt::Arg::Short('i') => arg_i = Some(PathBuf::from(parser.value()?)),

            // Upgrade PDE manager binary
            lexopt::Arg::Long("upgrade") => {
                return Ok(Args {
                    clone_dir: PathBuf::new(),
                    install_prefix: PathBuf::new(),
                    upgrade_self: true,
                });
            }

            /////////////////// UNEXPECTED ARGUMENTS ///////////////////
            lexopt::Arg::Short(c) => {
                return Err(format!("Unexpected argument: -{c}").into());
            }
            lexopt::Arg::Long(l) => {
                return Err(format!("Unexpected argument: --{l}").into());
            }
            lexopt::Arg::Value(v) => {
                return Err(format!("Unexpected value: {}", v.to_string_lossy()).into());
            }
        }
    }

    // Check missing arguments and apply defaults or throw error
    let arg_c = arg_c.unwrap_or_else(|| utils::home().join("projects"));
    let arg_i = arg_i.ok_or_else(|| "Missing argument: --install-prefix")?;

    return validate_args(Args {
        clone_dir: arg_c,
        install_prefix: arg_i,
        upgrade_self: false,
    });
}

fn validate_args(mut args: Args) -> Result<Args, Box<dyn std::error::Error>> {
    let ensure_exists_and_writable = |dir: &PathBuf| -> Result<(), Box<dyn std::error::Error>> {
        // Ensure directory exists
        fs::create_dir_all(dir).map_err(|e| format!("Failed to create directory {dir:?}: {e}"))?;

        // Check if directory is writable
        let test_file = dir.join(".pde-manager-write-test");
        fs::File::create(&test_file).map_err(|e| {
            format!(
                "Directory {dir:?} is not writable: {e}\n\
                Re-run with adequate write permissions and/or appropriate privileges"
            )
        })?;
        fs::remove_file(&test_file)
            .map_err(|e| format!("Failed to clean up test file in {dir:?}: {e}"))?;

        Ok(())
    };

    // Validate and normalize both path-based arguments
    ensure_exists_and_writable(&args.clone_dir)?;
    args.clone_dir = fs::canonicalize(args.clone_dir)?;
    ensure_exists_and_writable(&args.install_prefix)?;
    args.install_prefix = fs::canonicalize(args.install_prefix)?;

    Ok(args)
}
