# ThunderFlash

> This project is designed to simplify the setup of Thunderstore modpacks, especially for users who prefer not to use a mod manager or have friends who find mod managers cumbersome.

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/RatserX/thunderstore-modpack-script/powershell.yml)
![GitHub Release](https://img.shields.io/github/v/release/RatserX/thunderstore-modpack-script)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/H2H11DGC3V)

It is important to note that this project is not intended to replace tools like [r2modman](https://github.com/ebkr/r2modmanPlus) or [Gale](https://github.com/Kesomannen/gale). These tools are highly recommended for managing mods effectively, and their use is strongly encouraged.

## Usage

This project offers a collection of PowerShell scripts designed to streamline the setup of Thunderstore modpacks. Below is a list of supported games, each linking to its respective modpack setup guide:

| Game           | Modpacks                                 |
|----------------|------------------------------------------|
| Lethal Company | [Setup Guide](./docs/LETHALCOMPANY.md)   |
| R.E.P.O.       | [Setup Guide](./docs/REPO.md)            |

## Contributing

The initial release of this project includes scripts for my own modpacks. If you would like to add support for additional modpacks, you can either fork the project or submit a pull request.

To contribute a new modpack, navigate to the `modpacks` directory and locate the `.yml` file corresponding to the game you want to add the modpack to. If no such file exists, create one using the format provided in `example.yml`. Ensure the `.yml` file name matches the game name, written in lowercase and without special characters. 

Within the `.yml` file, add a new entry to the `modpacks` list with the relevant modpack details. The `powershell.yml` GitHub Actions workflow will automatically generate the necessary scripts (e.g., install, uninstall) based on the provided `base` scripts.
