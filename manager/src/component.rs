//////////////////////////////////// MANIFEST COMPONENT METADATA ///////////////////////////////////

use crate::arguments::Context;
use crate::log;
use crate::utils;
use flate2::read::GzDecoder;
use serde::Deserialize;
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;
use xz2::read::XzDecoder;

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub list: Vec<Component>,
}

#[derive(Debug, Deserialize)]
pub struct Component {
    #[allow(dead_code)]
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
    repo: String,
    #[serde(default)]
    tag: String,
    commands: Vec<String>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(default)]
struct VenvSpec {
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
    install_as: InstallAssetAs,
    path: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum InstallAssetAs {
    Copy,
    Folders,
    Symlink,
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
            Installer::BuildSource(spec) => {
                spec.tag = if spec.tag.is_empty() {
                    self.meta.version.clone()
                } else {
                    spec.tag.replace("{version}", &self.meta.version)
                };
                spec.commands.iter_mut().for_each(|cmd| {
                    *cmd = cmd.replace("{install_prefix}", &ctx.install_prefix.to_string_lossy())
                });
            },
            Installer::PythonVenv(spec) => {
                if spec.pkg.is_empty() {
                    spec.pkg = self.meta.name.clone();
                } else {
                    spec.pkg = spec.pkg.replace("{name}", &self.meta.name);
                }
                if spec.bin.is_empty() {
                    spec.bin = spec.pkg.clone();
                }
            },
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
                // Path
                spec.path = spec
                    .path
                    .replace("{asset}", &spec.asset)
                    .replace("{name}", &self.meta.name)
                    .replace("{version}", &self.meta.version);
            },
            Installer::RunScript(_) => {},
        }
        log!(info, "- Resolved placeholders in component fields");
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

fn build_from_source(ctx: &Context, meta: &Metadata, spec: &BuildSpec) -> utils::Result<()> {
    // Clone specific tag of GitHub repository to temp directory
    let clone_dir = ctx.temp_dir.join(&meta.name);
    log!(info, "- Cloning repository to {:?} ...", clone_dir);
    utils::clone_github(&spec.repo, &spec.tag, &clone_dir, true)?;

    // Execute build command list sequentially
    for command in &spec.commands {
        log!(info, "- Executing command: {command:?} ...");

        // Split build command into program & arguments
        let mut parts = command.split_ascii_whitespace();
        let prog = parts.next().unwrap_or("");
        let args: Vec<&str> = parts.collect();
        log!(debug, "Program: {prog} | Arguments: {args:?}");

        // Execute the build command
        let status = Command::new(&prog).args(&args).current_dir(&clone_dir).status()?;
        if !status.success() {
            return Err(format!("Build command failed: {status}").into());
        }
    }

    log!(info, "- Building from source completed!");
    Ok(())
}

