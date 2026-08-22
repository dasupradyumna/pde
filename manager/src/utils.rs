/////////////////////////////////// CONVENIENCE AND UTILITY ITEMS //////////////////////////////////

use std::fmt::Display;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::OnceLock;

pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

#[macro_export]
macro_rules! log {
    (debug, $($arg:tt)*) => {
        #[cfg(debug_assertions)] // Enable only in debug builds
        {
            let msg = format!($($arg)*);
            println!("\x1b[96m@ {}:{}:{}: {}\x1b[0m", file!(), line!(), column!(), msg)
        }
    };
    (info, $($arg:tt)*) => {
        println!("\x1b[36m{}\x1b[0m", format!($($arg)*))
    };
    (warn, $($arg:tt)*) => {
        println!("\x1b[33mWARN: {}\x1b[0m", format!($($arg)*))
    };
    (error, $($arg:tt)*) => {
        eprintln!("\n\x1b[31;1mERROR: {}\x1b[0m\n", format!($($arg)*))
    };
}

pub fn home() -> &'static PathBuf {
    static HOME: OnceLock<PathBuf> = OnceLock::new();
    HOME.get_or_init(|| home::home_dir().expect("$HOME environment variable not set"))
}

pub fn in_pde_root() -> bool {
    let mut ret = true;
    ret = ret && PathBuf::from(".git").exists();
    ret = ret
        && fs::read_to_string(".git/config")
            .map_or(false, |config| config.contains("dasupradyumna/pde"));
    return ret;
}

pub fn clone_github<Str>(
    url: Str,
    head: Str,
    clone_dir: &PathBuf,
    shallow: bool,
) -> self::Result<()>
where
    Str: AsRef<str> + Display,
{
    let mut command = Command::new("git");
    command
        .arg("clone")
        .arg(format!("https://github.com/{url}")) // TODO: Change this to SSH-based
        .arg(&clone_dir)
        .arg(format!("--branch={head}"))
        .args(&["--config", "advice.detachedHead=false"]);
    if shallow {
        command.arg("--depth=1");
    }
    log!(debug, "Clone command: {command:?}");

    let status = command.status()?;
    if !status.success() {
        Err(format!("Github clone failed for {}: {}", url, status).into())
    } else {
        Ok(())
    }
}

pub fn create_symlink<From, To>(from: From, to: To) -> self::Result<()>
where
    From: AsRef<Path>,
    To: AsRef<Path>,
{
    #[cfg(unix)]
    return Ok(std::os::unix::fs::symlink(from, to)?);

    #[cfg(windows)]
    return Ok(std::os::windows::fs::symlink_file(from, to)?);
}

pub fn strip_prefix_vector(files: Vec<PathBuf>, prefix: &PathBuf) -> self::Result<Vec<PathBuf>> {
    let mut stripped = Vec::new();
    for file in files {
        stripped.push(file.strip_prefix(prefix)?.to_path_buf());
    }
    Ok(stripped)
}
