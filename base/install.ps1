# Define global variables
$gameDirectory = "GAME_DIRECTORY"
$modpackAuthor = "MODPACK_AUTHOR"
$modpackName = "MODPACK_NAME"
$modpackVersion = "MODPACK_VERSION"

# Change preference variables
$ErrorActionPreference = "Stop"

function Install-Base {
    param (
        [string]$GameDirectory,
        [string]$ModpackAuthor,
        [string]$ModpackName,
        [string]$ModpackVersion
    )

    # Ask the user for the game path
    $selectedPath = Find-GamePath -GameDirectory $GameDirectory
    $gamePath = Get-GamePath -SelectedPath $selectedPath

    # Ask the user to confirm the game path
    $isValidGamePath = Confirm-GamePath -GamePath $gamePath
    if ($isValidGamePath -eq $false) {
        Write-Output "Confirmation failed. Exiting..."
        exit
    }

    # Ensure the game directory exists
    if (!(Test-Path -Path $gamePath)) {
        New-Item -ItemType Directory -Path $gamePath | Out-Null
    }

    # Delete the "BepInEx" directory inside the game path
    $gameBepInExPath = Join-Path -Path $gamePath -ChildPath "BepInEx"
    if (Test-Path -Path $gameBepInExPath) {
        Remove-Item -Recurse -Force -Path $gameBepInExPath
    }

    # Download the modpack
    $modpackInfo = "$ModpackAuthor-$ModpackName-$ModpackVersion"
    $modpackUri = "https://thunderstore.io/package/download/$ModpackAuthor/$ModpackName/$ModpackVersion/"
    $modpackZipPath = "$gamePath\$modpackInfo.zip"
    Invoke-WebRequest -Uri $modpackUri -OutFile $modpackZipPath

    # Extract the modpack
    Expand-Archive -Path $modpackZipPath -DestinationPath $gamePath -Force
    Remove-Item -Force -Path $modpackZipPath

    # Read the manifest.json file
    $manifestJsonPath = Join-Path -Path $gamePath -ChildPath "manifest.json"
    $manifestJson = Get-Content -Path $manifestJsonPath | ConvertFrom-Json
    $dependencies = $manifestJson.dependencies

    # Check the mod loader
    $modLoaderType, $modLoaderPath, $dependencyPath, $modLoaderInfo = Find-ModLoader -GamePath $gamePath -Dependencies $dependencies
    Write-Output "Installing mod loader: $modLoaderInfo."

    # Ensure the mod loader directory exists
    if (!(Test-Path -Path $modLoaderPath)) {
        New-Item -ItemType Directory -Path $modLoaderPath | Out-Null
    }

    # Ensure the dependency directory exists
    if (!(Test-Path -Path $dependencyPath)) {
        New-Item -ItemType Directory -Path $dependencyPath | Out-Null
    }

    # Process each dependency
    foreach ($dependency in $dependencies) {
        $modFields = $dependency -split "-"
        $modAuthor, $modName, $modVersion = $modFields
        $modKey = "$modAuthor-$modName"
        $modInfo = "$modKey-$modVersion"

        # Define the dependency extract directory
        $dependencyExtractPath = "$dependencyPath\$modKey"
        Write-Output "Installing mod: $modInfo."

        # Ensure the dependency extract directory exists
        if (!(Test-Path -Path $dependencyExtractPath)) {
            New-Item -ItemType Directory -Path $dependencyExtractPath | Out-Null
        }

        # Download the mod
        $modUri = "https://thunderstore.io/package/download/$modAuthor/$modName/$modVersion/"
        $dependencyZipPath = "$dependencyExtractPath.zip"
        Invoke-WebRequest -Uri $modUri -OutFile $dependencyZipPath

        # Extract the mod
        Expand-Archive -Path $dependencyZipPath -DestinationPath $dependencyExtractPath -Force
        Remove-Item -Force -Path $dependencyZipPath

        # Check for "BepInExPack" directory
        $bepInExPackPath = Join-Path -Path $dependencyExtractPath -ChildPath "BepInExPack"
        if (Test-Path -Path $bepInExPackPath) {
            Get-ChildItem -Path $bepInExPackPath -File -Depth 1 | Move-Item -Destination $gamePath -Force
            Get-ChildItem -Path $bepInExPackPath -Recurse | Move-Item -Destination $dependencyExtractPath -Force
            Remove-Item -Recurse -Force -Path $bepInExPackPath
        }

        # Check for "BepInEx" directory
        $bepInExPath = Join-Path -Path $dependencyExtractPath -ChildPath "BepInEx"
        if (Test-Path -Path $bepInExPath) {
            Get-ChildItem -Path $bepInExPath -Recurse | Move-Item -Destination $dependencyExtractPath -Force
            Remove-Item -Recurse -Force -Path $bepInExPath
        }

        # Check for other directories and move their contents
        Get-ChildItem -Path $dependencyExtractPath -Directory | ForEach-Object {
            $bepInExDirectory = $_.Name
            $bepInExPath = $_.FullName

            # Skip directories named the same as the mod
            if ($bepInExDirectory -eq $modName) {
                return
            }

            # Define the list of special directories
            $specialDirectories = @("patchers", "plugins")
            $isSpecialDirectory = $specialDirectories -contains $bepInExDirectory

            # Define the mod directory
            $modPath = "$modLoaderPath\$bepInExDirectory"
            if ($isSpecialDirectory) {
                $modPath = "$modPath\$modKey"
            }

            Write-Output "Configuring mod: $modInfo."

            # Ensure the mod directory exists
            if (!(Test-Path -Path $modPath)) {
                New-Item -ItemType Directory -Path $modPath | Out-Null
            }

            Get-ChildItem -Path $bepInExPath -Depth 1 | ForEach-Object {
                $isContainer = $_.PSIsContainer
                $item = $_.Name
                $itemPath = $_.FullName

                try {
                    if ($isSpecialDirectory) {
                        Copy-Item -Path $itemPath -Destination $modPath -Recurse -Force
                        Remove-Item -Recurse -Force -Path $itemPath
                    }
                    elseif ($isContainer) {
                        Move-Item -Path $itemPath -Destination $modPath -Force
                    }
                    else {
                        Move-Item -Path $itemPath -Destination $modPath
                    }
                }
                catch [System.IO.IOException] {
                    Write-Output "Unable to move $item to $modPath."
                }
                catch {
                    Write-Output "An error occurred that could not be resolved."
                    Write-Output $_
                }
            }

            Remove-Item -Recurse -Force -Path $bepInExPath
        }

        # Cleanup the install directories
        $dependencyItemsCount = Get-ChildItem -Path $dependencyExtractPath -Recurse | Measure-Object -Property Length -Sum
        if ($modLoaderInfo -eq $modInfo -or $dependencyItemsCount -eq 0) {
            Remove-Item -Recurse -Force -Path $dependencyExtractPath
        }
    }

    Write-Output "$modpackInfo has been successfully installed to $gamePath."   
}

