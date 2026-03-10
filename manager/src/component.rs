use crate::arguments::Context;
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
    asset_ext: String, // TODO: is this needed? depends on reqwest logic
}

impl Component {
    pub fn install(&self, ctx: &Context) {
        match &self.installer {
            Installer::BuildSource(spec) => build_from_source(ctx, spec),
            Installer::ReleaseAsset(spec) => download_release_asset(ctx, spec),
        }
    }
}

fn build_from_source(ctx: &Context, spec: &BuildSpec) {}

fn download_release_asset(ctx: &Context, spec: &ReleaseSpec) {}
