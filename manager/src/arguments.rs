/////////////////////////////////// COMMAND-LINE ARGUMENT PARSER ///////////////////////////////////

use crate::log;
use crate::utils;
use std::fs;
use std::path::PathBuf;
use std::process;

#[derive(Debug)]
pub enum Mode {
    UpgradeSelf(bool),
    ManageTools(Context),
}

#[derive(Debug)]
pub struct Context {
    pub pde_branch: String,
    pub pde_dir: PathBuf,
    pub temp_dir: PathBuf,
    pub install_prefix: PathBuf,
    pub state_file: PathBuf,
}

/// Display help message with full command-line argument descriptions
pub fn help() {
    println!("Usage: pde-manager [OPTIONS]\n");
    println!("  -h                  Show this help message and exit");
    println!("  -b <BRANCH>         PDE target branch (default: main)");
    println!("  -c <PATH>           PDE parent directory (default: $HOME/projects)");
    println!("  -i <PATH>           Prefix to installation paths\n");
    println!("  --upgrade           Upgrade pde-manager (release build)");
    println!("  --upgrade-debug     Upgrade pde-manager (debug build)");
    println!("                      (Assumes CWD is PDE root; fails otherwise)");
}

/// Parse command-line arguments to return execution mode and its context
pub fn parse() -> utils::Result<Mode> {
    // Tool management context flags
    let mut arg_b = None;
    let mut arg_c = None;
    let mut arg_i = None;

    // Core parser loop
    let mut parser = lexopt::Parser::from_env();
    while let Some(arg) = parser.next()? {
        match arg {
            /////////////////// TOOL MANAGEMENT FLAGS //////////////////
            // Show help
            lexopt::Arg::Short('h') => {
                self::help();
                process::exit(0);
            },
            // Clone target branch
            lexopt::Arg::Short('b') => arg_b = Some(parser.value()?.to_string_lossy().to_string()),
            // Clone parent directory
            lexopt::Arg::Short('c') => arg_c = Some(PathBuf::from(parser.value()?)),
            // Installation prefix
            lexopt::Arg::Short('i') => arg_i = Some(PathBuf::from(parser.value()?)),

            //////////////////// SELF UPGRADE FLAGS ////////////////////
            // Release build
            lexopt::Arg::Long("upgrade") => {
                log!(info, "\nParsed self upgrade flag: release");
                return Ok(Mode::UpgradeSelf(true));
            },
            // Debug build
            lexopt::Arg::Long("upgrade-debug") => {
                log!(info, "\nParsed self upgrade flag: debug");
                return Ok(Mode::UpgradeSelf(false));
            },

            ///////////////////// UNSUPPORTED FLAGS ////////////////////
            lexopt::Arg::Short(c) => {
                return Err(format!("Unexpected argument: -{c}").into());
            },
            lexopt::Arg::Long(l) => {
                return Err(format!("Unexpected argument: --{l}").into());
            },
            lexopt::Arg::Value(v) => {
                return Err(format!("Unexpected value: {}", v.to_string_lossy()).into());
            },
        }
    }

    log!(info, "\nParsing command-line arguments ...");

    // Check missing arguments and apply defaults or throw error
    let arg_b = match arg_b {
        Some(branch) => {
            log!(info, "- Parsed clone target branch: {branch}");
            branch
        },
        None => {
            let default = "main".to_string();
            log!(info, "- Applying default to clone target branch: {default}");
            default
        },
    };
    let arg_c = match arg_c {
        Some(clone_dir) => {
            log!(info, "- Parsed clone parent dir: {clone_dir:?}");
            clone_dir
        },
        None => {
            let default = utils::home().join("projects");
            log!(info, "- Applying default to clone parent dir: {default:?}");
            default
        },
    };
    let Some(arg_i) = arg_i else {
        return Err("Missing argument: -i (install prefix dir)".into());
    };
    log!(info, "- Parsed install prefix dir: {arg_i:?}");

    // Validate tool management context
    let ctx = validate(arg_b, arg_c, arg_i)?;
    Ok(Mode::ManageTools(ctx))
}

fn validate(
    pde_branch: String,
    mut clone_dir: PathBuf,
    mut install_prefix: PathBuf,
) -> utils::Result<Context> {
    let ensure_exists_and_writable = |dir: &PathBuf| -> utils::Result<()> {
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

    // Validate and normalize path-based arguments
    ensure_exists_and_writable(&clone_dir)?;
    clone_dir = fs::canonicalize(clone_dir)?;
    ensure_exists_and_writable(&install_prefix)?;
    install_prefix = fs::canonicalize(install_prefix)?;

    // Validate install prefix directories
    for dir in ["bin", "lib", "share"] {
        ensure_exists_and_writable(&install_prefix.join(dir))?;
    }

    // Compute temporary directory and state file path
    let pde_dir = clone_dir.join("pde");
    let temp_dir = pde_dir.join("temp");
    let state_file = pde_dir.join("state.toml");

    Ok(Context {
        pde_branch,
        pde_dir,
        temp_dir,
        install_prefix,
        state_file,
    })
}
