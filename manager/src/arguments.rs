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
}

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

pub fn parse() -> utils::Result<Mode> {
    let mut arg_b = None;
    let mut arg_c = None;
    let mut arg_i = None;

    let mut parser = lexopt::Parser::from_env();
    while let Some(arg) = parser.next()? {
        match arg {
            // Show help
            lexopt::Arg::Short('h') => {
                self::help();
                process::exit(0);
            }
            // Clone target branch
            lexopt::Arg::Short('b') => arg_b = Some(parser.value()?.to_string_lossy().to_string()),
            // Clone directory path
            lexopt::Arg::Short('c') => arg_c = Some(PathBuf::from(parser.value()?)),
            // Installation prefix
            lexopt::Arg::Short('i') => arg_i = Some(PathBuf::from(parser.value()?)),

            // Upgrade PDE manager binary
            lexopt::Arg::Long("upgrade") => return Ok(Mode::UpgradeSelf(true)),
            lexopt::Arg::Long("upgrade-debug") => return Ok(Mode::UpgradeSelf(false)),

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
    let arg_b = arg_b.unwrap_or_else(|| "main".to_string());
    let arg_c = arg_c.unwrap_or_else(|| utils::home().join("projects"));
    let arg_i = arg_i.ok_or_else(|| "Missing argument: -i (install prefix)")?;

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

    // Compute temporary directory
    let pde_dir = clone_dir.join("pde");
    let temp_dir = pde_dir.join("temp");

    Ok(Context {
        pde_branch,
        pde_dir,
        temp_dir,
        install_prefix,
    })
}
