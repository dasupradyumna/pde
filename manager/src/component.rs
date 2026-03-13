use crate::arguments::Context;
use crate::utils;
use flate2::read::GzDecoder;
use serde::Deserialize;
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub list: Vec<Component>,
}

#[derive(Debug, Deserialize)]
pub struct Component {
    group: Group,
    pub meta: Metadata,
    installer: Installer,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum Group {
    AI,
    Git,
    Neovim,
    WezTerm,
}

#[derive(Debug, Deserialize)]
pub struct Metadata {
    pub name: String,
    #[serde(default)]
    version: String,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum Installer {
    BuildSource(BuildSpec),
    PythonVenv(VenvSpec),
    ReleaseAsset(ReleaseSpec),
    RunScript(ScriptSpec),
}

#[derive(Debug, Deserialize)]
struct BuildSpec {
    _repo: String,
    _commands: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct VenvSpec {
    #[serde(default)]
    pkg: String,
    bin: String,
}

#[derive(Debug, Deserialize)]
struct ReleaseSpec {
    repo: String,
    #[serde(default)]
    tag: String,
    asset: String,
    ext: String,
    #[serde(default)]
    pkg: bool,
    bin: String,
}

#[derive(Debug, Deserialize)]
struct ScriptSpec {
    url: String,
    cmd: String,
    #[serde(default)]
    args: String,
    #[serde(default)]
    bin: String,
    #[serde(default)]
    env: Vec<(String, String)>,
}

impl Component {
    pub fn resolve_placeholders(&mut self, ctx: &Context) -> &mut Self {
        match &mut self.installer {
            Installer::BuildSource(_spec) => {}
            Installer::PythonVenv(spec) => {
                spec.pkg = spec.pkg.replace("{name}", &self.meta.name);
                spec.bin = spec.bin.replace("{name}", &self.meta.name);
            }
            Installer::ReleaseAsset(spec) => {
                // Tag
                spec.tag = if spec.tag.is_empty() {
                    self.meta.version.clone()
                } else {
                    spec.tag.replace("{version}", &self.meta.version)
                };
                // Asset
                spec.asset = spec
                    .asset
                    .replace("{name}", &self.meta.name)
                    .replace("{version}", &self.meta.version);
                // Binary
                spec.bin = spec
                    .bin
                    .replace("{asset}", &spec.asset)
                    .replace("{name}", &self.meta.name)
                    .replace("{version}", &self.meta.version);
            }
            Installer::RunScript(spec) => {
                // XXX: Required for opencode, remove if that is confirmed to use ReleaseAsset
                let install_prefix = ctx.install_prefix.to_string_lossy();
                spec.args = spec.args.replace("{version}", &self.meta.version);
                spec.bin = spec.bin.replace("{install_prefix}", &install_prefix);
                spec.env.iter_mut().for_each(|(_, v)| {
                    *v = v.replace("{install_prefix}", &install_prefix);
                });
            }
        }
        self
    }

