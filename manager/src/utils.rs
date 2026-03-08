use std::fmt::Display;
use std::fs;
use std::path::PathBuf;
use std::sync::OnceLock;

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
