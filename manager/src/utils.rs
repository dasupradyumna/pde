use std::fmt::Display;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::sync::OnceLock;

pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

pub fn home() -> &'static PathBuf {
    static HOME: OnceLock<PathBuf> = OnceLock::new();
    HOME.get_or_init(|| home::home_dir().expect("$HOME environment variable not set"))
}

pub fn has_command(command: &str) -> bool {
    which::which(command).is_ok()
}

pub fn print_err<Msg>(msg: Msg)
where
    Msg: Display,
{
    eprintln!("\n\x1b[31;1mERROR: {msg}\x1b[0m\n");
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
        .arg(format!("--branch={head}"));
    if shallow {
        command.arg("--depth=1");
    }
    let status = command.status()?;
    if !status.success() {
        Err(format!("Github clone failed for {}: {}", url, status).into())
    } else {
        Ok(())
    }
}