    pub fn install(&self, ctx: &Context) -> utils::Result<()> {
        let res = match &self.installer {
            Installer::BuildSource(spec) => build_from_source(ctx, &self.meta, spec),
            Installer::PythonVenv(spec) => install_to_python_venv(ctx, &self.meta, spec),
            Installer::ReleaseAsset(spec) => fetch_and_install_asset(ctx, &self.meta, spec),
            Installer::RunScript(spec) => fetch_and_run_script(ctx, &self.meta, spec),
        };
        res.map_err(|e| format!("Component installation failed: {}\n{e}", self.meta.name).into())
    }
}

fn build_from_source(_ctx: &Context, _meta: &Metadata, _spec: &BuildSpec) -> utils::Result<()> {
    Ok(())
}

fn install_to_python_venv(ctx: &Context, meta: &Metadata, spec: &VenvSpec) -> utils::Result<()> {
    let venv_name = format!(".{}", meta.name);
    let bin_dir = ctx.install_prefix.join("bin");
    let venv_dir = bin_dir.join(&venv_name);

    // Delete existing virtual environment, if any
    if venv_dir.exists() {
        fs::remove_dir_all(&venv_dir)?;
    }

    // Create python virtual environment and install package
    let status = Command::new("python3")
        .args(["-m", "venv", &venv_name])
        .current_dir(&bin_dir)
        .status()?;
    if !status.success() {
        return Err(format!("Venv creation failed: {}", status).into());
    }
    let status = Command::new(venv_dir.join("bin/pip"))
        .args(["install", &format!("{}=={}", spec.pkg, meta.version)])
        .status()?;
    if !status.success() {
        return Err(format!("Installation failed for {}: {}", spec.pkg, status).into());
    }

    // Create symlink to install location, ONLY if specified
    let bin_dst = bin_dir.join(match spec.bin.rsplit_once('/') {
        None => spec.bin.as_str(),
        Some((_, basename)) => basename,
    });
    if bin_dst.exists() {
        fs::remove_file(&bin_dst)?;
    }
    self::create_symlink(venv_dir.join(&spec.bin), bin_dst)?;

    Ok(())
}

fn fetch_and_install_asset(
    ctx: &Context,
    meta: &Metadata,
    spec: &ReleaseSpec,
) -> utils::Result<()> {
    // Ensure working directory for current component exists
    let work_dir = ctx.temp_dir.join(&meta.name);
    fs::create_dir_all(&work_dir)
        .map_err(|e| format!("Failed to create working directory: {e}"))?;

    // Download the asset and get its filename
    let asset_path = {
        // Construct the URL to download the asset
        let url = format!(
            "https://github.com/{}/releases/download/{}/{}{}",
            spec.repo, spec.tag, spec.asset, spec.ext
        );
        dbg!(&url);

        // Construct the asset file path
        let asset_path = ctx
            .temp_dir
            .join(format!("{}-{}{}", meta.name, meta.version, spec.ext));

        // Get total size and stream the download with progress
        self::fetch_asset_with_progress(&url, &asset_path)?;

        asset_path
    };

    // Extract asset into the working directory based on its extension
    let asset = File::open(&asset_path)?; // Re-open file for reading
    match spec.ext.as_str() {
        ".tar.gz" => {
            let gz = GzDecoder::new(&asset);
            let mut tar = tar::Archive::new(gz);
            tar.unpack(&work_dir)?;
        }

        ".tar" => {
            let mut tar = tar::Archive::new(&asset);
            tar.unpack(&work_dir)?;
        }

        ".gz" => {
            let gz = GzDecoder::new(&asset);
            let mut extracted = File::create(work_dir.join(&spec.bin))?;
            std::io::copy(&mut std::io::BufReader::new(gz), &mut extracted)?;
        }

        ".zip" | ".vsix" => {
            let mut zip = zip::ZipArchive::new(asset)?;
            zip.extract(&work_dir)?;
        }

        "" => fs::rename(&asset_path, work_dir.join(&spec.bin))?,

        _ => return Err(format!("Unsupported asset file extension: {}", spec.ext).into()),
    }

    // Ensure the binary is executable before installation
    // NOTE: Any Windows file with extension '.exe', '.bat', and '.cmd' can always be executed
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(work_dir.join(&spec.bin), fs::Permissions::from_mode(0o755))?;
    }

    // Get binary installation directory and destination file path
    let bin_dir = ctx.install_prefix.join("bin");
    let bin_dst = bin_dir.join(match spec.bin.rsplit_once('/') {
        None => spec.bin.as_str(),
        Some((_, basename)) => basename,
    });