function Confirm-GamePath {
    param (
        [string]$GamePath
    )

    $gamePathChoices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Proceed")
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Exit")
    )

    $gamePathChoice = $host.UI.PromptForChoice("Game path: $GamePath.", "Is this correct?", $gamePathChoices, -1)
    return ![System.Convert]::ToBoolean($gamePathChoice)
}

function Find-GamePath {
    param (
        [string]$GameDirectory
    )

    $driveLetters = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $gameUnqualifiedPaths = @(
        "\$GameDirectory",
        "\steamapps\common\$GameDirectory"
    )

    $storeUnqualifiedPaths = @(
        $(Split-Path -Path "$([Environment]::GetFolderPath("LocalApplicationData"))\EpicGames" -NoQualifier),
        $(Split-Path -Path "$([Environment]::GetFolderPath("LocalApplicationData"))\Steam" -NoQualifier),
        $(Split-Path -Path "$([Environment]::GetFolderPath("ProgramFilesX86"))\Epic Games" -NoQualifier),
        $(Split-Path -Path "$([Environment]::GetFolderPath("ProgramFilesX86"))\Steam" -NoQualifier),
        "\SteamLibrary"
    )

    $resolvedGamePath = Resolve-Path -Path "."
    foreach ($driveLetter in $driveLetters) {
        foreach ($storeUnqualifiedPath in $storeUnqualifiedPaths) {
            $storePath = Join-Path -Path $driveLetter -ChildPath $storeUnqualifiedPath
            foreach ($gameUnqualifiedPath in $gameUnqualifiedPaths) {
                $gamePath = Join-Path -Path $storePath -ChildPath $gameUnqualifiedPath
                if (Test-Path -Path $gamePath) {
                    $resolvedGamePath = Resolve-Path -Path $gamePath
                    return $resolvedGamePath
                }
            }
        }
    }

    return $resolvedGamePath
}

function Get-GamePath {
    param (
        [string]$InitialPath = ""
    )

    $isFormsAvailable = $true
    $selectedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InitialPath)
    $gamePath = $selectedPath

    try {
        Add-Type -AssemblyName System.Windows.Forms
    }
    catch {
        $isFormsAvailable = $false
    }

    if ($isFormsAvailable) {
        $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
            Description  = "Select the game folder"
            SelectedPath = $selectedPath
        }

        $null = [System.Windows.Forms.Application]::EnableVisualStyles()
        $folderBrowserOwner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
        if ($folderBrowserDialog.ShowDialog($folderBrowserOwner) -eq [System.Windows.Forms.DialogResult]::OK) {
            $gamePath = $folderBrowserDialog.SelectedPath
        }

        $folderBrowserDialog.Dispose()
        $folderBrowserOwner.Dispose()
    }
    else {
        while ($true) {
            $gamePath = Read-Host "Enter the game path (Default: $selectedPath)"
            if ([string]::IsNullOrWhiteSpace($gamePath)) {
                $gamePath = $selectedPath
            }

            if (Test-Path -Path $gamePath) {
                break
            }
        }
    }

    $resolvedGamePath = Resolve-Path -Path $gamePath
    return $resolvedGamePath
}

function Find-ModLoader {
    param (
        [string]$GamePath,
        [string[]]$Dependencies
    )

    $modLoaders = @{
        "Base-Spark" = @(0, "$GamePath\Spark", "$GamePath\Spark\mods", "0.0.0")
        "BepInEx-BepInExPack" = @(1, "$GamePath\BepInEx", "$GamePath\BepInEx\plugins")
        "LavaGang-MelonLoader" = @(2, "$GamePath\MelonLoader", "$GamePath\Mods")
    }

    foreach ($dependency in $dependencies) {
        $modLoaderAuthor, $modLoaderName, $modLoaderVersion = $dependency -split "-"
        $modLoaderKey = "$modLoaderAuthor-$modLoaderName"

        if ($modLoaders.ContainsKey($modLoaderKey)) {
            $modLoaderInfo = "$modLoaderKey-$modLoaderVersion"
            $modLoader = $modLoaders[$modLoaderKey]
            $modLoader += $modLoaderInfo
            return $modLoader
        }
    }

    return $modLoaders["Base-Spark"]
}

Install-Base -GameDirectory $gameDirectory -ModpackAuthor $modpackAuthor -ModpackName $modpackName -ModpackVersion $modpackVersion