fn install_to_python_venv(ctx: &Context, meta: &Metadata, spec: &VenvSpec) -> utils::Result<()> {
    let venv_name = format!(".{}", meta.name);
    let bin_dir = ctx.install_prefix.join("bin");
    let venv_dir = bin_dir.join(&venv_name);
    log!(info, "- Python virtual environment target path: {venv_dir:?}");

    // Delete existing virtual environment, if any
    if venv_dir.exists() {
        fs::remove_dir_all(&venv_dir)?;
        log!(debug, "Removed existing virtual environment");
    }

    // Create python virtual environment and install package
    let status = Command::new("python3")
        .args(["-m", "venv", &venv_name])
        .current_dir(&bin_dir)
        .status()?;
    if !status.success() {
        return Err(format!("Venv creation failed: {}", status).into());
    }
    log!(info, "- Created virtual environment successfully");
    let status = Command::new(venv_dir.join("bin/pip"))
        .args(["install", &format!("{}=={}", spec.pkg, meta.version)])
        .status()?;
    if !status.success() {
        return Err(format!("Installation failed for {}: {}", spec.pkg, status).into());
    }
    log!(info, "- Installed {venv_name:?} package in virtual environment");

    // Create symlink to install location, ONLY if specified
    let bin_dst = bin_dir.join(&spec.bin);
    if bin_dst.exists() {
        fs::remove_file(&bin_dst)?;
        log!(debug, "Removed existing symlink to package binary");
    }
    let bin_src = venv_dir.join("bin").join(&spec.bin);
    utils::create_symlink(&bin_src, &bin_dst)?;
    log!(info, "- Created a symlink: {bin_src:?} -> {bin_dst:?}");

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
    log!(debug, "Created working directory: {work_dir:?}");

    // Download the asset and get its filename
    let asset_path = {
        // Construct the URL to download the asset
        let url = format!(
            "https://github.com/{}/releases/download/{}/{}{}",
            spec.repo, spec.tag, spec.asset, spec.ext
        );
        log!(debug, "Asset URL: {url}");

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
            log!(info, "- Extracted TarGz compressed archive to {work_dir:?}");
        },

        ".tar.xz" => {
            let xz = XzDecoder::new(&asset);
            let mut tar = tar::Archive::new(xz);
            tar.unpack(&work_dir)?;
            log!(info, "- Extracted TarXz compressed archive to {work_dir:?}");
        },

        ".tar" => {
            let mut tar = tar::Archive::new(&asset);
            tar.unpack(&work_dir)?;
            log!(info, "- Extracted Tar archive to {work_dir:?}");
        },

        ".gz" => {
            let gz = GzDecoder::new(&asset);
            let mut extracted = File::create(work_dir.join(&spec.path))?;
            std::io::copy(&mut std::io::BufReader::new(gz), &mut extracted)?;
            log!(info, "- Extracted Gz compressed file to {work_dir:?}");
        },

        ".xz" => {
            let xz = XzDecoder::new(&asset);
            let mut extracted = File::create(work_dir.join(&spec.path))?;
            std::io::copy(&mut std::io::BufReader::new(xz), &mut extracted)?;
            log!(info, "- Extracted Xz compressed file to {work_dir:?}");
        },

        ".zip" | ".vsix" => {
            let mut zip = zip::ZipArchive::new(asset)?;
            zip.extract(&work_dir)?;
            log!(info, "- Extracted Zip file to {work_dir:?}");
        },

        "" => {
            fs::rename(&asset_path, work_dir.join(&spec.path))?;
            log!(info, "- Moved raw asset file to {work_dir:?}");
        },

        _ => return Err(format!("Unsupported asset file extension: {}", spec.ext).into()),
    }

    // Ensure the binary is executable before installation
    // NOTE: Any Windows file with extension '.exe', '.bat', and '.cmd' can always be executed
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(work_dir.join(&spec.path), fs::Permissions::from_mode(0o755))?;
        log!(debug, "Ensured binary is executable [Unix]");
    }

    // Get binary installation directory and destination file path
    let bin_dir = ctx.install_prefix.join("bin");
    let bin_dst = bin_dir.join(match spec.path.rsplit_once('/') {
        None => spec.path.as_str(),
        Some((_, basename)) => basename,
    });

    // Handle final binary installation
    if bin_dst.exists() {
        fs::remove_file(&bin_dst)?; // Remove existing binary
        log!(debug, "Removed existing binary in installation directory");
    }
    match &spec.install_as {
        InstallAssetAs::Copy => {
            // Install binary
            fs::rename(work_dir.join(&spec.path), &bin_dst)?;
            log!(info, "- Installed binary to {bin_dst:?}");
        },
        InstallAssetAs::Folders => {
            // Get the root directory inside asset
            let root_dir = work_dir.join(&spec.path);
            if !root_dir.exists() || !root_dir.is_dir() {
                return Err(format!(
                    "Folders install path not found or not a directory: {root_dir:?}",
                )
                .into());
            }
            log!(debug, "Package root directory: {root_dir:?}");

            // Check for each standard directory
            for folder_name in &["bin", "lib", "share"] {
                // Get source and destination directory paths
                let src_dir = root_dir.join(folder_name);
                let dst_dir = ctx.install_prefix.join(folder_name);
                if !src_dir.exists() {
                    continue;
                }

                // Iterate over every entry found (file or directory)
                log!(info, "- Moving items from {root_dir:?} to {:?}", ctx.install_prefix);
                for entry in fs::read_dir(&src_dir)? {
                    // Get source and destination entry paths
                    let entry = entry?;
                    let src_entry = entry.path();
                    let dst_entry = dst_dir.join(entry.file_name());

                    // Remove existing entry
                    if dst_entry.exists() {
                        if dst_entry.is_dir() {
                            fs::remove_dir_all(&dst_entry)?;
                        } else {
                            fs::remove_file(&dst_entry)?;
                        }
                        log!(debug, "Removed existing item: {dst_entry:?}");
                    }
                    fs::rename(&src_entry, &dst_entry)?;
                    log!(info, "  - Moved item: {:?}", entry.file_name());
                }
            }
        },
        InstallAssetAs::Symlink => {
            // Install asset as package
            let pkg_dst = bin_dir.join(format!(".{}", meta.name));
            if pkg_dst.exists() {
                fs::remove_dir_all(&pkg_dst)?; // Remove existing package
                log!(debug, "Removed existing package in installation directory");
            }
            fs::rename(&work_dir, &pkg_dst)?;
            log!(info, "- Installed extracted package to {pkg_dst:?}");

            // Create symlink to binary inside package
            let bin_src = pkg_dst.join(&spec.path);
            utils::create_symlink(&bin_src, &bin_dst)?;
            log!(info, "- Created a symlink: {bin_src:?} -> {bin_dst:?}");
        },
    }

    Ok(())
}

fn fetch_and_run_script(ctx: &Context, meta: &Metadata, spec: &ScriptSpec) -> utils::Result<()> {
    // Determine script file extension from cmd
    let script_path = ctx.temp_dir.join(format!("{}.{}", meta.name, spec.cmd));
    log!(debug, "Download script path: {script_path:?}");

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
    log!(info, "- Executed script successfully");

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
            log!(debug, "Removed existing binary");
        }
        utils::create_symlink(&spec.bin, &bin_dst)?;
        log!(info, "- Created a symlink: {:?} -> {bin_dst:?}", spec.bin);
    }

    Ok(())
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
    log!(info, "- Fetching asset to {asset_path:?} ...\n");
    loop {
        // Fetch the next chunk
        let n = response.read(&mut buffer)?;
        if n == 0 {
            if total_size > 0 {
                println!("\n"); // Preserve progress bar if rendered
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
                "▐{}{}▌ {}% {:.2} / {:.2} MB @ {:.2} MB/s\r",
                "█".repeat(filled),
                " ".repeat(empty),
                100 * downloaded / total_size,
                downloaded as f64 / (1024.0 * 1024.0),
                total_size as f64 / (1024.0 * 1024.0),
                speed
            );
            print!("    {}", bar);
            std::io::stdout().flush()?;
        }
    }
}
