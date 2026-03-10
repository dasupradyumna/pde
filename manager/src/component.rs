use crate::arguments::Context;
use crate::utils;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub list: Vec<Component>,
}

#[derive(Debug, Deserialize)]
pub struct Component {
    name: String,
    group: Group,
    version: String,
    installer: Installer,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Group {
    AI,
    Git,
    Neovim,
    WezTerm,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum Installer {
    BuildSource(BuildSpec),
    ReleaseAsset(ReleaseSpec),
}

#[derive(Debug, Deserialize)]
struct BuildSpec {
    repo: String,
    commands: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct ReleaseSpec {
    repo: String,
    asset: String,
    asset_ext: String,
    bin_path: String,
}

impl Component {
    pub fn install(&self, ctx: &Context) -> utils::Result<()> {
        let res = match &self.installer {
            Installer::BuildSource(spec) => build_from_source(ctx, &self.version, spec),
            Installer::ReleaseAsset(spec) => download_release_asset(ctx, &self.version, spec),
        };
        res.map_err(|e| format!("Installation failed: {}\n{e}", self.name).into())
    }
}

fn build_from_source(_ctx: &Context, _version: &String, _spec: &BuildSpec) -> utils::Result<()> {
    Ok(())
}

fn download_release_asset(
    ctx: &Context,
    version: &String,
    spec: &ReleaseSpec,
) -> utils::Result<()> {
    Ok(())
}
