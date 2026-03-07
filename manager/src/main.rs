mod component;

use crate::component::{Component, Installer};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process;

fn main() {
    let args = parse_args().unwrap_or_else(|e| {
        eprintln!("\n\x1b[31;1mERROR: {}\x1b[0m\n", e);
        show_help();
        process::exit(1);
    });
    dbg!(&args);

    // CLAUDE: IGNORE BELOW COMMENTS
    // Clone PDE (main) to target location
    // Read install spec file (TOML) into vector of components
    // Iterate over vector of components
    // - skip if component is disabled
    // - install component binaries
    //   - switch logic based on installation method
    //   - extra commands
    // - install config if enabled (mostly creating a symlink)
    // Display total time taken by the script
}

fn show_help() {
    println!("Usage: pde-manager [OPTIONS]\n");
    println!("  -h           Show this help message and exit");
    println!("  -c <PATH>    PDE clone directory (default: $HOME/projects)");
    println!("  -i <PATH>    Prefix to installation paths");
}

#[derive(Debug)]
struct Args {
    clone_dir: PathBuf,
    install_prefix: PathBuf,
}

fn parse_args() -> Result<Args, Box<dyn std::error::Error>> {
    let mut clone_dir = None;
    let mut install_prefix = None;

    let mut parser = lexopt::Parser::from_env();
    while let Some(arg) = parser.next()? {
        match arg {
            lexopt::Arg::Short('h') => {
                show_help();
                process::exit(0);
            }
            lexopt::Arg::Short('c') => clone_dir = Some(PathBuf::from(parser.value()?)),
            lexopt::Arg::Short('i') => {
                install_prefix = Some(PathBuf::from(parser.value()?));
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
    let home = env::var("HOME").map_err(|_| "$HOME environment variable not set".to_string())?;
    let clone_dir = clone_dir.unwrap_or_else(|| PathBuf::from(format!("{}/projects", home)));
    let install_prefix = install_prefix.ok_or_else(|| "Missing argument: --install-prefix")?;

    return validate_args(Args {
        clone_dir,
        install_prefix,
    });
}

fn validate_args(args: Args) -> Result<Args, Box<dyn std::error::Error>> {
    let ensure_exists_and_writable = |dir: &PathBuf| -> Result<(), Box<dyn std::error::Error>> {
        // Ensure directory exists
        fs::create_dir_all(dir).map_err(|e| format!("Failed to create directory {dir:?}: {e}"))?;

        // Check if directory is writable
        let test_file = dir.join(".pde-manager-write-test");
        if let Err(e) = fs::File::create(&test_file) {
            return Err(format!(
                "Directory {dir:?} is not writable: {e}\n\
                Re-run with adequate write permissions and/or appropriate privileges"
            )
            .into());
        }
        if let Err(e) = fs::remove_file(&test_file) {
            return Err(format!("Failed to clean up test file in {dir:?}: {e}").into());
        }

        Ok(())
    };

    ensure_exists_and_writable(&args.clone_dir)?;
    ensure_exists_and_writable(&args.install_prefix)?;

    Ok(args)
}