    // Handle final binary installation
    if bin_dst.exists() {
        fs::remove_file(&bin_dst)?; // Remove existing binary
    }
    if spec.pkg {
        // Install package
        let pkg_dst = bin_dir.join(format!(".{}", meta.name));
        if pkg_dst.exists() {
            fs::remove_dir_all(&pkg_dst)?; // Remove existing package
        }
        fs::rename(&work_dir, &pkg_dst)?;

        // Create symlink to binary inside package
        self::create_symlink(pkg_dst.join(&spec.bin), bin_dst)?;
    } else {
        // Install binary
        fs::rename(work_dir.join(&spec.bin), &bin_dst)?;
    }

    Ok(())
}

fn fetch_and_run_script(ctx: &Context, meta: &Metadata, spec: &ScriptSpec) -> utils::Result<()> {
    // Determine script file extension from cmd
    let script_path = ctx.temp_dir.join(format!("{}.{}", meta.name, spec.cmd));

    // Fetch the script with progress
    self::fetch_asset_with_progress(&spec.url, &script_path)?;

    // Execute the script
    let status = Command::new(&spec.cmd)
        .arg(&script_path)
        .args(spec.args.split_ascii_whitespace())
        .envs(spec.env.clone())
        .status()?;
    if !status.success() {
        return Err(format!("Script execution failed: {}", status).into());
    }

    // Create symlink to install location, ONLY if specified
    if !spec.bin.is_empty() {
        // Get binary installation directory and destination file path
        let bin_dir = ctx.install_prefix.join("bin");
        let bin_dst = bin_dir.join(match spec.bin.rsplit_once('/') {
            None => spec.bin.as_str(),
            Some((_, basename)) => basename,
        });

        // Handle final binary installation
        if bin_dst.exists() {
            fs::remove_file(&bin_dst)?;
        }
        self::create_symlink(&spec.bin, bin_dst)?;
    }

    Ok(())
}

fn create_symlink<From, To>(from: From, to: To) -> utils::Result<()>
where
    From: AsRef<Path>,
    To: AsRef<Path>,
{
    #[cfg(unix)]
    return Ok(std::os::unix::fs::symlink(from, to)?);

    #[cfg(windows)]
    return Ok(std::os::windows::fs::symlink_file(from, to)?);
}

fn fetch_asset_with_progress(
    url: &String,
    asset_path: &PathBuf,
) -> Result<(), Box<dyn std::error::Error>> {
    use std::io::Read; // To read the response

    // Fetch the asset data via a blocking GET
    let mut response = reqwest::blocking::get(url)?;
    if !response.status().is_success() {
        return Err(format!("HTTP error: {}", response.status()).into());
    }
    let total_size = response.content_length().unwrap_or(0) as usize;

    // Stream the response body with progress tracking
    const BAR_WIDTH: usize = 50;
    let mut asset = File::create(&asset_path)?;
    let mut buffer = [0u8; 8192];
    let start_time = Instant::now();
    let mut downloaded = 0usize;
    loop {
        // Fetch the next chunk
        let n = response.read(&mut buffer)?;
        if n == 0 {
            if total_size > 0 {
                println!(); // Preserve progress bar if rendered
            }
            return Ok(());
        }
        let elapsed = start_time.elapsed().as_secs_f64();

        // Write fetched chunk to asset file
        asset.write_all(&buffer[..n])?;
        downloaded += n;

        // Print progress bar only if response had Content-Length
        if total_size > 0 {
            let filled = BAR_WIDTH * downloaded / total_size;
            let empty = BAR_WIDTH - filled;
            let speed = if elapsed > 0.0 {
                downloaded as f64 / elapsed / (1024.0 * 1024.0)
            } else {
                0.0
            };
            let bar = format!(
                "[{}{}] {}% {:.2} / {:.2} MB @ {:.2} MB/s\r",
                "x".repeat(filled),
                " ".repeat(empty),
                100 * downloaded / total_size,
                downloaded as f64 / (1024.0 * 1024.0),
                total_size as f64 / (1024.0 * 1024.0),
                speed
            );
            print!("{}", bar);
            std::io::stdout().flush()?;
        }
    }
}
