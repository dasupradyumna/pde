use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub component: Vec<Component>,
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
pub enum Installer {
    BuildSource {
        repo: String,
        commands: Vec<String>,
    },
    ReleaseAsset {
        repo: String,
        asset: String,
        asset_ext: String, // TODO: is this needed? depends on reqwest logic
    },
}

impl Component {
    pub fn new(name: String, group: Group, version: String, installer: Installer) -> Self {
        Component {
            name,
            group,
            version,
            installer,
        }
    }

    pub fn install(&self) {
        match &self.installer {
            Installer::BuildSource { repo, commands } => build_from_source(),
            Installer::ReleaseAsset {
                repo,
                asset,
                asset_ext,
            } => download_release_asset(),
        }
    }
}

fn build_from_source() {}

fn download_release_asset() {}
